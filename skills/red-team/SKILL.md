---
name: red-team
description: Try to break a change before review. Attack a branch or pull request for correctness (boundaries, failure paths, concurrency, state over time, interaction with the rest of the product) and return each real problem as a failing test, with what was checked and found sound. Use when asked to red-team, stress-test, break or poke holes in a change, and as the red team in a build flow. Returns tests, not a written review (that is review-pr); not for style or structure.
---

# Red team

Answer one question: does this change do what its spec promises, in every situation it will meet? You have the spec
and the code. You do not have the author's reasoning, on purpose: judge what the code does, not what it was meant to
do.

Finding nothing severe is a valid outcome. A red team that must find something produces noise, and noise costs the
author a round.

## Ground rules

- Before anything else, and again at the start of every later round, check that you are in a worktree of your own,
  then move it to the commit you were given:
  ```sh
  git rev-parse --show-toplevel   # under .claude/worktrees/, and not the author's checkout
  git status --porcelain          # empty
  git reset --hard <sha>
  git log --oneline -1            # shows <sha>
  ```
  If either check fails, stop and say so without changing anything: you may be in the author's checkout. A review of
  the wrong commit reads exactly like a clean one. Install the repository's dependencies in your worktree if it has
  none.
- Never push, never write to the author's branch, never edit the spec, and don't read the ledger. Your output is
  commits in your worktree, scripts in the run directory's `repro/`, and a report.
- Correctness only. Structure, naming and duplication belong to the code quality pass; mention one in a line only if
  it hides a bug.
- The spec's Decisions and Out of scope are settled. Challenge one only with a concrete defect it causes.

## 1. Know what is promised

Read the spec: each acceptance criterion, the decisions, what is out of scope. Read the diff from base to head, then
the code around it: its callers, the outermost layer that reaches it (router, handler, validation, wrapper), and what
the change competes with. For each criterion, write down the claims it rests on. "A save is persisted" rests on the
request reaching the handler, the write succeeding and nothing overwriting it later.

## 2. Attack

For each claim, look for the input or the situation that breaks it. The usual places:

- **Boundaries**: empty, one, many, the maximum; zero, negative, very large and very small numbers; Unicode,
  whitespace and very long strings; missing versus null versus default.
- **Failure paths**: a dependency that times out, errors, or returns partial or malformed data. What the user sees,
  and what state is left behind.
- **Time and order**: two requests at once, the same request twice (retries, double clicks, at-least-once delivery),
  events out of order, clock and time-zone edges, a step interrupted halfway.
- **State over time**: a reload, a second tab, a restart, data written by the previous version, and data the new
  version writes that the old one must read during a rollout.
- **The rest of the product**: existing features that touch the same data or screen, configuration and permission
  variations, other roles.
- **Security boundaries**: who can call it, what it trusts from the client, what it exposes in errors and logs.

Prefer running to reasoning: run the code, call the endpoint, drive the UI, read the bytes actually written. Start
with the concerns the author named.

## 3. Prove it

For each problem you can reproduce, write the smallest test that fails because of it, in the repository's test style,
next to the tests it belongs with. Commit each finding on its own, tests only and no fix, with
`git commit --only <test files>` and a message that names the finding. Check `git show --name-status` afterwards: a
commit made while a mutation is live ships it. Run the test and confirm it fails for the reason you claim: read the
failure, not just the exit code.

When no test can reach it, such as a race that needs real infrastructure or a path only the UI takes, write a script
to `<run directory>/repro/<finding>.sh` with the exact steps and the expected and actual output.

Mutation-test the tests the author named: break the production code the way each test exists to catch, confirm the
test fails, and restore it. Report each test that passes anyway.

## 4. Report

1. The verdict in two sentences.
2. The findings, most severe first. For each: an id (R1, R2, …), a title that states the failure, the criterion it
   breaks, the evidence, the failure scenario and its severity: would a user hit it, how often, and what it costs them.
   The evidence is **CONFIRMED** with the test's name and commit, or the script, or **PLAUSIBLE** with the reasoning
   and what would confirm it.
3. Tests that are not load-bearing.
4. What you checked and found sound, one line each. This is how the author knows what you covered.
5. Your worktree's path and head commit.

## 5. When the author answers

The author answers with SendMessage, accepting some findings and rejecting others. For each rejection:

- If it shows you misread the code, withdraw the finding.
- If you still think it is real, answer with evidence: a reproduction, or a sharper one. Don't repeat the argument, and
  don't give way because the author sounds sure.
- If it is real and you agree it may not be worth handling, say so. That is the user's decision, not a dispute.

In a second round, move to the new commit with the first step's checks and reset, then check the fixes: run your tests
again, and attack what the fixes changed. Your earlier commits stay reachable; the author has already taken the ones
they accepted.
