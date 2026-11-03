---
name: rules
description: Adds, modifies or deletes the user's personal rules for Claude, asking one question at a time — the action, the scope (every repo of this user, or the repo of this session) and, for this repo, whether the rule applies to the whole repo or only to some files. Rules are never shared with the team. Use it with /rules, or when the user says "add a rule", "remember to always…", "from now on in this repo…", "change/delete that rule", "what rules do I have".
---

# Personal rules

A rule is a short instruction Claude reads at session start, or when it
touches the files the rule names. This skill manages **the user's personal
rules only**: nothing it writes is committed or reaches the team.

The user never edits a file and does not need to know where a rule lives.
**Every change goes through `~/.claude/skills/rules/rules.sh`** (called
`R` below): never create, edit or delete a rule file with Write, Edit, `rm`
or a redirect. Reading one with Read is fine.

| Scope | Loads | Stored in (do not tell the user unless asked) |
|---|---|---|
| Global | in every repo, every session | `~/.claude/rules/personal/<topic>.md` |
| This repo, whole repo | in this repo, every session | `<repo>/.claude/rules/personal/<topic>.md`, excluded from git locally |
| This repo, some files | in this repo, when Claude reads or edits a matching file | same, with `paths:` |

## The flow

One `AskUserQuestion` per step. If the user's message already answers a step
(e.g. "/rules add: always answer in Spanish, global"), skip it.

1. **First question: the action** — add, modify or delete. With no rules yet
   (`R list` is empty), go straight to add.
2. **Scope** — global or this repo. Outside a git repo, only global exists:
   say so and skip the question.
3. **This repo only: whole repo or some files.** For some files, run
   `R globs --repo .` and offer up to four of its patterns, each with
   its match count in the `description`; the user can type their own.
4. **The text.** Ask for it in the user's words. Tidy it into one to five
   imperative lines without changing its meaning. Propose a kebab-case topic
   from it.
5. **Preview and confirm.** Show the final text, the topic and where it
   applies, in one sentence ("Applies in this repo when Claude reads or edits
   `**/*.sql`"). Write only after a yes.
6. **Write**, always with the text in a quoted heredoc so `` ` ``, `$` and
   quotes in it stay literal:

   ```bash
   ~/.claude/skills/rules/rules.sh write --scope repo --repo . --topic sql-params --path '**/*.sql' <<'RULE'
   <the rule text, verbatim>
   RULE
   ```

   Drop `--repo .` and `--path` for a global rule; one `--path` per glob. On
   a refusal, show the `rules:` message in plain words and go back to the
   step it concerns.

**Modify and delete** start from `R list --repo .` (JSON). Offer the rules
as options: topic as label, scope, paths and the `preview` as description.
`preview` holds only three lines: for the full text, Read the rule's `file`.
Modify reuses steps 2–6 with the current values as defaults; a new scope or
topic is a write in the new place plus a delete of the old one. Delete shows
the full text and asks for confirmation before
`R delete --scope <scope> [--repo .] --topic <topic>`.

## Notices, once each, after a successful add

- **a rule is not a lock**: Claude follows rules as instructions and may
  still get one wrong. If the text says "never…" about something that must
  not happen (a command, a file, a deploy), say that only a hook blocks it
  and suggest asking for one. Do not create the hook here.
- **No customer data in rules**: names, emails, tax IDs, addresses, purchase
  history, costs, margins or stock never go in a rule. Credentials are
  refused by the script.
- **Size**: when the always-loaded personal rules (global plus this repo
  without `paths`) pass 40 lines in `R list`, say that long rules are
  followed less consistently and offer to merge or scope some.

## Gotchas

- A rule with broken frontmatter loads **everywhere** instead of on its files,
  silently. That is why only `R` writes them; never "fix" one by hand.
- Never put the rule text inside double quotes in a command: backticks and
  `$(…)` would run, and `$VAR` would be replaced. Always the `<<'RULE'`
  heredoc.
- Path-scoped rules load when Claude reads or edits a matching file, not on a
  Glob or Grep. Say so if the user expects a rule to apply to a search.
- A repo rule lives in this worktree only; another worktree of the same repo
  does not have it.
- Global and repo rules do not override each other: if they contradict,
  Claude may follow either. On add, if `list` shows a rule in the other scope
  on the same topic, point it out.
- Rules do not reach cloud sessions or Projects threads.
- The organization profile, the repo's `CLAUDE.md`, `CLAUDE.local.md` and any
  rule outside `personal/` are not this skill's: say where they live and that
  they are edited by hand in their own repo.
