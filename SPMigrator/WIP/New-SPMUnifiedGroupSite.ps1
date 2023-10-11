function New-SPMUnifiedGroupSite
{
    [cmdletbinding()]
    param(

    )

    $NewPNPSiteParams = @{
        Type = 'TeamSite'
        Title = $SourceSiteTitle
        Alias = $SourceSiteAlias
        Description = $SourceSiteDescription
        Owners = $SPMConfiguration.TargetSiteCollectionAdmins
        Connection = $TargetAdminConnection
    }

}