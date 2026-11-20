---
name: pr-evidence
description: Captioned before-and-after screenshots or recordings that show pull request reviewers what a change looks like to a user or developer. Use when a change affects UI, interactions, CLI output or terminal workflows and the diff alone does not show the result, or when asked for screenshots, a GIF or a recording for a pull request.
---

# Show the change to reviewers

Demonstrate the scenario, the relevant change and its result so a reviewer can understand the experience without
running it locally. Use screenshots for static results, GIFs for short interactions, and MP4 for longer sequences
where playback controls help.

- Keep artifacts in a directory of their own outside the checkout, such as `/home/agent/code/.artifacts/<task>/<run>/`
  in the agent sandbox. No capture report is required.
- Keep each attachment within 10 MiB. There is no fixed duration limit, but GIFs should be brief enough to follow
  without seeking. Leave enough pauses to read commands, see state changes and understand the result.
- Capture actual behavior from the tested revision, using test data without secrets, tokens or personal data, in the
  frame or in a URL.

The recipes assume the agent image's tools: `playwright-cli`, `asciinema`, `agg`, `ffmpeg`, and the `video-to-gif` and
`media-preview` helpers. Where a helper is missing, the recipes say what plain `ffmpeg` does instead.

## Decide what to capture

Capture when the result is something a reviewer would otherwise have to run the change to see. Skip it when the diff
already shows everything, such as a text change, a renamed flag or a refactor with no visible effect, and say in the
pull request that there is nothing to show.

- For a bug fix, capture before and after. For a new feature, after is usually enough.
- When the point is a number, such as how many labels wrap or how long a step takes, a table of measurements says more
  than a picture. Add a screenshot only to show what was measured.
- Prefer one screenshot of the right state over a recording, when nothing about the interaction matters.

## Show what a reviewer would see

A reviewer watches a recording knowing only the pull request and its issue. They should be able to tell where the
recording starts, what each action does and what the result means.

- Start from a screen the reviewer recognizes, such as the app's start page, and do setup before recording.
- Make every change on screen follow an action the reviewer can see. Navigating by URL or reloading mid-recording
  looks like the page changed on its own.
- For a bug fix, reach the bug the way a user does, by following the issue's steps through the product. Do not
  create the broken state behind the scenes, since that shows the symptom without showing it can happen. When the
  issue's steps do not reproduce it, find the path that does, and say in the pull request how the data arose.
- Record before and after with the same steps and input, and take screenshots at the same viewport, crop and device
  scale, so the two can be compared side by side.
- Crop a screenshot to the part that changed, with enough around it to recognize where it is. A full 2× screen of
  which one field changed makes the reviewer search.
- Warm up first: load each page once, so that slow first loads do not throw off the timing. Wait for the next element
  rather than sleeping a fixed time.
- An overlay, highlight or annotation that the product does not draw is fine when it helps, such as one that reads a
  value the eye cannot see. Say in the caption that it is not part of the product.

Before attaching, watch the whole recording once, as that reviewer.

Read only the relevant recipe: [browser](references/browser.md), [desktop](references/desktop.md) or
[terminal](references/terminal.md). The desktop recipe suits a flow with several pages or a native window, and needs an
Agent with a graphical desktop.

## Write the evidence section

Put the captures under an `## Evidence` heading in the pull request body:

1. One or two sentences on the premise: which app or command, what data, and the starting state.
2. Each capture with a caption above it that says what to look at, labelled with the revision it shows, such as
   **Before (base `4f8a80f`)** and **After (`d35ce46`)**.
3. Alt text on every image and GIF that says what it shows, not "image" or a filename. A video renders as a player
   and cannot carry alt text, so its caption has to say it all.

## Attach

From the artifact directory, use local image references in the PR body; `gh --attach` uploads files and rewrites
those references to hosted URLs. Pass one `--attach` per file, with the alt text after a `#`. For example, after
pushing the branch:

```sh
gh pr create --repo <owner>/<repo> --base main --head <branch> \
  --title 'fix: ...' --body-file pr-body.md \
  --attach './before.gif#Before: links are lost after autosave' \
  --attach './after.gif#After: links survive autosave'
gh pr edit <number> --attach './after.gif#After: links survive autosave'
```

A file the body does not reference is appended to the end of the body, so reference each one where its caption is.

If an upload fails, inspect the PR before retrying: partial success can create or update the PR despite a nonzero
exit. Retry missing attachments with `gh pr edit`, rather than repeating creation. Uploads need repository write
access and a token recognized by `gh` as a personal access or OAuth token.

Read the body back with `gh pr view <number> --json body -q .body` and confirm attachments have hosted URLs and sit
under their captions.
