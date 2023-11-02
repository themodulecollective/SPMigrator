function Copy-SPOSiteGroupPermission
{
    param(
        $PNPSourceSite
        ,
        $PNPTargetSite
        ,
        [hashtable]$UserMap
        ,
        [switch]$RecurseMembership
        ,
        [parameter()]
        [string[]]$IncludedGroups = @('Members', 'Owners', 'Visitors')
        ,
        [switch]$testOutput
    )

    #Get Site and Site Group Details
    $SourceSiteGroups = Get-PnPSiteGroup -Connection $PNPSourceSite
    $TargetSiteGroups = Get-PnPSiteGroup -Connection $PNPTargetSite
    $SourceSiteWeb = Get-PnPWeb -Connection $PNPSourceSite
    $TargetSiteWeb = Get-PnPWeb -Connection $PNPTargetSite

    #Hashtables of Site Groups
    $SSGHash = @{}
    $TSGHash = @{}
    #Populate Hashtables
    $SourceSiteGroups.foreach({
            $SSGHash.add($_.LoginName, $_)
        })
    $TargetSiteGroups.foreach({
            $TSGHash.add($_.LoginName, $_)
        })

    # Map Source and Target Site Groups
    $SiteGroupMap = @{}
    $IncludedGroups.foreach({
            $iG = $_
            $SGKey = $SourceSiteWeb.Title + ' ' + $iG
            switch ($SSGHash.ContainsKey($SGKey))
            {
                $true
                {
                    #try match based on Source Site Group Name
                    switch ($TSGHash.ContainsKey($SGKey))
                    {
                        $true
                        {$SiteGroupMap.add($SGKey, $SGKey)}
                        $false
                        {
                            #try match based on Target Site Group Name
                            $TGKey = $TargetSiteWeb.Title + ' ' + $iG
                            switch ($TSGHash.ContainsKey($TGKey))
                            {
                                $true
                                {$SiteGroupMap.add($SGKey, $TGKey)}
                                $false
                                {
                                    Write-Warning -Message "For Source Site $($SourceSiteWeb.Title) and Target Site $($TargetSiteWeb.Title)"
                                    Write-Warning -Message "Unable to map Source Group $SGKey to a Target Site Group"
                                }
                            }
                        }
                    }
                }
                $false
                {
                    Write-Warning "For Source Site ($SourceSiteWeb.Title), did not find expected group $SGKey"
                }
            }
        })


    # "Flatten" Source Group Members
    switch ($RecurseMembership)
    {
        $true
        {
            $SiteGroupMap.Keys.ForEach({
                    $RawMembers = Get-PnPGroupMember -Group $_ -Connection $PNPSourceSite
                    $UserMembers = @($RawMembers.where({$_.PrincipalType -eq 'User'}).UserPrincipalName)
                    $GroupMembers = @($RawMembers.where({$_.PrincipalType -eq 'SecurityGroup'}).foreach({
                                Get-EntraIDGroupMember -GroupID $_.LoginName.split('|')[2] -Recurse
                            }).UserPrincipalName)
                    $RecursedMembers = @(@($UserMembers + $GroupMembers) | Sort-Object -Unique | Select-Object -Unique)
                    $SSGHash.$_ | Add-Member -MemberType NoteProperty -Name RecursedMembers -Value $RecursedMembers
                })
        }
        $false
        {
            # nothing to do here in this iteration of the code.  the Users property of the group already lists user and group members. Users by UPN and groups by ID
        }
    }

    # Map Source and Target Site Group Members

    switch ($RecurseMembership)
    {
        $true
        {
            $SiteGroupMap.Keys.ForEach({
                    $MappedMembers = @($SSGHash.$_.RecursedMembers.foreach({if ($Usermap.ContainsKey($_)) {$Usermap.$_}}))
                    $SSGHash.$_ | Add-Member -MemberType NoteProperty -Name MappedMembers -Value $MappedMembers
                })
        }
        $false
        {
            $SiteGroupMap.Keys.ForEach({
                    $MappedMembers = @($SSGHash.$_.Users.foreach({if ($usermap.ContainsKey($_)) {$Usermap.$_}}))
                    $SSGHash.$_ | Add-Member -MemberType NoteProperty -Name MappedMembers -Value $MappedMembers
                })
        }
    }


    switch ($testOutput)
    {
        $true
        {$SiteGroupMap.keys.foreach({$SSGHash.$_})}
        $false
        {
            $SiteGroupMap.Keys.ForEach({
                    $Group = $SiteGroupMap.$_
                    $SSGHash.$Group.MappedMembers.foreach({
                            Add-PnPGroupMember -Group $Group -LoginName $_ -Connection $PNPTargetSite
                        })
                })
        }
    }

}