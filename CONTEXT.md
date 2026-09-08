# Endpoint Health Audit

This context defines the terms used to collect and export a Windows endpoint's basic health state.

## Language

**Audited Endpoint**:
The Windows 11 device on which the health checks execute and whose state appears in the report.
_Avoid_: Development machine, host

**Health Report**:
A CSV record containing the collected health state of one Audited Endpoint at a point in time.
_Avoid_: Log, scan result

**System Drive**:
The Windows volume identified by the Audited Endpoint's `SystemDrive` environment value.
_Avoid_: C drive, OS disk

**Health Status**:
The assessment assigned to a collected check: `Healthy`, `Warning`, `Unhealthy`, or `Unknown` when it could not be collected.
_Avoid_: Pass, failure
