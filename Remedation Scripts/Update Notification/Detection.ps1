$registryPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$valueName = "RestartNotificationsAllowed2"

if (Test-Path $registryPath) {
    $value = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
    if ($value.$valueName -eq 1) {
        Write-Output "Compliant"
        exit 0
    }
}

Write-Output "Non-Compliant"
exit 1