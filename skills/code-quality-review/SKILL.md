---
name: code-quality-review
description: Judge how a pull request, branch or stack (often everything behind one issue) will age, against the repository's own guides (CONTRIBUTING, coding standards, AGENTS.md, ADRs) - one home per rule, reuse without abstracting ahead of need, reads like the rest of the codebase, no duplication or drift across PRs. Use when asked about code quality, maintainability, conventions or the simplest way to do something. Read-only unless asked to apply its findings, as a build flow does. Not for bugs (/code-review) or a quick cleanup of the current diff (/simplify).
---

# Code quality review

Answer one question: is this the simplest way to express the change, does it follow the repository's own rules, and
will it age well? Take the functionality as vetted. Correctness bugs belong to a code review; mention one if you trip
over it, but don't hunt for them.

A thumbs-up is a valid outcome. Don't invent findings to have something to say.

Scale to the input. For a single PR, step 1 is a line and step 5 is skipped; the rest applies as written.

## Ground rules

- Read-only. No comments, reviews, pushes or edits on the PRs unless the user asks. In apply mode, below, you change
  code in your own worktree and nowhere else.
- Fetch before reading. Never reset, check out or edit in a clone or worktree you didn't create for this review.
  Build the end state in a scratch worktree of your own, and remove it when you are done.
- Cite every finding as `path:line` at the head of the PR it is in, and name the PR.

## 1. Map the whole change

Start from what the user gave you and find everything that belongs to it:

- The issue's body and comments, which often hold a PR table and a merge order: `gh issue view N --comments`.
  PRs that mention it: `gh pr list --search "N in:body" --state all`.
- Stacked PRs: a PR whose base is another PR's branch, and PRs based on one of these (`gh pr list --base <branch>`).
- PRs in sibling repositories (docs, libraries) that the PRs link to.
- Design records the PRs cite or change (ADRs, design docs), and any plan the user keeps for the work, such as a
  task tracker entry or a handoff.

List each PR with its number, base and head, size, merge order and what it does in one line. The sizes show where
the weight is.

## 2. Read the repository's guides

Read the rules the repository writes down for itself before reading any code, so findings are measured against them
rather than against taste. Find them at the base branch:

```
git ls-files | grep -iE '(^|/)(contributing|coding[-_]?standards?|style[-_]?guide|conventions|agents|claude)\.md$|copilot-instructions\.md$|^\.cursor/rules/|pull_request_template|(^|/)(adr|adrs|decisions)/'
```

When the repository has no CONTRIBUTING file of its own, GitHub falls back to the organization's `.github`
repository: `gh api repos/<org>/.github/contents/CONTRIBUTING.md --jq .content | base64 -d`. READMEs next to the
changed code can carry rules of the same kind; read those too. Ignore guides inside vendored or third-party code,
and from an ADR folder read only the records the PRs cite or whose subject the change touches.

Guides complement and extend each other:

- A file at the root, or under `docs/` or `.github/`, applies to the whole repository.
- A component's file, often in `<component>/docs/` or the component root, applies to the files under that component
  and adds what only it needs. It usually names the file it extends and links to it.
- For each changed file, apply the root files and every component file whose component contains it. Where they
  disagree, the more specific file wins.
- If a PR changes a guide, judge the code against the guide as the PR leaves it, and review the guide change as part
  of the PR.

Sort what the guides say:

- **Rules about code**, from coding standards, AGENTS.md and the code parts of CONTRIBUTING: naming, structure,
  error handling, where things live, what to avoid. These are criteria for every lens in step 6.
- **Rules about the change**, mostly from CONTRIBUTING and the PR template: tests required with a change, changelog
  or release-note entries, docs updated alongside, one concern per PR, migrations or deprecations handled a stated
  way. Check these against the PR as a whole.
- **Rules about process** that a reviewer cannot see in the change, such as branch naming, sign-off or who
  approves. Leave these out.

Skip what a tool already enforces. Find the linters, formatters, analyzers and CI checks (`.editorconfig`, lint
configs, `.github/workflows/`) and check the PR's CI status instead (`gh pr checks N`). The review adds value on the
written rules no tool checks.

When the code around the change consistently does something a guide forbids, the guide may be stale. Don't flag the
PR for following its neighbors; raise the mismatch as an open question.

## 3. Write down the yardstick

Before judging anything, write one line each for:

- the rules the change implements, usually the issue's acceptance criteria;
- the repository rules from step 2 that apply to the changed files, citing each as `guide:line`;
- the principles the codebase already states about this area, in comments, ADRs and READMEs, such as "state comes
  from the server, so it survives reloads" or "the outer layer decides what renders";
- how the plan said to build it, when there is a plan. Where the code drifted from the plan, the plan was often the
  simpler shape.

## 4. Read each PR against its own base

- Read the code first, then the tests:
  `git diff <base>...<head> -- . ':!*.test.*' ':!*.spec.*' ':!*Tests*' ':!*/test/*'`. The tests show which states
  the author thinks can occur. A test that renders a unit below the app's outer gate proves the unit works,
  not that the state can occur in the app.
- Read the whole file where the change sits inside dense logic, such as a state machine, a router or a wrapper. The
  diff hides what the new code competes with.
- For each new helper, flag, state field, hook, diagnostic, event or configuration option, note the question it
  answers and how many callers it has.

## 5. Build the end state

Each PR can look fine alone while the merged result answers the same question five ways. Merge the stack in its
merge order into a scratch worktree with the script next to this file:

```
scripts/merge-stack.sh <repo> <scratch-dir>/merged origin/main origin/<first-branch> origin/<second-branch> ...
```

It keeps both sides of a conflict, so a conflicted source file may not compile; the tree is for reading and
searching only. Search it for the lookups, type checks and conditions you noted in step 4, to see how often each
now appears.

## 6. Look through these lenses

The lenses pull in both directions: toward consolidating what is duplicated, and away from abstracting what is not.
A finding from one group should not create a finding in another.

**Duplication**

1. **One rule, one place.** For each rule from step 3, list every place that works it out and compare the
   conditions. Different conditions for the same rule will drift apart. Suggest one owner that decides, and a
   helper or context the others read.
2. **An existing mechanism beside the new one.** Before accepting a new flag, state field, helper or code path,
   search for one that already does the job: similar names, the neighbors of the changed code, the PR the change
   builds on. A new `transitioning` flag next to an existing `locked`, or a hand-written "has a page" check next to
   an existing `getFirstPage`, are typical.
3. **Copied lookups.** The same few lines that find, classify or parse something, pasted across files. Look for a
   helper that already exists before suggesting a new one.
4. **Copies across tools.** The same definition in the runtime, the editor, the CLI and the analyzer. Some copying is
   forced, as when an analyzer cannot reference the runtime. Diff the copies anyway: drift between them is the
   strongest evidence you can bring.

**Necessity**

5. **Abstraction ahead of need.** A new interface, base class, generic parameter, helper or configuration option
   with one caller or no named consumer. Inline it until a second caller exists. Two or three similar lines are
   cheaper than the wrong abstraction.
6. **Reachability.** For each defensive condition, trace from the outermost layer (router, wrapper, gate,
   validation) whether the state can reach it. When an outer layer already rules the state out, the inner check is
   a second source of truth. Prefer ruling invalid states out once, at the outer layer.
7. **Permanent code for a passing state.** Migrations, compatibility branches and suggestions that exist only for
   previews or one-off upgrades, when another tool already covers them.
8. **Dead code left behind.** A branch reachable only through another PR's short-circuit; a route, URL or parameter
   nothing requests anymore; a helper whose callers are gone.

**Placement**

9. **Where state lives.** Session-local memory, timers and effects that track something the server knows break when
   the user reloads or opens a second tab. Check whether the source system already stores something close, such as
   a `FirstDeferredAt` beside a missing `FirstFailedAt`, that would make the code a pure function of fetched state.
10. **Policy hidden in generic code.** A rule added inside a generic evaluator, base class or utility, keyed on
    identity, that nobody reading the caller will find.
11. **Signature creep.** Positional booleans and parameters added to thread one special case through a general
    function. The decision often belongs somewhere else.

**Consistency**

12. **Siblings handle the same problem the same way.** Sibling implementations, such as task types, handlers or
    migrations, should check the same kind of problem at the same point (startup, run, request), with helpers of the
    same shape.
13. **Overlapping diagnostics and messages.** Two errors or warnings that mean the same thing, often matched by a
    single condition elsewhere, should be one with the reason as an argument. Check whether they have shipped before
    suggesting a merge.

**Explicitness**

14. **Implicit invariants.** A comment such as "only X renders here" or "this can only happen when" carries a rule
    the code does not enforce. Make it explicit with the shared check from lens 1.
15. **Tests that cannot fail.** A test that asserts what the code does rather than what it must do, mocks the unit
    it claims to test, or would pass with the change reverted. Ask what the broken version would make it print.
16. **Comments that tell the journey.** Comments and doc comments that describe how the code got here ("now uses",
    "no longer", "changed to") or restate the code, instead of saying what the thing is or why it must be so.

Name what is already right as well: a removed workaround, a deleted subsystem, one helper shared by several call
sites. The user needs to know what to keep.

## 7. Verify before reporting

For each finding:

- Open the code at the PR head again and confirm the lines.
- Say how you know it. Verified: you ran or checked it. Inferred: it follows from reading. For an inferred
  reachability claim, say how to confirm it, such as which test suite to run after narrowing the condition.
- Drop it if it does not hold up, or if it is only a style preference the repository's guides and code don't share.
- If a suggestion would change behavior, say so and leave the decision to the user. Don't reopen functionality the
  user called vetted.
- Check that the suggested shape itself follows the guides from step 2 and does not trip another lens.

Run tests or experiments only when a claim depends on them and reading cannot settle it.

## 8. Report

In the chat, unless the user asks for a page or PR comments:

1. Two or three sentences on the problem and what the change offers.
2. The verdict in one paragraph: thumbs-up, close, or not yet, and what kind of work the findings ask for, such as
   consolidation, simplification or redesign.
3. What is already right.
4. The findings, ordered by how much they affect how the code ages, not by bug severity. For each: a title that
   states the point, the PRs, the places as `path:line` bullets, why it ages badly, the suggested shape, and the
   guide rule it relates to as `guide:line`, if any.
5. Rules about the change from step 2 that the PRs miss, such as a missing changelog entry or tests, one line each.
6. Open questions: judgment calls that depend on facts you don't have, such as how many apps use something, a team
   decision, or a guide the codebase no longer follows.
7. Small items, in one short list.
8. What you ran and what you didn't, which guides you applied, and which checkout the line numbers refer to.

Offer to turn the report into a page or PR comments. Don't post anything unless asked.

## Apply mode

When you are asked to make the changes rather than report them, as the code quality pass in a build flow is, review
the same way, then:

- Before anything else, and again at the start of every later round, check that you are in a worktree of your own,
  then move it to the commit you were given:
  ```sh
  git rev-parse --show-toplevel   # under .claude/worktrees/, and not the author's checkout
  git status --porcelain          # empty
  git reset --hard <sha>
  git log --oneline -1            # shows <sha>
  ```
  If either check fails, stop and say so without changing anything: you may be in the author's checkout. Install the
  repository's dependencies in your worktree if it has none. Never push and never write to the author's branch; the
  author takes your commits from your worktree, so leave it in place when you finish.
- Change anything inside the footprint you were given, usually the files the change touches, into the shape you would
  suggest. Outside it, report a proposal instead of committing: a reviewer of this change should not have to review a
  second one.
- Behaviour does not change. Every test stays green, including the red team's reproduction tests; run the full suite at
  your head, not a subset. You may move or rename the red team's tests, but leave their assertions as they are: they
  pin the behaviour, and a loosened assertion also stays green. A finding that needs a behaviour change goes in the
  report for the author to decide.
- Commit one finding at a time, with a message that states the point. Renames, moves and formatting go in commits of
  their own. Every change follows the guides from step 2.
- Report as step 8 says, with the commit beside each finding you applied, the proposals you did not apply and why, and
  your worktree's path and head commit.

## 9. Clean up

Remove the scratch worktree you added in step 5 with `git -C <repo> worktree remove --force <dir>` and
`git -C <repo> worktree prune`, and delete the temporary files you made. Leave every other worktree alone, including
the one you work in.
