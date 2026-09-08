# Windows Endpoint Health Audit

This repository will contain a modular PowerShell script for collecting a basic health snapshot from a local Windows 11 endpoint. Development and documentation can happen on macOS, but the script's Windows-specific behavior must be executed and validated on a Windows 11 laptop.

## Planned Script

The implementation will be a Windows PowerShell 5.1 script named `Get-EndpointHealthReport.ps1`. It will run locally against the Audited Endpoint and return one `[PSCustomObject]` per execution.

The script will expose these parameters:

- `-OutputPath`: destination CSV path; defaults to `C:\Temp\HealthReport.csv`.
- `-Append`: optional switch. Without it, the current CSV is replaced. With it, the new Health Report row is appended.

If the destination directory does not exist, the script will create it. Directory creation and CSV export will be protected by `Try/Catch` handling.

## Checks

### 1. System Drive capacity

The script will detect the OS volume from the Windows `SystemDrive` environment value rather than assuming `C:`. It will collect:

- Drive identifier.
- Free space in GB, rounded for report readability.
- Free space percentage.
- `DiskHealthStatus`.

Disk status rules:

- `Healthy`: at least 10 GB and at least 10 percent free.
- `Warning`: below either threshold.
- `Unknown`: the drive cannot be queried.

### 2. Windows Update service

The script will query the `wuauserv` service and record its actual state and a derived `WindowsUpdateHealthStatus`:

- `Running` → `Healthy`.
- `Stopped` or `Paused` → `Warning`.
- `Disabled` → `Unhealthy`.
- Query unavailable or access denied → `Unknown`.

### 3. Pending reboot

The script will inspect these registry signals:

- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending`.
- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired`.
- `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager`, property `PendingFileRenameOperations`.

`PendingReboot` will be `True` when one or more signals are present. `PendingRebootReasons` will identify every detected signal. A missing signal is normal and does not itself indicate an error.

### 4. Microsoft Defender

The script will use `Get-MpComputerStatus` when available and record these values where exposed:

- `AMServiceEnabled`.
- `AntivirusEnabled`.
- `AntispywareEnabled`.
- `RealTimeProtectionEnabled`.
- `AntivirusSignatureVersion`.
- `AntivirusSignatureLastUpdated`.

`DefenderHealthStatus` will be `Healthy` when required protection values are enabled, `Unhealthy` when a required protection value is disabled, and `Unknown` when Defender data cannot be collected. Signature version and timestamp are informational; no signature-age threshold is applied.

## Health Report contract

The exported CSV will contain one row with these fields:

`Timestamp`, `ComputerName`, `SystemDrive`, `FreeDiskGB`, `FreeDiskPercent`, `DiskHealthStatus`, `WindowsUpdateServiceStatus`, `WindowsUpdateHealthStatus`, `PendingReboot`, `PendingRebootReasons`, `DefenderHealthStatus`, `AMServiceEnabled`, `AntivirusEnabled`, `AntispywareEnabled`, `RealTimeProtectionEnabled`, `AntivirusSignatureVersion`, `AntivirusSignatureLastUpdated`, and `Errors`.

Each check will have independent `Try/Catch` handling. If a check fails, its status will be `Unknown`, unavailable values will remain empty, and `Errors` will contain a useful diagnostic message. Other checks will continue and the script will still attempt to export the Health Report.

The script will not require an elevated PowerShell session. Elevation may improve access to some endpoint data, but access failures must be represented in the report rather than causing an unhandled termination.

## Usage after implementation

Run with the default destination:

```powershell
.\Get-EndpointHealthReport.ps1
```

Write to another destination:

```powershell
.\Get-EndpointHealthReport.ps1 -OutputPath 'C:\Temp\HealthReport-Test.csv'
```

Append a historical row:

```powershell
.\Get-EndpointHealthReport.ps1 -OutputPath 'C:\Temp\HealthReport.csv' -Append
```

## Validation target

Validation will occur on the Windows 11 laptop after cloning this repository. The validation must confirm that:

1. The script runs under Windows PowerShell 5.1.
2. The default path creates `C:\Temp\HealthReport.csv`.
3. The CSV contains one row and all documented fields.
4. Reported disk, Windows Update, reboot, and Defender values match the endpoint's observable state.
5. Replacement and append behavior work as documented.
6. An unavailable check produces `Unknown` and an error while preserving the other check results.

The macOS environment is suitable for editing, reviewing, Git tracking, and documentation. It cannot provide authoritative results for the Windows service, Windows registry, or Defender checks.

## Planning documents

- [Feature specification](docs/specs/windows-endpoint-health-report.md)
- [Ticket 01: Build the Endpoint Health Report](.scratch/windows-endpoint-health-report/issues/01-build-endpoint-health-report.md)
- [Ticket 02: Validate on Windows 11](.scratch/windows-endpoint-health-report/issues/02-validate-on-windows-11.md)
