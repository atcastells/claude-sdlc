# Review: 2.5.0 — secondary profile per repository

- **Slug**: `.sdlc/project-profiles/`
- **Policy**: `skills/sdlc/templates/REVIEW.md` (the repo has no root
  `REVIEW.md`).
- **Passes**: three `reviewer` subagents (bugs, security, conformance) in
  parallel; fixes; `verifier` re-run (green).

## PR description

### What

A repo can declare a secondary profile that is added, for that repo only,
on top of the organization profile.

- `.claude/workflow.json`: `"profile": ".claude/profile"`.
- `hooks/project-profile.sh` (SessionStart: startup, clear, compact; silent
  on resume) injects the profile's `CLAUDE.md`, marked repo-authored,
  capped at 150 lines and 12 KB.
- `hooks/lib/profile.sh`: `project_profile_dir` / `project_profile_file`.
  Relative path inside the repo only; symlinked files ignored; oversized
  files (`profile.env` > 4 KB, `CLAUDE.md` > 16 KB) ignored before reading;
  notices never echo the declared value.
- `credential-guard` and `production-gate` load the repo `profile.env` on
  top of the global one: their messages name the repo's secrets manager
  and policy. What they block does not change.
- `evals/run.sh`: `WORKFLOW_PROFILE` also in installed mode; profile cases
  cannot run code (`script`, `env`, path-like `hook` are skipped); new case
  kind `file_lacks`.
- Template `skills/repo-setup/templates/project-profile/` and `repo-setup`
  notes; `/repo-setup upgrade` keeps every other `workflow.json` key.
- First user: rune-world (`.claude/profile/` in that repo, committed
  there).

### Verification

- `bash evals/run.sh` → PASS 194, FAIL 0 (also with `EVALS_ROOT` set);
  with `profiles/example` → PASS 195.
- rune-world profile cases (`rw-a`…`rw-g`) → PASS 7, FAIL 0, in repo and
  installed mode.
- `HOME=$(mktemp -d) ./install.sh --no-profile` → PASS 181, FAIL 0.
- `check-public.sh` → exit 0 (pre-existing WARN: `LICENSE` placeholder).
- Live: a new rune-world session showed the profile header;
  `/repo-setup upgrade` there kept the `profile` key.

## Findings

### Important — all fixed before this PR

| # | Pass | Where | Defect | Demonstration | Fix |
|---|------|-------|--------|---------------|-----|
| 1 | security | `hooks/lib/profile.sh`, both guards | A large repo `profile.env` made a guard exceed its 5 s timeout before blocking | 400,000-line file: production-gate took 7 s | Files over 4 KB ignored before reading; now 0.04 s, still exit 2 |
| 2 | security | `hooks/project-profile.sh` | The invalid-path notice echoed the repo's value, uncapped, into context | A value with a `SYSTEM:` line was injected | Notices are fixed strings |
| 3 | security | `hooks/project-profile.sh` | 150-line cap did not bound bytes | 200 KB single-line file injected whole | 12 KB byte cap + note; `CLAUDE.md` > 16 KB ignored |
| 4 | security | `evals/run.sh` | Profile cases could run code in installed mode (`script` outside root, `BASH_ENV`) | Marker file created by a profile case | `script`, `env`, path-like `hook` skipped for profile cases |
| 5 | conformance | template | No eval protected the public template | `grep` found no case | Cases 108d–108d6 |
| 6 | conformance | rune-world cases | Nothing checked for organization terms outside the "sin objeto" section | Planted term passed all cases | `rw-g` with the new `file_lacks` kind |

Also fixed: missing-dir notice wording; empty `cwd`; quoted prefix strip;
`EVALS_ROOT` leaking into case 108a; guard coverage for symlinked,
oversized and undeclared `profile.env` (98i); the Git line removed from the
rune-world profile.

### Nits — not fixed

1. An existing profile dir's name appears in the header (one line, no
   newlines; same trust as the repo's `CLAUDE.md`).
2. The repo's `WF_*` names (≤ 400 characters) appear in guard block
   messages: recorded in the spec's policy, not closed.
3. `run.sh` pads names to 58 characters: longer names touch "PASS".
4. A session started in a subdirectory of the repo does not find the
   profile (`cwd` is used as is).

### Unconfirmed

- How Claude Code reacts to a PreToolUse hook timeout (the reason finding
  1 mattered); fixed regardless.
- Whether Claude Code truncates large `additionalContext` itself.
