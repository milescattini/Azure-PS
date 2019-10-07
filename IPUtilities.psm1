function Get-PublicIPs
{
    <#
    Get-PublicIPs will return a list of custom objects based on the public lists of CloudFlare and Azure services. 
    Each object will contain a name and an array of CIDR IPs.
    You must provide a basefile path which will be used to temporarily store the IP lists. 

    Example: $MyListofIPs = Get-PublicIps -BaseFilePath 'C:\Temp' -CloudFlareIPUrl 'https://www.cloudflare.com/ips-v4'
    #>

    param(
        [CmdletBinding()]
        [Parameter(Mandatory=$true)][string]$BaseFilePath, 
        [string]$AzureIPUrl, 
        [array]$AzureServices,
        [string]$CloudFlareIPUrl
    )
    
    try{
        $ReturnList = @()

        if ($AzureServices.Length -ge 1){
    
            $FilePath = $BaseFilePath + '\Temp.json'
            foreach($AzureService in $AzureServices){   
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($AzureIPUrl, $FilePath)
            }

            $JsonFile = Get-Content -Raw -Path $FilePath | ConvertFrom-Json
        
            foreach ($AzureService in $AzureServices){
                $ServiceConfiguration = $JsonFile.values | Where-Object {$_.name -eq $AzureService}
                $IPObject = [PSCustomObject]@{
                    Name = $AzureService
                    IPs = $ServiceConfiguration.properties.addressPrefixes
                }
                $ReturnList += $IPObject
            }
        }

        if($CloudFlareIPUrl){
            $FilePath = $BaseFilePath + '\CfTemp.txt'

            $webClient = New-Object System.Net.WebClient
            $cloudFlareIPString = $webclient.DownloadString($CloudFlareIPUrl)
            $CloudflareIPs = $cloudFlareIPString.TrimEnd().Split([Environment]::NewLine)

            $IPObject = [PSCustomObject]@{
                Name = 'CloudFlare'
                IPs = $CloudflareIPs
            }
            
            $ReturnList += $IPObject

        }
        return $ReturnList;
    }

    catch{
        Write-Host($error[0])
    }
        
}

function Set-RedisWhitelist
{
 <#    Get-RedisWhitelist will configure a Redis whitelist based on the IP object returned from get-PublicIPs or a custom IP object. The expected format:
        Name        IPs
        {string}    {String[]}

        Ie. 
        Name                IPs
        ----                ---
        AzureTrafficManager {13.65.92.252/32, 13.65.95.152/32, 13.75.124.254/32, 13.75.127.63/32...}

        Redis requires a IP range as opposed to CIDR. Set-RedisWhiteList will convert to range using Get-IPrangeStartEnd 
    
 #>

    param(
        [Parameter(Mandatory=$true)][string]$ResourceGroupName, 
        [Parameter(Mandatory=$true)][string]$RedisName, 
        [Parameter(Mandatory=$true)][object]$WhitelistObject
    )
    
    try{

        $RedisIpList = New-Object Collections.Generic.List[object]

        foreach ($IPCategory in $WhitelistObject){
            foreach ($IPAdress in $IPCategory.IPs){

                $IPArray = $IPAdress.Split('/')
                
                $IPObj = Get-IPrangeStartEnd -ip $IPArray[0] -cidr $IPArray[1]
                $Rulename = $IPCategory.Name.Replace('.', '')

                $IPRange = [PSCustomObject]@{
                    Name    = $Rulename
                    IPRange = $IPObj               
                }      

            $RedisIpList += $IPRange
            }
        }

        $i = 1;
        foreach ($IpEntry in $RedisIpList)
        {
            $rulename = $IpEntry.Name + $i

            New-AzureRmRedisCacheFirewallRule -Name $RedisName -RuleName $rulename -StartIP $IpEntry.IpRange.Start -EndIP $IpEntry.IpRange.End
            $i++;

        }
    }
    catch{
        Write-Host($error[0])
    }
}

function Get-IPrangeStartEnd 
{       
    <#
    Get-IPrangeStartEnd will return an IP range from CIDR notation. This is a custom version of the MS implementation https://gallery.technet.microsoft.com/scriptcenter/Start-and-End-IP-addresses-bcccc3a9
    Sample Usage: 
    $myIP = Get-IPrangeStartEnd -ip '192.168.1.24' -cidr 8

    Returns and object with Start and End Values. i.e 

    start     end
    -----     ---
    192.0.0.0 192.255.255.255
    #>

    param (  
        [string]$start,  
        [string]$end,  
        [string]$ip,  
        [int]$cidr  
    )    
    function IP-toINT64 () {  
        param ($ip)  
       
        $octets = $ip.split(".")  
        return [int64]([int64]$octets[0]*16777216 +[int64]$octets[1]*65536 +[int64]$octets[2]*256 +[int64]$octets[3])  
    }  
    
    function INT64-toIP() {  
    param ([int64]$int)  

    return (([math]::truncate($int/16777216)).tostring()+"."+([math]::truncate(($int%16777216)/65536)).tostring()+"."+([math]::truncate(($int%65536)/256)).tostring()+"."+([math]::truncate($int%256)).tostring() ) 
    }  
    
    $ipaddr = [Net.IPAddress]::Parse($ip)
    $maskaddr = [Net.IPAddress]::Parse((INT64-toIP -int ([convert]::ToInt64(("1"*$cidr+"0"*(32-$cidr)),2)))) 
    $networkaddr = new-object net.ipaddress ($maskaddr.address -band $ipaddr.address)
    $broadcastaddr = new-object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $maskaddr.address -bor $networkaddr.address))


    $startaddr = IP-toINT64 -ip $networkaddr.ipaddresstostring  
    $endaddr = IP-toINT64 -ip $broadcastaddr.ipaddresstostring  
    
    $temp=""|Select start,end 
    $temp.start=INT64-toIP -int $startaddr 
    $temp.end=INT64-toIP -int $endaddr 
    return $temp 
}

function Get-PublicIPFromResourceGroup 
{       
    <# Get-PublicIPFromResourceGroup will return a object with the name and public address(es)
    Example Format: 

    name                                        IpAddress
    ----                                        ---------
    kubernetes-a2c5cd94a23e11e9345c7642e0a7e0   192.168.10.1
    #>

    param (  
        [Parameter(Mandatory=$true)][string]$ResourceGroupName
    )   

    try{

        $ReturnList = @()
        
        if ($IPProperty.length -eq 0){
            write-host ("No Public Ip Addresses In " + $ResourceGroupName)
            return $null
        }

        write-host ("Public IPs Found:" + $IPProperty.Length)
        
        foreach ($IPEntry in $IPProperty){

            $IPObject = [PSCustomObject]@{

                name = $IPProperty.Name
                IpAddress = $IPProperty.IpAddress

            }

            $ReturnList += $IPObject
        }

        return $IPObject
    }
    catch{
        Write-Host($error[0])

    }

}

function Set-ContainerRegistryWhitelist 
{       
    <# Set-ContainerRegistryWhitelist takes a string array on IP in CIDR. Container Registries do not display IP addresses in firewall configuration. 

    This will use the current authorsation context.

    Sample usage:

    Set-ContainerRegistryWhitelist -ResourceGroupName 'MyRg' -ContainerRegistry 'MyCR' -IpAddresses '192.168.1.1','77.88.77.0/24'

    #>

    param (  
        [Parameter(Mandatory=$true)][string]$ResourceGroupName,
        [Parameter(Mandatory=$true)][string]$ContainerRegistry,
        [Parameter(Mandatory=$true)][array]$IPAddresses
    )  

    try{

        $GetResource = Get-AzureRMResource -ResourceName $ContainerRegistry -ResourceGroupName $ResourceGroupName
        $SubscriptionId = $GetResource.SubscriptionId

        $uri = ('https://management.azure.com/subscriptions/' +  $SubscriptionId  + '/resourceGroups/' + $ResourceGroupName + '/providers/Microsoft.ContainerRegistry/registries/' + $ContainerRegistry + '?api-version=2019-05-01')
        $Header = @{
            Authorization = (Get-AzureRmAccessToken)
        }
        $ContainerRegistryConfig = Invoke-RestMethod -Method GET -uri $uri -Header $Header

        $configList = @();

       foreach ($IPAddress in $IPAddresses){
            $IPRule = [PSCustomObject]@{
                action = "Allow"
                value  = $IPAddress
            }
            $configList += $IPRule
        }

        $ContainerRegistryConfig.properties.networkruleset.ipRules = $configList
        $ContainerRegistryConfig.properties.networkruleset.defaultaction = "Deny"

        $ContainerRegistryJson = $ContainerRegistryConfig | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Method PATCH -uri $uri -Header $Header -Body $ContainerRegistryJson -ContentType 'application/json'



    }
    catch{
        Write-Host($error[0])

    }

}

function Get-AzureRmAccessToken
{
    <#A TechNet Implementation for retrieving an access token from Context. 
    https://gallery.technet.microsoft.com/scriptcenter/Easily-obtain-AccessToken-3ba6e593
    #>

    $ErrorActionPreference = 'Stop'
  
    if(-not (Get-Module AzureRm.Profile)) {
        Import-Module AzureRm.Profile
    }
    # refactoring performed in AzureRm.Profile v3.0 or later
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azureRmProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."    
    }
  
    $currentAzureContext = Get-AzureRmContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token = ("Bearer " + $token.AccessToken)

    return $token
}
