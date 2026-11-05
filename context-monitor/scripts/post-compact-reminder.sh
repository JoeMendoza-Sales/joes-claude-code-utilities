#!/bin/bash
# Runs on SessionStart with matcher "compact", i.e. right after a manual or automatic /compact.
# SessionStart stdout is added to Claude's context, so this reaches Claude (a PreCompact hook's
# output doesn't).
cat > /dev/null
echo "CONTEXT WAS JUST COMPACTED. The summary above is lossy. Before continuing, re-read your memory index and any notes or files for the current task, and don't trust exact numbers, names or paths from the summary without checking them against the source."
exit 0
