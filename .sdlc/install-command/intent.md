# Intent: Suggest the exact install command when the machine is behind

- **Originator**: maintainer
- **Date**: 2026-10-08
- **Status**: approved by product owner (2026-10-08, asked for in the request)
- **Slug**: install-command

## The problem, in the originator's words

> "Being blocked on running install.sh should be suggested automatically,
> with a command."

## Who it affects

Every developer who changes the workflow or pulls a new version: the
installed `~/.claude` stays behind until someone remembers `install.sh`.

## What happens if we do nothing

Observed on 2026-10-08 on the maintainer's machine:

- `~/.claude` has 2.0.0; 2.1.0 is committed and 2.2.0 is ready in
  `/Users/<dev>/claude-sdlc`, but no session-start notice appeared.
- Cause: the installation records its source as a **different clone**
  (`~/Repos/claude-sdlc`, still at 2.0.0). `workflow-version-check` compares
  installed vs that clone, finds them equal, and stays silent. The clone the
  developer is working in is never compared.
- When the notice does fire, it says "Recommend the developer runs
  `<src>/install.sh`": no ready-to-run command and no hint that it can be run
  from the session with `!`.

## How we will know it is solved

- Whenever the machine is behind, the session-start notice carries one
  command the developer can run as is (`! cd '<dir>' && ./install.sh`).
- Opening a claude-sdlc clone that is ahead of the installation triggers the
  notice, whatever clone the installation came from.
- The agent shows the command; the developer runs it (it writes to
  `~/.claude`).

## Open questions

None.
