# Second-model pass for Claude Code, run through the Codex CLI on a ChatGPT plan sign-in
# (no OpenAI API key, so no per-call bill; it uses your plan's Codex message allowance).
#   art  : Codex may WRITE, but only inside -Out (workspace-write sandbox rooted there).
#          Then this script renders every SVG to -Out\_renders\*.png (outside the sandbox) and hands
#          the renders back to Codex for one fix pass. -NoReview skips that pass.
#   copy : Codex is read-only; its reply lands in -Out\reply.md for Claude to curate.
# Usage: .\codex-pass.ps1 -Mode art|copy -Brief brief.md -Out <dir> [-Model gpt-6-sol] [-Effort medium] [-NoReview]
# Arguments are parsed by hand from $args (no param block).
# Windows PowerShell 5.1: keep this file ASCII-only, or 5.1 misreads it.
$Mode = $null; $Brief = $null; $Out = $null; $Model = "gpt-6-sol"; $Effort = "medium"; $Review = $true
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "-Mode"     { $Mode   = $args[++$i] }
        "-Brief"    { $Brief  = $args[++$i] }
        "-Out"      { $Out    = $args[++$i] }
        "-Model"    { $Model  = $args[++$i] }
        "-Effort"   { $Effort = $args[++$i] }
        "-NoReview" { $Review = $false }
    }
}
if ($Mode -notin @("art", "copy") -or -not $Brief -or -not $Out) {
    Write-Error "Usage: codex-pass.ps1 -Mode art|copy -Brief brief.md -Out <dir> [-Model m] [-Effort e] [-NoReview]"; exit 1
}
if (-not (Test-Path $Brief)) { Write-Error "No brief at $Brief"; exit 1 }
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = (Resolve-Path $Out).Path
# PS5.1 pipes to native exes as ASCII by default; briefs carry em dashes, prices, etc.
$OutputEncoding = New-Object System.Text.UTF8Encoding $false

function Invoke-Codex($prompt, $sandbox, $reply, $images) {
    # Windows silently falls back to read-only unless a native sandbox is chosen. "unelevated" =
    # restricted token + ACLs on the workspace; no admin, no machine-wide accounts (unlike "elevated").
    # The "-" (prompt from stdin) goes first so the variadic -i can't swallow it.
    $cx = @("exec", "-", "--model", $Model, "--sandbox", $sandbox,
            "-c", 'windows.sandbox="unelevated"', "-c", "model_reasoning_effort=`"$Effort`"",
            "--cd", $Out, "--skip-git-repo-check", "--color", "never", "--output-last-message", $reply)
    foreach ($img in $images) { $cx += @("-i", $img) }
    $t = Get-Date
    # Out-Host: otherwise codex's stdout becomes part of this function's return value.
    $prompt | & codex @cx | Out-Host
    $code = $LASTEXITCODE
    Write-Host ("codex-pass {0} model={1} exit={2} secs={3} reply={4}" -f `
        $Mode, $Model, $code, [int]((Get-Date) - $t).TotalSeconds, $reply)
    return $code
}

# Chrome can't start inside Codex's restricted token, so renders happen here, outside the sandbox.
function Render-Svgs {
    $browser = @("C:\Program Files\Google\Chrome\Application\chrome.exe",
                 "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") |
               Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $browser) { Write-Warning "No Chrome or Edge found; skipping renders and the fix pass."; return @() }
    $dir = Join-Path $Out "_renders"
    New-Item -ItemType Directory -Force $dir | Out-Null
    $profileDir = Join-Path $env:TEMP "codex-pass-chrome"
    $pngs = @()
    foreach ($svg in Get-ChildItem $Out -Filter *.svg) {
        $w = 1600; $h = 900
        try {
            $vb = ([xml](Get-Content $svg.FullName -Raw -Encoding UTF8)).DocumentElement.GetAttribute("viewBox") -split "[\s,]+"
            if ($vb.Count -eq 4) { $w = [int][double]$vb[2]; $h = [int][double]$vb[3] }
        } catch {}
        $png = Join-Path $dir ($svg.BaseName + ".png")
        $uri = ([System.Uri]$svg.FullName).AbsoluteUri
        & $browser --headless=new --disable-gpu --hide-scrollbars "--user-data-dir=$profileDir" `
            "--window-size=$w,$h" "--screenshot=$png" $uri 2>$null | Out-Null
        if (Test-Path $png) { $pngs += $png }
    }
    return $pngs
}

if ($Mode -eq "copy") {
    $rules = @"
RULES: Do not modify any files and do not run commands that change anything. Reply with text only.
Never change a number, date, name or factual claim; flag it instead if you think it is wrong.
"@
    $prompt = $rules + "`n`n" + (Get-Content $Brief -Raw -Encoding UTF8)
    exit (Invoke-Codex $prompt "read-only" (Join-Path $Out "reply.md") @())
}

$rules = @"
RULES: Save every deliverable as a file in the current directory (one file per asset, named as the brief asks).
Write nothing outside the current directory. Do not use the network. Do not install anything.
Do not try to render or screenshot your files; the caller renders them and shows you the result.
When done, reply with a list of the files you wrote and one line on each.
"@
$brief = Get-Content $Brief -Raw -Encoding UTF8
$code = Invoke-Codex ($rules + "`n`n" + $brief) "workspace-write" (Join-Path $Out "reply.md") @()
if ($code -ne 0) { exit $code }
$pngs = Render-Svgs
if (-not $Review -or $pngs.Count -eq 0) { exit 0 }

# Codex's first test SVG had a broken mask that hid every arc; one look at the render catches that.
$names = ($pngs | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) + ".svg" }) -join ", "
$fix = @"
RULES: Edit only the SVG files in the current directory. Do not use the network or install anything.
Do not try to render files yourself.

Attached are browser renders of the SVGs you wrote, in this order: $names.
Compare each render with the brief below. If anything the brief asks for is missing, invisible, clipped,
off-palette or crowding the space meant for text, fix that SVG. If a render already matches, leave it alone.
Reply with one line per file: "fixed: <what>" or "ok".

BRIEF:
$brief
"@
$code = Invoke-Codex $fix "workspace-write" (Join-Path $Out "review.md") $pngs
Render-Svgs | Out-Null
exit $code
