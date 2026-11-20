# agent-skills

Skills for building software with coding agents, written for Claude Code. They take a feature from an idea or
an issue to a pull request a reviewer can trust:

| Skill | What it does |
| --- | --- |
| `build-feature` | Takes a feature or an issue to a draft pull request through three gates with you (the spec, a demo, the draft), running the skills below as subagents. Runs only as `/build-feature`. |
| `red-team` | Tries to break a change and returns each problem as a failing test. |
| `code-quality-review` | Judges how a change will age against the repository's own guides; read-only unless asked to apply its findings. |
| `acceptance-check` | A last pass that uses each acceptance criterion as a user would and records the evidence. |
| `pr-evidence` | Captioned screenshots and recordings that show reviewers what a change looks like. |
| `review-pr` | A three-pass review of a pull request, reported in chat, with a reading order for the human reviewer. Posts nothing. |

The skills are environment-neutral: where they need something that differs between setups (where to note a
problem found along the way, where captures go), they defer to your own instructions.

## Install

**As a Claude Code plugin:**

```text
/plugin marketplace add danielskovli/agent-skills
/plugin install agent-skills@danielskovli
```

**In an agentctl agent definition:** clone this repository and list the skills you want under `skills`, each as
`- source: <clone>/skills/<name>`.

**By hand:** link or copy `skills/<name>` into `~/.claude/skills/` or a project's `.claude/skills/`. Install
`acceptance-check` together with `pr-evidence`, which it reads from beside itself.

## Contributing

`ruby scripts/check-skills.rb` checks every skill's frontmatter and that no person or organisation is named in
one; CI runs it with Claude Code's own `claude plugin validate .`.
