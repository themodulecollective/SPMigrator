function Export-ADUser {
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
        # Users Domain. Used when naming export file
        [parameter(Mandatory)]
        [string]$Domain
        ,
        # Includes Exchange user attributes. Exchange:$false = 'DisplayName', 'Mail', 'proxyAddresses', 'SamAccountName', 'UserPrincipalName', 'Company', 'department', 'objectSID', 'DistinguishedName', 'ObjectGUID', 'mS-DS-ConsistencyGUID', 'physicalDeliveryOfficeName'
        # Exchange:$true adds 'msExchMasterAccountSid', 'mailnickname', 'mS-DS-ConsistencyGUID', 'msExchMailboxGuid'
        [parameter()]
        [bool]$Exchange = $true
        ,
        # Include custom attribute to the exported user attributes
        [parameter()]
        [string[]]$CustomProperty
        ,
        # Compress the XML file into a Zip file
        [parameter()]
        [switch]$CompressOutput
    )


    if ($null -eq $(Get-Module -Name ActiveDirectory)) {
        Import-Module ActiveDirectory -ErrorAction Stop
    }

    $Properties = @(@('DisplayName','GivenName','Surname','Mail','Initials', 'proxyAddresses', 'SamAccountName', 'UserPrincipalName','City', 'Country', 'countryCode','Company', 'Department','Division','Description','businesscategory', 'SID', 'DistinguishedName','CanonicalName','ObjectGUID', 'mS-DS-ConsistencyGUID', 'physicalDeliveryOfficeName', 'EmployeeID', 'EmployeeNumber', 'employeeType','Manager','Enabled','LastLogonDate') | Sort-Object)

    switch ($Exchange) {
        $true {
            $Properties = @(@($Properties;@('msExchMasterAccountSid', 'mailnickname', 'msExchMailboxGuid');@($((1..15).foreach({"ExtensionAttribute$_"}));$((16..45).foreach({"msExchExtensionAttribute$_"}));$((1..5).foreach({"msExchExtensionCustomAttribute$_"})))) | Sort-Object)
        }
    }

    $Properties = @(@($Properties;$CustomProperty) | Sort-Object -Unique)

    $DateString = Get-Date -Format yyyyMMddhhmmss

    $OutputFileName = $Domain + 'ADUsers' + 'AsOf' + $DateString
    $OutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.xml')

    $ADUsers = Get-ADUser -Properties $Properties -filter * #| Sort-Object -Property $Properties -Descending

    $ADUsers | Export-Clixml -Path $outputFilePath

    if ($CompressOutput) {
        $ArchivePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.zip')

        Compress-Archive -Path $OutputFilePath -DestinationPath $ArchivePath

        Remove-Item -Path $OutputFilePath -Confirm:$false
    }
}