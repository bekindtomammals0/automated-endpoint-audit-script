# Windows Endpoint Health Report

## Problem Statement

An administrator needs a lightweight, repeatable way to capture essential Windows 11 endpoint health information in a CSV file. Manual checks of free space, Windows Update, reboot state, and Microsoft Defender are slow and inconsistent.

## Solution

Provide a modular Windows PowerShell 5.1 script that collects the agreed health state from the local Audited Endpoint, assigns clear Health Status values, and exports one Health Report record to a parameterized CSV destination. The script is prepared on macOS but executes and is validated on a Windows 11 laptop.

## User Stories

1. As a Windows administrator, I want to run one script locally, so that I can collect core endpoint health state consistently.
2. As a Windows administrator, I want the script to identify the System Drive automatically, so that nonstandard Windows installations are handled correctly.
3. As a Windows administrator, I want free space reported in gigabytes and as a percentage, so that I can judge storage capacity quickly.
4. As a Windows administrator, I want disk capacity classified as `Healthy` when at least 10 GB and 10 percent remain, so that low-capacity endpoints stand out.
5. As a Windows administrator, I want the exact Windows Update service state reported, so that I can identify whether updates can operate.
6. As a Windows administrator, I want the Windows Update service classified by its operating state, so that a stopped or disabled service is distinguishable from a running service.
7. As a Windows administrator, I want standard registry-based pending-reboot signals evaluated, so that I can see whether a restart is needed.
8. As a Windows administrator, I want each detected pending-reboot reason retained, so that I can understand why the endpoint needs a restart.
9. As a Windows administrator, I want Microsoft Defender protection, service, and signature information reported, so that I can assess antivirus coverage.
10. As a Windows administrator, I want a Health Report even if an individual check is inaccessible, so that one failure does not suppress the other collected state.
11. As a Windows administrator, I want check-level errors included in the Health Report, so that I can distinguish missing data from an unhealthy endpoint.
12. As a Windows administrator, I want the output location configurable, so that I can store the report where my workflow requires.
13. As a Windows administrator, I want the default report written to `C:\Temp\HealthReport.csv`, so that the script works without extra arguments.
14. As a Windows administrator, I want the default export to replace the prior report and an option to append history, so that I can choose between current-state and historical reporting.
15. As a developer using macOS, I want the implementation committed before cloning onto Windows, so that Windows-specific execution occurs against the exact reviewed revision.
16. As a Windows administrator without elevation, I want the script to report inaccessible checks as `Unknown`, so that it remains useful without requiring administrator rights.

## Implementation Decisions

- The script runs locally on an Audited Endpoint under Windows PowerShell 5.1. PowerShell 7 compatibility is secondary and is not the validation target.
- The public interface accepts an `OutputPath` parameter whose default is `C:\Temp\HealthReport.csv`, and an optional append mode.
- The script creates a missing output directory before export. An output-directory or export failure is handled and reported rather than terminating with an unhandled exception.
- Separate modules of script logic collect System Drive capacity, the Windows Update service state, pending-reboot registry state, and Microsoft Defender state. An orchestration step packages their results into exactly one `[PSCustomObject]` per execution.
- The Health Report includes collection timestamp and endpoint identity; raw check values; a Health Status for each check; pending-reboot reasons; Defender service, antivirus, antispyware, real-time protection, and signature data where available; and a consolidated error field.
- System Drive capacity is healthy only when both free capacity measures meet the agreed threshold: at least 10 GB and at least 10 percent. Below either threshold is `Warning`.
- The Windows Update service is queried by its `wuauserv` service name. `Running` is `Healthy`; `Stopped` and `Paused` are `Warning`; `Disabled` is `Unhealthy`; and an inaccessible or unavailable query is `Unknown`.
- A pending reboot is present when at least one of these standard registry signals exists: Component Based Servicing `RebootPending`, Windows Update `RebootRequired`, or Session Manager `PendingFileRenameOperations`.
- Defender state is read from the Windows Defender management interface. Antivirus, antimalware service, antispyware, and real-time protection values are retained when available. A disabled required protection value is `Unhealthy`; unavailable Defender data is `Unknown`. Signature version and last-update data are informational and have no agreed staleness threshold.
- Every check uses independent `Try/Catch` handling. A failed check produces `Unknown` and adds a descriptive error, while the other checks and export still proceed where possible.
- The script must not require elevation. Running elevated may produce more complete data but does not change the script contract.

## Testing Decisions

- The primary seam is the script's public invocation with a supplied OutputPath. A good test runs the script and checks externally visible Health Report output, rather than asserting internal function calls.
- On Windows 11, verify that the script creates a CSV containing one row and the documented fields, reports the actual System Drive and `wuauserv` state, evaluates reboot state, and returns Defender data when the management interface is available.
- Verify replacement behavior with the default export mode and multi-row behavior with append mode.
- Exercise error resilience by making at least one supported data source unavailable or inaccessible where safely possible, then confirm the Health Report retains other check results and records an `Unknown` status and error.
- No existing automated tests or test harness exist in this repository. If automated tests are introduced, use Pester and retain Windows 11 integration validation as the authoritative environment-specific check.

## Out of Scope

- Automatic remediation of disk, update, reboot, or Defender problems.
- Installing updates, restarting the endpoint, changing services, or changing Defender configuration.
- Remote endpoint collection, fleet aggregation, scheduling, alert delivery, dashboards, or a graphical interface.
- Configurable health thresholds beyond the agreed disk capacity rule.
- A Defender signature-age health threshold.
- Validation of Windows-only APIs on macOS.

## Further Notes

- Development and documentation work may occur on macOS, but Windows-specific commands, registry locations, and Defender data must execute on a Windows 11 Audited Endpoint.
- The initial real-world validation takes place after the repository is cloned to the Windows 11 laptop.
- Local Git is initialized for source and planning-document tracking. No remote issue tracker is configured, so the ready-for-agent tickets are stored locally.
