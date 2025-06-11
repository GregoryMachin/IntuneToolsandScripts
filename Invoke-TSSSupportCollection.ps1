<#
.SYNOPSIS
    Silently download and run the Microsoft TSS bundle to collect a
    **DND_SetupReport** trace *without* user interaction*,* then compress the
    results to **C:\TSS_Results** for manual upload. The script follows the
    my logging standards **and** captures *all* TSS console output to the
    same daily log file.

.DESCRIPTION
    ● Builds the required GDMTT folder structure under *C:\ProgramData\GDMTT*.
    ● Logs every step to *C:\ProgramData\GDMTT\Logs\TSS_<yyyyMMdd>.log* and
      echoes to the console when run interactively.
    ● Downloads the latest *TSS.zip* (override with **-DownloadUri**).
    ● Extracts to a timestamp‑stamped temp folder.
    ● Launches **TSS.ps1** in a hidden child PowerShell instance with:
        - `-CollectLog <CollectName>` (default *DND_SetupReport*)
        - `-AcceptEula`   (auto‑accept licence)
        - `-RemoteRun`    (disable GUI pop‑ups)
        - `-LogFolderPath C:\TSS_Results`
      StdOut/StdErr from that child are both redirected into the daily log.
    ● Compresses *C:\TSS_Results* → *C:\TSS_Results\TSS_<yy_MM_dd_HH‑mm>.zip* and
      copies the archive to *C:\ProgramData\GDMTT\Backup*.
    ● **-CleanTemp** switch deletes the temp folder on success.

.PARAMETER CollectName
    Collection name passed to **-CollectLog** (defaults to *DND_SetupReport*).

.PARAMETER DownloadUri
    Alternate download location for the TSS bundle (defaults to aka.ms link).

.PARAMETER CleanTemp
    Remove the temporary extraction folder when finished.

.NOTES
    Deploy via Intune as a PowerShell script and tick **Run as SYSTEM**.
#>

[CmdletBinding()]
param(
    [string]$CollectName = 'DND_SetupReport',
    [string]$DownloadUri = 'http://aka.ms/getTSS',
    [switch]$CleanTemp
)

#───────── Helper: Log ─────────────────────────────────────────────────────────
function Write-GDMTTLog {
    param(
        [string]$Level,
        [string]$Message
    )
    $ts   = Get-Date -Format 'yyyyMMdd HH:mm:ss'
    $user = try {
        (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
    } catch {
        "$($env:USERDOMAIN)\\$($env:USERNAME)"
    }
    $line = "$ts $user $Level $Message"
    Add-Content -Path $script:LogFile -Value $line
    Write-Host $line
}

function Invoke-TssSupportCollection {
    [CmdletBinding()]
    param(
        [string]$CollectName,
        [string]$DownloadUri,
        [switch]$CleanTemp
    )

    try {
        #── Folder preparation ───────────────────────────────────────────────
        $GDMTTRoot = 'C:\ProgramData\GDMTT'
        $logsDir   = Join-Path $GDMTTRoot 'Logs'
        $backupDir = Join-Path $GDMTTRoot 'Backup'
        $cacheDir  = Join-Path $GDMTTRoot 'cache'
        $tempDir   = Join-Path $GDMTTRoot 'temp'
        foreach ($dir in @($logsDir,$backupDir,$cacheDir,$tempDir)) {
            if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        }

        $script:LogFile = Join-Path $logsDir ("TSS_{0}.log" -f (Get-Date -Format 'yyyyMMdd'))
        if (-not (Test-Path $LogFile)) { New-Item -Path $LogFile -ItemType File -Force | Out-Null }

        $stamp     = Get-Date -Format 'yy_MM_dd_HH-mm'
        $workRoot  = Join-Path $tempDir "TSS_$stamp"
        New-Item -Path $workRoot -ItemType Directory -Force | Out-Null

        $tssZip      = Join-Path $workRoot 'TSS.zip'
        $extractPath = Join-Path $workRoot 'EXTRACTED'
        $resultsDir  = 'C:\TSS_Results'
        if (-not (Test-Path $resultsDir)) { New-Item -Path $resultsDir -ItemType Directory -Force | Out-Null }

        #── Download & extract ───────────────────────────────────────────────
        Write-GDMTTLog 'Info' "Downloading TSS bundle from $DownloadUri"
        Invoke-WebRequest -Uri $DownloadUri -OutFile $tssZip -UseBasicParsing -ErrorAction Stop
        Write-GDMTTLog 'Data' "Downloaded $((Get-Item $tssZip).Length) bytes"

        Write-GDMTTLog 'Info' "Extracting bundle to $extractPath"
        Expand-Archive -Path $tssZip -DestinationPath $extractPath -Force

        #── Execution policy (process) ───────────────────────────────────────
        Write-GDMTTLog 'Info' 'Setting ExecutionPolicy (Process) to RemoteSigned'
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force

        #── Locate TSS.ps1 ───────────────────────────────────────────────────
        $tssScript = Get-ChildItem -Path $extractPath -Filter 'TSS.ps1' -Recurse | Select-Object -First 1
        if (-not $tssScript) { throw 'TSS.ps1 not found after extraction' }

        #── Run TSS silently ─────────────────────────────────────────────────
        $tssOut = Join-Path $logsDir ("TSS_console_{0}.log" -f $stamp)
        $tssErr = Join-Path $logsDir ("TSS_error_{0}.log"   -f $stamp)
        Write-GDMTTLog 'Info' "Running TSS.ps1 -CollectLog $CollectName -AcceptEula -RemoteRun"

        $pwArgs = @(
            '-NoProfile',
            '-ExecutionPolicy','Bypass',
            '-File',"`"$($tssScript.FullName)`"",
            '-CollectLog',$CollectName,
            '-AcceptEula',
            '-RemoteRun',
            '-LogFolderPath',$resultsDir
        )

        Start-Process -FilePath 'powershell.exe' -ArgumentList $pwArgs -WindowStyle Hidden -Wait -RedirectStandardOutput $tssOut -RedirectStandardError $tssErr

        Write-GDMTTLog 'Info' 'TSS collection completed'

        if (-not (Test-Path $resultsDir)) { throw "$resultsDir not found - TSS may have failed" }

        #── Compress results ────────────────────────────────────────────────
        $zipFile   = Join-Path $resultsDir ("TSS_${stamp}.zip")
        $zipBackup = Join-Path $backupDir  ("TSS_${stamp}.zip")

        Write-GDMTTLog 'Info' "Compressing results in $resultsDir to $zipFile"
        Compress-Archive -Path (Join-Path $resultsDir '*') -DestinationPath $zipFile -Force
        Copy-Item -Path $zipFile -Destination $zipBackup -Force
        Write-GDMTTLog 'Data' "Archive size = $((Get-Item $zipFile).Length) bytes"

        #── Cleanup ─────────────────────────────────────────────────────────
        if ($CleanTemp) {
            Write-GDMTTLog 'Info' "Cleaning temp folder $workRoot"
            Remove-Item -Path $workRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-GDMTTLog 'Info' 'Script completed successfully'
    }
    catch {
        Write-GDMTTLog 'Error' $_.Exception.Message
        throw
    }
}

#───────── Auto‑invoke when executed directly ────────────────────────────────
if ($PSCommandPath -and ([IO.Path]::GetFileName($MyInvocation.InvocationName)) -ieq ([IO.Path]::GetFileName($PSCommandPath)) ) {
    Invoke-TssSupportCollection -CollectName $CollectName -DownloadUri $DownloadUri -CleanTemp:$CleanTemp.IsPresent
}
