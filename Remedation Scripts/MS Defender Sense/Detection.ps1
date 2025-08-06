#-------------------------------------------------------------------------------
# Detect-MDESensor.ps1
# Logs to C:\ProgramData\GDMTT\Logs\detection.log and Windows Application log
# Source: GDMTT-detection (Info=1000, Error=1001)
#-------------------------------------------------------------------------------

# --- Setup logging folder & parameters ---
$logFolder    = 'C:\ProgramData\GDMTT\Logs'
$logFile      = Join-Path $logFolder 'detection.log'
$eventSource  = 'GDMTT-detection'
$infoEventId  = 1000
$errorEventId = 1001

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

# --- Detection logic ---
try {
    Log-Info 'Starting detection of MDE sensor...'
    Write-Output 'Checking OS build...'
    $build = [Environment]::OSVersion.Version.Build
    Log-Info "OS Build = $build"

    # On 24H2+ check Sense capability
    if ($build -ge 26100) {
        Write-Output 'Verifying Sense capability...'
        $cap = Get-WindowsCapability -Online -Name 'Microsoft.Windows.Sense.Client~~~~' -ErrorAction Stop
        if ($cap.State -ne 'Installed') {
            $msg = "Sense capability missing on build $build"
            Log-Info $msg
            Write-Output $msg
            exit 1
        }
        Log-Info 'Sense capability is installed.'
    }

    # Check the Sense service
    Write-Output 'Checking Sense service...'
    $svc = Get-Service -Name Sense -ErrorAction Stop
    $svcConfig = Get-CimInstance Win32_Service -Filter "Name='Sense'" -ErrorAction Stop

    if ($svc.Status -ne 'Running' -or $svcConfig.StartMode -ne 'Auto') {
        $msg = "Sense service not running or not set to Automatic (Status=$($svc.Status), StartMode=$($svcConfig.StartMode))"
        Log-Info $msg
        Write-Output $msg
        exit 1
    }

    # All good
    $msg = 'MDE sensor OK: capability present, service running and Auto.'
    Log-Info $msg
    Write-Output $msg
    exit 0
}
catch {
    $errorMsg = $_.Exception.Message
    Log-Error "Detection failed: $errorMsg"
    Write-Output "Detection error: $errorMsg"
    exit 1
}
