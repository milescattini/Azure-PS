#A quick implementation of updating a FA or WA whitelist from a static list. 

Param(
[string]$ResourceGroupName,
[array]$AppNames
)

$TrafficManagerIPs = "13.65.92.252","13.65.95.152","13.75.124.254","13.75.127.63","13.75.152.253","13.75.153.124","13.84.222.37","23.96.236.252","23.101.191.199","40.68.30.66","40.68.31.178","40.78.67.110","40.87.147.10","40.87.151.34","40.114.5.197","52.172.155.168","52.172.158.37","52.173.90.107","52.173.250.232","52.240.144.45","52.240.151.125","65.52.217.19","104.41.187.209","104.41.190.203","104.42.192.195","104.45.149.110","104.215.91.84","137.135.46.163","137.135.47.215","137.135.80.149","137.135.82.249","191.232.208.52","191.232.214.62"
$CloudFlareIPs = "173.245.48.0/20","103.21.244.0/22","103.22.200.0/22","103.31.4.0/22","141.101.64.0/18","108.162.192.0/18","190.93.240.0/20","188.114.96.0/20","197.234.240.0/22","198.41.128.0/17","162.158.0.0/15","104.16.0.0/12","172.64.0.0/13","131.0.72.0/22"

ForEach ($app in $AppNames)
{
    $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Web/sites/config -ResourceName "$app/web" -ApiVersion 2018-11-01
    $props = $resource.Properties
    $props.ipSecurityRestrictions = @()

    #Traffic Manager IPs
    foreach ($ip in $TrafficManagerIPs){
        $restriction    = [PSCustomObject]@{
            ipAddress   = $ip+'/32'
            name        = "Traffic Manager"
            priority    = 300
        }
        $props.ipSecurityRestrictions+= $restriction
    }

    #CloudFlare IPs
    foreach ($ip in $CloudFlareIPs){
        $restriction    = [PSCustomObject]@{
            ipAddress   = $ip
            name        = "CloudFlare"
            priority    = 100
        }
        $props.ipSecurityRestrictions+= $restriction
    }
    
    $props.ipSecurityRestrictions+= $restriction

    Set-AzResource -ResourceGroupName  $ResourceGroupName -ResourceType Microsoft.Web/sites/config -ResourceName "$app/web" -ApiVersion 2018-11-01 -PropertyObject $props -Force
}
