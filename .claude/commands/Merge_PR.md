---
description: Merge a PR that was reviewed earlier in THIS session, then tear down its worktree, branch, and (if solved) its issue.
argument-hint: [pr-number]
allowed-tools: ["Bash", "Glob", "Grep", "Read"]
---

# Merge a Reviewed PR + Clean Up

Merge the PR in `$ARGUMENTS` (or the current branch's PR if blank), then remove the worktree/branch and confirm the linked issue is closed.

**This command is destructive and outward-facing (it merges to the base branch and deletes branches).** The *only* authorization to merge is a review that happened **earlier in this same session**. Enforce the guard in Step 1 before anything else — if it fails, STOP and tell the user to run `/Review_PR <num>` first. Do not merge a PR you have not seen reviewed this session.

WSL note: use `gh.exe` (not `gh`), and run every `gh.exe`/`git` command from the **main worktree**, never from inside a PR worktree — `gh.exe` errors with "not a git repository" inside `git worktree add` dirs ([[gh-in-worktrees]], [[gh-cli-wsl]]).

## Step 1 — Session-review guard (BLOCKING — check first)

Look back through **this conversation**. Proceed only if ALL hold:
1. A fresh-context review of **this specific PR** (same number/branch) appears **earlier in this session** — via `/Review_PR`, `/code-review`, or an equivalent review you performed and reported.
2. Its verdict was **APPROVE** or **APPROVE_WITH_CHANGES**. If **REQUEST_CHANGES**, or there were **Critical** findings, those must have been resolved (fix merged, or the user explicitly accepted/waived them in this session).

If no qualifying review exists in this session, respond exactly with a refusal and stop:
> ⛔ PR #`<num>` hasn't been reviewed in this session. Run `/Review_PR <num>` first, then re-run `/Merge_PR <num>`.

Never fabricate or assume a review happened. "I reviewed it in a previous session" does not count — the guard is per-session by design.

## Step 2 — Resolve the PR and preflight

```
gh.exe pr view <num> --json number,title,state,mergeable,mergeStateStatus,headRefName,baseRefName,url,body
gh.exe pr checks <num>        # must be passing or "no checks reported"
```
Refuse to merge unless: `state == OPEN`, `mergeable == MERGEABLE`, `mergeStateStatus == CLEAN`, and checks pass (or none configured). If any is off (DIRTY, BEHIND, BLOCKED, failing checks), report it and stop — don't try to force it.

**No-data-loss check** — confirm the branch on origin is what was reviewed and nothing local is unpushed:
```
git fetch origin
git rev-parse <headRef>  ==  git rev-parse origin/<headRef>     # no unpushed commits
git log --oneline origin/<headRef>..<headRef>                   # must be empty
```

## Step 3 — Merge (match the repo's convention)

Detect how this repo merges and mirror it:
```
git log --oneline --merges -3      # merge commits present → use --merge
```
- Merge commits in history → `gh.exe pr merge <num> --merge`
- Squash convention → `gh.exe pr merge <num> --squash`
- (Don't pass `--delete-branch` here — the local branch is checked out in a worktree, so branch deletion is handled after the worktree is gone in Step 4.)

Then confirm: `gh.exe pr view <num> --json state,mergeCommit` shows `MERGED`.

## Step 4 — Tear down the worktree (only if no longer needed)

```
git worktree list        # find the worktree whose branch == <headRef>
```
If a worktree exists for the branch, verify it holds **no work the PR doesn't already have**:
```
git -C <worktree> status --porcelain
```
- Only **untracked scratch** (e.g. `PLAN.md` from `/Begin_session`) → safe to discard: `git worktree remove <worktree> --force`.
- **Tracked modifications or unpushed commits** → STOP. Do not force-remove. Report what's there and ask the user — that's unmerged work.

Run destructive removals **one attempt per command** ([[no-chained-destructive-retries]]) so the user can intervene.

## Step 5 — Delete the branch (local + remote)

After the worktree is gone:
```
git branch -D <headRef>
git push origin --delete <headRef>
```

## Step 6 — Sync base + confirm the issue

```
git pull --ff-only origin <baseRef>      # update local base to the merged state
```
Linked issue: a PR body with `Closes #N` auto-closes the issue on merge. Verify:
```
gh.exe issue view <N> --json state
```
- Already `CLOSED` → done.
- Still `OPEN` **and** the PR fully resolves it (the original defect is fixed, per the session review) → close it: `gh.exe issue close <N> --comment "Resolved by #<num> (merged <mergeCommit>)."`
- The PR only **partially** addresses it, or the review left the core ask unresolved → **leave it open** and say so. Residual edge cases filed as their own separate issues do NOT block closing the main issue.

## Step 7 — Report

Summarize: merge commit SHA + base, issue state, worktree removed, branch deleted (local+remote), local base fast-forwarded. Surface anything you skipped or that needs the user's attention (e.g. a residual follow-up issue still open, an unrelated pruned ref).

## Refuse / stop conditions (summary)
- No qualifying review this session → Step 1 refusal.
- Not mergeable / not clean / failing checks → stop, report.
- Worktree has tracked changes or unpushed commits → stop, ask.
Each of these protects against merging the wrong thing or losing work; don't paper over them.
