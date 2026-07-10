---
description: Fresh-context PR review — fans out parallel specialized subagents (or reviews inline if agents are absent) on the current PR diff.
argument-hint: [pr-number | review-aspects]
allowed-tools: ["Bash", "Glob", "Grep", "Read", "Task"]
---

# Fresh-Context PR Review

Run a comprehensive review of a PR: the one on the current branch, the PR number in `$ARGUMENTS` if given, or the uncommitted working-tree diff if no PR exists.

**Principle:** The session that wrote the code should NOT be the session that reviews it. Run this in a fresh `claude` session so the reviewers aren't primed by the implementer's reasoning. Fresh context, different blind spots, no sycophancy.

**`$ARGUMENTS`** — may be a **PR number** (e.g. `33`) or a list of **review aspects** (e.g. `errors tests`). A bare integer is a PR number; words are aspect filters. Blank → review the current branch's PR with every applicable reviewer.

## Step 0 — Reviewer mode (check ONCE, up front)

Check whether the named reviewer agents exist: `ls .claude/agents/ ~/.claude/agents/ 2>/dev/null || true` (the `|| true` keeps a missing dir from surfacing as an error).
- **Agents present** (`code-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`, `code-simplifier`) → **subagent mode**: fan out in parallel (Step 3a).
- **Agents absent** → **inline mode**: a single fresh session plays all roles itself (Step 3b). This is a first-class path, not a degraded one — do NOT spawn `general-purpose` agents as a substitute (they start cold, re-derive context, and burn tokens without the specialized prompts).

## Step 1 — Identify the diff (resolve the ref explicitly)

- `gh.exe pr view <num> --json number,url,title,headRefName,baseRefName,body` to resolve the PR. With no arg, omit `<num>` to use the current branch.
- **Do not assume `HEAD` is the PR branch** — this command is meant to run from a clean `main`. Resolve the head ref from the JSON and `git fetch origin` first, then diff against `origin/<headRefName>`.
- **Verify where (or whether) the head is checked out locally before telling reviewers where to read.** The session-start git status header can be stale, and repos using the `/Begin_session` flow keep branches in `.worktrees/<branch>` while the main checkout stays on `main`. Run `git worktree list` and only claim "the branch is checked out at `<path>`" if that tree's SHA matches `origin/<headRefName>`; otherwise instruct reviewers to read via `git show origin/<headRef>:<path>`. A wrong local-path claim makes every reviewer independently waste tokens rediscovering it.
- If no PR exists, fall back to the working tree: `git diff origin/<base>...HEAD` + `git status`.

## Step 2 — Pull the diff token-efficiently (IMPORTANT)

A full `gh pr diff` can be thousands of lines dominated by churn that isn't worth reviewer tokens. Triage in this order:

1. **`gh.exe pr diff <num> --name-only`** (or `git diff --name-only origin/<base>...origin/<headRef>`) to see the file list and classify: source vs tests vs docs.
2. **Read the source diff scoped to code globs first** — `gh pr diff` does **not** accept a pathspec (`gh pr diff <n> -- <files>` errors), so use git:
   `git diff origin/<base>...origin/<headRef> -- <source globs>`
   Derive the globs from the name-only list (e.g. `'src/**'` for a JS/TS repo, `'**/*.py'` for Python). This is the part reviewers actually judge.
3. **Treat `*.md` / doc churn and pure format reflows as skim-only.** Progress logs and changelogs with huge single-line entries, and formatter passes (ruff/prettier/gofmt) that reflow whole files, balloon the diff with near-zero review signal. Confirm docs were updated where required; don't read them line-by-line. To suppress whitespace-only noise use `git diff -w`.
4. Note the changed files + high-level intent (PR body / linked issue) — that's the context every reviewer needs.
5. **Re-review rounds:** if the PR body records earlier review-fix rounds, name the already-fixed findings and the deferred follow-up issues in every reviewer prompt (so they aren't re-reported), and tell reviewers to weight scrutiny toward the commits since the last reviewed SHA while keeping the full diff as context.

## Step 3a — Subagent mode (agents present): fan out in parallel

Decide which reviewers apply from the diff:
- **Always**: `code-reviewer` (general quality + CLAUDE.md compliance)
- **If error handling / try-except / fallback / AST-parse code changed**: `silent-failure-hunter`
- **If tests added or modified**: `pr-test-analyzer`
- **After the above**: `code-simplifier` (non-blocking polish)

Launch all applicable subagents in **one message** (one `Task` call each, same batch, concurrent). Per [[no-shared-scratch-for-subagents]], **inline the context into each prompt** — do not pre-stage `/tmp` scratch files. Each prompt gets:
- The changed-file list + 1-paragraph PR intent
- The scoped source diff (or the path to read, scoped to code globs)
- "Focus on the diff, not the rest of the repo; the branch is remote — use `git show origin/<headRef>:<path>`"
- "Critical/Important findings must cite `file:line`"

## Step 3b — Inline mode (agents absent): one session, all aspects

Review the scoped diff yourself across the same four lenses, in this order, keeping them mentally separate:
1. **Correctness + CLAUDE.md compliance** (always)
2. **Silent failures** — only if error handling / fallback / AST code changed
3. **Tests** — only if tests changed: do they pin the real invariant and cover each failure mode?
4. **Simplification** — non-blocking polish

The four agent files in `.claude/agents/` are the rubric for each lens even when running inline — skim the relevant one if unsure what to look for.

## Step 4 — Aggregate

```markdown
# PR Review — <pr-title>

## Critical (must fix before merge)
- [aspect] <issue> — `file.py:42` — <fix>

## Important (should fix)
- [aspect] <issue> — `file.py:87`

## Suggestions
- [aspect] <suggestion> — `file.py:120`

## Strengths
- <what the PR did well>

## Verdict
APPROVE / APPROVE_WITH_CHANGES / REQUEST_CHANGES
```

## Step 5 — Do not apply fixes

This command reviews; it does not edit. If the user wants fixes applied, that's a separate command (`/code-review --fix`, `/simplify`) or a follow-up.

## Usage

```
/Review_PR            # current branch's PR, every applicable reviewer
/Review_PR 33         # PR #33
/Review_PR errors tests   # only silent-failure-hunter + pr-test-analyzer
```

## Notes

- **Parallel is the default in subagent mode.** Sequential defeats the point.
- Keep critical findings actionable: `file:line` + one sentence + suggested fix. Vague complaints get ignored.
- If the PR is trivial (docs-only, single-line), return APPROVE with zero findings rather than fabricating issues.
- WSL: use `gh.exe` (not `gh`) per [[gh-cli-wsl]]; `gh.exe` fails inside `git worktree` dirs per [[gh-in-worktrees]].
- Reviewers are read-only — never let a review pass edit code.
- **No `cd` in parallel tool batches.** When inspecting a worktree, use absolute paths or `git -C <worktree>` — a `cd` in one call of a parallel batch can leave a sibling command running in the wrong directory, where an empty grep silently reads as "no findings".
- **Use the dedicated Grep/Read tools, not Bash `grep`/`sed`/`cat`,** to inspect files during review — fewer permission prompts, structured output. Reserve Bash for `git`/`gh` commands.
- **Token: prefer the diff and `git show origin/<headRef>:<path>` over Read on files inside a checked-out worktree** — reading inside a worktree injects that worktree's CLAUDE.md into context as a duplicate of what you already have.
- **Unchecked test-plan items (`- [ ]`) in the PR body are review findings** when they cover the change's core invariant — call them out in the verdict rather than treating the test plan as done.
