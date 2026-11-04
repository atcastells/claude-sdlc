# Intent: Claudio — new name, plain README, workflow tips

- **Originator**: maintainer
- **Date**: 2026-11-04
- **Status**: approved by product owner (2026-11-04, "apruebo")
- **Slug**: claudio

## The problem, in the originator's words

> "I want to make an improvement: rename it to Claudio, improve the README
> so it is simple, zero technical, with a single instruction so the user's
> AI agent takes care of everything, and add tooltips with recommendations
> based on the workflow."
> (translated from Spanish)

Three asks, kept separate so each can be approved on its own:

1. **Rename** the project to Claudio.
2. **README** simple and non-technical, with one instruction to paste into
   the user's AI agent that does the whole install.
3. **Tooltips**: recommendations based on the workflow.
4. **Company progress phrases** (added 2026-11-04): "I want the starter
   kit phrases to move to the Elektro3 company profile we have in the
   documentation repo, and to be applied when that profile is installed."
   (translated)

## Who it affects

Any Claude Code user who would install the workflow (chosen 2026-11-04),
including people who are not technical. What the repo shows today (verified 2026-11-04):

- The name `claude-sdlc` appears in 45 tracked files: the GitHub remote
  (`atcastells/claude-sdlc`), the default clone path `~/claude-sdlc`, the
  `claude-sdlc:` prefix of every hook notice (`hooks/workflow-version-check.sh`,
  `hooks/mode.sh`, `hooks/plan-resume.sh`, `hooks/project-profile.sh`), temp
  marker names (`claude-sdlc-mode-<id>`, `claude-sdlc-report-<id>`), evals
  that assert those strings, and past `.sdlc/` artifacts.
- `README.md` (41 lines) already opens with a paste-into-Claude-Code
  install instruction, followed by a by-hand `git clone` command and a
  feature list that uses terms like hooks, evals, `verifier`, Haiku/Sonnet.
- Progress phrases (Claude Code `spinnerVerbs`), verified 2026-11-04:
  64 phrases in the local starter kit (`~/Repos/starter-kit/global/settings.json`,
  not a git repo; its copy in the documentation repo was deleted in commit
  `ec95956`); 27 of them in the maintainer's `~/.claude/settings.json`,
  present since before the first install. Nothing in this repo or in the
  Elektro3 profile sets them.
- The company profile today: `profiles/elektro3/company.json` (in the clone
  `~/Repos/claude-sdlc`) names the documentation repo and one rules file,
  `IA/Perfil Elektro3/Reglas Elektro3.md`. `install.sh` only appends that
  file to `CLAUDE.md`; on an existing `settings.json` it merges only
  `hooks`, `permissions` and `statusLine` and keeps everything else, so a
  company cannot ship phrases today.
- There is no tooltip-like mechanism today. The closest things are the
  status line (`status-line.sh`, shows mode, model, branch, context) and
  the SessionStart / UserPromptSubmit notices the hooks inject.

## What happens if we do nothing

Chosen by the originator (2026-11-04): it is hard to adopt. The technical
name and README put off people who are not technical, so fewer install it.

## How we will know it is solved

Chosen by the originator (2026-11-04), three signals:

- Install with one sentence: someone with no technical knowledge pastes the
  sentence from the README into Claude Code and ends up with Claudio
  installed, without touching the terminal.
- README without jargon: its main part uses none of hook, eval, jq, semver,
  subagent or model names, and fits on one screen.
- Useful hints in the bar: during a plan, the status line shows the task in
  progress against its estimate, what is left of the plan, and a
  context/cost warning, without being asked.

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|
| 2026-11-04 | How far does the rename go? | Everything: visible name, hook notice prefix, temp markers, clone folder `~/claudio`. The GitHub repo is renamed by the maintainer; existing installs keep working from the old path. | maintainer |
| 2026-11-04 | Who reads the plain README? | Any Claude Code user: pastes one sentence, never needs to know what a hook or an eval is. | maintainer |
| 2026-11-04 | Where do the tooltips appear? | "The idea is that they are more meta topics, for example an estimate of the time a task will take, etc., in the status line." (translated) | maintainer |
| 2026-11-04 | Which meta hints besides the estimate? | Task in progress against its estimate (e.g. `T3 4m/6m`); what is left of the plan (e.g. `5/12 · ~22m left`); a context/cost warning. Not chosen: next workflow step. | maintainer |
| 2026-11-04 | One release or several? | One: 3.0.0. | maintainer |
| 2026-11-04 | Company progress phrases | The 64 starter kit phrases move to the Elektro3 company profile in the documentation repo (`IA/Perfil Elektro3/`) and are applied when that profile is installed. | maintainer |
| 2026-11-04 | Company phrases vs the user's own | The company phrases replace the user's. | maintainer |
| 2026-11-04 | "punto y coma" vs "punto y semicolon" | "The Elektro3 one" (translated): read as the starter kit version, "Buscando el punto y coma". | maintainer |
| 2026-11-04 | Only phrases, or other display settings? | Only phrases. Other settings can be considered later if they are visible in all three clients: desktop, terminal and T3 Code. | maintainer |
| 2026-11-04 | Success signals | Install with one sentence; README without jargon; useful hints in the bar. Not chosen as a signal: "nothing breaks for an existing install from `~/claude-sdlc`". | maintainer |

## Open questions

- Answered (2026-11-04): rename covers everything; see Decisions.
- Answered (2026-11-04): README reader is any Claude Code user.
- Answered in part (2026-11-04): tooltips are meta information in the
  status line, e.g. how long a task will take. Data that exists today:
  the `Est` and `Status` columns of `.sdlc/<slug>/plan.md`, the `start`
  lines and actuals in `.sdlc/<slug>/actuals.jsonl`, and the medians of
  `skills/sdlc/calibrate.sh`. Answered (2026-11-04): see Decisions.
- Answered (2026-11-04): one release, 3.0.0.
- Compatibility for existing installs: the rename decision says they keep
  working from the old path, but it was not chosen as a success signal.
  Design must say how far it goes (old clone path, old `claude-sdlc:`
  prefixes in evals, old temp markers) and whether a migration note is
  enough.
- Plan progress in the status line: which plan counts when several
  `.sdlc/<slug>/plan.md` are open, and what is shown outside a plan.
- Context/cost warning: thresholds are not stated (the bar already turns
  yellow at 60% and red at 80%).
- Answered (2026-11-04): company phrases replace the user's; the starter
  kit wording wins; only phrases for now (see Decisions). Still open: what
  happens to the user's phrases if the profile is later uninstalled or
  drops them (restored from the install backup, or left as they are).
- Writing the phrases file into the documentation repo changes a repo
  other than this one (company GitLab); the maintainer commits it.
- "Without touching the terminal": installing needs `jq` and `git`; a user
  without them depends on the agent installing them, which may need
  permissions on their machine.

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.
