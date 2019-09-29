<#
Get-PublicIPs will return a list of custom objects based on the public lists of CloudFlare and Azure services. 
Each object will contain a name and an array of CIDR IPs.

You must provide a basefile path which will be used to temporarily store the IP lists. 

Example: $MyListofIPs = Get-PublicIps -BaseFilePath 'C:\Temp' -CloudFlareIPUrl 'https://www.cloudflare.com/ips-v4'
#>

function Get-PublicIPs{
param(
    [Parameter(Mandatory=$true)][string]$BaseFilePath, 
    [Parameter][string]$AzureIPUrl, 
    [Parameter][array]$AzureServices,
    [Parameter][string]$CloudFlareIPUrl
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
            $CloudflareIPs = $cloudFlareIPString.Split([Environment]::NewLine)

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

<#
Sample Input Data 

$path = 'C:\temp'
$AzureServices = 'AppService.AustraliaCentral'
$AzureIPListUrl = 'https://download.microsoft.com/download/7/1/D/71D86715-5596-4529-9B13-DA13A5DE5B63/ServiceTags_Public_20190923.json'
$CloudFlareIpListUrl = 'https://www.cloudflare.com/ips-v4'
#>

$sampleIPList = Get-PublicIPs -BaseFilePath $Path -AzureIPUrl $AzureIPListUrl -AzureServices $AzureServices -CloudFlareIPUrl $CloudFlareIpListUrl

