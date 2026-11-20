---
name: review-pr
description: Review a GitHub pull request. Use when the user asks to review, analyze, or critique a PR — by number, URL, or reference to "this PR" / "current PR". Covers code review, architecture review, blind-spot analysis, comment triage, and a suggested reading order for the human reviewer.
user-invocable: true
---

# PR Code Review

Review a GitHub pull request in three passes: (1) code analysis, (2) blind-spot analysis, (3) triage of existing review comments. Report everything back in chat for discussion — do NOT post comments to GitHub.

The goal is not a verdict — it is the best possible analysis to fuel a follow-up discussion with the PR authors. Two rules follow from that:

- **Defects must be earned.** Every defect claim needs a concrete failure scenario traced through the actual code. No vague "this might be a problem" findings.
- **Questions are not defects.** Anything worth discussing that you cannot prove wrong is raised as an open question, clearly separated from findings. An insightful question is often more valuable than a minor finding — never pad the findings list to look thorough, and never soften a real defect into a question to be polite.

## Input

The user provides a PR number (e.g. `123`) or a full GitHub URL.

Extract the PR number. If a URL is provided, also extract the `owner/repo` — otherwise use the current repo.

## Phase 0 — Setup

1. Fetch PR metadata:
   ```bash
   gh pr view <number> --json title,body,baseRefName,headRefName,files,url,comments,reviews
   ```

2. Determine if you're already on the PR's head branch:
   - If yes: work directly in the current worktree.
   - If no: check out the PR branch in an isolated worktree so the user's working directory is not disturbed. Follow the environment's worktree convention if its instructions name one (for example one worktree per task under a fixed directory); otherwise use the `EnterWorktree` tool.

3. Fetch the diff:
   ```bash
   gh pr diff <number>
   ```

4. Gather context beyond the diff:
   - Read the PR description and any linked issues — note what the PR *claims* to do and any explicitly stated non-goals.
   - If the project has an `AGENTS.md`, `CLAUDE.md`, or relevant ADRs covering the touched areas, read them — they are the authoritative reference for architecture and conventions.
   - Skim recent history of the touched areas (`git log --oneline -15 -- <paths>`) for related in-flight work the PR might conflict or overlap with.

## Phase 1 — Code Analysis

Analyze the PR methodically. For each changed file, read the full file (not just the diff hunks) to understand surrounding context. Skip trivial changes (formatting-only, import reordering) and focus on substantive logic changes.

### How to read the code

- **Always read the full file** for files with substantive logic changes — diff context lines are not enough.
- **Grep for usages** when a public API changes (method signature, interface, model property) to verify all call sites are updated.
- **Check test coverage** for new/changed behavior — what is tested, and what new behavior has no test?

### Analysis lenses

These guide what you look for. They are **not** output sections — findings from all lenses go into one ranked list.

1. **Correctness** — does the implementation match the PR's claims? Logic errors, off-by-one, race conditions, unhandled edge cases, incorrect queries/migrations, missing test updates.
2. **Architecture & layer boundaries** — business logic in controllers, data access leaking into domain layers, tight coupling, domain models polluted with infrastructure concerns, work done in the wrong layer. Judge against the project's own documented architecture, not generic ideals.
3. **Robustness & quality** — error handling (missing or excessive), premature or missing abstractions, unnecessary complexity, naming inconsistent with the codebase, duplication vs. premature DRY.
4. **Security** (light touch) — injection, secrets in code, missing authorization on new endpoints, overly permissive CORS/auth. Note obvious concerns; don't deep-dive.

### Verification discipline

Before a candidate defect becomes a reported finding:

1. **Construct the failure scenario**: a specific input or state that produces a specific wrong outcome. If you cannot construct one from the actual code, it is not a defect — drop it, or demote it to an open question if it's still worth discussing.
2. **Re-read the relevant code** to confirm the scenario survives contact with the full picture — guards, callers, validation upstream, or tests you may have missed on first read often dissolve a finding.
3. **Label the result**: `CONFIRMED` (traced end-to-end through the code) or `PLAUSIBLE` (couldn't fully verify, but the risk is concrete enough to raise).

## Phase 2 — Blind-Spot Analysis

This pass looks for what the authors *haven't* considered — things the diff itself won't show you.

**First, steelman the PR**: write down (for yourself, not the output) the strongest case for why the authors' approach is right. Attacks that survive a steelman are the ones worth raising; attacks that don't are noise.

Then work through these angles. Not all apply to every PR — skip the irrelevant ones silently rather than padding:

- **Unstated assumptions** — what must be true for this code to be correct that nothing enforces or documents? (Call ordering, single-writer assumptions, data invariants, "this config is always present", "this list is always small".) Which of these are load-bearing?
- **The dog that didn't bark** — what did this PR *not* change that arguably should move with it? Symmetric operations (create without delete, setup without teardown), other call sites with the same underlying bug, docs, config, error paths, monitoring.
- **Requirements drift** — what small, plausible change in requirements would break this design? Is the solution shaped around today's exact case in a way that will hurt tomorrow?
- **Failure modes under stress** — partial failure mid-operation, retries and idempotency, concurrent execution, timeouts, resource exhaustion, what happens at 100x the expected volume.
- **Ownership windows** — when the PR introduces or extends a contract that hands an owning resource (a stream, a disposable, a lease, a lock) to a caller, enumerate every window between acquiring it and handing it on, and ask what throws inside each: a throw before the handoff, a loop that fails halfway through owned items, the next hop downstream. Asking "does each caller dispose what it receives?" only covers the happy path. "Unchanged by this PR" is a blame argument, not a correctness argument; trace it anyway and make the scope call explicitly.
- **Lifecycle & operations** — rollout order and rollback safety, migration sequencing, compatibility with in-flight versions during deploy, observability (if this breaks in production, how would anyone find out, and how fast?).
- **Alternatives not taken** — is there a meaningfully simpler design, or a different layer for this change, that the authors may not have weighed? Only raise alternatives that are genuinely competitive — not hypotheticals for their own sake.
- **Second-order effects** — what does this change make harder later? What precedent does it set that the next PR will copy?

The output of this phase is **open questions and discussion points**, not defects. If attacking from one of these angles uncovers an actual defect, promote it into Phase 1's verification discipline and report it as a finding.

## Phase 3 — Review Comments

After completing your own analysis (so existing comments don't anchor it):

1. Fetch all review comments on the PR:
   ```bash
   gh api repos/{owner}/{repo}/pulls/<number>/comments --paginate
   gh api repos/{owner}/{repo}/pulls/<number>/reviews --paginate
   gh api repos/{owner}/{repo}/issues/<number>/comments --paginate
   ```

2. For each substantive comment (skip bot noise, resolved threads, and "LGTM"):
   - Summarize the comment and who made it
   - State whether you **agree**, **disagree**, or **partially agree**, with brief reasoning
   - Note if a comment overlaps with one of your findings or questions

## Output Format

Organize the output by **findings ranked by severity**, not by review criteria. Never write per-category "No issues found" filler — positive verification gets exactly one compact section, and empty sections are omitted entirely.

```markdown
## PR Review: #<number> — <title>

**Branch:** `<head>` → `<base>`
**Files changed:** <count>
**PR link:** <url>

### Summary
<1-3 sentences: what the PR does, plus a one-sentence overall assessment. If the PR
exceeds a reviewable size, say so here and how it could have been split.>

### Suggested reading order
<For the human who reads this after you. One line per step: file (and function or
region), what it does, why it comes at this point. Start at the entry point, follow
the flow, put where state changes in the middle, end at the riskiest part. Mark
mechanical files (snapshots, generated code, lock files) as skimmable. Omit for
PRs of one or two files.>

### Findings
<Ranked most-severe first. Omit this section entirely if there are none —
say so in the Summary instead. Each finding:>

**<n>. [<blocker|major|minor|nit>] [<CONFIRMED|PLAUSIBLE>] <one-sentence defect>** — `file:line`
<Failure scenario: specific input/state → specific wrong outcome.>
<Suggested direction, if useful — a direction, not a full patch.>

### What was verified
<2-5 bullets: the substantive things checked that came up clean — e.g. "all 7
call sites of the renamed method updated", "migration is reversible and ordered
correctly", "new endpoint covered by integration tests". This is where
confirmation of correctness lives — compact, specific, and only for checks that
actually took effort. Not a restatement of the lens list.>

### Open questions & blind spots
<From Phase 2. Numbered, each one specific to THIS PR: the question, and one
sentence on why it matters / what hangs on the answer. These are discussion
prompts for the authors, not defects. Skip generic questions that could be
asked of any PR.>

### Review comments
| Comment | Author | My take |
|---------|--------|---------|
| <summary> | <author> | <agree/disagree/partial + reasoning> |

### Verdict
<One of: Approve / Request Changes / Needs Discussion>
<Which findings (if any) are blocking, and which questions most deserve an
answer before merge.>
```

## Important

- Do NOT post anything to GitHub. All output stays in chat.
- Do NOT approve or reject the PR via `gh`. Just report your analysis.
- A clean PR is a valid outcome: zero findings with a strong "What was verified" section and sharp open questions is a *better* review than padded findings. A fabricated or unverified finding costs more credibility than a missed nit.
- If the PR is very large (20+ files), prioritize files with the most substantive changes, note which files you skimmed vs. deeply reviewed, and say in the Summary that it exceeds a reviewable size and how it could have been split.
- If you used a worktree, exit it when done with `ExitWorktree`, or remove it if you created it by hand.
- **Reviewing work you or another session authored?** Remembered dispositions ("pre-existing", "already filed", "out of scope") are claims, not facts. Re-verify them with the same skepticism as the code and surface them at full weight; self-review bias survives fact-checking by hiding in the classifications.

## After the review

If the review surfaced a reusable lesson — a class of defect worth checking for next time, a technique that found something, a convention the authors keep missing — write it as a feedback memory following the memory conventions in force. One lesson per file, with the why. Skip PR-specific details that will not recur.
