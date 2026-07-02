Begin a plan in plan mode for a general task (no GitHub issue required; may or may not run inside a worktree). Follow the steps below in order before doing any open-ended exploration.

## 1. Establish scope (do this first, before any other reads)

Lock the plan to exactly one clearly stated goal before reading anything else. Read that scope explicitly — do not assume it from chat context.

1. Determine the planning subject from the argument to this command if given; otherwise from the user's most recent request, or a `PLAN.md`/task/handoff file at the repo root. If the subject is ambiguous or could cover multiple distinct pieces of work, ask the user which one to plan before proceeding.
2. Restate the goal back to the user in one or two sentences as the first thing in your plan, including what is explicitly **out of scope** if that helps bound the work.
3. **If the task is really a bundle of several independent work items**, do NOT plan the bundle. List the items and ask the user to pick one to plan against — or confirm they genuinely want a single umbrella plan.
4. **Check for related in-flight work.** If the repo has open branches, worktrees, PRs, or issues touching the same area (`git branch -a`, `gh pr list`, `gh issue list` as appropriate), surface their state. If sibling work is in motion, ask the user (via `AskUserQuestion`) whether to coordinate, wait, or proceed independently — do not silently re-plan work already in motion.

## 2. Plan the work

Once scope is locked to one primary goal:

- Review project documentation as needed. If the repo has an index/table-of-contents doc (e.g. `DOCUMENTATION_INDEX.md`, `README`, or `CLAUDE.md`), start there so you read the targeted doc rather than many large ones.
- Use context7 for library/SDK/CLI docs — even for libraries you think you know, since training data may lag. Skip context7 for refactoring, scripts from scratch, business-logic debugging, or general programming concepts.
- If a `/grill-me` command is available, invoke it to stress-test the plan and resolve each branch of the decision tree.
- Spawn sub-agents **for research only** (use `Explore` for codebase searches, `Plan` for design validation). Do not delegate synthesis or understanding.
- If you are <95% confident in the architecture, present multiple options with pros/cons and an explanation of the problem — do not pick silently. Ask follow-up questions whenever ambiguous; lean toward questioning over assuming.
- Adhere to security best practices and tie the plan back to the project's overall goal before finalizing.

## 3. Output

End your turn with either `AskUserQuestion` (still resolving requirements) or `ExitPlanMode` (plan finalized and ready for approval). No other ending.
