# 01 — Build the Endpoint Health Report

**Migrated to:** [GitHub Issue #1](https://github.com/bekindtomammals0/automated-endpoint-audit-script/issues/1)

GitHub is the canonical tracker for this ticket. This file is retained as an archived planning record.

**What to build:** A Windows administrator can run one modular Windows PowerShell 5.1 command on an Audited Endpoint and receive a single exported Health Report that covers System Drive capacity, Windows Update service state, registry-based reboot state, and Microsoft Defender state. The report handles each unavailable data source independently, writes to the configured destination, and supports current-state replacement or historical append output.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] The script accepts the agreed output path and append behavior, creates its output directory when needed, and exports exactly one Health Report object for a normal execution.
- [ ] The report includes all four health checks, their agreed classifications, and raw information needed to interpret each result.
- [ ] A failed individual check is reported as `Unknown` with an error while successful checks remain in the exported Health Report.
- [ ] The default output is `C:\Temp\HealthReport.csv`; the System Drive is detected rather than hard-coded.
