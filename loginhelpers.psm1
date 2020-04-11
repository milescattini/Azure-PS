function Install-Az{

    $InformationPreference = "Continue"

    $requiredModules = "Az.Accounts","Az.Resources","Az.Compute","Az.Storage"
    $modules = get-installedmodule
    $missingModules = $requiredModules | ?{$modules.Name -notcontains $_}

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

function Connect-toAzure{
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true)]
        [string]
        $TenantId,

        [Parameter(Mandatory = $true)]
        [string]
        $SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]
        $ClientId,

        [Parameter(Mandatory = $true)]
        [string]
        $ClientSecret
    )

    $InformationPreference = "Continue"

    Install-Az

    Disable-AzContextAutosave -Scope Process | Out-Null

    $creds = [System.Management.Automation.PSCredential]::new($ClientId, (ConvertTo-SecureString $ClientSecret -AsPlainText -Force))
    Connect-AzAccount -Tenant $TenantId -Subscription $SubscriptionId -Credential $creds -ServicePrincipal | Out-Null
    Write-Information "Connected to Azure..."

}
