# Phase 9 soak checklist

Thresholds in `config/phase9-soak-thresholds.json` are frozen before execution. A short smoke is not a soak.

- [ ] Record release identity, machine, OS, architecture, operator, and start time
- [ ] Run every required scenario for at least 24 hours
- [ ] Sample RSS and file-descriptor counts every 300 seconds (at least 288 samples)
- [ ] Record every crash, supervision event, failure, and recovery
- [ ] Compare observed maxima/growth against every configured threshold
- [ ] Record completion time and retain raw samples under the repository `_build` evidence tree
