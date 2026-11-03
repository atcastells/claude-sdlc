# Map: <project>

The whole project at a glance. Nodes are systems or features, not single
changes; edges mean "builds on". Updated at the end of each Vibe iteration.

```mermaid
flowchart LR
  classDef idea fill:#eef,stroke:#88a,stroke-dasharray: 4 3
  classDef wip fill:#ffd,stroke:#b90
  classDef done fill:#dfd,stroke:#393
  classDef dropped fill:#eee,stroke:#999,color:#999

  core[Core]:::done
  feature_a[Feature A]:::wip
  feature_b[Feature B]:::idea
  core --> feature_a
  core --> feature_b
```

| Node | State | Local document |
|------|-------|----------------|
| Core | done | — |
| Feature A | wip | `.sdlc/vibe/feature-a.md` |
| Feature B | idea | — |
