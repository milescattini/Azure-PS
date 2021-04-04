# The DB performance requirement is much higher during some specific operations.
# As such, this script will increase the DTU by a certain DTU to ensure appropriate performance / cost balance during update. 

function Update-AzSQLDTU
    Param(
        [ValidateSet('Increase','Decrease')]
        [String]
        $Mode,

        [String]
        $ResourceGroupName,

        [String]
        $DatabaseName,

        [String]
        $ServerName,

        [Int]
        $ScaleSize = 2
    )


    Write-Host "Getting DB Configuration of $($DatabaseName).. "
    $db = Get-AzSqlDatabase -ResourceGroupName $ResourceGroupName -DatabaseName $DatabaseName -ServerName $ServerName
    $currentObjective = [System.Int32]::Parse($db.CurrentServiceObjectiveName[1])
    Write-Host "Current DTU Scale Unit is: $($ScaleSize)"
    Write-Host "Current DTU is: $($db.CurrentServiceObjectiveName) `n"

    # Successive runs of an Increase or Decrease, perhaps in a task that is failign at another step, could result in significant cost increase. 
    # Run a quick sanity check to ensure the DTU is not going to be greater than 6
    if ($Mode -eq 'Increase' -and $currentObjective -gt 4){
        Write-Host "DTU Already 4, not increasing further.."
    }

    if ($Mode -eq 'Decrease' -and $currentObjective -lt 0){
        Write-Host "DTU Already 0, not decreasing further.."
    }

    if ($Mode -eq 'Increase' -and $currentObjective -le 4){
        Write-Host "Increasing SKU.."
        $newObjectiveName = 'S' + ($currentObjective + $ScaleSize)
    }

    elseif ($Mode -eq 'Decrease'){
        Write-Host "Decreasing SKU.."
        $newObjectiveName = 'S' + ($currentObjective - $ScaleSize)
    }

    Write-Host "Setting DB Sku on $($DatabaseName) to $($newObjectiveName).."
    Set-AzSqlDatabase -ResourceGroupName $ResourceGroupName -DatabaseName $DatabaseName -ServerName $ServerName -RequestedServiceObjectiveName $newObjectiveNam
}
