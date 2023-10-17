param (
    [string]$emailAddress = ${env:EMAILADDRESS},
    [string]$domainPattern = ${env:DOMAINPATTERN}
)

# Check if script is running as admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Relaunch script with admin rights
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-File `"$($MyInvocation.MyCommand.Definition)`""
    exit
}

# Ensure Temp Directory
$downloadDir = "C:\temp"
if (-not (Test-Path $downloadDir)) {
    New-Item -Path $downloadDir -ItemType Directory
}

# Ensure that the current user has Full Control over the directory
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$acl = Get-Acl -Path $downloadDir
$permission = "$currentUser","FullControl","Allow"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
if (-not ($acl.Access | Where-Object { $_.IdentityReference.Value -eq $currentUser -and $_.FileSystemRights -eq "FullControl" })) {
    $acl.SetAccessRule($accessRule)
    $acl | Set-Acl -Path $downloadDir
}

# Determine OS type
$os = Get-WmiObject -Class Win32_OperatingSystem