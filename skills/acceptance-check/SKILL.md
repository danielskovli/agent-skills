---
name: acceptance-check
description: Check a finished branch against its spec's acceptance criteria the way a user would. Reruns the full suite and the red team's reproductions, walks every criterion through the running product, and records before and after with the pr-evidence skill. Use as the last pass before a pull request opens, or when asked to accept a branch against its spec. Not for just seeing a change run (use run).
---

# Acceptance check

You come to the change fresh, the way its first user will. Answer: does each acceptance criterion hold when you use
the product, and can a reviewer see that it does? Don't hunt for edge cases; a red team has done that. Your value is
that you did not watch it being built.

## Ground rules

- Before anything else, and again at the start of every later round, check that you are in a worktree of your own,
  then move it to the head commit you were given:
  ```sh
  git rev-parse --show-toplevel   # under .claude/worktrees/, and not the author's checkout
  git status --porcelain          # empty
  git reset --hard <sha>
  git log --oneline -1            # shows <sha>
  ```
  If either check fails, stop and say so without changing anything: you may be in the author's checkout. Install the
  repository's dependencies in your worktree if it has none.
- Don't change the code, and don't read the ledger. Your output is a report and the captures in the run directory's
  `evidence/`.
- Start every server you use from your own worktree, and stop it when you are done. If a port is already taken, find
  out what holds it rather than using it: a capture served from someone else's checkout shows the wrong code. Finish
  with your worktree on the head commit.
- The `not handling` entries you were given are settled. Raise one again only with new evidence that it matters more
  than was judged.

## 1. Run what exists

Run the full suite at the head, not a subset, and read the summary. Run the red team's reproduction tests by name and
its scripts in `repro/`, and confirm that each now shows the expected result.

## 2. Use it

For each acceptance criterion, in order, use the product as a user would: from a screen or command they would
recognise, through the steps, to the result. Record for each whether it holds, fails or cannot be checked, and how you
checked it.

Note what confuses you as a first-time user, such as a label that misleads or an error that doesn't say what to do,
even when the criterion technically holds. Give it a low severity; the author decides.

## 3. Capture

Follow the `pr-evidence` skill by reading `<this skill's directory>/../pr-evidence/SKILL.md`, not a skill of that name,
which may be an older copy. Decide what to capture as it says: for a
fix, before at the base commit and after at the head, with the same steps and input; for a new feature, usually after
alone. Write captions and alt text. To switch revisions, check out the base and the head in your own worktree, after
the same checks as the first step.

Put the files in `evidence/` and write `evidence/evidence.md`: a draft of the pull request's Evidence section with the
premise, each caption and the file it belongs to. Don't attach anything or open a pull request; the author does that.

When a criterion fails, capture the failure. It is the evidence the author needs.

## 4. Report

1. The verdict in one sentence: accept, or not yet.
2. Each acceptance criterion: holds, fails or cannot be checked, and how you checked it.
3. The findings, most severe first. For each: an id (C1, C2, …), a title that states the problem, the criterion, steps
   to reproduce from a recognisable start, what you expected and what happened, and whether you saw it (**CONFIRMED**)
   or infer it (**PLAUSIBLE**).
4. The evidence files and the path of `evidence.md`.
5. What you ran, with the commits.

## 5. Second round

The author answers with SendMessage after fixing. Move to the new commit with the first step's checks and reset, check
your findings again, run the suite again, and capture again only what the fixes changed. When the author rejects a
finding, answer with steps or a capture, not with argument.
