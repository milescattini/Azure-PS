function Install-Az{

    $InformationPreference = "Continue"

    $modules = get-installedmodule

    if($modules.Name.Contains("Az.Accounts") -AND $modules.Name.Contains("Az.Resources")) {
        Import-Module Az.Accounts, Az.Resources
        Write-Information "Modules already installed. Importing.. "
    }

    else{
        Install-Module Az -Force -AllowClobber
        Write-Information "Installing Az.. "
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
