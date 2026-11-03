---
name: workflow-install
description: Finds out where the company repo (the one that holds the shared company rules) lives on this machine, or helps clone it, and gives the developer the one command that installs the rules. Use it with /workflow-install, or when the user says "install the company rules", "where is the company repo", or when the session-start notice says the saved company repo is missing.
---

# Install the company rules

The installed workflow profile may point at a company repo whose rules file
is composed into `~/.claude/CLAUDE.md` by `install.sh`. This skill finds that
repo and hands the developer the command. It writes nothing itself.

## Step 0: read the profile

```bash
p=$(cat ~/.claude/workflow/profile 2>/dev/null) && jq -r '.url, .rules' "$p/company.json"
```

`url` is the clone URL, `rules` a path relative to the company repo. If there
is no profile or no `company.json`, say there is nothing to set up and stop.

`<name>` below is the basename of `url` without `.git`.

## The flow

One `AskUserQuestion` per step.

1. **Where is the company repo?** Options, fixed suggestions that are not
   checked in advance: `~/Repos/<name>`, `~/<name>`, "Not cloned yet (show me the
   clone command)". The free-text "Other" is added automatically for any other path.
2. **Cloning only: where to clone?** A second `AskUserQuestion` with the same
   two suggestions (and "Other").
3. **Check only the chosen path.** When the repo should already exist, check
   that `<dir>/<rules>` is a file (`test -f`). If not, say so in one
   sentence and ask again (step 1). When cloning, the directory may not
   exist yet: do not check it.
4. **Show one command** for the developer to run with `!`. Expand `~` to the
   real path. `<source>` is the content of `~/.claude/workflow/source`.

   Existing clone:

   ```
   ! cd '<source>' && ./install.sh --company-repo '<dir>'
   ```

   Cloning first:

   ```
   ! git clone '<url>' '<dir>' && cd '<source>' && ./install.sh --company-repo '<dir>'
   ```

   Say that this skill does not run it: the command clones and writes to
   `~/.claude`, so the developer runs it.

## Rules of this skill

- It never runs `git clone` or `install.sh`: it only shows the command.
- It does not search the disk: no `find`, no `ls` over home. It only checks
  the one path the developer chose.
- It never edits `~/.claude`, the profile or the company repo.
- The installer validates the rules file again; if it refuses, show its
  `company rules:` message in plain words and go back to step 1.
- When the saved company repo goes missing (moved or deleted), the
  session-start notice suggests `/workflow-install`; the flow is the same.
