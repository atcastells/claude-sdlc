# claude-sdlc

An agentic SDLC workflow for [Claude Code](https://code.claude.com).

## Install

Paste this into Claude Code:

```text
Install the claude-sdlc workflow: clone https://github.com/atcastells/claude-sdlc into ~/claude-sdlc (git pull if it is already there), read its README, run ./install.sh --no-profile (or --profile <dir> if I tell you I have an organization profile), and show me the eval summary it prints.
```

Or by hand (requires `jq`):

```bash
git clone https://github.com/atcastells/claude-sdlc && cd claude-sdlc && ./install.sh --no-profile
```

## What you get

- **Every change leaves a trail.** `intent.md` → `spec.md` → `plan.md` →
  diff + tests → PR → `incident.md`, committed in the repo. Nothing is built
  before you approve the plan.
- **Guards that do not depend on the model.** Hooks block credentials in
  code, weakened tests and actions on production.
- **Git stays yours.** Claude prepares; you commit, push and release.
- **Work verified before you see it.** A `verifier` runs the build, the tests
  and two nearby flows; three `reviewer`s check bugs, security and fit with
  the spec.
- **Lower cost.** Haiku looks things up, Sonnet verifies and reviews, the
  main model edits.
- **Rules that stay true.** An eval suite tests the configuration itself and
  runs whenever it changes.
- **Your organization's rules on top.** Language, data protection, secrets
  manager and compliance contact go in a profile:
  [`profiles/example`](profiles/example/README.md).

## License

MIT — see [LICENSE](LICENSE).
