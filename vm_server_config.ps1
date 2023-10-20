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
Add-WebConfiguration -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/security/access" -value @{sslFlags="Ssl, SslNegotiateCert, SslRequireCert, Ssl128"} -Force
Add-WebConfiguration -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication" -value @{enabled="true"} -Force
Add-WebConfiguration -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication/manyToOneMappings" -value @{enabled="true";name="ECDH Configuration";description="ECDH with Strong Crypto";permissionMode="Allow"} -Force

# Enable HSTS and other security headers
$appcmd = "$env:windir\system32\inetsrv\appcmd.exe"
& $appcmd set config -section:system.webServer/httpProtocol /+"customHeaders.[name='Strict-Transport-Security',value='max-age=15768000; includeSubDomains; preload']" /commit:apphost
& $appcmd set config -section:system.webServer/httpProtocol /+"customHeaders.[name='X-Content-Type-Options',value='nosniff']" /commit:apphost
& $appcmd set config -section:system.webServer/httpProtocol /+"customHeaders.[name='Referrer-Policy',value='strict-origin-when-cross-origin']" /commit:apphost
& $appcmd set config -section:system.webServer/httpProtocol /+"customHeaders.[name='X-XSS-Protection',value='1; mode=block']" /commit:apphost
& $appcmd set config -section:system.webServer/httpProtocol /+"customHeaders.[name='X-Frame-Options',value='DENY']" /commit:apphost
& $appcmd set config -section:system.webServer/httpProtocol /+"customHeaders.[name='Content-Security-Policy',value='default-src 'self';']" /commit:apphost
& $appcmd set config /section:httpProtocol /-customHeaders.[name='Server']
& $appcmd set config /section:serverSideInclude /+ssiExecDisable
& $appcmd set site "Default Web Site" /+limits.maxBandwidth:500000

# Disable WebDAV
Remove-WindowsFeature Web-DAV

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

# Use Win-ACME to obtain a Let's Encrypt certificate
$wacs = "c:\win-acme\wacs.exe"
& $wacs --source iis --host-pattern $domainPattern --accepttos --emailaddress $emailAddress --closeonfinish

# Check if the new certificate was generated
$letsEncryptCert = Get-ChildItem -Path Cert:\LocalMachine\WebHosting | Where-Object {$_.Subject -like "CN=$domainPattern"} | Sort-Object NotAfter -Descending | Select-Object -First 1

if ($letsEncryptCert) {
    Write-Host "Successfully fetched Let's Encrypt Certificate with Thumbprint: $($letsEncryptCert.Thumbprint)" -ForegroundColor Green
    
    # Remove the old IIS binding
    Remove-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:$domainPattern" -Protocol https -Confirm:$False -RemoveConfigOnly

    # Create the new binding with the Let's Encrypt certificate
    New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:$domainPattern" -CertificateThumbPrint $letsEncryptCert.Thumbprint -CertStoreLocation "Cert:\LocalMachine\WebHosting" -Protocol https -Force
    Write-Host "IIS binding updated successfully with the Let's Encrypt certificate." -ForegroundColor Green
} else {
    Write-Host "Failed to fetch Let's Encrypt Certificate for $domainPattern." -ForegroundColor Red
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