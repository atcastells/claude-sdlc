# Plan: actuals

## Tasks

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| T1 | first | a.sh | case 1 | R1 | implementer | — | 5m/400k | done (W1) |
| T2 | second | b.sh | case 2 | R2 | main | T1 | 5m/500k | in progress |

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| W1 | T1 | 5m | check |

## Estimate vs actual

| # | Runs on | Est | Actual | Deviation (min / tok) | Cause |
|---|---------|-----|--------|-----------------------|-------|
| T1 | implementer | 5m/400k | 1.5m/235k | −70 % / −41 % | starting table too high |
