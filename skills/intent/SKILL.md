---
name: intent
description: Feeds and refines the intent.md of SDLC stage 1 by asking one question at a time, with suggested answers grounded in the code and always the option to answer in your own words. Each answer is written to the file as it arrives. Use it when the user says /intent, wants to start or complete an intent, answer an intent's open questions, or says "keep asking", "ask me", "complete the intent".
---

# Refining the intent

SDLC stage 1. `intent.md` captures the problem **in the originator's words**,
and it almost never comes out complete on the first pass: gaps remain that
only the originator can close.

This skill closes them **one at a time**, and writes each answer to the file
the moment it arrives.

## Finding the file

`.sdlc/<slug>/intent.md` in the current repo. If there are several slugs, ask
which one (one `AskUserQuestion` with a slug per option). If there is none,
start one from `~/.claude/skills/sdlc/templates/intent.md` and fill it with
this same loop.

## Before asking anything: find out

**Do not ask what you can verify.** Every question spends the originator's
attention; spending it on something a `grep` answers is disrespectful.

Before the first question, read the code, the repo's `CLAUDE.md`, the branch
and the files involved. What you find goes into the intent as fact, not as a
question. What remains is what only the originator knows: intent, priority,
risk appetite, scope, and the why behind a historical decision.

Examples of the boundary:
- "Is there already a checkbox component in the design system?" → verify it.
- "Do all three forms get this, or only two?" → ask it.
- "How many lines does the file have?" → verify it.
- "Why does the edit form allow changing the plan but the signup form does
  not?" → ask it; the code says *what* it does, not *why* it was decided.

## The loop

One question per turn. Never two. Never a questionnaire.

1. **Pick the question that changes the work the most.** If the answer does
   not alter what gets built, do not ask it yet. Priority: scope > acceptable
   risk > undocumented historical decision > detail.
2. **Ask that single question with `AskUserQuestion`.** 2-4 options, each with
   a short `label` and a `description` saying what choosing it implies. If you
   recommend one, put it first and add "(Recommended)" to the label.
   The "Other" the tool adds on its own is how they answer in their own words
   — do not add a "write my own answer" option, it is already there.
3. **Write the answer to `intent.md` immediately**, in the section it belongs
   to, and remove it from "Open questions". Do not keep answers in memory to
   dump at the end: if the session drops, they are lost, and that is exactly
   the problem the artifact chain solves.
4. **Record the decision** in the decisions section (see below), with a date.
5. **Re-evaluate.** An answer often opens or closes other questions.
   Recompute the priority before the next one; do not follow a fixed list.
6. **Repeat until the intent supports the decision to move to Design**, or
   until the user says stop.

## Options must be grounded

A suggested option is worth what you know about the repo. Derive each one
from something real — a file, a precedent, a number — and say it in the
`description`.

Bad:
> What scope do you want? · Everything · Part · Minimal

Good (the numbers here are illustrative; yours come from the repo):
> **Do all three forms get it, or only the ones real customers use?**
> - *All three (Recommended)* — The internal form is 250 lines with no
>   pricing logic; a cheap pilot of the pattern before touching signup and edit.
> - *Only signup and edit* — 2,100 lines and the real business risk. The
>   internal one waits until the pattern is proven.
> - *Only edit* — The largest file (1,080 lines) and the one that already has
>   the address block. Starts the pattern where the debt is.

If you have no basis for three distinct options, give two. Two honest options
beat three with a filler.

## When to stop

Stop when the intent supports the decision to move to Design: the problem is
clear, who it affects, how we will know it is solved, and the main risk is
named.

**Not every question needs closing.** A declared gap is a valid outcome: if
the originator does not know, write it down as a gap and move on. What is not
acceptable is filling it in yourself.

When done, summarize in two lines: what was decided and what remains open.
And remind them that the developer makes the commit.

## Sections you maintain

On top of the `intent.md` template, this skill adds and maintains:

```markdown
## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|
| 2026-08-27 | Task scope | All three forms, internal one first | <originator> |
```

That table is the part of the audit trail that says **who decided what and
when**. Never rewrite or reorder it: only append rows.

If an answer contradicts something already written in the intent, fix the
body of the document and add the new row — but do not delete the old one. A
reverted decision is information, not a mistake to hide.

## Rules

- One question per turn. The temptation to ask four is the temptation to turn
  this into a form.
- Each answer is written before the next question.
- Do not invent repo facts to fill an option. If you did not verify it, do not
  claim it in the `description`.
- Do not ask for personal data or sensitive business data (as the
  organization profile defines it) to fill the intent. The intent describes
  the problem; it does not contain the data.
- If the task involves decisions about people or any high-risk scenario, flag
  it in the intent and recommend consulting the compliance contact named in
  the profile before moving to Design.
