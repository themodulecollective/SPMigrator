function Export-UnifiedGroupDrive
{
    <#
    .SYNOPSIS
        Get all Azure Active Directory Unified Groups and export their Drive Info to Excel
    .DESCRIPTION
        Get all Azure Active Directory Unified Groups and export their Drive Info to Excel including DriveName, DriveURL, DriveID, driveType, SiteURL, createdDateTime, lastModifiedDateTime, and quota information
    .EXAMPLE
        Export-AzureADGroupDrive -OutputFolderPath "C:\Users\UserName\Documents"
        All Unified Groups in the connected tenant (via Graph) Drive Info  will be exported to an Excel file in Documents
    #>

    [cmdletbinding()]
    param(
        # Folder path for the XML or Zip export
        [parameter(Mandatory)]
        [string]$OutputFolderPath
    )

    $DateString = Get-Date -Format yyyyMMddhhmmss

    $TenantID = (Get-MgContext).TenantID

    $OutputFileName = $TenantID + 'GroupDrives' + 'AsOf' + $DateString
    $OutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.xlsx')

    $Groups = Get-OGGroup -Property $Property -All

    $UnifiedGroupDrives = @(@($Groups |
            Select-Object -ExcludeProperty groupTypes -Property *,
            @{n='groupType'; e={$_.groupTypes -join '|'}}).where({
                $_.groupType -like '*Unified*'
            }).foreach({
                Get-OGGroupDrive -GroupID $_.ID | Select-Object -Property *, @{n='TenantID'; e={$TenantID}}
            }))

    $UnifiedGroupDrives | Export-Excel -Path $OutputFilePath -WorksheetName UnifiedGroupDrives -TableName UnifiedGroupDrives -TableStyle Medium4

}
