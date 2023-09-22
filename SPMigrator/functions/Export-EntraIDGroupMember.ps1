function Export-EntraIDGroupMember
{
    <#
    .SYNOPSIS
        Get all Entra ID  Groups and export their Membership Info to Excel
    .DESCRIPTION
        Get all Entra ID Groups and export their Membership Info to Excel including Member ID, Member Display Name, Member Mail, Member UserPrincipalName, and Member UserType
    .EXAMPLE
        Export-EntraIDGroupMember -OutputFolderPath "C:\Users\UserName\Documents"
        All Entra ID Groups in the connected tenant (via Graph) Membership Info  will be exported to an Excel file in Documents
    #>

    [cmdletbinding()]
    param(
        # Folder path for the XML or Zip export
        [parameter(Mandatory)]
        [string]$OutputFolderPath
    )

    $DateString = Get-Date -Format yyyyMMddhhmmss

    $TenantID = (Get-MgContext).TenantID

    $OutputFileName = $TenantID + 'GroupMembers' + 'AsOf' + $DateString
    $OutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.xlsx')

    Write-Information -MessageData 'Getting All Entra Unified Groups'
    $Groups = Get-OGGroup -All

    Write-Information -MessageData 'getting the Group Members'

    $GroupMembers = @($Groups.foreach({
                $Group = $_
                Get-MgGroupMemberAsUser -GroupID $_.ID -Property ID,DisplayName,Mail,UserPrincipalName,UserType |
                Select-Object -ExcludeProperty 'ID' -Property @{n='GroupID';e={$Group.ID}},
                    @{n='GroupDisplayName';e={$Group.displayName}},
                    @{n='GroupMail';e={$Group.mail}},
                    @{n='MemberID';e={$_.ID}},
                    @{n='MemberDisplayName';e={$_.DisplayName}},
                    @{n='MemberMail';e={$_.Mail}},
                    @{n='MemberUserPrincipalName';e={$_.UserPrincipalName}},
                    @{n='MemberUserType';e={$_.UserType}}
            }))

    $GroupMembers | Export-Excel -Path $OutputFilePath -WorksheetName GroupMembers -TableName GroupMembers -TableStyle Medium4
}
