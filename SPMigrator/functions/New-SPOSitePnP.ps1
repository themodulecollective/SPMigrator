#creates sites using a CSV file
<#Templates
Site Page Publishing = CommunicationSite
Group = TeamSite -Alias will be group name no spaces
Team = TeamSite -Alias will be group name no spaces
Team Channel = TeamSiteWithoutMicrosoft365Group

#>

#Define Variables
param(
    [Int]$wavenum = $(throw '-wavenum is required')


)
#$csvfile = "D:\SPMigration\CSVFiles\$($wavefilename)"
#$URLS = Import-Csv $csvfile -Delimiter ","


$migSite = 'https://ahsonline.sharepoint.com/teams/RMRSharePointMigration'
$migJobsList = 'Migration Jobs'
$AdminCenterURL = 'https://ahsonline-admin.sharepoint.com/'
$listQuery = "<Where><Eq><FieldRef Name='WaveNumber'/><Value Type='Number'>" + $wavenum + '</Value></Eq></Where>'

Try
{
    #Connect to Tenant Admin-Login with Service Account
    $adminconn = Connect-PnPOnline -Url $AdminCenterURL -Interactive -ReturnConnection
    $migconn = Connect-PnPOnline -Url $migSite -Interactive -ReturnConnection
}
catch
{
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

$URLS = Get-PnPListItem -List $migJobsList -Query $listQuery -Connection $migconn
Write-Host $URLS.count
Foreach ($row in $URLS)
{

    #set source site url
    $SourceSiteURL = $row['Title']
    Write-Host $SourceSiteURL
    #get last part of site url to construct dest url and site title (title will be changed after migration)
    $position = $SourceSiteURL.LastIndexOf('/')
    $SiteTitle = $SourceSiteURL.Substring($position + 1)
    Write-Host $SiteTitle
    #set site owner of new site to current user (will be updated after migration)
    $SiteOwner = $Global:currentSession.userId
    $Template = $row['SiteTemplateType']
    $Timezone = 12

    #create dest url if does not exist already
    if($row['DestinationUrl'] -eq $null)
    {
        $DestSiteURL = 'https://ahsonline.sharepoint.com/teams/' + $SiteTitle
        Write-Host 'dest site url null'
    }
    else
    {
        $DestSiteURL = $row['DestinationUrl']
        Write-Host 'dest site url NOT null'
    }
    Write-Host $DestSiteURL

    Try
    {


        #Check if site exists already
        $Site = Get-PnPTenantSite -Connection $adminconn | Where-Object {$_.Url -eq $DestSiteURL}

        If ($Site -eq $null)
        {
            #sharepoint online pnp powershell create site collection
            If($Template -eq 'TeamSite')
            {
                New-PnPSite -Type $Template -Title $SiteTitle -Alias $SiteTitle -TimeZone 12 -Connection $adminconn
                Write-Host "Site Collection $($DestSiteURL) Created Successfully!" -ForegroundColor Green
            }
            else
            {
                New-PnPSite -Type $Template -Title $SiteTitle -Url $DestSiteURL -TimeZone 12 -Owner $SiteOwner -Connection $adminconn
                Write-Host "Site Collection $($DestSiteURL) Created Successfully!" -ForegroundColor Green
            }

            #add existing group to site with template TeamSiteWithoutMicrosoft365Group
            #Add-PnPMicrosoft365GroupToSite -Url $SiteURL -Alias "NewGroupForSite" -DisplayName "NewGroupForSite"
        }
        else
        {
            Write-Host "Site $($DestSiteURL) exists already!" -ForegroundColor Yellow
        }

        #add migraiton team and service accounts to destination sites
        Set-PnPTenantSite -Identity $DestSiteURL -Owners @('AdeleV@rcd8.onmicrosoft.com') -Connection $adminconn
        #Add-PnPSiteCollectionAdmin -Owners @("AdeleV@rcd8.onmicrosoft.com") -Connection

        #update custom script on dest site to copy aspx pages
        Set-PnPTenantSite -Identity $DestSiteURL -DenyAddAndCustomizePages:$false -Connection $adminconn
        Write-Host "Updated $($DestSiteURL)"

        #update item in migraiton jobs list
        Set-PnPListItem -List $migJobsList -Identity $row -Values @{'MigrationStatus' = 'Ready'; 'DestinationUrl' = $DestSiteURL} -Connection $migconn
    }
    catch
    {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }


}
#Disconnect-PnPOnline -Connection $adminconn
#Disconnect-PnPOnline -Connection $migconn
