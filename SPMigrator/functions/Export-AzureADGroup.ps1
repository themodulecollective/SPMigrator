function Export-AzureADGroup {
    <#
    .SYNOPSIS
        Get all Azure Active Directory Groups and export them to a XML file
    .DESCRIPTION
        Export all Azure Active Directory Groups to an XML file. Optional Zip export using $compressoutput switch param. Can specify additional properties to be included in the user export using CustomProperty param.
    .EXAMPLE
        Export-AzureADGroup -OutputFolderPath "C:\Users\UserName\Documents"
        All Groups in the connected tenant (via Graph) will be exported to an xml file in Documents
    #>

    [cmdletbinding()]
    param(
        # Folder path for the XML or Zip export
        [parameter(Mandatory)]
        [string]$OutputFolderPath
        ,
        # Include custom attribute to the exported user attributes
        [parameter()]
        [string[]]$Property
        ,
        # Compress the XML file into a Zip file
        [parameter()]
        [switch]$CompressOutput
    )


    $DateString = Get-Date -Format yyyyMMddhhmmss

    $TenantID = (Get-MGContext).TenantID

    $OutputFileName = $TenantID + 'Groups' + 'AsOf' + $DateString
    $OutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.xml')

    $Groups = get-OGGroup -Property $Property -All

    $Groups |
        Select-Object -ExcludeProperty groupTypes -property *,
            @{n='groupType';e={$_.groupTypes -join '|'}},
            @{n='TenantID'; e={$TenantID}}  |
        Export-Clixml -Path $outputFilePath

    if ($CompressOutput) {
        $ArchivePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.zip')

        Compress-Archive -Path $OutputFilePath -DestinationPath $ArchivePath

        Remove-Item -Path $OutputFilePath -Confirm:$false
    }
}
