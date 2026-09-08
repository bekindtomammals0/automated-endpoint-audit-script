# 02 — Validate on a Windows 11 Audited Endpoint

**What to build:** A Windows administrator can confirm that the cloned repository's Health Report works against an actual Windows 11 laptop and that its exported values represent that Audited Endpoint rather than the macOS development machine.

**Blocked by:** 01 — Build the Endpoint Health Report.

**Status:** ready-for-agent

- [ ] Run the script from the cloned repository in Windows PowerShell 5.1 with a safe output location and verify that one readable CSV row is created.
- [ ] Verify that reported System Drive, Windows Update, pending-reboot, and Defender information match the Windows 11 Audited Endpoint's observable state.
- [ ] Verify default replacement and append output behavior, and capture any access-limited checks as `Unknown` with an explanatory error.
