# Whisper transcribe

Local, speaker-labeled transcripts of two-person calls, with no meeting bot. Record in OBS with your mic and the other person's audio on separate tracks; this script turns the file into a clean transcript that Claude can read, with talk-time stats.

On an NVIDIA GPU it takes about a minute per 30-minute call (faster-whisper `large-v3`). It also runs on CPU and Macs with `--device cpu`, more slowly.

**Get consent before you record.** In many places, including California, everyone on the call has to agree to being recorded.

## Why separate tracks

Guessing who's speaking from one mixed track (diarization) gets it wrong a lot. Here the speaker labels come from which track the audio is on, so they're reliable. Each track is transcribed on its own with word timestamps, then the words are interleaved by time.

The hard part is **bleed**. Without headphones, your mic picks up the other person faintly. The script drops a word from your track when it's quiet there and much louder on the other track at the same moment. A second rule catches low mic gain, where your own speech is quiet too and only the raw gap between the tracks gives the bleed away. Check `bleed_words_dropped` in the output after the first few runs.

## OBS setup

Settings → Output → Recording: format **mkv**, audio tracks **1, 2 and 3** ticked. Then in Edit → Advanced Audio Properties:
- **Mic**: tracks 1 and 2
- **Desktop audio**: tracks 1 and 3

Track 1 is the normal mix for listening back; tracks 2 and 3 are what the script uses. If your layout differs, pass `--mic-track` and `--desktop-track` (counted from 0 among the audio streams).

## Install

```bash
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt     # macOS/Linux: .venv/bin/pip
```

On a Mac, drop the two `nvidia-*` lines from `requirements.txt` first.

## Usage

```bash
.venv/Scripts/python transcribe.py "2026-11-04 10-00-00.mkv" call-notes \
  --me "Me" --them "Alex" --title "Intro call with Alex" \
  --prompt "Alex, Priya, Kubernetes, MEDDPICC."
```

This writes:
- `call-notes.md`: the readable transcript, with talk-time share, word counts and your five longest answers at the top
- `call-notes.json`: turns, stats, and every word dropped as bleed (so you can check the filter)

`--prompt` steers spelling of names and jargon, which Whisper otherwise mishears. Still check names before you quote anyone.

## Notes

- Audio is decoded with the ffmpeg bundled in `imageio-ffmpeg`, so there's nothing else to install, and it sidesteps a PyAV 19 bug in faster-whisper's own decoder.
- Short interjections ("yeah", "right") that land inside the other person's turn are folded into it as an inline note, so long answers aren't chopped into pieces.
- Transcripts are private. Keep them out of git (add `*.md` outputs to `.gitignore` wherever you save them).
