#!/usr/bin/env bash
# Claude Code statusLine command
# Shows model name, current worktree, effort, and context-window usage.

input=$(cat)

# Parse JSON with python3 (jq is not installed in this WSL env).
mapfile -t fields < <(python3 - "$input" <<'PY'
import json, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    d = {}
model = (d.get("model") or {}).get("display_name") or ""
ctx = d.get("context_window") or {}
used = ctx.get("used_percentage")
tokens = (ctx.get("total_input_tokens") or 0) + (ctx.get("total_output_tokens") or 0)
effort = (d.get("effort") or {}).get("level") or ""
# Rolling 5-hour usage limit ("session" limit that resets); Pro/Max only,
# absent until the first API response in the session.
sl = ((d.get("rate_limits") or {}).get("five_hour") or {}).get("used_percentage")
ws = d.get("workspace") or {}
cwd = ws.get("current_dir") or d.get("cwd") or ""
session_id = d.get("session_id") or ""
session_name = d.get("session_name") or ""
for v in (model, used if used is not None else "", cwd, tokens, effort,
          sl if sl is not None else "", session_id, session_name):
    print(v)
PY
)

model="${fields[0]:-}"
used="${fields[1]:-}"
cwd="${fields[2]:-}"
tokens="${fields[3]:-0}"
effort="${fields[4]:-}"
sl="${fields[5]:-}"
session_id="${fields[6]:-}"
session_name="${fields[7]:-}"

# Humanise the token count: 15500 -> 15.5k, 1200000 -> 1.2M.
fmt_tokens=""
if [ -n "$tokens" ] && [ "$tokens" -gt 0 ] 2>/dev/null; then
    if [ "$tokens" -ge 1000000 ]; then
        fmt_tokens=$(awk "BEGIN{printf \"%.1fM\", $tokens/1000000}")
    elif [ "$tokens" -ge 1000 ]; then
        fmt_tokens=$(awk "BEGIN{printf \"%.1fk\", $tokens/1000}")
    else
        fmt_tokens="$tokens"
    fi
fi

# Derive a short worktree label. If cwd sits under a `.worktrees/<name>` dir
# (the convention used by Begin_session), show "<name>". Otherwise fall back
# to the basename of the current directory.
worktree=""
in_worktree=0
if [ -n "$cwd" ]; then
    if [[ "$cwd" == *"/.worktrees/"* ]]; then
        worktree="${cwd##*/.worktrees/}"
        worktree="${worktree%%/*}"
        in_worktree=1
    else
        worktree="${cwd##*/}"
    fi
fi

reset='\033[00m'
dim='\033[2m'
yellow='\033[33m'
red='\033[31m'

# Second row: short session-task description written by the UserPromptSubmit
# hook (statusline-task-summary.sh); falls back to /rename's session_name.
print_task_line() {
    local task=""
    if [ -n "$session_id" ] && [ -s "/tmp/claude-statusline-task-${session_id}" ]; then
        task=$(head -c 64 "/tmp/claude-statusline-task-${session_id}")
    elif [ -n "$session_name" ]; then
        task="$session_name"
    fi
    # Never surface CLI error text that slipped into a task file.
    case "$task" in Error*|error*) task="" ;; esac
    if [ -n "$task" ]; then
        printf "\n${dim}task:${reset} %s" "$task"
    fi
}

# Build the session-limit suffix (rolling 5h usage; 100% = limit reached).
# Warn in yellow >=75% and red >=90%.
sl_suffix=""
if [ -n "$sl" ]; then
    sl_int=$(printf '%.0f' "$sl")
    if [ "$sl_int" -lt 0 ]; then sl_int=0; fi
    if [ "$sl_int" -gt 100 ]; then sl_int=100; fi
    if [ "$sl_int" -ge 90 ]; then
        sl_suffix=" | ${dim}SL:${reset} ${red}${sl_int}%%${reset}"
    elif [ "$sl_int" -ge 75 ]; then
        sl_suffix=" | ${dim}SL:${reset} ${yellow}${sl_int}%%${reset}"
    else
        sl_suffix=" | ${dim}SL:${reset} ${sl_int}%%"
    fi
fi

prefix=""
if [ -n "$model" ]; then
    prefix="$model"
fi
if [ -n "$worktree" ]; then
    # Highlight the name in yellow when sitting in a separate worktree (not main).
    if [ "$in_worktree" -eq 1 ]; then
        wt_label="${yellow}${worktree}${reset}"
    else
        wt_label="$worktree"
    fi
    if [ -n "$prefix" ]; then
        prefix="$prefix | ${dim}wt:${reset} $wt_label"
    else
        prefix="${dim}wt:${reset} $wt_label"
    fi
fi
if [ -n "$effort" ]; then
    if [ -n "$prefix" ]; then
        prefix="$prefix | ${dim}effort:${reset} $effort"
    else
        prefix="${dim}effort:${reset} $effort"
    fi
fi

if [ -z "$used" ]; then
    if [ -n "$prefix" ]; then
        printf "%b | context: --${sl_suffix}" "$prefix"
    fi
    print_task_line
    exit 0
fi

used_int=$(printf '%.0f' "$used")
if [ "$used_int" -lt 0 ]; then used_int=0; fi
if [ "$used_int" -gt 100 ]; then used_int=100; fi

tok_suffix=""
if [ -n "$fmt_tokens" ]; then
    tok_suffix=" (${fmt_tokens} tokens)"
fi

if [ -n "$prefix" ]; then
    printf "%b | context: %d%% used%s${sl_suffix}" \
        "$prefix" "$used_int" "$tok_suffix"
else
    printf "context: %d%% used%s${sl_suffix}" \
        "$used_int" "$tok_suffix"
fi
print_task_line
