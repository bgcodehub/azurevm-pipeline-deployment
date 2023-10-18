param (
    [string]$emailAddress,
    [string]$domainPattern,
    [string]$os,
    [string]$dnsName
)

if ($os.ProductType -eq "2" -or $os.ProductType -eq "3") { # Server OS
    # Install the necessary features for Server OS
    Install-WindowsFeature NET-Framework-45-ASPNET, NET-WCF-HTTP-Activation45, NET-WCF-Pipe-Activation45, NET-WCF-TCP-Activation45, Web-WebServer, Web-Request-Monitor, Web-Dyn-Compression, Web-Basic-Auth, Web-Windows-Auth, Web-App-Dev, Web-Net-Ext45, Web-Asp-Net45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-WebSockets, Web-Mgmt-Console, WAS, WAS-Config-APIs, Web-AppInit
} elseif ($os.ProductType -eq "1") { # Client OS
    # Install the necessary features for Client OS
    Enable-WindowsOptionalFeature -Online -FeatureName NetFx4-AdvSrvs, NetFx4Extended-ASPNET45, WCF-HTTP-Activation45, WCF-Pipe-Activation45, WCF-TCP-Activation45, WCF-TCP-PortSharing45, IIS-WebServerRole, IIS-NetFxExtensibility45, IIS-ASPNET45, IIS-ISAPIExtensions, IIS-ISAPIFilter, IIS-WebSockets, IIS-RequestMonitor, IIS-ManagementConsole, IIS-HttpCompressionDynamic, IIS-BasicAuthentication, IIS-WindowsAuthentication, IIS-ApplicationInit, WAS-WindowsActivationService, WAS-ConfigurationAPI
}

# Configure IIS for MIME types
Install-WindowsFeature Web-Scripting-Tools
Import-Module WebAdministration
Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location 'Default Web Site' -filter "system.webServer/staticContent" -name "." -value @{fileExtension='.';mimeType='text/plain'}

# Enable HSTS
$appcmd = "c:\windows\system32\inetsrv\appcmd.exe"
& $appcmd set config -section:system.applicationHost/sites "/[name='Default Web Site'].hsts.enabled:True" /commit:apphost
& $appcmd set config -section:system.applicationHost/sites "/[name='Default Web Site'].hsts.max-age:31536000" /commit:apphost
& $appcmd set config -section:system.applicationHost/sites "/[name='Default Web Site'].hsts.includeSubDomains:False" /commit:apphost
& $appcmd set config -section:system.applicationHost/sites "/[name='Default Web Site'].hsts.redirectHttpToHttps:True" /commit:apphost
& $appcmd set config -section:staticContent /+"[fileExtension='.',mimeType='text/plain']"

# Apply the Strong Crypto registry settings
Invoke-Expression -Command "reg import '$(Build.SourcesDirectory)\config\StrongCrypto+DisableSSL2.0-3.0-TLS1.0-1.0.reg'"

# Check if 'TenantEncryptionCert' certificate exists
$getcert = Get-ChildItem -Path Cert:LocalMachine\MY | Where-Object {$_.FriendlyName -eq "TenantEncryptionCert"}

# If not, create a new self-signed certificate
if (-not $getcert) {
    $getcert = New-SelfSignedCertificate -DnsName $dnsName -CertStoreLocation "cert:\LocalMachine\My" -FriendlyName "TenantEncryptionCert"
}

$thumbprint = $getcert.Thumbprint
Import-Module WebAdministration
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

#Recreate the HTTPS binding with the new cert
$getnewcert=$(Get-ChildItem -Path Cert:LocalMachine\WebHosting | Where-Object {$_.Subject -like "CN=$domainPattern"})
$newthumbprint=$getnewcert.Thumbprint
Remove-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:$domainPattern" -Protocol https -Confirm:$False
New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:$domainPattern" -CertificateThumbPrint $newthumbprint -CertStoreLocation "Cert:\LocalMachine\WebHosting" -Protocol https

# Dynamic Download of .NET Hosting Bundle
$ProgressPreference = 'SilentlyContinue'
$dotnet6main = invoke-webrequest "https://dotnet.microsoft.com/en-us/download/dotnet/6.0" -usebasicparsing

$hostingbundle = ($dotnet6main.links | where-object {$_.href -like "*hosting*"} | select-object -first 1 | select -expandproperty href)
$dotnet = "https://dotnet.microsoft.com"
$craftedlink = "$dotnet$hostingbundle"
$pattern = '(?<=aspnetcore-)(.*)(?=-windows)'
$hostingversion = [regex]::Matches($craftedlink, $pattern).Value
$hostingdownload = (invoke-webrequest -uri "$craftedlink" -usebasicparsing)
$directdownloadlink = ($hostingdownload.links | where {$_.href -like "*hosting*"} | select-object href | select-object -first 1 | select -expandproperty href)

Invoke-WebRequest -Uri $directdownloadlink -OutFile "c:\temp\latest-hosting-bundle-$hostingversion.exe"

# Download lastest version of the desktop runtime
$runtimedesktop = ($dotnet6main.links | where-object {$_.href -like "*desktop-runtime*"} | select-object -first 1 | select -expandproperty href)
$craftedruntimelink = "$dotnet$runtimedesktop"
$pattern = '(?<=windowsdesktop-)(.*)(?=-windows)'
$runtimeversion = [regex]::Matches($craftedruntimelink, $pattern).Value
$runtimedownload = (invoke-webrequest -uri "$craftedruntimelink" -usebasicparsing)
$directruntimedownloadlink = ($runtimedownload.links | where {$_.href -like "*desktop-runtime*"} | select-object href | select-object -first 1 | select -expandproperty href)

Invoke-WebRequest -Uri $directruntimedownloadlink -OutFile "c:\temp\latest-desktop-runtime-$runtimeversion.exe"

# Download the lastest version of the SDK
$sdk = ($dotnet6main.links | where-object {$_.href -like "*sdk*"} | select-object -first 1 | select -expandproperty href)
$craftedsdklink = "$dotnet$sdk"
$pattern = '(?<=sdk-)(.*)(?=-windows)'
$sdkversion = [regex]::Matches($craftedsdklink, $pattern).Value
$sdkdownload = (invoke-webrequest -uri "$craftedsdklink" -usebasicparsing)
$directsdkdownloadlink = ($sdkdownload.links | where {$_.href -like "*sdk*"} | select-object href | select-object -first 1 | select -expandproperty href)

Invoke-WebRequest -Uri $directsdkdownloadlink -OutFile "c:\temp\latest-sdk-$sdkversion.exe"

Start-Process -FilePath "c:\temp\latest-hosting-bundle-$hostingversion.exe" -ArgumentList '/install /quiet /norestart' -Wait -NoNewWindow
Start-Process -FilePath "c:\temp\latest-desktop-runtime-$runtimeversion.exe" -ArgumentList '/install /quiet /norestart' -Wait -NoNewWindow
Start-Process -FilePath "c:\temp\latest-sdk-$sdkversion.exe" -ArgumentList '/install /quiet /norestart' -Wait -NoNewWindow