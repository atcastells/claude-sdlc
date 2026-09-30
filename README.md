# claude-sdlc

An agentic SDLC workflow for [Claude Code](https://code.claude.com): an
artifact chain (`intent.md` → `spec.md` → `plan.md` → diff + tests → PR →
`incident.md`), deterministic guard hooks, skills, a verifier subagent and an
eval suite that checks the configuration itself. This repo is the source of
truth; each machine's `~/.claude` is an installation.

## Install

Paste this into Claude Code and it installs the workflow for you:

```text
Install the claude-sdlc workflow: clone https://github.com/atcastells/claude-sdlc into ~/claude-sdlc (git pull if it is already there), read its README, run ./install.sh --no-profile (or --profile <dir> if I tell you I have an organization profile), and show me the eval summary it prints.
```

Claude asks for permission before running `install.sh`, which writes to
`~/.claude`. To do it by hand instead:

```bash
git clone https://github.com/atcastells/claude-sdlc && cd claude-sdlc
./install.sh --no-profile                  # core only
./install.sh --profile profiles/my-org     # core + your organization's rules
```

Requires `jq`. The installer is idempotent, backs up what it overwrites, and
ends by running the eval suite: if it does not finish green, the install is
not valid. Hooks take effect in the next Claude Code session. Plugins, session
history, credentials and per-machine settings do not travel with the repo.

## What is in it

| Piece | What it does |
|---|---|
| `global/CLAUDE.md` | Core rules: style, git reserved for the developer, production, data and credentials, quality, stopping and continuing, artifact chain |
| `skills/sdlc` | The six stages, intent/spec/plan/incident/REVIEW templates, session and cost guidance |
| `skills/intent` | Refines an `intent.md` one question at a time, with grounded options |
| `skills/repo-setup` | Audits, sets up or upgrades a repo (deterministic `check.sh`) |
| `agents/verifier.md` | Verifies a change + two adjacent flows; reports, does not fix |
| `hooks/credential-guard.sh` | Blocks writes that embed credentials |
| `hooks/test-guard.sh` | Blocks weakening tests (skip, removed asserts, commented out) |
| `hooks/production-gate.sh` | Blocks actions on production without `RELEASE_APPROVAL` |
| `hooks/evals-on-config-change.sh` | Runs the suite when the agent's config changes |
| `hooks/workflow-version-check.sh` | At session start, says whether the repo or the machine is behind |
| `evals/` | The suite: every case protects a rule; `origin` points to its incident |
| `profiles/example/` | Template for an organization profile |
| `scripts/check-public.sh` | Fails if a private profile or a denylisted term would be published |
| `VERSION`, `CHANGELOG.md`, `migrations/` | Versioning and what projects must change on upgrade |
| `settings.template.json` | Permissions + hooks with `$HOME` paths |

## Profiles

The core names no company, person or internal system. Your organization's
rules — answer language, data-protection law, what counts as sensitive
business data, your secrets manager, your compliance contact — go in a
profile: `cp -R profiles/example profiles/my-org` and fill it in. See
[`profiles/example/README.md`](profiles/example/README.md).

`profiles/*` is git-ignored except the example. If you fork this repo to
publish your own version, run `scripts/install-git-hooks.sh` so
`check-public.sh` runs on every commit and push.

## Updating

Repo → machines → projects:

1. Edit here. `bash evals/run.sh` tests the repo before installing.
2. Bump `VERSION`, add to `CHANGELOG.md` and, if project files change, write
   `migrations/<version>.md` (see `CLAUDE.md` › Releasing a version).
3. `git pull && ./install.sh` on each machine. The profile is remembered.
4. In each project, the `workflow-version-check` hook compares
   `.claude/workflow.json` with the installed version and lists pending
   migrations; `/repo-setup upgrade` applies them with one confirmation.

Your own hooks or permissions go in `~/.claude/settings.local.json`:
`install.sh` replaces `hooks` and `permissions` in `settings.json` whole.

## Cost

You pay per turn and most of it comes from cache. What moves the bill: extra
turns, output (and thinking), and breaking the cache. The workflow already
pushes that way: `medium` effort by default, `verifier` on Sonnet, CLAUDE.md
global + project ≤ 200 lines (`check.sh`), and a cut (`/compact` or `/clear`)
at the end of each SDLC stage. Details in the `sdlc` skill › Session, context
and cost. `/usage` shows the real cost of a session.

## Golden rule

No real credential ever enters this repo, not even as a test fixture: evals
use tokens with a valid format and a fake value (`squ_aaa...`).

## License

MIT — see [LICENSE](LICENSE).
