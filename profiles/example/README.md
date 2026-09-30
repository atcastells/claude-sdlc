# Example profile

A profile adds your organization's rules on top of the core workflow. The
core stays generic; everything that names your company, people, systems or
policies lives in a profile. This one is a template: copy it, then fill it in.

```bash
cp -R profiles/example profiles/my-org     # profiles/* is git-ignored, except this example
$EDITOR profiles/my-org/*
./install.sh --profile profiles/my-org     # remembered for later reinstalls
WORKFLOW_PROFILE=profiles/my-org bash evals/run.sh
bash scripts/check-public.sh               # before publishing a fork: no private term leaks
```

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Appended to the core `~/.claude/CLAUDE.md`. Language, data-protection law, compliance contact, anything specific. Keep it short: it is resent on every turn (core + profile ≤ 110 lines). |
| `profile.env` | Names the hooks use in their messages. Plain `KEY=VALUE` data, never executed. Keys: `WF_ORG_NAME`, `WF_SECRETS_MANAGER`, `WF_COMPLIANCE_CONTACT`, `WF_POLICY_NAME`. |
| `evals/cases/*.json` | Evals for your rules. Installed as `p-*.json`; `{profile}` resolves to this directory in repo mode. |
| `settings.json` | Optional. Permission lists are unioned with the core template; other keys are deep-merged. |
| `denylist.txt` | Terms that must never appear in the public repo (your company, people, internal hosts). Read only by `scripts/check-public.sh`; never installed. |

A private profile never leaves your machine: `.gitignore` excludes
`profiles/*` except this directory, and `scripts/install-git-hooks.sh` runs
`check-public.sh` before every commit and push.
