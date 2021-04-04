function Upload-ToAzFileShare {
    param ($resourceGroup, $storageAccount, $shareName, $workingDirectory)

    $storageKey = Get-AzStorageAccountKey -ResourceGroupName $resourceGroup -AccountName $storageAccount

    $connectTestResult = Test-NetConnection -ComputerName "$storageAccount.file.core.windows.net" -Port 445
    if ($connectTestResult.TcpTestSucceeded) {
        # Save the password so the drive will persist on reboot
        cmd.exe /C "cmdkey /add:`"$storageAccount.file.core.windows.net`" /user:`"Azure\$storageAccount`" /pass:`"$($storageKey[0].value)`""
        # Mount the drive
        New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$storageAccount.file.core.windows.net\$shareName" -Persist
    } else {
        Write-Error -Message "Unable to reach the Azure storage account via port 445."
    }

    Copy-Item $workingDirectory\* -Destination "Z:\" -Recurse -force
}
