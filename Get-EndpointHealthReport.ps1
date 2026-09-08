<#
.SYNOPSIS
    Collects and exports a health snapshot for the local Windows endpoint.

.DESCRIPTION
    Collects System Drive capacity, Windows Update service state, pending reboot
    signals, and Microsoft Defender state. Each check is isolated so an
    unavailable data source is reported as Unknown without preventing the other
    checks or the CSV export from completing.

.PARAMETER OutputPath
    The CSV file to create or update. Defaults to C:\Temp\HealthReport.csv.

.PARAMETER Append
    Appends a row to an existing report instead of replacing it.

.EXAMPLE
    .\Get-EndpointHealthReport.ps1

.EXAMPLE
    .\Get-EndpointHealthReport.ps1 -OutputPath 'C:\Temp\HealthReport.csv' -Append
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = 'C:\Temp\HealthReport.csv',

    [Parameter()]
    [switch]$Append
)

function New-CheckResult {
    param(
        [System.Collections.IDictionary]$Properties
    )

    return [PSCustomObject]$Properties
}

function Get-SystemDriveHealth {
    $errors = @()
    $systemDrive = $env:SystemDrive

    try {
        if ([string]::IsNullOrWhiteSpace($systemDrive)) {
            throw 'The SystemDrive environment value is not available.'
        }

        $filter = "DeviceID = '$systemDrive'"
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter $filter -ErrorAction Stop

        if ($null -eq $disk) {
            throw "The System Drive '$systemDrive' could not be queried."
        }

        if ($null -eq $disk.Size -or [double]$disk.Size -le 0) {
            throw "The System Drive '$systemDrive' returned an invalid capacity."
        }

        if ($null -eq $disk.FreeSpace) {
            throw "The System Drive '$systemDrive' returned no free-space value."
        }

        $freeDiskGBExact = [double]$disk.FreeSpace / 1GB
        $freeDiskPercentExact = ([double]$disk.FreeSpace / [double]$disk.Size) * 100
        $freeDiskGB = [math]::Round($freeDiskGBExact, 2)
        $freeDiskPercent = [math]::Round($freeDiskPercentExact, 2)
        $healthStatus = if ($freeDiskGBExact -ge 10 -and $freeDiskPercentExact -ge 10) {
            'Healthy'
        }
        else {
            'Warning'
        }

        return New-CheckResult -Properties ([ordered]@{
                SystemDrive     = $systemDrive
                FreeDiskGB      = $freeDiskGB
                FreeDiskPercent = $freeDiskPercent
                HealthStatus    = $healthStatus
                Errors          = $errors
            })
    }
    catch {
        $errors += "System Drive check failed: $($_.Exception.Message)"

        return New-CheckResult -Properties ([ordered]@{
                SystemDrive     = $systemDrive
                FreeDiskGB      = $null
                FreeDiskPercent = $null
                HealthStatus    = 'Unknown'
                Errors          = $errors
            })
    }
}

function Get-WindowsUpdateHealth {
    $errors = @()

    try {
        $service = Get-CimInstance -ClassName Win32_Service -Filter "Name = 'wuauserv'" -ErrorAction Stop

        if ($null -eq $service) {
            throw "The Windows Update service 'wuauserv' could not be queried."
        }

        $serviceStatus = [string]$service.State
        $healthStatus = if ([string]::Equals([string]$service.StartMode, 'Disabled', [System.StringComparison]::OrdinalIgnoreCase)) {
            'Unhealthy'
        }
        else {
            switch ($serviceStatus) {
                'Running' { 'Healthy'; break }
                'Stopped' { 'Warning'; break }
                'Paused'  { 'Warning'; break }
                default { 'Unknown'; break }
            }
        }

        if ($healthStatus -eq 'Unknown') {
            $errors += "Windows Update returned an unrecognized service state: '$serviceStatus'."
        }

        return New-CheckResult -Properties ([ordered]@{
                ServiceStatus = $serviceStatus
                HealthStatus  = $healthStatus
                Errors        = $errors
            })
    }
    catch {
        $errors += "Windows Update check failed: $($_.Exception.Message)"

        return New-CheckResult -Properties ([ordered]@{
                ServiceStatus = $null
                HealthStatus  = 'Unknown'
                Errors        = $errors
            })
    }
}

function Get-PendingRebootHealth {
    $errors = @()
    $reasons = @()

    $rebootPendingPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    $rebootRequiredPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    $sessionManagerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'

    try {
        if (Test-Path -LiteralPath $rebootPendingPath -PathType Container -ErrorAction Stop) {
            $reasons += 'Component Based Servicing: RebootPending'
        }
    }
    catch {
        $errors += "Pending reboot check could not inspect Component Based Servicing: $($_.Exception.Message)"
    }

    try {
        if (Test-Path -LiteralPath $rebootRequiredPath -PathType Container -ErrorAction Stop) {
            $reasons += 'Windows Update: RebootRequired'
        }
    }
    catch {
        $errors += "Pending reboot check could not inspect Windows Update: $($_.Exception.Message)"
    }

    try {
        $sessionManager = Get-ItemProperty -LiteralPath $sessionManagerPath -ErrorAction Stop
        $pendingFileRenameProperty = $sessionManager.PSObject.Properties['PendingFileRenameOperations']

        if ($null -ne $pendingFileRenameProperty) {
            $reasons += 'Session Manager: PendingFileRenameOperations'
        }
    }
    catch {
        $errors += "Pending reboot check could not inspect Session Manager: $($_.Exception.Message)"
    }

    return New-CheckResult -Properties ([ordered]@{
            PendingReboot        = if ($reasons.Count -gt 0) { $true } elseif ($errors.Count -gt 0) { $null } else { $false }
            PendingRebootReasons = if ($reasons.Count -gt 0) { $reasons -join '; ' } else { $null }
            Errors               = $errors
        })
}

function Get-DefenderHealth {
    $errors = @()

    try {
        $defenderCommand = Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($null -eq $defenderCommand) {
            throw 'Get-MpComputerStatus is not available on this endpoint.'
        }

        $defenderStatus = & $defenderCommand -ErrorAction Stop
        if ($null -eq $defenderStatus) {
            throw 'Get-MpComputerStatus returned no data.'
        }

        $requiredProperties = @(
            'AMServiceEnabled',
            'AntivirusEnabled',
            'AntispywareEnabled',
            'RealTimeProtectionEnabled'
        )

        $missingProperties = @()
        $disabledProperties = @()
        $values = [ordered]@{}

        foreach ($propertyName in $requiredProperties) {
            $property = $defenderStatus.PSObject.Properties[$propertyName]
            if ($null -eq $property -or $null -eq $property.Value) {
                $missingProperties += $propertyName
                $values[$propertyName] = $null
            }
            else {
                $values[$propertyName] = [bool]$property.Value
                if (-not [bool]$property.Value) {
                    $disabledProperties += $propertyName
                }
            }
        }

        if ($missingProperties.Count -gt 0) {
            $errors += 'Defender data did not expose required value(s): ' + ($missingProperties -join ', ')
            $healthStatus = 'Unknown'
        }
        elseif ($disabledProperties.Count -gt 0) {
            $healthStatus = 'Unhealthy'
        }
        else {
            $healthStatus = 'Healthy'
        }

        $signatureVersionProperty = $defenderStatus.PSObject.Properties['AntivirusSignatureVersion']
        $signatureUpdatedProperty = $defenderStatus.PSObject.Properties['AntivirusSignatureLastUpdated']

        return New-CheckResult -Properties ([ordered]@{
                HealthStatus                   = $healthStatus
                AMServiceEnabled               = $values['AMServiceEnabled']
                AntivirusEnabled               = $values['AntivirusEnabled']
                AntispywareEnabled             = $values['AntispywareEnabled']
                RealTimeProtectionEnabled      = $values['RealTimeProtectionEnabled']
                AntivirusSignatureVersion     = if ($null -ne $signatureVersionProperty) { $signatureVersionProperty.Value } else { $null }
                AntivirusSignatureLastUpdated = if ($null -ne $signatureUpdatedProperty) { $signatureUpdatedProperty.Value } else { $null }
                Errors                         = $errors
            })
    }
    catch {
        $errors += "Defender check failed: $($_.Exception.Message)"

        return New-CheckResult -Properties ([ordered]@{
                HealthStatus                   = 'Unknown'
                AMServiceEnabled               = $null
                AntivirusEnabled               = $null
                AntispywareEnabled             = $null
                RealTimeProtectionEnabled      = $null
                AntivirusSignatureVersion     = $null
                AntivirusSignatureLastUpdated = $null
                Errors                         = $errors
            })
    }
}

$allErrors = @()
$systemDriveHealth = Get-SystemDriveHealth
$allErrors += $systemDriveHealth.Errors

$windowsUpdateHealth = Get-WindowsUpdateHealth
$allErrors += $windowsUpdateHealth.Errors

$pendingRebootHealth = Get-PendingRebootHealth
$allErrors += $pendingRebootHealth.Errors

$defenderHealth = Get-DefenderHealth
$allErrors += $defenderHealth.Errors

$report = [PSCustomObject][ordered]@{
    Timestamp                    = (Get-Date).ToUniversalTime().ToString('o')
    ComputerName                 = if ([string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) { [Environment]::MachineName } else { $env:COMPUTERNAME }
    SystemDrive                  = $systemDriveHealth.SystemDrive
    FreeDiskGB                   = $systemDriveHealth.FreeDiskGB
    FreeDiskPercent              = $systemDriveHealth.FreeDiskPercent
    DiskHealthStatus             = $systemDriveHealth.HealthStatus
    WindowsUpdateServiceStatus   = $windowsUpdateHealth.ServiceStatus
    WindowsUpdateHealthStatus    = $windowsUpdateHealth.HealthStatus
    PendingReboot                = $pendingRebootHealth.PendingReboot
    PendingRebootReasons         = $pendingRebootHealth.PendingRebootReasons
    DefenderHealthStatus         = $defenderHealth.HealthStatus
    AMServiceEnabled             = $defenderHealth.AMServiceEnabled
    AntivirusEnabled             = $defenderHealth.AntivirusEnabled
    AntispywareEnabled           = $defenderHealth.AntispywareEnabled
    RealTimeProtectionEnabled    = $defenderHealth.RealTimeProtectionEnabled
    AntivirusSignatureVersion    = $defenderHealth.AntivirusSignatureVersion
    AntivirusSignatureLastUpdated = $defenderHealth.AntivirusSignatureLastUpdated
    Errors                       = if ($allErrors.Count -gt 0) { $allErrors -join ' | ' } else { $null }
}

try {
    $outputDirectory = Split-Path -Path $OutputPath -Parent
    if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
        $outputDirectory = (Get-Location).Path
    }

    if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container -ErrorAction Stop)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force -ErrorAction Stop | Out-Null
    }

    $appendToExistingFile = $Append -and (Test-Path -LiteralPath $OutputPath -PathType Leaf -ErrorAction Stop)
    if ($appendToExistingFile) {
        $report | Export-Csv -Path $OutputPath -NoTypeInformation -Append -Encoding UTF8 -ErrorAction Stop
    }
    else {
        $report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    }
}
catch {
    $allErrors += "Report export failed: $($_.Exception.Message)"
    $report.Errors = $allErrors -join ' | '
}

Write-Output $report
