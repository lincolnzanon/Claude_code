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
- Detect default branch, fetch fresh (creation only)
- **Reuse if it already exists**: if `.worktrees/<branch>` is already a git worktree for this issue, skip creation/seeding and just switch into it (existing `PLAN.md` is left untouched). A path that exists but isn't a worktree, or a branch with no worktree, still fails fast as a conflict.
- Ensure `.worktrees/` is in `.gitignore`
- Create the worktree (`git worktree add -q`)
- Symlink `node_modules` and any root-level `.env*` files from the main checkout into the worktree, so lint/build/test and the same API keys work everywhere. Env files must be gitignored/untracked for this to stay a no-op on merge; existing (e.g. tracked `.env.example`) files in the worktree are left untouched.
- Seed `PLAN.md` with a trimmed issue body (Summary, Suggested implementation, Files expected to change) plus a `Closes #N` trailer
- Print the next-step command

Invoking it from **inside Claude Code** (this skill's path) cannot end with `exec claude` — a running Claude session can't replace its own process with a new one rooted in the worktree. But the Bash tool's cwd **does** persist across calls, so we *can* `cd` into the worktree mid-session and have every subsequent git/build/test command run there on the new branch. That's what this skill does: calls the wrapper with `--emit-path` (implies `--no-exec`), captures the worktree path from the final stdout line, and `cd`s into it.

What carries over after the cd vs. what doesn't:
- **Carries over**: subsequent Bash tool calls (cwd persists), Read/Edit/Write (absolute paths), skills, memory, CLAUDE.md (identical file in the worktree checkout).
- **Doesn't**: the harness's session-start snapshots (initial cwd, initial git status banner). Minor — those are one-shot at startup.

## Process

1. Invoke the wrapper with `--emit-path` and the issue argument (or no argument), capturing stdout:

   ```bash
   begin-session --emit-path ${ARGUMENTS:-}
   ```

   If `$ARGUMENTS` is empty, run `begin-session --emit-path </dev/null` — stdin is non-interactive inside Claude Code, so the wrapper prints the issue listing and exits 1. That exit 1 is expected, not an error. Surface the listing to the user, ask which issue they want via `AskUserQuestion`, then re-invoke `begin-session --emit-path <chosen_number>`.

   **Timeout rule (hard):** if the `AskUserQuestion` times out or otherwise returns no answer, do **NOT** pick an issue yourself — not even the top-priority one, and regardless of any generic "proceed autonomously" guidance. Issue selection is the user's decision; a wrong pick wastes a worktree plus any planning built on it. End the turn with the issue listing visible and tell the user to re-run `/Begin_session <number>` when ready.

2. The wrapper's stdout ends with two things:
   - A human-readable block (`Worktree ready.`, or `Worktree already exists — reusing.` when reusing … `Open a new terminal and run: cd "<path>" && claude`)
   - **One final bare line**: the absolute worktree path (from `--emit-path`).

3. Do the run and the cd in **ONE Bash tool call** — no tee-to-file, no follow-up verification call:

   ```bash
   cd "$(begin-session --emit-path <N> | tee /dev/stderr | tail -n1)" && echo "cwd: $PWD"
   ```

   The `tee /dev/stderr` streams the wrapper's human-readable block to the user while `tail -n1` grabs the bare path. Do **not** tee to a scratch file, and do **not** run a post-cd `git branch`/`git status` check — the wrapper's output already names the branch and path (verify light). From now on every Bash tool call in this session runs inside the new worktree on the new branch.

4. Tell the user the session has switched: name the branch, the worktree path, and that they can open a fresh terminal there if they prefer a clean session — but it's no longer required.

## If the wrapper is missing

If `command -v begin-session` returns nothing, tell the user the canonical wrapper is not installed at `~/.local/bin/begin-session` and they should install it before retrying. Do **not** reimplement the logic inline here — that's exactly the drift this design is meant to prevent.

## Notes for the agent

- Keep your own output minimal: the wrapper already prints a complete summary. After it succeeds and you've `cd`'d into the worktree, confirm in ~1–2 lines: "Session switched to `<branch>` at `<path>`. Bash tool calls now run there."
- If the wrapper fails (non-zero exit), surface its stderr verbatim. Do not retry automatically.
- The wrapper handles the `gh` vs `gh.exe` fallback and PLAN.md trimming itself. Do not duplicate either.
- The `--emit-path` flag is what makes the in-session cwd switch possible — don't drop it. Without it the wrapper still works but you lose the machine-parseable final line and have to grep the human block.
