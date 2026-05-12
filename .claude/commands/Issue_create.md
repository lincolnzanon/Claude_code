Create new issues for the above with detailed descriptions adhering to the below. First, review previous issue names and current pending issues; if the new issue overlaps, update the existing issue body via GitHub CLI instead of creating a duplicate.

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
