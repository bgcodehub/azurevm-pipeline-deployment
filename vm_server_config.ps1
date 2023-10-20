param (
    [string]$emailAddress,
    [string]$domainPattern,
    [string]$dnsName
)

$osType = Get-WmiObject -Class Win32_OperatingSystem

if ($osType.ProductType -eq "2" -or $osType.ProductType -eq "3") { # Server OS
    # Install the necessary features for Server OS
    Install-WindowsFeature NET-Framework-45-ASPNET, NET-WCF-HTTP-Activation45, NET-WCF-Pipe-Activation45, NET-WCF-TCP-Activation45, Web-WebServer, Web-Request-Monitor, Web-Dyn-Compression, Web-Basic-Auth, Web-Windows-Auth, Web-App-Dev, Web-Net-Ext45, Web-Asp-Net45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-WebSockets, Web-Mgmt-Console, WAS, WAS-Config-APIs, Web-AppInit
} elseif ($osType.ProductType -eq "1") { # Client OS
    # Install the necessary features for Client OS
    Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs, NetFx4Extended-ASPNET45, WCF-HTTP-Activation45, WCF-Pipe-Activation45, WCF-TCP-Activation45, WCF-TCP-PortSharing45, IIS-WebServerRole, IIS-NetFxExtensibility45, IIS-ASPNET45, IIS-ISAPIExtensions, IIS-ISAPIFilter, IIS-WebSockets, IIS-RequestMonitor, IIS-ManagementConsole, IIS-HttpCompressionDynamic, IIS-BasicAuthentication, IIS-WindowsAuthentication, IIS-ApplicationInit, WAS-WindowsActivationService, WAS-ConfigurationAPI
}

# Configure IIS for MIME types
Install-WindowsFeature Web-Scripting-Tools
Import-Module WebAdministration
Add-WebConfiguration -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/staticContent/mimeMap" -value @{fileExtension=".";mimeType="text/plain"} -Force

# Enable HSTS
$appcmd = "$env:windir\system32\inetsrv\appcmd.exe"
& $appcmd set config -section:system.webServer/httpProtocol /+"customHeaders.[name='Strict-Transport-Security',value='max-age=31536000; includeSubDomains; preload']" /commit:apphost

# Download the Strong Crypto registry settings from GitHub
$repoUrl = "https://raw.githubusercontent.com/bgcodehub/azurevm-pipeline-deployment/main/config/StrongCrypto%2BDisableSSL2.0-3.0-TLS1.0-1.1.reg"
Invoke-WebRequest -Uri $repoUrl -OutFile "c:\temp\StrongCrypto+DisableSSL2.0-3.0-TLS1.0-1.1.reg"

# Apply the Strong Crypto registry settings
Invoke-Expression -Command "reg import 'c:\temp\StrongCrypto+DisableSSL2.0-3.0-TLS1.0-1.1.reg'"

# Ensure the temporary certificate is used for the IIS binding 
$getcert = New-SelfSignedCertificate -DnsName $dnsName -CertStoreLocation "cert:\LocalMachine\My" -FriendlyName "TenantEncryptionCert"
$thumbprint = $getcert.Thumbprint
New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:$domainPattern" -CertificateThumbPrint $thumbprint -CertStoreLocation "Cert:\LocalMachine\MY" -Protocol https

# Dynamically Download and Setup Latest Version of Win-Acme
$ProgressPreference = 'SilentlyContinue'
$git = "https://github.com"
$acmemainlink = Invoke-WebRequest "$git/win-acme/win-acme/releases/latest" -UseBasicParsing
$trimmedlink = ($acmemainlink.Links | Where-Object {$_.href -like "*releases/tag*"} | Select-Object -first 1 | select -ExpandProperty href)
$latestacmelink = "$git$trimmedlink"
$pattern = '(?<=releases/tag/)(.*)'
$latestacmeversion = [regex]::Matches($latestacmelink, $pattern).Value
$latestacmelink = $latestacmelink.Replace('tag','download')
Invoke-WebRequest "$latestacmelink/win-acme.$latestacmeversion.x64.trimmed.zip" -OutFile "c:\temp\win-acme.$latestacmeversion.x64.trimmed.zip"
Expand-Archive -Path c:\temp\win-acme.$latestacmeversion.x64.trimmed.zip -DestinationPath 'c:\win-acme'

$wacs = "c:\win-acme\wacs.exe"
& $wacs --source iis --host-pattern $domainPattern --accepttos --emailaddress $emailAddress --closeonfinish

# Recreate the HTTPS binding with the new cert
$getnewcert = Get-ChildItem -Path Cert:LocalMachine\WebHosting | Where-Object {$_.Subject -like "CN=$domainPattern"}
$newthumbprint = $getnewcert.Thumbprint
Remove-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:bgtestapp.westus2.cloudapp.azure.com" -Protocol https -Confirm:$False -RemoveConfigOnly
$latestCert = Get-ChildItem -Path Cert:LocalMachine\WebHosting | Where-Object {$_.Subject -eq "CN=bgtestapp.westus2.cloudapp.azure.com"} | Sort-Object NotAfter -Descending | Select-Object -First 1

if ($latestCert) {
    # Add the new HTTPS binding using the located certificate's thumbprint and use the -Force switch
    New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:bgtestapp.westus2.cloudapp.azure.com" -CertificateThumbPrint $latestCert.Thumbprint -CertStoreLocation "Cert:\LocalMachine\WebHosting" -Protocol https -Force
    Write-Host "HTTPS binding updated successfully with the thumbprint $($latestCert.Thumbprint)" -ForegroundColor Green
} else {
    Write-Host "Could not find a valid certificate for bgtestapp.westus2.cloudapp.azure.com in the WebHosting store." -ForegroundColor Red
}

# Dynamic Download of .NET Hosting Bundle
$ProgressPreference = 'SilentlyContinue'
$dotnet6main = invoke-webrequest "https://dotnet.microsoft.com/en-us/download/dotnet/6.0" -usebasicparsing

# Hosting Bundle
$hostingbundle = ($dotnet6main.links | Where-Object {$_.href -like "*hosting*"} | Select-Object -first 1).href
$hostingdownload = Invoke-WebRequest -uri "https://dotnet.microsoft.com$hostingbundle" -UseBasicParsing
$directdownloadlink = ($hostingdownload.links | Where-Object {$_.href -like "*hosting*"} | Select-Object -first 1).href
Invoke-WebRequest -Uri $directdownloadlink -OutFile "c:\temp\latest-hosting-bundle.exe"

# Desktop Runtime
$runtimedesktop = ($dotnet6main.links | Where-Object {$_.href -like "*desktop-runtime*"} | Select-Object -first 1).href
$runtimedownload = Invoke-WebRequest -uri "https://dotnet.microsoft.com$runtimedesktop" -UseBasicParsing
$directruntimedownloadlink = ($runtimedownload.links | Where-Object {$_.href -like "*desktop-runtime*"} | Select-Object -first 1).href
Invoke-WebRequest -Uri $directruntimedownloadlink -OutFile "c:\temp\latest-desktop-runtime.exe"

# SDK
$sdk = ($dotnet6main.links | Where-Object {$_.href -like "*sdk*"} | Select-Object -first 1).href
$sdkdownload = Invoke-WebRequest -uri "https://dotnet.microsoft.com$sdk" -UseBasicParsing
$directsdkdownloadlink = ($sdkdownload.links | Where-Object {$_.href -like "*sdk*"} | Select-Object -first 1).href
Invoke-WebRequest -Uri $directsdkdownloadlink -OutFile "c:\temp\latest-sdk.exe"

# Install .NET components
Start-Process -FilePath "c:\temp\latest-hosting-bundle.exe" -ArgumentList '/install /quiet /norestart' -Wait -NoNewWindow
Start-Process -FilePath "c:\temp\latest-desktop-runtime.exe" -ArgumentList '/install /quiet /norestart' -Wait -NoNewWindow
Start-Process -FilePath "c:\temp\latest-sdk.exe" -ArgumentList '/install /quiet /norestart' -Wait -NoNewWindow