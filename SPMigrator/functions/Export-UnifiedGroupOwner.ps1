function Export-UnifiedGroupOwner
{
    <#
    .SYNOPSIS
        Get all Azure Active Directory Unified Groups and export their Drive Info to Excel
    .DESCRIPTION
        Get all Azure Active Directory Unified Groups and export their Drive Info to Excel including DriveName, DriveURL, DriveID, driveType, SiteURL, createdDateTime, lastModifiedDateTime, and quota information
    .EXAMPLE
        Export-UnifiedGroupOwner -OutputFolderPath "C:\Users\UserName\Documents"
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

    $OutputFileName = $TenantID + 'GroupOwners' + 'AsOf' + $DateString
    $OutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.xlsx')

    Write-Information -MessageData 'Getting All Entra Unified Groups'
    $Groups = Get-OGGroup -UnifiedAll

    Write-Information -MessageData 'Filtering Entra Groups for Unified Groups, then getting the Group Owners'

    $UnifiedGroupOwners = @($Groups.foreach({
                $GID = $_.ID
                Get-MgGroupOwner -GroupID $GID |
                Select-Object -Property @{n='OwnerID';e={$_.ID}},@{n='GroupID';e={$GID}}
            }))

    $UnifiedGroupOwners | Export-Excel -Path $OutputFilePath -WorksheetName UnifiedGroupOwners -TableName UnifiedGroupOwners -TableStyle Medium4
}
