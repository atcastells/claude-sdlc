# .sdlc — artifact chain

Every development stage ends by writing a file here that the next stage
reads. The commit chain is the audit trail: who asked for what, what the agent
produced, who approved it.

```
.sdlc/<slug>/
  intent.md    the problem, in the originator's words       -> product owner approves
  spec.md      requirements and design, policy applied       -> PO + tech lead approve
  plan.md      atomic tasks; nothing is implemented until    -> the engineer approves
               it is APPROVED
  review.md    validation findings, for the PR               -> code owner approves
  incident.md  only if something failed in production        -> service owner
```

`<slug>` in kebab-case, one per task. Always committed — they are part of the
code, not private notes.

Templates and details: the global `sdlc` skill. To fill an intent question by
question: the `intent` skill.
