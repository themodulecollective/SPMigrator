#Admin Center & Site collection URL
$AdminCenterURL = "https://XXXXXXXXXXXXXX.com/"
$CSVPath = "C:\Temp\GroupsReport.csv"

#Connect to SharePoint Online
Connect-SPOService -url $AdminCenterURL -Credential (Get-Credential)

$GroupsData = @()

#Get all Site collections
Get-SPOSite -Limit ALL | ForEach-Object {
    Write-Host -f Yellow "Processing Site Collection:"$_.URL

    #get sharepoint online groups powershell
    $SiteGroups = Get-SPOSiteGroup -Site $_.URL

    Write-host "Total Number of Groups Found:"$SiteGroups.Count

    ForEach($Group in $SiteGroups)
    {
        $GroupsData += New-Object PSObject -Property @{
            'Site URL' = $_.URL
            'Group Name' = $Group.Title
            'Permissions' = $Group.Roles -join ","
            'Users' =  $Group.Users -join ","
        }
    }
}
#Export the data to CSV
$GroupsData | Export-Csv $CSVPath -NoTypeInformation

Write-host -f Green "Groups Report Generated Successfully!"
