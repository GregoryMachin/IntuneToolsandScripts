#-------------------------------------------------------------------------------
# Remediate-MDESensor.ps1
# Logs to C:\ProgramData\GDMTT\Logs\remediation.log and Windows Application log
# Source: GDMTT-remediation (Info=2000, Error=2001)
#-------------------------------------------------------------------------------

# --- Setup logging folder & parameters ---
$logFolder    = 'C:\ProgramData\GDMTT\Logs'
$logFile      = Join-Path $logFolder 'remediation.log'
$eventSource  = 'GDMTT-remediation'
$infoEventId  = 2000
$errorEventId = 2001

# Ensure log folder exists
New-Item -ItemType Directory -Path $logFolder -Force | Out-Null

# Register EventLog source if missing
if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
    New-EventLog -LogName Application -Source $eventSource
}

# --- Logging helper functions ---
function Log-Info {
    param([string]$Message)
    $ts = (Get-Date).ToString('o')
    "$ts [INFO]  $Message" | Out-File -FilePath $logFile -Append
    Write-EventLog -LogName Application -Source $eventSource -EventId $infoEventId -EntryType Information -Message $Message
}
function Log-Error {
    param([string]$Message)
    $ts = (Get-Date).ToString('o')
    "$ts [ERROR] $Message" | Out-File -FilePath $logFile -Append
    Write-EventLog -LogName Application -Source $eventSource -EventId $errorEventId -EntryType Error -Message $Message
}

# --- Remediation logic ---
try {
    Log-Info 'Starting remediation of MDE sensor...'
    Write-Output 'Determining OS build...'
    $build = [Environment]::OSVersion.Version.Build
    Log-Info "OS Build = $build"

    # 1) On 24H2+ installs Sense capability via DISM + reboot
    if ($build -ge 26100) {
        Log-Info 'Build ≥ 26100 detected—installing Sense capability via DISM.'
        Write-Output 'Installing Sense capability…'
        $dism = Start-Process -FilePath 'dism.exe' `
            -ArgumentList '/Online','/Add-Capability','/CapabilityName:Microsoft.Windows.Sense.Client~~~~' `
            -NoNewWindow -Wait -PassThru

        if ($dism.ExitCode -ne 0) {
            $msg = "DISM Add-Capability failed (ExitCode=$($dism.ExitCode))"
            Log-Error $msg
            Write-Output $msg
            exit 1
        }

        Log-Info 'DISM succeeded—rebooting to complete Sense install.'
        Write-Output 'Rebooting now…'
        Restart-Computer -Force
        # Script halts here on success
    }

    # 2) Configure and start Sense service (post-reboot or on older builds)
    Log-Info 'Configuring Sense service startup and status.'
    Write-Output 'Checking Sense service…'
    $svc = Get-Service -Name Sense -ErrorAction Stop
    $svcConfig = Get-CimInstance Win32_Service -Filter "Name='Sense'" -ErrorAction Stop

    if ($svcConfig.StartMode -ne 'Auto') {
        Log-Info 'Setting Sense service startup type to Automatic.'
        Write-Output 'Setting startup type to Automatic…'
        Set-Service -Name Sense -StartupType Automatic -ErrorAction Stop
    }

    if ($svc.Status -ne 'Running') {
        Log-Info 'Starting Sense service.'
        Write-Output 'Starting service…'
        Start-Service -Name Sense -ErrorAction Stop
    }

    Log-Info 'Sense service is configured and running.'
    Write-Output 'Remediation successful.'
    exit 0
}
catch {
    $errorMsg = $_.Exception.Message
    Log-Error "Remediation failed: $errorMsg"
    Write-Output "Remediation error: $errorMsg"
    exit 1
}

# 3) Fallback if service still missing
$msg = 'Sense service missing—please deploy MDE onboarding package.'
Log-Error $msg
Write-Output $msg
exit 1
