---
description: Begin a session in a new worktree tied to a GitHub issue
---

# Begin Session

Start a focused work session for a single GitHub issue. Creates an isolated git worktree, seeds a planning doc, and opens a new editor window rooted there.

## Argument

`$ARGUMENTS` — the GitHub issue number (e.g. `/Begin_session 42`).

If empty, the skill will list the top open issues ranked by priority labels and ask the user to pick one.

## Issue conventions (aligned with `/Issue_create`)

Issues created for this workflow should match **`Issue_create`**:

- **Title:** Include the GitHub issue number as digits in the title (e.g. `[42] auth-session-fix`) so it stays searchable and matches branch slugs derived from `gh issue view`.
- **Priority:** Exactly one label named **`P0`**, **`P1`**, **`P2`**, or **`P3`** — those exact strings — so the empty-argument issue list below can rank work correctly.

## Process

### 1. Preflight

Confirm the environment is ready:

```bash
git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "Not in a git repo"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh CLI not authenticated. Run: gh auth login"; exit 1; }
```

Capture the repo root for later steps:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
```

### 2. Resolve the issue number

**If `$ARGUMENTS` is non-empty:** treat it as the issue number. Strip a leading `#` if present.

```bash
ISSUE_NUM="${ARGUMENTS#\#}"
```

**If `$ARGUMENTS` is empty:** list the top 10 open issues ranked by priority label (P0 → P3), present them to the user, and ask which one to start.

```bash
gh issue list \
  --state open \
  --limit 50 \
  --json number,title,labels \
  --jq '
    map(
      . + {
        priority: (
          [.labels[].name | select(test("^P[0-3]$"))] | sort | first // "P9"
        )
      }
    )
    | sort_by(.priority, .number)
    | .[:10]
    | .[] | "\(.priority)  #\(.number)  \(.title)"
  '
```

Present the list to the user. Wait for their pick, then set `ISSUE_NUM` to the chosen number.

### 3. Fetch issue details and derive the slug

```bash
ISSUE_JSON="$(gh issue view "$ISSUE_NUM" --json number,title,body,labels,url)"
ISSUE_TITLE="$(echo "$ISSUE_JSON" | jq -r .title)"
ISSUE_BODY="$(echo "$ISSUE_JSON" | jq -r .body)"
ISSUE_URL="$(echo "$ISSUE_JSON" | jq -r .url)"

SLUG="$(echo "$ISSUE_TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' \
  | cut -c1-40 \
  | sed 's/-$//')"

BRANCH="${ISSUE_NUM}-${SLUG}"
WORKTREE_REL=".worktrees/${BRANCH}"
WORKTREE_ABS="${REPO_ROOT}/${WORKTREE_REL}"
```

### 4. Detect default branch and fetch fresh

```bash
DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)"
git fetch origin "$DEFAULT_BRANCH" --quiet
```

### 5. Fail fast on conflicts

Refuse to proceed if the branch or worktree path already exists. Tell the user exactly what was found so they can resolve it manually.

```bash
if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  echo "Branch '${BRANCH}' already exists. Delete it or pick a different issue." >&2
  exit 1
fi

if [ -e "$WORKTREE_ABS" ]; then
  echo "Worktree path '${WORKTREE_REL}' already exists. Remove it first." >&2
  exit 1
fi
```

### 6. Ensure `.worktrees/` is gitignored

```bash
GITIGNORE="${REPO_ROOT}/.gitignore"
if [ ! -f "$GITIGNORE" ] || ! grep -qxF ".worktrees/" "$GITIGNORE"; then
  printf '\n.worktrees/\n' >> "$GITIGNORE"
fi
```

### 7. Create the worktree

```bash
git worktree add -b "$BRANCH" "$WORKTREE_ABS" "origin/${DEFAULT_BRANCH}"
```

### 8. Seed `PLAN.md` inside the worktree

Write the planning doc at `${WORKTREE_ABS}/PLAN.md` with this exact structure:

```markdown
# Plan: #<ISSUE_NUM> — <ISSUE_TITLE>

**Issue:** <ISSUE_URL>
**Branch:** <BRANCH>
**Base:** origin/<DEFAULT_BRANCH>

## Issue body

<ISSUE_BODY>

## Plan

- [ ] (fill in steps)

---

Closes #<ISSUE_NUM>
```

Substitute the captured variables when writing the file. The trailing `Closes #<N>` line is consumed later by `/commit` and `/open-pr`.

### 9. Open a new editor window rooted at the worktree

Detect the host and spawn a fresh instance:

```bash
if [ -n "$CURSOR_TRACE_ID" ] || [ "$TERM_PROGRAM" = "cursor" ]; then
  cursor "$WORKTREE_ABS" >/dev/null 2>&1 &
  SPAWNED="cursor"
elif command -v cursor >/dev/null 2>&1 && [ -n "$VSCODE_INJECTION" ]; then
  cursor "$WORKTREE_ABS" >/dev/null 2>&1 &
  SPAWNED="cursor"
else
  SPAWNED="manual"
fi
```

A running Claude Code session cannot reliably fork itself into a new directory, so for Claude Code (and any unknown host) leave `SPAWNED=manual` and rely on the fallback below.

### 10. Confirm and print manual fallback

Always print a summary the user can act on, regardless of spawn outcome:

```
Worktree ready.

  Issue:     #<ISSUE_NUM> — <ISSUE_TITLE>
  Branch:    <BRANCH>
  Path:      <WORKTREE_ABS>
  Plan:      <WORKTREE_ABS>/PLAN.md

To work in the worktree:
  cd "<WORKTREE_ABS>" && claude     # for Claude Code
  cursor "<WORKTREE_ABS>"           # for Cursor (already launched if detected)

Finish with /commit and /open-pr — the `Closes #<ISSUE_NUM>` trailer in PLAN.md will auto-close the issue on merge.
```

## Notes for the agent

- Run sequentially — each step depends on the previous. Do not parallelize.
- If any preflight or fail-fast check trips, stop and surface the error verbatim; do not try to recover automatically.
- The `PLAN.md` lives inside the worktree, not the main checkout. Do not write it at the repo root.
- The current session does **not** continue inside the worktree — it remains as the launcher. Tell the user explicitly so they don't expect a transparent cwd switch.
