$registryPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$valueName = "RestartNotificationsAllowed2"
$valueData = 1

# Ensure the registry path exists
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

# Set the registry value
Set-ItemProperty -Path $registryPath -Name $valueName -Value $valueData -Type DWord
Write-Output "Remediated"