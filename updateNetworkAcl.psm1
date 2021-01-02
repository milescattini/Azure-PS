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
