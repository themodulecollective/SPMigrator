function Export-AzureADLicensing {
    <#
    .SYNOPSIS
        Get and export all Active Directory user and group licensing and export to an excel file
    .DESCRIPTION
        Get and export all Active Directory user and group licensing and export to an excel file
        Improvement Ideas:  https://learn.microsoft.com/en-us/azure/active-directory/enterprise-users/licensing-ps-examples#remove-direct-licenses-for-users-with-group-licenses
    .EXAMPLE
        Export-ADUser -OutputFolderPath "C:\Users\UserName\Documents" -Domain contoso
        All users in the domain Contoso will be exported Documents in the file 20221014021841contosoUsers.xml

        Export-ADUser -OutputFolderPath "C:\Users\UserName\Documents" -Domain contoso -Exchange:$true
        All users in the domain Contoso will be exported Documents in the file 20221014021841contosoUsers.xml. The user attributes will include some exchange attributes. ex. msExchMailboxGuid and mailnickname

        Export-ADUser -OutputFolderPath "C:\Users\UserName\Documents" -Domain contoso -CustomProperty CustomAttribute17
        All users in the domain Contoso will be exported Documents in the file 20221014021841contosoUsers.xml and CustomAttribute17 will be included in the User attributes
    #>

    [cmdletbinding()]
    param(
        # Folder path for the XML or Zip export
        [parameter(Mandatory)]
        [string]$OutputFolderPath
        ,
        [parameter(Mandatory)]
        [ValidateSet('UserLicensing','GroupLicensing')]
        [string[]]$Operation
    )

    $DateString = Get-Date -Format yyyyMMddhhmmss

    $Tenant = (Get-MGContext).TenantID

    switch ($Operation)
    {
        'UserLicensing'
        {
            $OutputFileName = $Tenant + 'UserLicensing' + 'AsOf' + $DateString
            $OutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.xlsx')
            $OGUsers = get-oguser -All
            $OGUsersSkus = $OGUsers.ForEach({$UPN = $_.UserPrincipalName; Get-OGUserSku -UserPrincipalName $UPN -IncludeDisplayName | where-object -FilterScript {$_.skuDisplayName -eq 'Microsoft 365 E3'} | Select-Object -Property *,@{n='UserPrincipalName';e={$UPN}}})
            $OGUsersSkus |
                Select-Object UserPrincipalName,skuId,skuDisplayName,ServicePlanNames,ServicePlanDisplayNames |
                Export-Excel -Path $OutputFilePath -TableName UserLicensing -TableStyle Medium1
        }
        'GroupLicensing'
        {
            $OutputFileName = $Tenant + 'GroupLicensing' + 'AsOf' + $DateString
            $OutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.xlsx')
            $OGLR = Get-OGGroupLicenseReport -All -IncludeDisplayName
            $OGLRJ = $OGLR | Group-Join -Property GroupDisplayName,skuDisplayName,ServicePlanIsEnabled -JoinProperty ServicePlanDisplayName,ServicePlanName,ServicePlanID -JoinDelimiter ';'
            $OGLRJ | Export-Excel -Path $OutputFilePath -TableName GroupLicensing -TableStyle Medium1
        }
    }
}