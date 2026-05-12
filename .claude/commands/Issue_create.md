Create new issues for the above with detailed descriptions adhering to the below. First, review previous issue names and current pending issues; if the new issue overlaps, update the existing issue body via GitHub CLI instead of creating a duplicate.

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
