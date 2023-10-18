param (
    [string]$resourceGroup,
    [string]$vmName,
    [string]$userPublicIp
)

# NSG name is the same as VM's name for simplicity
$nsgName = "$vmName"

# Get the NSG
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name $nsgName

# Remove rule 1000
$nsg.SecurityRules.Remove(($nsg.SecurityRules | Where-Object { $_.Priority -eq 1000 }))

# Remove rule 1001
$nsg.SecurityRules.Remove(($nsg.SecurityRules | Where-Object { $_.Priority -eq 1001 }))

# Allow 443
$rule443 = New-AzNetworkSecurityRuleConfig -Name "Allow-443" -Description "Allow port 443" -Access "Allow" -Protocol "Tcp" -Direction "Inbound" -Priority 100 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange "443"
$nsg.SecurityRules.Add($rule443)

# Allow 80
$rule80 = New-AzNetworkSecurityRuleConfig -Name "Allow-80" -Description "Allow port 80" -Access "Allow" -Protocol "Tcp" -Direction "Inbound" -Priority 101 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange "80"
$nsg.SecurityRules.Add($rule80)

# Allow 3389 from user's IP
$rule3389 = New-AzNetworkSecurityRuleConfig -Name "Allow-3389-UserIP" -Description "Allow port 3389 from user's IP" -Access "Allow" -Protocol "Tcp" -Direction "Inbound" -Priority 102 -SourceAddressPrefix $userPublicIp -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange "3389"
$nsg.SecurityRules.Add($rule3389)

# Define the IP ranges to be denied
$denyIPRanges = @(
    "195.154.54.0/24", "185.156.74.0/24", "188.92.77.0/24", "94.232.47.0/24",
    "125.227.51.0/24", "95.179.231.0/24", "52.188.83.0/24", "52.166.58.199",
    "52.224.48.0/22", "194.61.52.0/22", "185.202.0.0/22", "5.136.0.0/13",
    "95.24.0.0/13", "176.208.0.0/13", "178.64.0.0/13", "37.9.0.0/20", "37.9.16.0/20",
    "37.9.32.0/20", "37.9.48.0/21", "37.9.64.0/18", "37.9.128.0/21", "37.9.144.0/20",
    "37.9.192.0/21", "37.9.240.0/21", "178.154.0.0/17", "178.154.128.0/17",
    "91.220.163.0/24", "185.193.88.0/24", "45.155.204.0/24", "45.134.26.0/24",
    "45.146.164.0/24", "45.155.205.0/24", "45.145.65.0/24"
)

# Create a single deny rule for the IPs
$rule = New-AzNetworkSecurityRuleConfig -Name "Deny-MultipleIPs" -Description "Deny multiple IPs" -Access "Deny" -Protocol "*" -Direction "Inbound" -Priority 110 -SourceAddressPrefix $denyIPRanges -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange "*"
$nsg.SecurityRules.Add($rule)

# Apply the updated NSG
Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg