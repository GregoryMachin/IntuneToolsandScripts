<#
.SYNOPSIS
    Trigger an on-demand Intune Proactive Remediation for a list of devices,
    coming either from a CSV file or directly via DeviceNames.

.PARAMETER DeviceNames
    One or more computer names to remediate (used when not using CsvPath).

.PARAMETER CsvPath
    Path to a CSV file that contains a column named 'Computer' with the device names.

.PARAMETER ScriptPolicyId
    The GUID of your Proactive Remediation script package (from the Intune portal).
    At the Remediation Overview get the ID from inbetween "~/overview/id/"" and "/scriptName/"
    Eg: https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/UXAnalyticsScriptMenu/~/overview/id/xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx/scriptName/FixIt%20MS%20All/isFirstParty~/false

.EXAMPLE
    # From a CSV
    .\Invoke-IntuneOnDemandRemediation.ps1 `
      -CsvPath .\Devices.csv `
      -ScriptPolicyId "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx"

.EXAMPLE
    # Directly
    .\Invoke-IntuneOnDemandRemediation.ps1 `
      -DeviceNames "PC001","PC002" `
      -ScriptPolicyId "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx"
#>

[CmdletBinding(DefaultParameterSetName='ByList')]
param(
    [Parameter(Mandatory=$true,ParameterSetName='ByList')]
    [String[]]$DeviceNames,

    [Parameter(Mandatory=$true,ParameterSetName='ByCsv')]
    [ValidateScript({ Test-Path $_ })]
    [String]$CsvPath,

    [Parameter(Mandatory=$true)]
    [String]$ScriptPolicyId
)

function Write-Log {
    param($Message, $Level = 'INFO')
    $ts = (Get-Date).ToString('o')
    Write-Host "[$ts] [$Level] $Message"
}

try {
    # Resolve DeviceNames from CSV if needed
    if ($PSCmdlet.ParameterSetName -eq 'ByCsv') {
        Write-Log "Importing device list from CSV: $CsvPath"
        $csv = Import-Csv -Path $CsvPath
        if (-not ($csv | Get-Member -Name Computer -MemberType NoteProperty)) {
            throw "CSV does not contain a 'Computer' column."
        }
        $DeviceNames = $csv | Select-Object -ExpandProperty Computer
        Write-Log "Found $($DeviceNames.Count) devices in CSV."
    }

    # 1) Ensure Graph auth module is installed & loaded
    if (-not (Get-Module Microsoft.Graph.Authentication -ListAvailable)) {
        Write-Log "Installing Microsoft.Graph.Authentication module..."
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module Microsoft.Graph.Authentication

    # 2) Connect to Graph
    Write-Log "Connecting to Microsoft Graph…"
    Connect-MgGraph `
      -Scopes "DeviceManagementManagedDevices.Read.All","DeviceManagementManagedDevices.PrivilegedOperations.All" `
      -ErrorAction Stop

    # 3) Loop through each device name
    foreach ($name in $DeviceNames) {
        Write-Log "Looking up Intune device ID for '$name'..."

        $resp = Invoke-MgGraphRequest `
            -Method GET `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$name'" `
            -ErrorAction Stop

        if (-not $resp.value -or $resp.value.Count -eq 0) {
            Write-Log "Device '$name' not found in Intune." "ERROR"
            continue
        }

        $mdId = $resp.value[0].id
        Write-Log "Found '$name' ⇒ ID $mdId"

        # 4) Trigger the on-demand remediation
        Write-Log "Triggering on-demand remediation for '$name'..."
        $bodyJson = @{ scriptPolicyId = $ScriptPolicyId } | ConvertTo-Json
        try {
            Invoke-MgGraphRequest `
              -Method POST `
              -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$mdId/initiateOnDemandProactiveRemediation" `
              -Body $bodyJson `
              -ErrorAction Stop

            Write-Log "> Remediation triggered on '$name'."
        }
        catch {
            Write-Log "Failed on '$name': $($_.Exception.Message)" "ERROR"
        }
    }
}
catch {
    Write-Log "Fatal error: $($_.Exception.Message)" "ERROR"
    exit 1
}
finally {
    Write-Log "Disconnecting from Graph..."
    try { Disconnect-MgGraph } catch { Write-Log "Disconnect suppressed: $($_.Exception.Message)" "WARN" }
}
