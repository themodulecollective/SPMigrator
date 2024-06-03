function Export-SPOSite {
    [cmdletbinding()]
    param(
        [parameter()]
        [string]$OutputFolderPath
        ,
        [parameter()]
        [switch]$PersonalSite
        
    )

    $SPOTenant = Get-SPOTenant
    if ($null -eq $SPOTenant)
    {throw('you must connect to a tenant using Connect-SPOService before running Export-SPOSite')}

    $GetSPOSiteParams = @{
        Limit = 'ALL'
    }

    switch ($PersonalSite)
    {
        $true
        {
            $GetSPOSiteParams.IncludePersonalSite = $true
            $sites = @(@(Get-SPOSite @GetSPOSiteParams).Where({$_.Template -eq 'SPSPERS#10'}))
        }
        $false
        {
            $sites = @(Get-SPOSite @GetSPOSiteParams)
        }
    }

    

    $DateString = Get-Date -Format yyyyMMddhhmmss

    $OutputFileName = $(switch ($PersonalSite) {$true {'PersonalSites'} default {'SPOSites'}}) + 'AsOf' + $DateString
    $OutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.xlsx')
    $sites |
    Select-Object -ExcludeProperty 'InformationSegment','ExcludedBlockDownloadGroupIds','ExcludeBlockDownloadSharePointGroups' `
        -Property *,@{n='InformationSegment';e={$_.InformationSegment.guid -join '|'}},
        @{n='ExcludedBlockDownloadGroupIds';e={$_.ExcludedBlockDownloadGroupIds.guid -join '|'}},
        @{n='ExcludeBlockDownloadSharePointGroups';e={$_.ExcludeBlockDownloadSharePointGroups -join '|'}} |
    Export-Excel -path $outputFilePath -WorksheetName 'Sites' -TableName 'Sites' -TableStyle Medium4 
}


