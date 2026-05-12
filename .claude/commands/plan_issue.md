Begin a plan in plan mode for the work in the current `/Begin_session` worktree. Follow the steps below in order before doing any open-ended exploration.

## 1. Establish issue scope (do this first, before any other reads)

This worktree was created by `/Begin_session <N>` and is tied to exactly one GitHub issue. Read that scope explicitly — do not assume it from chat context.

1. Read `PLAN.md` at the worktree root. It contains the seeded Summary, Suggested implementation, Files-expected-to-change, and a `Closes #N` trailer. Extract `N`.
2. Re-fetch the live issue body (it may have been edited since the worktree was created):
   ```bash
   gh.exe issue view <N> --json number,title,body,labels,url,state
   ```
   If `gh` is not on PATH, use `gh.exe` directly (WSL setup). State the title and URL back to the user as the first thing in your plan.
3. **If the issue is a parent with sub-issues**, do NOT plan the parent. List its sub-issues via:
   ```bash
   gh.exe api repos/:owner/:repo/issues/<N>/sub_issues --jq '.[] | {number, title, state}'
   ```
   Then stop and ask the user to `/Begin_session` against one of the children — `/Begin_session` is one-worktree-per-issue, and parent issues are tracking-only.
4. **Read the "Related issues / PRs" section** of the issue body. For each linked open issue/PR, run `gh.exe issue view <M> --json state,title,url` (or `gh.exe pr view`) and surface its state. If a sibling is in-flight, ask the user via `AskUserQuestion` whether to coordinate, wait, or proceed independently — do not silently re-plan work already in motion.

## 2. Plan the work

Once scope is locked to one primary issue:

- Review project documentation as needed. Always start with `DOCUMENTATION_INDEX.md` per the project's CLAUDE.md (it points to the targeted doc, saving you from reading multiple ~1000-line MDs).
- Use context7 for library/SDK/CLI docs — even for libraries you think you know, since training data may lag. Skip context7 for refactoring, scripts from scratch, business-logic debugging, or general programming concepts.
- Invoke `/grill-me` to stress-test the plan and resolve each branch of the decision tree.
- Spawn sub-agents **for research only** (use `Explore` for codebase searches, `Plan` for design validation). Do not delegate synthesis or understanding.
- If you are <95% confident in the architecture, present multiple options with pros/cons and an explanation of the issue — do not pick silently. Ask follow-up questions whenever ambiguous; lean toward questioning over assuming.
- Adhere to security best practices and tie the plan back to the project's overall goal (per CLAUDE.md / MAIDI_PRODUCT_SPECIFICATION.md) before finalizing.

## 3. Output

End your turn with either `AskUserQuestion` (still resolving requirements) or `ExitPlanMode` (plan finalized and ready for approval). No other ending.
