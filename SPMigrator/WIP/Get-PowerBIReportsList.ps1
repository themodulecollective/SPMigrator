Install-Module "MicrosoftPowerBIMgmt"
#Log into Power BI
# You will be prompted to Log in
Login-PowerBI

#Folder Location (My OneDrive Location)
$FolderLocation = 'C:\My Folder\PowerBIDashboards.csv'
$workspaceList = @()

$Workspaces = Get-PowerBIWorkspace -Scope Organization -Include All -All
Write-Host $Workspaces.Count
foreach($W in $Workspaces){
    if($W.IsOnDedicatedCapacity -eq $true -and $W.Type -eq "Workspace"){
        #$Reports = Get-PowerBIReport -WorkspaceId $W.Id -Scope Organization
        $Reports = Get-PowerBIDashboard -WorkspaceId $W.Id -Scope Organization
        if($Reports.Count -eq 0){
            Write-Output "$($W.Name) - No Reports"
        }
        else{
            foreach($R in $Reports){
                Write-Output "$($W.Name) - $($R.Name)"

                foreach($user in $W.Users){
                    $Data = new-object PSObject
                    $Data | Add-member NoteProperty -Name "WorkspaceName" -Value $W.Name
                    $Data | Add-member NoteProperty -Name "ReportName" -Value $R.Name
                    $Data | Add-member NoteProperty -Name "UserName" -Value $user.Identifier
                    $Data | Add-member NoteProperty -Name "AccessPermission" -Value $user.accessright
                    $workspaceList += $Data
                }
            }
        }
    }
}
$workspaceList | Export-Csv -Path $FolderLocation -NoTypeInformation