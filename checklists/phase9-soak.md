# Phase 9 soak checklist

Thresholds in `config/phase9-soak-thresholds.json` are frozen before execution. A short smoke is not a soak.

- [ ] Record release identity, machine, OS, architecture, operator, and start time
- [ ] Run every required scenario for at least 24 hours
- [ ] Sample `at`, `rss_mib`, and `file_descriptors` every 300 seconds (at least 288 samples, with coverage from start to finish)
- [ ] Record every crash, supervision event, failure, and recovery
- [ ] Record aggregate `unexpected_process_exits` and `failed_lifecycle_scenarios` counts
- [ ] Compare observed maxima/growth against every configured threshold
- [ ] Record completion time and retain raw samples under the repository `_build` evidence tree
