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


function Set-KeyvaultNetworkACL {

    param (
        $ResourceGroupName,
        $KeyvaultName,
        $Mode = "Update"
    )

    Install-Az
    $ip = Get-AgentIP
    switch ($Mode) {
        "Update" { 
            $currentIPs = (Get-AzKeyVault -VaultName $KeyvaultName).NetworkAcls
            if ($currentIPs.IpAddressRanges.Length -eq 0) {
                Update-AzKeyVaultNetworkRuleSet -VaultName $KeyvaultName -ResourceGroupName $ResourceGroupName -Bypass AzureServices -IpAddressRange "$($ip)" -DefaultAction Deny 
                Write-Host "Setting Client IP Only: $($ip)/32"
            }
            else {
                $currentIPs.IpAddressRanges.Add($($ip))
                Write-Host "Setting Client Ip: $($ip)"
                foreach ($ipAdress in $currentIPs.IpAddressRanges){
                    Write-Host "Retaining Existing IP in Whitelist: $($ipAdress)" 
                 }          
                Update-AzKeyVaultNetworkRuleSet -VaultName $KeyvaultName -ResourceGroupName $ResourceGroupName -Bypass AzureServices -IpAddressRange $currentIPs.IpAddressRanges -DefaultAction Deny
            }
       }

        "Delete" { 
            Write-Host "Removing Client Ip: $($ip)/32.."
            Remove-AzKeyVaultNetworkRule -VaultName $KeyvaultName -ResourceGroupName $ResourceGroupName -IpAddressRange "$($ip)/32"
         }
    }

}

function Set-AppServiceNetworkACL {

    param (
        $ResourceGroupName,
        $AppServiceName,
        $Mode = "Update"
    )

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


    Install-Az

    Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName -AccountName $AccountName -DefaultAction Deny

    $ip = Get-AgentIP

    switch ($Mode) {
        "Update" { 
            Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -AccountName $AccountName -IPAddressOrRange $($ip)
            Write-Host "Sleep for 90 seconds, allow storage account ACL to apply.. "
            Start-Sleep -s 90
            } 
        "Delete" { 
            Remove-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -AccountName $AccountName -IPAddressOrRange $($ip)
            }  
     }

}



