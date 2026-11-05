"""Transcribe a two-person call recorded in OBS (separate mic and desktop tracks) into a
speaker-labeled transcript, locally, with faster-whisper.

OBS layout this expects (Advanced Audio Properties):
  audio track 1 = mix, track 2 = mic only (you), track 3 = desktop audio only (them)

Usage:
  python transcribe.py RECORDING.mkv OUT_BASENAME --me "Me" --them "Alex" --title "..." --prompt "names, jargon"
Writes OUT_BASENAME.md (readable transcript) and OUT_BASENAME.json (words, turns, stats).

How speakers are separated: each track is transcribed on its own, with word timestamps.
A word is dropped as bleed when it is quiet on its own track (well under that track's speech
level) while the other track is clearly louder at the same moment. Remaining words are
interleaved by time, so the turn order is reliable to within a fraction of a second.
"""
import argparse
import glob
import json
import os
import subprocess
import sys

import numpy as np

# Windows + NVIDIA: ctranslate2 finds cuBLAS/cuDNN via PATH; the nvidia-* pip wheels ship them here.
if os.name == "nt":
    _site = os.path.join(sys.prefix, "Lib", "site-packages", "nvidia")
    for _bin in glob.glob(os.path.join(_site, "*", "bin")):
        os.environ["PATH"] = _bin + os.pathsep + os.environ["PATH"]
        os.add_dll_directory(_bin)

import imageio_ffmpeg  # noqa: E402
from faster_whisper import WhisperModel  # noqa: E402

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
SR = 16000
FRAME = 320  # 20 ms level frames


def load_track(src, audio_index):
    """Decode one audio stream to 16 kHz mono float32 (audio_index is 0-based among audio streams).
    Decoded here rather than by faster-whisper, whose PyAV path breaks on av>=19."""
    raw = subprocess.run(
        [FFMPEG, "-loglevel", "error", "-i", src, "-map", f"0:a:{audio_index}",
         "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0


def frame_db(audio):
    f = audio[: len(audio) // FRAME * FRAME].reshape(-1, FRAME)
    return 20 * np.log10(np.sqrt((f ** 2).mean(axis=1)) + 1e-9)


def level(db, start, end):
    """Loudest 20 ms frame inside a word's span."""
    a, b = int(start * SR / FRAME), max(int(end * SR / FRAME), int(start * SR / FRAME) + 1)
    seg = db[a:b]
    return float(seg.max()) if len(seg) else -120.0


def transcribe_words(model, audio, speaker, prompt):
    segments, _ = model.transcribe(
        audio, language="en", beam_size=5, word_timestamps=True, vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 500},
        condition_on_previous_text=False, initial_prompt=prompt,
    )
    words = []
    for s in segments:
        for w in s.words or []:
            if w.word.strip():
                words.append({"speaker": speaker, "start": round(w.start, 2), "end": round(w.end, 2),
                              "word": w.word, "p": round(w.probability, 3)})
    return words


def drop_bleed(words, own_db, other_db, margin_db=25.0, louder_db=15.0, gap_db=20.0):
    """Split words into (kept, bleed). The speech reference is the track's 90th-percentile level.
    gap_db catches bleed when mic gain is low (speech around -60 dB): then your own speech sits
    near the reference and only the raw gap to the other track gives the bleed away."""
    ref = float(np.percentile(own_db, 90))
    kept, bleed = [], []
    for w in words:
        own = level(own_db, w["start"], w["end"])
        other = level(other_db, w["start"], w["end"])
        w["db"] = round(own, 1)
        if (own < ref - margin_db and other > own + louder_db) or other > own + gap_db:
            bleed.append(w)
        else:
            kept.append(w)
    return kept, bleed


def build_turns(words, me, backchannel_max=3, fold_gap=1.5):
    """Group time-sorted words into turns; fold short interjections that land inside the
    other person's ongoing turn into it as an inline note, so monologues aren't shredded."""
    groups = []
    for w in sorted(words, key=lambda x: x["start"]):
        if groups and groups[-1]["speaker"] == w["speaker"]:
            groups[-1]["words"].append(w)
            groups[-1]["end"] = w["end"]
        else:
            groups.append({"speaker": w["speaker"], "start": w["start"], "end": w["end"], "words": [w]})
    for g in groups:
        g["text"] = "".join(w["word"] for w in g["words"]).strip()

    turns = []
    i = 0
    while i < len(groups):
        g = groups[i]
        if (turns and i + 1 < len(groups)
                and len(g["words"]) <= backchannel_max
                and turns[-1]["speaker"] == groups[i + 1]["speaker"] != g["speaker"]
                and g["start"] - turns[-1]["end"] <= fold_gap
                and groups[i + 1]["start"] - g["end"] <= fold_gap):
            nxt = groups[i + 1]
            turns[-1]["text"] += f" *({g['speaker']}: {g['text']})* " + nxt["text"]
            turns[-1]["end"] = nxt["end"]
            turns[-1]["words"] += nxt["words"]
            turns[-1]["interjections"].append(g)
            i += 2
            continue
        turns.append({**g, "interjections": []})
        i += 1
    return turns


def ts(sec):
    sec = int(sec)
    return f"{sec // 3600}:{sec % 3600 // 60:02d}:{sec % 60:02d}" if sec >= 3600 else f"{sec // 60:02d}:{sec % 60:02d}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("recording")
    ap.add_argument("out")
    ap.add_argument("--me", default="Me")
    ap.add_argument("--them", default="Them")
    ap.add_argument("--title", default="Transcript")
    ap.add_argument("--prompt", default="", help="names and jargon to bias spelling, e.g. 'Alex, Priya, Kubernetes, MEDDPICC.'")
    ap.add_argument("--model", default="large-v3", help="smaller and faster on CPU: medium, small")
    ap.add_argument("--device", default="cuda", choices=["cuda", "cpu"], help="cpu for Macs or no NVIDIA GPU (much slower)")
    ap.add_argument("--context", default="Recorded call.", help="one punctuated sentence describing the recording")
    ap.add_argument("--mic-track", type=int, default=1, help="0-based audio stream index of the mic-only track")
    ap.add_argument("--desktop-track", type=int, default=2, help="0-based audio stream index of the desktop-only track")
    args = ap.parse_args()

    mic = load_track(args.recording, args.mic_track)
    desk = load_track(args.recording, args.desktop_track)
    mic_db, desk_db = frame_db(mic), frame_db(desk)

    # A punctuated prompt keeps large-v3 from dropping into unpunctuated lowercase.
    prompt = args.context.strip() + " " + args.prompt.strip()
    model = WhisperModel(args.model, device=args.device,
                         compute_type="float16" if args.device == "cuda" else "int8")
    print("transcribing mic track...", flush=True)
    mine = transcribe_words(model, mic, args.me, prompt)
    print("transcribing desktop track...", flush=True)
    theirs = transcribe_words(model, desk, args.them, prompt)

    mine, mine_bleed = drop_bleed(mine, mic_db, desk_db)
    theirs, theirs_bleed = drop_bleed(theirs, desk_db, mic_db)
    turns = build_turns(mine + theirs, args.me)

    speakers = (args.me, args.them)
    secs = {k: sum(w["end"] - w["start"] for w in mine + theirs if w["speaker"] == k) for k in speakers}
    nwords = {k: sum(1 for w in mine + theirs if w["speaker"] == k) for k in speakers}
    total = sum(secs.values()) or 1
    longest = sorted((t for t in turns if t["speaker"] == args.me), key=lambda t: t["end"] - t["start"], reverse=True)[:5]
    stats = {
        "duration": ts(len(mic) / SR),
        "speaking_seconds": {k: round(v) for k, v in secs.items()},
        "speaking_share_pct": {k: round(v / total * 100) for k, v in secs.items()},
        "words": nwords,
        "turns": {k: sum(1 for t in turns if t["speaker"] == k) for k in speakers},
        "longest_turns_me": [{"start": ts(t["start"]), "seconds": round(t["end"] - t["start"])} for t in longest],
        "bleed_words_dropped": {args.me: len(mine_bleed), args.them: len(theirs_bleed)},
    }

    with open(args.out + ".json", "w", encoding="utf-8") as f:
        json.dump({"recording": os.path.basename(args.recording), "stats": stats,
                   "turns": [{k: v for k, v in t.items() if k != "words"} | {"interjections": [
                       {"speaker": g["speaker"], "start": g["start"], "text": g["text"]} for g in t["interjections"]]}
                       for t in turns],
                   "dropped_as_bleed": mine_bleed + theirs_bleed}, f, indent=1)

    share = stats["speaking_share_pct"]
    lines = [
        f"# {args.title}", "",
        f"Source: `{os.path.basename(args.recording)}` ({stats['duration']}). OBS recording with separate mic and "
        f"desktop tracks, transcribed locally with faster-whisper {args.model}.",
        "Speaker labels come from which track the audio is on, not from guessing. This is a machine transcript, "
        "so names, numbers and jargon may be misheard; check the recording before quoting anyone.", "",
        f"**Speaking time:** {args.me} {share[args.me]}% ({ts(secs[args.me])}), "
        f"{args.them} {share[args.them]}% ({ts(secs[args.them])}). "
        f"**Words:** {args.me} {nwords[args.me]}, {args.them} {nwords[args.them]}. "
        f"**Longest {args.me} answers:** " + ", ".join(f"{t['start']} ({t['seconds']}s)" for t in stats["longest_turns_me"]) + ".",
        "", "---", "",
    ]
    for t in turns:
        lines += [f"**[{ts(t['start'])}] {t['speaker']}:** {t['text']}", ""]
    with open(args.out + ".md", "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(json.dumps(stats))


if __name__ == "__main__":
    main()
