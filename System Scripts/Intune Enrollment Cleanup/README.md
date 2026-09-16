# Intune Enrollment Cleanup

`Reset-IntuneEnrollment.ps1` is a guarded, last-resort repair tool for a
Windows endpoint where the supported **Settings > Accounts > Access work or
school > Disconnect** action failed to remove a corrupt local Intune MDM
enrollment.

It is not a fleet-wide unenrollment script. It requires the expected computer
name and the exact enrollment GUID, MDM certificate thumbprint, TPM key
container, Intune device ID, and crypto provider. It aborts if those values do
not match the local Intune enrollment.

## What it removes

- The one specified Intune enrollment registry record and its status
- The same GUID under EnterpriseResourceManager, PolicyManager, Provisioning,
  OMADM, and related MDM application state
- The same EnterpriseMgmt scheduled-task folder
- The one specified Local Computer MDM certificate
- The one specified key container through its recorded crypto provider
- The Intune Management Extension, its device identity/cache, and its residual
  directories, unless `-KeepIntuneManagementExtension` is supplied
- PolicyManager Current values whose recorded owner is the old enrollment,
  unless `-KeepPolicyManagerCurrent` is supplied

## What it preserves

- The on-premises Active Directory domain join and computer account
- The TPM itself and every other TPM key
- BitLocker protectors
- Installed Win32 applications
- The Autopilot registration or absence of one
- Intune and Entra cloud objects
- User profiles and per-user WAM/Entra registration data

The registry exports and moved IME directories are forensic backups. They are
not a complete rollback because the broken TPM-backed private key cannot be
exported.

## Required sequence for TA-F4798J4

1. Sign in as `HALLCOUNTY\jtsmith`.
2. Open **Settings > Accounts > Access work or school**.
3. Select the Hall County connection and choose **Disconnect**.
4. Sign out.
5. Sign in with an administrative technician account and open 64-bit Windows
   PowerShell as Administrator.
6. Copy the script to `C:\Reset-IntuneEnrollment.ps1`.
7. Run audit-only mode first:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Reset-IntuneEnrollment.ps1" -ExpectedComputerName "TA-F4798J4" -EnrollmentId "7BB62591-9BE5-4C3B-9475-3EA0D2E486F7" -ExpectedIntuneDeviceId "db4670d7-de5d-4496-bdc7-652cb38c3a0b" -MdmCertificateThumbprint "45330198FA983C78A09574F469DA3B373F404F69" -KeyContainer "ConfigMgrEnrollment0"
```

8. Confirm that the output reports the expected computer, domain, GUID,
   certificate, key container, and `ProviderID=MS DM Server`.
9. Run execute mode:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Reset-IntuneEnrollment.ps1" -ExpectedComputerName "TA-F4798J4" -EnrollmentId "7BB62591-9BE5-4C3B-9475-3EA0D2E486F7" -ExpectedIntuneDeviceId "db4670d7-de5d-4496-bdc7-652cb38c3a0b" -MdmCertificateThumbprint "45330198FA983C78A09574F469DA3B373F404F69" -KeyContainer "ConfigMgrEnrollment0" -Execute
```

10. The script writes its evidence and backup under:

```text
C:\IntuneEnrollmentCleanupBackup\TA-F4798J4_<timestamp>\
```

The timestamped backup directory is restricted to local SYSTEM and the local
Administrators group because the registry exports contain management identity
and enrollment metadata.

11. A successful cleanup exits with `3010`, meaning restart required. Restart
    before attempting registration.
12. Sign in as `HALLCOUNTY\jtsmith` and connect the Hall County account once
    through **Access work or school**.

## Required post-enrollment proof

Do not call the repair successful only because Settings shows a connected
account. Confirm all of the following:

- A new enrollment GUID exists under
  `HKLM\SOFTWARE\Microsoft\Enrollments`
- A new MDM client certificate and usable private key exist
- The key container is not `ConfigMgrEnrollment0` from the old enrollment
- A new Intune device ID exists and is not
  `db4670d7-de5d-4496-bdc7-652cb38c3a0b`
- A new matching EnterpriseMgmt task folder exists
- Native MDM sync succeeds
- The Intune Management Extension is reinstalled automatically after a Win32
  app or PowerShell workload is assigned

If the script cannot delete the exact key container, stop. Do not clear the TPM
or manually delete TPM/KSP storage files; reimage the endpoint instead.

If `-Execute` fails at any point **after** the key-container deletion
succeeds (for example, certificate removal or registry cleanup throws), do
not re-run this script. Its identity pre-checks require the certificate, the
EnterpriseMgmt task folder, and the key container to all still be present,
and a partial run will already have removed some of them -- a re-run will
correctly abort rather than resume. Instead, open `Cleanup-Summary.txt` and
`Cleanup.log` in that run's backup directory
(`C:\IntuneEnrollmentCleanupBackup\<computer>_<timestamp>\`) to see exactly
which steps completed, then either finish the remaining registry cleanup by
hand using that evidence or reimage the endpoint.
