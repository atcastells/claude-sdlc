# <repo-name>

<One sentence: what it is, for whom, on which stack. What an `ls` does not tell.>

## Commands

```bash
<build>       # <what output means it is fine; how long it takes>
<test>        # <how many tests; what is normal>
<lint>        # <>
<start>       # <>
```

## Structure

<What is new and what is legacy. Where not to extend. What an `ls` does not tell.>

## Conventions

- Code in English. Comments only when the logic is not obvious. No emojis.
- <naming, aliases, the repo's own patterns>
- Tests are mandatory for business logic. Before proposing a commit: `<test>`
  and `<lint>`.

## Security

- NEVER log passwords, tokens, or customers' personal or tax data.
- NEVER commit `.env*`, certificates or keystores. Secrets live in the secrets
  manager and are injected through environment variables.
- NEVER point at production from development.
- <domain-specific rules: soft delete, sanitization, etc.>

## Git

- NEVER run `git commit`, `push`, `merge`, `rebase`, `reset`, `stash`, `tag`,
  `cherry-pick`. Git writes belong to the developer.
- `checkout` and `branch` only when the developer explicitly asks.
- Base branch: `<master|main>`.

## What Claude gets wrong

<Empty at first. When Claude repeats a mistake twice, it goes here.>
