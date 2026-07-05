#!/usr/bin/env bash
# UserPromptSubmit hook: keep a ≤5-word "what is this session doing" summary
# in /tmp/claude-statusline-task-<session_id>, displayed as the second row of
# the statusline (see statusline-command.sh).
#
# Flow: hook invocation parses stdin JSON and immediately re-execs itself
# detached (--bg) so the prompt is never blocked; the background pass calls
# `claude -p --model haiku` and atomically writes the summary file.

# Recursion guard: the nested `claude -p` below fires this same hook in its
# own session. Without this, every prompt would fork-bomb haiku calls.
[ -n "$CC_TASKLINE" ] && exit 0

CLAUDE_BIN="/home/linco/.local/bin/claude"

if [ "$1" = "--bg" ]; then
    session_id="$2"
    prompt="$3"
    task_file="/tmp/claude-statusline-task-${session_id}"

    prev=""
    [ -f "$task_file" ] && prev=$(head -c 100 "$task_file")

    export CC_TASKLINE=1
    # JSON output so CLI errors (e.g. "Reached max turns") are detected
    # instead of being written to the task file as if they were summaries.
    raw=$("$CLAUDE_BIN" -p --model haiku --max-turns 2 --output-format json \
        "Previous session description: \"${prev}\". Latest user message in a coding session: \"${prompt}\". Reply with ONLY a short present-participle description (5 words max) of what this session is working on, e.g. \"Reviewing PR 82\" or \"Planning statusline feature\". No quotes, no trailing punctuation. Do NOT use any tools. If the previous description still fits the latest message, repeat it exactly." \
        2>/dev/null)

    summary=$(python3 - "$raw" <<'PY'
import json, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
if d.get("is_error") or d.get("subtype") != "success":
    sys.exit(0)
text = (d.get("result") or "").strip().splitlines()
text = text[0].strip().strip('"\'') if text else ""
if text and not text.lower().startswith("error"):
    print(text[:48])
PY
)

    if [ -n "$summary" ]; then
        tmp="${task_file}.tmp.$$"
        printf '%s' "$summary" > "$tmp" && mv "$tmp" "$task_file"
    fi
    exit 0
fi

input=$(cat)

# Parse JSON with python3 (jq is not installed in this WSL env). Prompt is
# flattened to one line so mapfile keeps one field per line.
mapfile -t fields < <(python3 - "$input" <<'PY'
import json, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    d = {}
print(d.get("session_id") or "")
prompt = " ".join((d.get("prompt") or "").split())
print(prompt[:1500])
PY
)

session_id="${fields[0]:-}"
prompt="${fields[1]:-}"

# Nothing to do without a session, and don't burn a haiku call on "yes"/"ok".
[ -z "$session_id" ] && exit 0
[ "${#prompt}" -lt 8 ] && exit 0

# Detach fully (setsid) so the summarizer survives this hook process exiting.
# stdout must stay empty: UserPromptSubmit stdout is injected into context.
setsid bash "$0" --bg "$session_id" "$prompt" >/dev/null 2>&1 </dev/null &

exit 0
