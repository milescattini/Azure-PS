function Get-PublicIPs{
    <#
    Get-PublicIPs will return a list of custom objects based on the public lists of CloudFlare and Azure services. 
    Each object will contain a name and an array of CIDR IPs.
    You must provide a basefile path which will be used to temporarily store the IP lists. 

    Example: $MyListofIPs = Get-PublicIps -BaseFilePath 'C:\Temp' -CloudFlareIPUrl 'https://www.cloudflare.com/ips-v4'

    Sample Input Data:
    $path = 'C:\temp'
    $AzureServices = 'AppService.AustraliaCentral'
    $AzureIPListUrl = 'https://download.microsoft.com/download/7/1/D/71D86715-5596-4529-9B13-DA13A5DE5B63/ServiceTags_Public_20190923.json'
    $CloudFlareIpListUrl = 'https://www.cloudflare.com/ips-v4'
    $CloudFlareIPUrl = 'https://www.cloudflare.com/ips-v4'
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
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($AzureIPUrl, $FilePath)
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


function Format-RedisWhitelist{
    param(
        [Parameter(Mandatory=$true)][string]$ResourceGroupName, 
        [Parameter(Mandatory=$true)][string]$RedisName, 
        [Parameter(Mandatory=$true)][System.Object]$WhitelistObject
    )
    
    try{
        $RedisIpList = New-Object Collections.Generic.List[object]

        foreach ($IPCategory in $WhitelistObject){
            foreach ($IPAdress in $IPCategory.IPs){
                $IPArray = $IPAdress.Split('/')
                
                $IPObj = Get-IPrangeStartEnd -ip $IPArray[0] -cidr $IPArray[1]

                $IPRange = [PSCustomObject]@{
                    Name = $IPCategory.Name
                    IPRange = $IPObj               
                }          
            $RedisIpList += $IPRange
            }
        }

        $list = New-Object Collections.Generic.List[object]
        $i = 0
        foreach ($IpEntry in $RedisIpList)
        {
            $TemporaryObject = [PSCustomObject]@{
                Name = $IpEntry.Name + $i
                apiVersion = '2018-03-01'
                Properties = [PSCustomObject]@{  
                    startIP = $IpEntry.IPRange.Start
                    endIP = $IpEntry.IPRange.End
                }       
            }    
            $list.Add($TemporaryObject)
            $i++;
        }

        $json = $list | ConvertTo-Json

        return $list;     
       
    }
    
    catch{
        Write-Host($error[0])
    }
}



function Get-IPrangeStartEnd {       
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
   

    

