
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

  command -v gh  >/dev/null 2>&1 || die "gh CLI not installed. Install: https://cli.github.com/"      command -v git >/dev/null 2>&1 || die "git not installed."

  gh auth status >/dev/null 2>&1 || die "gh not authenticated. Run: gh auth login"

  git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository."
  
  REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
  [[ -n "$REMOTE_URL" ]] || die "no 'origin' remote configured."
  [[ "$REMOTE_URL" == *github.com* ]] || die "remote 'origin' is not a GitHub URL: $REMOTE_URL"

  BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"                                           [[ -n "$BRANCH" ]] || die "HEAD is detached; check out a branch first."

  if [[ ! "$BRANCH" =~ ^([0-9]+)- ]]; then
    die "branch '$BRANCH' does not match the '<issue-number>-<label>' convention (e.g.
  127-auth-session-fix)."
  fi
  ISSUE_NUM="${BASH_REMATCH[1]}"
  
  if [[ -n "$(git status --porcelain)" ]]; then
    die "working tree not clean. Commit or stash changes before opening a PR."
  fi
  
  UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  [[ -n "$UPSTREAM" ]] || die "branch '$BRANCH' has no upstream. Push first: git push -u origin
  '$BRANCH'"

  git fetch --quiet "$(git config --get "branch.${BRANCH}.remote")" "$BRANCH" || die "failed to     
  fetch upstream."

  LOCAL_SHA="$(git rev-parse HEAD)"
  REMOTE_SHA="$(git rev-parse "$UPSTREAM")"
  if [[ "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
    AHEAD="$(git rev-list --count "${UPSTREAM}..HEAD")"
    BEHIND="$(git rev-list --count "HEAD..${UPSTREAM}")"                                            
    die "local and upstream diverge (ahead $AHEAD, behind $BEHIND). Push/pull before opening a PR."
  fi

  EXISTING_PR="$(gh pr list --head "$BRANCH" --state open --json number,url --jq '.[0].url //       
  empty')"
  if [[ -n "$EXISTING_PR" ]]; then
    die "an open PR already exists for branch '$BRANCH': $EXISTING_PR"
  fi

  if ! gh issue view "$ISSUE_NUM" --json number >/dev/null 2>&1; then
    die "issue #$ISSUE_NUM not found (branch '$BRANCH' implies it should exist). Rename the branch
  or create the issue."
  fi

  DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')"
  [[ -n "$DEFAULT_BRANCH" ]] || die "could not determine repo default branch."

  mapfile -t LABELS < <(gh issue view "$ISSUE_NUM" --json labels --jq '.labels[].name' 2>/dev/null  
  || true)

  BODY="$(printf '## Summary\n%s\n\n## Test plan\n%s\n\nCloses #%s\n' "$SUMMARY" "$TEST_PLAN"       
  "$ISSUE_NUM")"

  GH_ARGS=(pr create --title "$BRANCH" --body "$BODY" --base "$DEFAULT_BRANCH" --head "$BRANCH")    
  for label in "${LABELS[@]:-}"; do
    [[ -n "$label" ]] && GH_ARGS+=(--label "$label")
  done

  PR_URL="$(gh "${GH_ARGS[@]}")" || die "gh pr create failed."
  printf '%s\n' "$PR_URL"