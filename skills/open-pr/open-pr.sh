#!/usr/bin/env bash
# Open a GitHub PR for the current branch, linking the issue named in the branch.
# Branch convention: <issue-number>-<label>  (e.g. 127-auth-session-fix)
# Usage: open-pr.sh --summary "<text>" --test-plan "<text>"
# On success: prints the PR URL to stdout.

set -euo pipefail

die() { printf 'open-pr: %s\n' "$*" >&2; exit 1; }

SUMMARY=""
TEST_PLAN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary)    SUMMARY="${2:-}"; shift 2 ;;
    --test-plan)  TEST_PLAN="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$SUMMARY"   ]] || die "missing required --summary"
[[ -n "$TEST_PLAN" ]] || die "missing required --test-plan"

# Resolve gh binary — prefer plain `gh`, fall back to `gh.exe` for WSL.
if command -v gh >/dev/null 2>&1; then
  GH=gh
elif command -v gh.exe >/dev/null 2>&1; then
  GH=gh.exe
else
  die "gh CLI not installed. Install: https://cli.github.com/"
fi
command -v git >/dev/null 2>&1 || die "git not installed."

"$GH" auth status >/dev/null 2>&1 || die "gh not authenticated. Run: $GH auth login"

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository."

REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
[[ -n "$REMOTE_URL" ]] || die "no 'origin' remote configured."
[[ "$REMOTE_URL" == *github.com* ]] || die "remote 'origin' is not a GitHub URL: $REMOTE_URL"

BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
[[ -n "$BRANCH" ]] || die "HEAD is detached; check out a branch first."

if [[ ! "$BRANCH" =~ ^([0-9]+)- ]]; then
  die "branch '$BRANCH' does not match the '<issue-number>-<label>' convention (e.g. 127-auth-session-fix)."
fi
ISSUE_NUM="${BASH_REMATCH[1]}"

# WSL+worktree fix: when GH=gh.exe is invoked inside a git worktree (not the
# main checkout), the Windows binary cannot resolve the gitfile pointer in .git
# and bails with "not a git repository" — and `gh pr create` does so even when
# --repo is supplied (it still inspects local git). Two-part fix:
#   1. Inject explicit --repo OWNER/NAME so subcommands that accept it skip
#      local-repo detection. NOTE: `gh repo view` takes a POSITIONAL repo, not
#      --repo, so it is handled separately via $OWNER_REPO below.
#   2. Run every gh.exe call from the MAIN worktree dir (which has a real .git)
#      via gh_cmd(). All identifying args (--repo/--head/--base) are explicit, so
#      operating on the worktree's branch from the main checkout is safe.
GH_REPO_ARGS=()
OWNER_REPO=""
GH_CWD="."
if [[ "$GH" == "gh.exe" ]]; then
  GIT_DIR_PATH="$(git rev-parse --git-dir)"
  GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"
  if [[ "$GIT_DIR_PATH" != "$GIT_COMMON_DIR" ]]; then
    # Inside a worktree. Derive owner/name from the GitHub remote URL.
    OWNER_REPO="$(printf '%s' "$REMOTE_URL" | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#')"
    [[ -n "$OWNER_REPO" ]] && GH_REPO_ARGS=(--repo "$OWNER_REPO")
    # The main worktree is always the first entry of `git worktree list`.
    MAIN_WT="$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')"
    [[ -n "$MAIN_WT" && -d "$MAIN_WT" ]] && GH_CWD="$MAIN_WT"
  fi
fi

# Run gh from $GH_CWD: the main worktree under the WSL+worktree case above, "."
# (in place) otherwise. git commands still run in the current worktree.
gh_cmd() { ( cd "$GH_CWD" && "$GH" "$@" ); }

# `git status --porcelain` reports untracked files too; the /Begin_session
# skill seeds a `PLAN.md` scratch file at the worktree root that is not
# meant to be committed. Filter it (and a small whitelist of similar
# scratch files) out of the cleanness check so /open-pr doesn't bail.
DIRTY_LINES="$(git status --porcelain | grep -Ev '^\?\? PLAN\.md$' || true)"
if [[ -n "$DIRTY_LINES" ]]; then
  printf 'open-pr: dirty files preventing PR:\n%s\n' "$DIRTY_LINES" >&2
  die "working tree not clean. Commit or stash changes before opening a PR."
fi

UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
[[ -n "$UPSTREAM" ]] || die "branch '$BRANCH' has no upstream. Push first: git push -u origin '$BRANCH'"

git fetch --quiet "$(git config --get "branch.${BRANCH}.remote")" "$BRANCH" || die "failed to fetch upstream."

LOCAL_SHA="$(git rev-parse HEAD)"
REMOTE_SHA="$(git rev-parse "$UPSTREAM")"
if [[ "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
  AHEAD="$(git rev-list --count "${UPSTREAM}..HEAD")"
  BEHIND="$(git rev-list --count "HEAD..${UPSTREAM}")"
  die "local and upstream diverge (ahead $AHEAD, behind $BEHIND). Push/pull before opening a PR."
fi

EXISTING_PR="$(gh_cmd "${GH_REPO_ARGS[@]}" pr list --head "$BRANCH" --state open --json number,url --jq '.[0].url // empty')"
if [[ -n "$EXISTING_PR" ]]; then
  die "an open PR already exists for branch '$BRANCH': $EXISTING_PR"
fi

if ! gh_cmd "${GH_REPO_ARGS[@]}" issue view "$ISSUE_NUM" --json number >/dev/null 2>&1; then
  die "issue #$ISSUE_NUM not found (branch '$BRANCH' implies it should exist). Rename the branch or create the issue."
fi

# `gh repo view` uses a POSITIONAL repo arg (not --repo); pass $OWNER_REPO when set.
DEFAULT_BRANCH="$(gh_cmd repo view ${OWNER_REPO:+"$OWNER_REPO"} --json defaultBranchRef --jq '.defaultBranchRef.name')"
[[ -n "$DEFAULT_BRANCH" ]] || die "could not determine repo default branch."

mapfile -t LABELS < <(gh_cmd "${GH_REPO_ARGS[@]}" issue view "$ISSUE_NUM" --json labels --jq '.labels[].name' 2>/dev/null || true)

BODY="$(printf '## Summary\n%s\n\n## Test plan\n%s\n\nCloses #%s\n' "$SUMMARY" "$TEST_PLAN" "$ISSUE_NUM")"

GH_ARGS=("${GH_REPO_ARGS[@]}" pr create --title "$BRANCH" --body "$BODY" --base "$DEFAULT_BRANCH" --head "$BRANCH")
for label in "${LABELS[@]:-}"; do
  [[ -n "$label" ]] && GH_ARGS+=(--label "$label")
done

PR_URL="$(gh_cmd "${GH_ARGS[@]}")" || die "gh pr create failed."
printf '%s\n' "$PR_URL"
