function Export-SPOExternalUser {
    [cmdletbinding(DefaultParameterSetName = 'SiteURL')]
    param(
        [parameter(Mandatory,ParameterSetName = 'SiteURL')]
        [string[]]$SiteURL
        ,
        [parameter()]
        [string]$OutputFolderPath
        ,
        [parameter(ParameterSetName = 'SharingNotDisabled')]
        [switch]$SharingNotDisabled
    )

    $SPOTenant = Get-SPOTenant
    if ($null -eq $SPOTenant)
    {throw('you must connect to a tenant using Connect-SPOService before running Export-SPOSite')}

    switch ($Pscmdlet.ParameterSetName)
    {
        'SharingNotDisabled'
        {
            $SiteURL = @(@(@(Get-SPOSite -Limit 'ALL').where({$_.SharingCapability -ne 'Disabled'})).URL)
        }
    }

    $i = 0
    $ExternalSiteUsers = @(
    $SiteURL.foreach({
        $ItThrew = $false
        $URL = $_
        do {
            try {
                Get-SPOExternalUser -SiteURL $URL -Position $i -PageSize 50 -ErrorAction Stop |
                Select-Object -Property DisplayName,Email,InvitedBy,AcceptedAs,WhenCreated,
                    @{n='SiteURL';e={$URL}}
                $i+=50
            }
            catch {
                $ItThrew = $true
            }
        }
        until ($ItThrew)
    })
    )

    $DateString = Get-Date -Format yyyyMMddhhmmss
    $OutputFileName = 'ExternalSiteUsers' + 'AsOf' + $DateString
    $OutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.xlsx')
    $ExternalSiteUsers | Export-Excel -path $outputFilePath -WorksheetName 'ExternalUsers' -TableName 'ExternalUsers' -TableStyle Medium4

}