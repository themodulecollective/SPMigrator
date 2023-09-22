function Remove-SPMSiteCollectionAdmin {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [validateset('Source','Target')]
        [string]$Environment
        ,
        [parameter()]
        [string[]]$SiteURL
    )
    $SPMConfiguration = Get-SPMConfiguration
    $SPOTenant = Get-SPOTenant
    if ($null -eq $SPOTenant)
    {throw('you must connect to a tenant using Connect-SPOService before running Remove-SiteCollectionAdmin')}

    switch ($Environment)
    {
        'Source'
        {
            if ($null -eq $SPMConfiguration.SourceSiteCollectionAdmins
                -or $SPMConfiguration.SourceSiteCollectionAdmins.count -lt 1 )
            {
                throw ('SourceSiteCollectionAdmins must be added to SPMConfiguration before running Remove-SiteCollectionAdmin')
            }
            else
            {
                $SPMConfiguration.SourceSiteCollectionAdmins.foreach({
                    $LoginName = $_
                    $SiteURL.foreach({
                        $Site = $_
                        try {
                            Set-SPOUser -LoginName $LoginName -Site $Site -IsSiteCollectionAdmin $false
                        }
                        catch {
                            Write-Warning "Failed to add $LoginName to $Site as SiteCollectionAdmin"
                        }
                    })
                })
            }
        }
        'Target'
        {
            if ($null -eq $SPMConfiguration.TargetSiteCollectionAdmins
                -or $SPMConfiguration.TargetSiteCollectionAdmins.count -lt 1 )
            {
                throw ('TargetSiteCollectionAdmins must be added to SPMConfiguration before running Remove-SiteCollectionAdmin'
            }
            else
            {
                $SPMConfiguration.TargetSiteCollectionAdmins.foreach({
                    $LoginName = $_
                    $SiteURL.foreach({
                        $Site = $_
                        try {
                            Set-SPOUser -LoginName $LoginName -Site $Site -IsSiteCollectionAdmin $false
                        }
                        catch {
                            Write-Warning "Failed to add $LoginName to $Site as SiteCollectionAdmin"
                        }
                    })
                })
            }
        }
    }
}