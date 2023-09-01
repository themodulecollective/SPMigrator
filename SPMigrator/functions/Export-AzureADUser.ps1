function Export-AzureADUser {
    <#
    .SYNOPSIS
        Get all Active Directory user and export them to a XML file
    .DESCRIPTION
        Export all Active Directory user to an XML file. Optional Zip export using $compressoutput switch param. Can specify additional properties to be included in the user export using CustomProperty param.
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
        # Include custom attribute to the exported user attributes
        [parameter()]
        [string[]]$CustomProperty
        ,
        # Compress the XML file into a Zip file
        [parameter()]
        [switch]$CompressOutput
    )

    $Properties = @(
     'accountEnabled','assignedLicenses','businessPhones','city','companyName','country','department','displayName','employeeId','givenName','id','jobTitle','lastPasswordChangeDateTime','licenseAssignmentStates','mail','mailNickname','mobilePhone','officeLocation','onPremisesDistinguishedName','onPremisesDomainName','onPremisesExtensionAttributes','onPremisesImmutableId','onPremisesLastSyncDateTime','onPremisesSamAccountName','onPremisesSecurityIdentifier','onPremisesSyncEnabled','onPremisesUserPrincipalName','preferredLanguage','surname','usageLocation','userPrincipalName','userType'
    )

    $Properties = @(@($Properties;$CustomProperty) | Sort-Object -Unique)

    $DateString = Get-Date -Format yyyyMMddhhmmss

    $TenantID = (Get-MGContext).TenantID

    $OutputFileName = $TenantID + 'Users' + 'AsOf' + $DateString
    $OutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.xml')

    $Users = get-oguser -Property $Properties

    $Users | Select-Object -property *,@{n='TenantID'; e={$TenantID}}  Export-Clixml -Path $outputFilePath

    if ($CompressOutput) {
        $ArchivePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.zip')

        Compress-Archive -Path $OutputFilePath -DestinationPath $ArchivePath

        Remove-Item -Path $OutputFilePath -Confirm:$false
    }
}