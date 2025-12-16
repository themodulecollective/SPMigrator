Add-PowerAppsAccount
$arrAppsList = @()
$arrAppsWithNames = @()


$arrAppsList = Get-AdminPowerApp | ForEach-Object { if (Get-AdminPowerAppConnectionReferences -EnvironmentName $(Get-PowerAppEnvironment -EnvironmentName Default-2ceab55e-7e82-4c58-a343-8fa4f1288712).EnvironmentName -AppName $_.AppName | Where-Object -Property ConnectorName -EQ -Value "shared_sharepointonline") {$_ | Select-Object DisplayName, @{Label="Owner";e={$_.Owner.displayName}},@{Label="Email";e={$_.Owner.userPrincipalName}}, AppName }}

$arrAppsList | Export-Csv -Path "c:\My Folder\PowerAppsList.csv" -NoTypeInformation
