function Export-SPOSite {
    [cmdletbinding()]
    param(
        [parameter()]
        [string]$OutputFolderPath
    )

    $SPOTenant = Get-SPOTenant
    if ($null -eq $SPOTenant)
    {throw('you must connect to a tenant using Connect-SPOService before running Export-SPOSite')}

    $sites = Get-SPOSite -Limit 'ALL'

    $DateString = Get-Date -Format yyyyMMddhhmmss

    $OutputFileName = 'Sites' + 'AsOf' + $DateString
    $OutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.xlsx')
    $sites | Export-Excel -path $outputFilePath -WorksheetName 'Sites' -TableName 'Sites' -TableStyle Medium4

}