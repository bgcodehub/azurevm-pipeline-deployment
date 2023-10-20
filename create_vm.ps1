param (
    [string]$vmName,
    [string]$resourceGroup,
    [string]$location,
    [string]$adminUsername,
    [string]$dnsName
)

function Wait-ForResourceReady {
    param (
        [Parameter(Mandatory=$true)]
        [object]$resource,
        [int]$timeoutInSeconds = 120
    )

    $elapsedTime = 0
    while ($resource.ProvisioningState -ne "Succeeded" -and $elapsedTime -lt $timeoutInSeconds) {
        Start-Sleep -Seconds 5
        $elapsedTime += 5
        $resource = Get-AzResource -Id $resource.Id -ExpandProperties
    }

    if ($resource.ProvisioningState -ne "Succeeded") {
        throw "Resource $($resource.Name) did not reach 'Succeeded' state within timeout period."
    }
}

# Convert the password from the environment variable to a SecureString
$securePassword = ConvertTo-SecureString -String ${env:ADMINPASSWORD} -AsPlainText -Force

# Create the PSCredential object
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminUsername, $securePassword

# Create a public IP address with Static allocation, Standard SKU, and the desired DNS name label
$pip = New-AzPublicIpAddress -Name "$vmName-PublicIP" -ResourceGroupName $resourceGroup -Location $location -AllocationMethod Static -Sku Standard -DomainNameLabel $dnsName
Wait-ForResourceReady -resource $pip

# Create the VM with specified public IP
New-AzVm `
  -ResourceGroupName $resourceGroup `
  -Name $vmName `
  -Location $location `
  -Size "Standard_D4s_v3" `
  -Credential $credential `
  -PublicIpAddressName $pip.Name `
  -Image 'MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest'