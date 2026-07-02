Create issues for the above with detailed descriptions adhering to the below. First, review previous issue names and current pending issues, then classify each problem in the input against the partitioning rubric below before any `gh` calls.

## Partitioning rubric (run this first)

| If the problems are…                                                                  | Then create…                                                                                                       |
|---------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------|
| **The same bug at the same place** as an existing open issue                          | No new issue. Update the existing issue body via `gh.exe issue edit <N> --body-file -`.                            |
| **One shippable unit** (one PR, one reviewer, one priority) covering N small items    | **One** issue with a `- [ ]` task list in the body.                                                                |
| **Distinct units of work that share a parent goal** (each needs its own PR/priority)  | **One parent issue + N sub-issues** (see sub-issue workflow below). Each sub-issue is `/Begin_session`-able.       |
| **Distinct units of work with no shared parent**, but cross-referencing each other    | **N separate issues**, each listing the others under "Related issues / PRs."                                       |
| **Genuinely unrelated**                                                               | **N separate issues**, no cross-references.                                                                        |

"Overlap" means the **same** problem at the **same** place. Different bugs in the same module are NOT overlap — make them siblings (parent + sub-issues) or related (cross-linked), not a merged body. Never fold a distinct bug into another issue's body just because they share a file or feature.

## Overlap check (run BEFORE any `issue create`)

Always do this in two passes so titles don't hide overlap:

1. **Browse recent open issues** (titles + labels only, ~50 most recent):
   ```bash
   gh.exe issue list --state all --limit 50 --json number,title,labels
   ```
2. **Targeted search** of titles AND bodies for any term from the problem you're about to file:
   ```bash
   gh.exe issue list --state all --search "<term1> <term2> in:title,body" --json number,title,state
   ```
3. **Read the body** of any title that even *might* overlap before deciding:
   ```bash
   gh.exe issue view <N> --json title,body,state
   ```

**Critical gotcha — never use bare `--search "x OR y OR z"`.** Multi-term `OR` queries without an `in:` qualifier can return results from across all of GitHub (not just the current repo), flooding context with hundreds of irrelevant issues. Always include `in:title,body` (or narrower like `in:title`), and prefer space-separated AND-terms over `OR`.

If an overlap candidate is confirmed (per the rubric above), update its body via `gh.exe issue edit <N> --body-file -` instead of creating a duplicate. Re-emit the *whole* body (gh replaces, doesn't append) — preserve the existing structure and add a "Recurrence log" / "Reconfirmed YYYY-MM-DD" section.

## Environment & bootstrap (read first)

- **WSL note**: if `gh` is not on PATH (common on this user's Windows + WSL setup), use the Windows binary `gh.exe` directly. Check `command -v gh.exe` once; do NOT chase `gh` on PATH.
- **`gh.exe --body-file` cannot read WSL paths** (e.g. `/tmp/foo.md`). Always pipe the body via stdin: `cat body.md | gh.exe issue create --title "..." --body-file -`. Same for `gh.exe issue edit <N> --body-file -`.
- **Bootstrap P0–P3 labels idempotently** before applying. Each `gh.exe label create` is a no-op if the label already exists, so it's safe to run unconditionally:
  ```bash
  gh.exe label create P0 --description Critical --color B60205 2>/dev/null
  gh.exe label create P1 --description High     --color D93F0B 2>/dev/null
  gh.exe label create P2 --description Medium   --color FBCA04 2>/dev/null
  gh.exe label create P3 --description Low      --color 0E8A16 2>/dev/null
  ```
  Skip this step entirely if `gh.exe label list | grep -E '^P[0-3]\b'` already shows all four.
- **Multi-issue workflow — minimize round-trips**:
  1. Write all bodies to local files **with `[N]` placeholders** wherever they cross-reference sibling issues that don't have numbers yet.
  2. Create all issues in parallel (one `gh.exe issue create` per body) and capture the assigned numbers from each URL.
  3. In a single parallel batch, run `gh.exe issue edit <N> --title "[<N>] <slug>" --add-label <Px>` for each (rename + label in one call).
  4. Patch the `[N]` placeholders to real numbers in the local body files, then re-upload bodies in a single parallel batch.
- **Sub-issue workflow** (when the rubric says parent + N children):
  1. Create the parent issue first via `gh.exe issue create`. Capture its number `P` and rename/label it as `[<P>] <slug>` + `Px`.
  2. Create each child issue in parallel (use `[P]` placeholder in child bodies if they reference the parent). Capture child numbers `C1..Cn`.
  3. Link each child to the parent via the REST API (note: `sub_issues` takes the issue's numeric `id`, NOT its `number`):
     ```bash
     for Ci in $C1 $C2 ...; do
       CHILD_ID=$(gh.exe api repos/:owner/:repo/issues/$Ci --jq .id)
       gh.exe api -X POST repos/:owner/:repo/issues/$P/sub_issues -F sub_issue_id=$CHILD_ID
     done
     ```
  4. Rename + label each child (`[<Ci>] <slug>` + `Px`) in a single parallel batch — same as the multi-issue flow above.
  5. Patch `[P]` placeholders in child bodies to the real parent number, then re-upload child bodies in parallel.
  6. The parent body should be a short "why this group exists" + the list of children. GitHub renders sub-issue progress automatically, so don't manually maintain a checklist of child statuses.

## Title (required)

- **Issue number in the title:** Once GitHub assigns the issue number, the title **must** include that same number as digits (typically right after creation). Recommended shape: `[<N>] <short-slug>` where `<N>` matches GitHub’s `#N` (example after creation: `[127] auth-session-fix`).
- **Flow:** Create the issue (`gh issue create` …), read the new number from the command output or URL, then set the final title with `gh issue edit <N> --title "[<N>] <short-slug>"` so the digits in the title always match the issue.
- **Slug:** Use a short kebab-style description (about one to three words after the bracket), e.g. `auth-session-fix`. Before creating, review existing titles and reuse/update overlapping issues instead of duplicating.

## Priority labels (required)

Apply **exactly one** GitHub label whose name is one of:

| Label   | Meaning   |
|---------|-----------|
| `P0`    | Critical  |
| `P1`    | High      |
| `P2`    | Medium    |
| `P3`    | Low       |

Use `gh issue edit <N> --add-label P1` (swap `P1` for the chosen tier). These names are required so `/Begin_session` and other tooling can sort by priority. Do not use alternate spellings or extra priority labels on the same issue.

## Body

Summary: 1–2 sentences stating the problem and its impact.

Context: Where this is observed (e.g., in which component, test, or user flow) and how it was discovered.

Current behavior: What happens now (with example error messages, logs, or code snippets if relevant).

Expected behavior: What should happen instead.

Steps to reproduce (if bug): Clear, numbered steps from a clean state.

Possible causes / root‑cause analysis: 1–2 concise paragraphs with your working hypothesis.

Suggested fix / implementation idea (optional): A high‑level proposal with which files and APIs you’d expect to change.

Related issues / PRs: Link any existing issues or PRs that are relevant.
