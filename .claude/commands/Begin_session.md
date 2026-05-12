---
description: Begin a session in a new worktree tied to a GitHub issue
---

# Begin Session

Start a focused work session for a single GitHub issue by creating an isolated git worktree, seeding a planning doc, and printing the one-liner the user runs in a fresh terminal to enter Claude Code inside the new worktree.

## Argument

`$ARGUMENTS` — the GitHub issue number (e.g. `/Begin_session 42`). Leading `#` is stripped automatically by the wrapper.

If empty, the wrapper will list the top 10 open issues by priority (P0 → P3) and prompt for a pick — surface its prompt output to the user and pass their answer back via stdin.

## How this skill works

This skill is a **thin shim** over `~/.local/bin/begin-session`, which is the canonical implementation (same script you can also run directly from a terminal). The wrapper does:

- Preflight (git repo + `gh`/`gh.exe` auth)
- Resolve issue number (or list + prompt)
- Fetch issue title/url/body once
- Derive `<num>-<slug>` branch + `.worktrees/<branch>` path
- Detect default branch, fetch fresh, fail-fast on existing branch/path
- Ensure `.worktrees/` is in `.gitignore`
- Create the worktree (`git worktree add -q`)
- Seed `PLAN.md` with a trimmed issue body (Summary, Suggested implementation, Files expected to change) plus a `Closes #N` trailer
- Print the next-step command

Invoking it from **inside Claude Code** (this skill's path) cannot end with `exec claude`, because a running Claude session can't move its own cwd into the worktree. So this skill calls the wrapper with `--no-exec`: the wrapper does full setup, then prints the manual one-liner.

## Process

Run the wrapper with `--no-exec` and the issue argument (or no argument):

```bash
begin-session --no-exec ${ARGUMENTS:-}
```

If `$ARGUMENTS` is empty, the wrapper enters interactive mode (lists issues, prompts for a number). In that case, surface the listing to the user, ask which issue they want via `AskUserQuestion`, then re-invoke `begin-session --no-exec <chosen_number>`.

After the wrapper exits 0, its last lines look like:

```
Open a new terminal and run:
  cd "<WORKTREE_ABS>" && claude
```

**Relay that command to the user as the next action** — that's the whole point of running the skill from inside Claude. Do not try to `! claude` or otherwise launch Claude from inside this session; the cwd-switch is not possible from a running Claude.

## If the wrapper is missing

If `command -v begin-session` returns nothing, tell the user the canonical wrapper is not installed at `~/.local/bin/begin-session` and they should install it before retrying. Do **not** reimplement the logic inline here — that's exactly the drift this design is meant to prevent.

## Notes for the agent

- Keep your own output minimal: the wrapper already prints a complete summary. After it succeeds, re-state only the final two-line `Open a new terminal and run:` block so the user has it as the last thing on screen.
- If the wrapper fails (non-zero exit), surface its stderr verbatim. Do not retry automatically.
- The wrapper handles the `gh` vs `gh.exe` fallback and PLAN.md trimming itself. Do not duplicate either.
