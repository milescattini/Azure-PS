function Install-Az {

    param (
          $RequiredModules = ("Az.Accounts","Az.Resources" , "Az.KeyVault", "Az.Websites")
    )

    Uninstall-AzureRm
    $InformationPreference = "Continue"
    $modules = get-installedmodule
  
    $missingModules = $RequiredModules | ?{$modules.Name -notcontains $_}
  
    if($missingModules.Length -eq 0) {
        foreach($missingModule in $missingModules){
            Write-Information "Importing $($missingModule)"
            Import-Module $missingModule -Force
        }
    }
      
    else{
        foreach($missingModule in $missingModules){
            Write-Information "Installing $($missingModule)"
            Install-Module $missingModule -Force -AllowClobber
        }
    }
}

function Get-AgentIP {
    return (Invoke-WebRequest -uri "http://ifconfig.me/ip" -UseBasicParsing).Content
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


function Set-KeyvaultNetworkACL {

    param (
        $ResourceGroupName,
        $KeyvaultName,
        $Mode = "Update"
    )

    Write-host "Configuring Keyvault..`n Vault:$($KeyvaultName)`n`n"

    Install-Az
    $ip = Get-AgentIP
    switch ($Mode) {
        "Update" { 
            Write-Host "Setting Client IP: $($ip)/32 on keyvault: $($KeyvaultName).."
            Update-AzKeyVaultNetworkRuleSet -VaultName $KeyvaultName -ResourceGroupName $ResourceGroupName -Bypass AzureServices -IpAddressRange "$($ip)" -DefaultAction Deny 
        }

        "Delete" { 
            Write-Host "Removing all ips from keyvault: $($KeyvaultName).."
            Update-AzKeyVaultNetworkRuleSet -VaultName $KeyvaultName -ResourceGroupName $ResourceGroupName -IpAddressRange @()  
         }
    }

}

function Set-AppServiceNetworkACL {

    param (
        $ResourceGroupName,
        $AppServiceName,
        $Mode = "Update"
    )

    Write-host "Configuring App Service..`n App:$($AppServiceName)`n`n"

    Install-Az
    $ip = Get-AgentIP

    switch ($Mode) {
        "Update" { Add-AzWebAppAccessRestrictionRule -ResourceGroupName $ResourceGroupName -WebAppName $AppServiceName -Name "Agent IP - $($ip)" -Priority 100 -Action Allow -IpAddress "$($ip)/32" }
        "Delete" { Remove-azwebappaccessrestrictionrule -ResourceGroupName $ResourceGroupName -WebAppName $AppServiceName -Name "Agent IP - $($ip)" }
    }
 

}

function Set-StorageNetworkACL {

    param (
        $ResourceGroupName,
        $AccountName,
        $Mode = "Update"
    )

    Write-host "Configuring Storage..`n Storage Account:$($AccountName)`n`n"

    Install-Az

    switch ($Mode) {
        "Update" {
            Write-Host "Set default firewall action to Allow.."
            Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName -Name $AccountName -DefaultAction Allow
            Write-Host "Sleep for 2 mins allow storage account ACL to apply.. "
            Start-Sleep -m 2
            } 
        "Delete" {
            Write-Host "Set default firewall action to Deny.."
            Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName -Name $AccountName -DefaultAction Deny

            Write-Host "Remove any specified ips.."
            Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName -Name $AccountName -IpRule @()  
            }  
     }

}
