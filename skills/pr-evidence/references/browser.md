# Browser captures

Use a named session per task. Keep the viewport consistent when comparing revisions. Run capture commands from
the artifact directory.

```sh
export PLAYWRIGHT_CLI_SESSION=<task>
playwright-cli open --browser chromium http://localhost:8080/
playwright-cli resize 1280 720
playwright-cli snapshot
# Navigate using the snapshot's element refs.
playwright-cli screenshot --filename=result.png
```

For an interaction, record the scenario with pauses long enough to follow each action and read its result. Size the
video to the viewport, since it is otherwise scaled to fit 800 by 800 pixels. `--cursor` draws a pointer that travels
to each action, so the reviewer sees what is clicked:

```sh
playwright-cli video-start browser.webm --size 1280x720 --cursor
playwright-cli run-code --filename=scenario.js
playwright-cli video-stop
video-to-gif browser.webm result.gif
media-preview result.gif
playwright-cli close
```

`scenario.js` supplies an async Playwright function taking `page`. Navigate to the starting page before
`video-start`, and only click or type after it, so that nothing changes on screen without a visible cause.
`playwright-cli video-chapter` adds a title card between steps when the steps need naming. Use `playwright-cli --help`
for commands or the `playwright-cli` skill for more involved automation. Standalone Playwright scripts are also an
option: run them with `NODE_PATH="$(npm root -g)" node script.js`, and in an ES module load Playwright with
`createRequire(import.meta.url)('playwright')`, since `import` ignores `NODE_PATH`.

Two traps in `run-code` takes:

- **A native dialog ends `run-code` early.** At a `confirm()` or `alert()` the CLI returns with a "Modal state" block
  and no `### Result`, while the script runs on in the browser: the take looks failed, `video-stop` cuts it, and the
  app has changed anyway. Replace the dialog before the action, and again after every `goto`:
  `await page.evaluate(() => { window.confirm = () => true; })`. Check each script's output for its return value,
  not the exit code.
- **`page.screencast.showOverlay` overlays outlive navigation** and stack when replaced from concurrent handlers. For
  a panel that updates, draw one element by id and redraw it whole, and start each take in a fresh tab (`tab-new`,
  then `tab-close 0`).

A failed take usually leaves the app changed, so set its state up with a script you can rerun on a fresh copy.

`video-to-gif` supports `--start`, `--duration`, `--width` and `--fps`. Trim irrelevant waits or reduce dimensions/frame
rate without sacrificing readability. For longer interactions, prefer MP4:

```sh
ffmpeg -i browser.webm -c:v libx264 -pix_fmt yuv420p -movflags +faststart -an result.mp4
```

Inspect the screenshot or the contact sheet produced by `media-preview` before attaching.

Without the helpers, `ffmpeg` does both. A GIF with a palette computed from the clip, which is smaller and sharper than
the default palette, and a contact sheet of eight frames to read as an image:

```sh
ffmpeg -i browser.webm -vf "fps=12,scale=1280:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" result.gif
ffmpeg -i result.gif -vf "select=not(mod(n\,<frames/8>)),scale=480:-1,tile=4x2" -frames:v 1 result.preview.png
```
