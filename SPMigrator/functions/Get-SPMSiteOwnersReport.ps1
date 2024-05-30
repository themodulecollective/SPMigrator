#requires -modules PnP.PowerShell, xProgress
function Get-SPMSiteOwnerRole
{
    [cmdletbinding(DefaultParameterSetName = 'AllSites')]
    param(
        [parameter(Mandatory)]
        [ValidateScript({$_.Url -like '*-admin.sharepoint.com/' })]
        [PnP.PowerShell.Commands.Base.PnPConnection]$PNPAdminConnection
        ,
        [parameter(Mandatory)]
        [string]$AdminIdentity
        ,
        [parameter()]
        [string[]]$Filtered #Identities to ignore when processing -  list of  UserPrincipalName or other SPO user list identifier
        ,
        [parameter(ParameterSetName = 'SpecifiedSites')]
        [string[]]$SiteURL
    )

    $cp = @{
        Connection = $PNPAdmin
    }

    switch ($PSCmdlet.ParameterSetName)
    {
        'SpecifiedSites'
        {
            $Sites = @($SiteURL.foreach({
                        Get-PnPTenantSite -Identity $_ @cp
                    }))
        }
        'AllSites'
        {
            $Sites = @(Get-PnPTenantSite @cp )
        }
    }

    $Sites = $Sites | Sort-Object -Property Template

    $xpiD = New-xProgress -ArrayToProcess $Sites -CalculatedProgressInterval 10Percent -Activity 'Getting Site Owner Roles'

    $Sites.foreach({
            $site = $_
            Write-xProgress -Identity $xpiD
            #add admin identity as owner for getting site group members
            Write-Verbose -Message "Processing Site: $($site.title), $($site.URL)"
            Set-PnPTenantSite -Identity $site.URL -Owners $AdminIdentity @cp

            $OwnerAdminMemberships = @(
                $(Get-PnPSiteGroup -Site $site.URL @cp).where({$_.Roles -contains 'Full Control'}).Users |
                Select-Object -Property @{n='UserPrincipalName'; e={$_}}, @{n='Role'; e={'Site Owner'}}
                if ($site.groupID -ne '00000000-0000-0000-0000-000000000000')
                {
                    Get-PnPMicrosoft365GroupOwner -Identity $site.groupID @cp |
                    Select-Object -ExpandProperty UserPrincipalName |
                    Select-Object -Property @{n='UserPrincipalName'; e={$_}}, @{n='Role'; e={'Group Owner'}}
                }
            )

            #Filter out Filtered Identities
            $OwnerAdminMemberships = @($OwnerAdminMemberships.where({$_.UserPrincipalName -notin $Filtered -and $_.UserPrincipalName -like '*@*'}))

            $OAMHash = @{}
            $OwnerAdminMemberships.foreach({
                    $oam = $_
                    switch($OAMHash.ContainsKey($oam.UserPrincipalName))
                    {
                        $true
                        {
                            $OAMHash.$($oam.UserPrincipalName).add($oam.Role)
                        }
                        $false
                        {
                            $OAMHash.add($oam.UserPrincipalName, [System.Collections.Generic.List[psobject]]@($oam.Role))
                        }
                    }
                })
            $OAMHash.GetEnumerator().foreach({
                    [PSCustomObject]@{
                        SiteTitle         = $site.Title
                        SiteURL           = $site.URL
                        UserPrincipalName = $_.Name
                        Role              = $_.Value -join '|'
                    }

                })
        })
    Complete-xProgress -Identity $xpiD
}