# Installing Claudio — steps for the agent

You are the person's AI agent. They may not be technical: do the work, ask
only what you cannot find out, and say what you are doing in one plain
sentence per step. Do not ask them to type commands.

1. **Tools.** Claudio needs `git` and `jq`. Check with `command -v git jq`.
   If one is missing, ask the person before installing anything, then use
   what the machine has (macOS: `brew install jq` with Homebrew,
   `xcode-select --install` for git; Linux: the system package manager;
   Windows: inside WSL). If they say no, stop and tell them what is missing.
2. **Get Claudio.** If `~/claudio` holds a Claudio clone (it has
   `install.sh` and `VERSION`), update it with
   `git -C ~/claudio pull --ff-only`. An older clone at `~/claude-sdlc`
   keeps working: update and use that one instead. Otherwise run
   `git clone https://github.com/atcastells/claudio ~/claudio`.
3. **Organization profile.** Ask: "Did your company give you its own
   settings for Claudio?" If Claudio was installed before, `./install.sh`
   with no option reuses the previous organization profile: skip the
   question. If yes, get the profile folder. If that folder has a
   `company.json`, it reads the company rules from a company repository:
   ask where they have it, or clone the `url` it names with their access.
4. **Run the installer** from the Claudio folder, with `--verbose` so the
   self-check runs in front of you:
   - with a profile: `./install.sh --verbose --profile <folder>`, adding
     `--company-repo <folder>` when step 3 found a company repository;
   - without one: `./install.sh --verbose --no-profile`;
   - Claudio installed before and the question skipped: `./install.sh --verbose`
     (keeps the previous profile; never add `--no-profile` here, it drops it).
   It writes to `~/.claude`, keeps a backup of the previous settings, and
   ends with the self-check summary (`PASS: <n> FAIL: 0`). If the company profile
   brings its own progress phrases, they replace the person's own; say so.
5. **Explain the result in plain words**: what was installed, whether the
   self-check passed, that they should restart Claude Code, and that `/vibe`
   and the bottom bar of the terminal are now available. If something
   failed, say what and what you suggest; do not retry with other options
   without asking.
