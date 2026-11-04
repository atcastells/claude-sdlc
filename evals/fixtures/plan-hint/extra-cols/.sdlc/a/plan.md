# Plan

Intro

| # | Task | Files | Test | Requirement | Runs on | Depends | Est | Status |
|---|---|---|---|---|---|---|---|---|
| T1 | run `jq '.x | length'` ok | `a.sh` | t | R1 | main | — | 4m/650k | done (W1; diff read) |
| T2 | b | f | t | R1 | main | T1 | 6m/300k | in progress |
| T3 | c | f | t | R1 | main | T2 | 3m/1M | pending |

After | text
| T9 | ignored | x | x | x | x | x | 99m | pending |
