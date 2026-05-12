  name: open-pr
  description: Open a GitHub pull request for the current branch, linking the issue referenced in
  the branch name. Use when the user asks to open/create a PR, "ship this", "make a pull request",  
  or similar. Branch must follow `<issue-number>-<label>` convention (e.g. `127-auth-session-fix`).
  ---
  
  # Open PR

  Creates a GitHub PR for the current branch using `./scripts/open-pr.sh`. The script handles       
  preflight checks and PR creation — you supply the **Summary** and **Test plan** content.

  ## When to invoke

  User asks to open a PR for the current branch. Assume the branch is already pushed and commits are   final — this skill does not commit, push, or create branches. If those steps haven't happened
  yet, run `/commit` and `git push` first.
  
  ## Issue conventions

  Issues should follow **`Issue_create`**: title includes the issue number as digits (e.g. `[127] auth-session-fix`), and priority uses exactly one GitHub label **`P0`**, **`P1`**, **`P2`**, or **`P3`**.

  ## Branch convention

  Branch must match `^<digits>-<label>` (e.g. `127-auth-session-fix`). The leading digits are the
  GitHub issue number this PR closes (same as in the issue title). The script will abort if:

  - branch doesn't match the convention
  - the issue doesn't exist on GitHub
  - working tree isn't clean
  - branch isn't pushed / is out of sync with upstream
  - an open PR for this branch already exists
  - `gh` is missing or not authenticated, or `origin` isn't on GitHub

  ## Steps
  
  1. Read the issue for context. Set `ISSUE_NUM` to the leading digits of the current branch (same rule as `open-pr.sh`), then:
     gh issue view "$ISSUE_NUM" --json title,body,labels
  
  2. Read commits and diff on the branch to understand what shipped:
     git log --no-merges ..HEAD --format='%h %s%n%b'
     git diff --stat ..HEAD

  3. Compose:
  - **Summary** — 3–5 bullets describing what changed and why (grounded in the issue + diff).
  - **Test plan** — markdown checklist of how this was validated (commands run, behaviors checked,
  edge cases).                                                                                      

  4. Run the script:
     ./scripts/open-pr.sh
       --summary "$SUMMARY"
       --test-plan "$TEST_PLAN"

  5. Report the printed PR URL back to the user.

  ## Body format produced

  \`\`\`
  ## Summary
  <your summary>
  
  ## Test plan
  <your test plan>

  Closes #<num>
  \`\`\`

  PR title mirrors the branch name. Base branch is the repo default. Issue labels are copied to the 
  PR.

  ## Codex / Cursor

  The script is the source of truth — Codex or Cursor can invoke it directly with the same
  `--summary` / `--test-plan` flags. Only this SKILL.md is Claude Code–specific.

  For Codex / Cursor in the same repo, point them at ./scripts/open-pr.sh in AGENTS.md and
  .cursor/rules/ respectively — same flag contract, no duplication.
