$allUsers = Get-AppxPackage -AllUsers | Select-Object Name, PackageFullName
$prov     = Get-AppxProvisionedPackage -Online | Select-Object DisplayName, PackageName

$allUsers | Sort-Object Name | Export-Csv "$env:PUBLIC\Desktop\Appx_Installed_AllUsers.csv" -NoTypeInformation
$prov     | Sort-Object DisplayName | Export-Csv "$env:PUBLIC\Desktop\Appx_Provisioned.csv" -NoTypeInformation