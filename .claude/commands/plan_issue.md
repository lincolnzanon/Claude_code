Begin a plan in plan mode for a GitHub issue. Follow the steps below in order before doing any open-ended exploration.

## 1. Establish issue scope (do this first, before any other reads)

Lock the plan to exactly one GitHub issue before reading anything else. Read that scope explicitly — do not assume it from chat context.

1. Determine the issue number `N`. Take it from the argument to this command if given; otherwise infer it from the current branch name (e.g. `123-some-label` → `123`) or a `PLAN.md`/task file at the repo root containing a `Closes #N` trailer. If you cannot determine `N` unambiguously, ask the user.
2. Re-fetch the live issue body (it may have been edited since work started):
   ```bash
   gh issue view <N> --json number,title,body,labels,url,state
   ```
   State the title and URL back to the user as the first thing in your plan.
3. **If the issue is a parent with sub-issues**, do NOT plan the parent. List its sub-issues via:
   ```bash
   gh api repos/:owner/:repo/issues/<N>/sub_issues --jq '.[] | {number, title, state}'
   ```
   Then stop and ask the user to pick one of the children to plan against — parent issues are tracking-only.
4. **Read any "Related issues / PRs" section** of the issue body. For each linked open issue/PR, run `gh issue view <M> --json state,title,url` (or `gh pr view`) and surface its state. If a sibling is in-flight, ask the user (via `AskUserQuestion`) whether to coordinate, wait, or proceed independently — do not silently re-plan work already in motion.

## 2. Plan the work

Once scope is locked to one primary issue:

- Review project documentation as needed. If the repo has an index/table-of-contents doc (e.g. `DOCUMENTATION_INDEX.md`, `README`, or `CLAUDE.md`), start there so you read the targeted doc rather than many large ones.
- Use context7 for library/SDK/CLI docs — even for libraries you think you know, since training data may lag. Skip context7 for refactoring, scripts from scratch, business-logic debugging, or general programming concepts.
- If a `/grill-me` command is available, invoke it to stress-test the plan and resolve each branch of the decision tree.
- Spawn sub-agents **for research only** (use `Explore` for codebase searches, `Plan` for design validation). Do not delegate synthesis or understanding.
- If you are <95% confident in the architecture, present multiple options with pros/cons and an explanation of the issue — do not pick silently. Ask follow-up questions whenever ambiguous; lean toward questioning over assuming.
- Adhere to security best practices and tie the plan back to the project's overall goal before finalizing.

## 3. Output

End your turn with either `AskUserQuestion` (still resolving requirements) or `ExitPlanMode` (plan finalized and ready for approval). No other ending.
