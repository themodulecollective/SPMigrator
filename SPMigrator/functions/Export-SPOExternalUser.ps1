function Export-SPOExternalUser {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [string[]]$SiteURL
        ,
        [parameter()]
        [string]$OutputFolderPath
    )

    $SPOTenant = Get-SPOTenant
    if ($null -eq $SPOTenant)
    {throw('you must connect to a tenant using Connect-SPOService before running Export-SPOSite')}

    $ItThrew = $false
    $i = 0
    $ExternalSiteUsers = @(
    $SiteURL.foreach({
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