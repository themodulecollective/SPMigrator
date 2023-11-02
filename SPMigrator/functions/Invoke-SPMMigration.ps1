function Invoke-SPMMigration
{
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [psobject[]]$ToProcess
        ,
        [parameter(Mandatory)]
        [ValidateSet('HostSelection', 'PrepareSource', 'ProvisionTarget', 'ProvisionTargetSite', 'UpdateBacklog', 'PrepareTarget', 'ConnectSharegate', 'Copy-SitePermissions', 'Copy-Site', 'Report')]
        [string[]]$Operation
        ,
        [parameter(Mandatory)]
        [ValidateSet('Overwrite', 'IncrementalUpdate', 'Rename', 'Skip')]
        [string]$OnContentItemExists
        ,
        [parameter(Mandatory)]
        [ValidateSet('Merge', 'Skip')]
        [string]$OnSiteObjectExists
        ,
        [parameter(Mandatory)]
        [ValidateSet('InitialDataMigration', 'DeltaDataMigration')]
        [string]$CopySiteStatus
        ,
        [parameter(Mandatory)]
        [ValidateSet('QualityAssurance', 'UserAcceptanceTesting')]
        [string]$CopySiteCompletedStatus
        ,
        [parameter()]
        [string]$WriteProgressActivity
    )

    Write-Information -MessageData 'Creating MappingSettings'
    $MappingSettings = Import-UserAndGroupMapping -Path $SPMConfiguration.UserMappingFile
    #$MappingSettings = Set-UserAndGroupMapping -MappingSettings $MappingSettings -UnresolvedUserOrGroup -Destination 'RMR-SR-Mig-Usr2@multihosp.net'
    Write-Information -MessageData 'Creating CopySettings'
    $CopySettings = New-CopySettings -OnContentItemExists $OnContentItemExists -OnSiteObjectExists $OnSiteObjectExists
    Write-Information -MessageData "Entering Processing Loop with $($ToProcess.count) Items"
    if (-not $PSBoundParameters.ContainsKey('WriteProgressActivity')) {$WriteProgressActivity = 'Process Migration Operations'}
    $xProgressID = New-xProgress -ArrayToProcess $ToProcess -ExplicitProgressInterval 1 -Activity $WriteProgressActivity
    :nextprocess foreach ($i in $ToProcess)
    {
        if (Test-Path -Path $SPMConfiguration.StopProcess -PathType Leaf)
        {
            Write-Information -MessageData 'Detected Stop Process Signal from Operator' -InformationAction Continue
            break :nextprocess
        }
        $currentItem = Get-SPMBacklogItem -Id $i.ID
        $status = "Processing Backlog Site $($currentItem.ID)"
        Set-xProgress -Status $status -Identity $xProgressID
        Write-xProgress -Identity $xProgressID
        Write-Information -MessageData $status

        try
        {
            switch ($Operation)
            {
                'HostSelection'
                {
                    switch ([string]::IsNullOrWhiteSpace($currentItem.MigrationHost))
                    {
                        $true
                        {
                            $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -MigrationHost $SPMConfiguration.Hostname -LogMessage "MigrationHost Nominated:$($SPMConfiguration.hostname)"
                            Write-Information -MessageData 'MigrationHost Nominated'
                            Start-Sleep -Seconds $SPMConfiguration.ItemClaimSleep
                            $currentItem = Get-SPMBacklogItem -Id $currentItem.ID
                            switch ($currentItem.MigrationHost -eq $SPMConfiguration.Hostname)
                            {
                                $true
                                {
                                    $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "MigrationHost Confirmed:$($SPMConfiguration.hostname)"
                                    Write-Information -MessageData 'MigrationHost Confirmed'
                                }
                                $false
                                {
                                    $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "MigrationHost Yielded:$($SPMConfiguration.hostname)"
                                    Write-Information -MessageData 'MigrationHost Yielded'
                                    continue nextprocess
                                }
                            }
                        }
                        $false
                        {
                            $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "MigrationHost Not Contested:$($SPMConfiguration.hostname)"
                            Write-Information -MessageData 'MigrationHost Not Contested'
                            continue nextprocess
                        }
                    }
                }
                'PrepareSource'
                {
                    #Prepare Source
                    try
                    {
                        $status = 'Add QA Site Collection Owners to Source Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Attempting: $status"
                        $null = Set-PnPTenantSite -Url $currentItem.SourceSiteURL -Owners $SPMConfiguration.SourceSiteCollectionAdmins -Connection $PNPSource
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'ProvisionTarget'
                {
                    #Provision Target
                    try
                    {
                        $status = 'Create Target Unified Group'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Attempting: $status" -MigrationStatus ProvisionTarget
                        $currentGroup = New-SPMTargetGroup -SourceRecord $currentItem -method AzureAD
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'ProvisionTargetSite'
                {
                    #Provision Target
                    try
                    {
                        $status = 'Create Target Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Attempting: $status" -MigrationStatus ProvisionTarget
                        $sourceSite = Get-PnPTenantSite -Identity $currentItem.SourceSiteURL -Connection $PNPSource -ErrorAction Stop
                        [URI]$sourceURL = $sourceSite.Url
                        $newSiteURL = $(
                            switch ($null -eq $currentItem.TargetSiteURL)
                            {
                                $true
                                {$spmConfiguration.TargetURLBase + $sourceURL.AbsolutePath}
                                $false
                                {$currentItem.TargetSiteURL}
                            })

                        $newPNPTenantSiteParams = @{
                            Connection   = $PNPTarget
                            Template     = $currentItem.RootWebTemplate
                            Title        = $sourceSite.Title
                            StorageQuota = $currentItem.StorageUsedMB + 1024
                            TimeZone     = $SPMConfiguration.PNPPreferredTimeZone
                            Url          = $newSiteURL
                            Wait         = $true
                            Owner        = $SPMConfiguration.NonGroupSiteOwner
                        }
                        #$newPNPTenantSiteParams
                        New-PnPTenantSite @newPNPTenantSiteParams
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'UpdateBacklog'
                {
                    $status = 'Update Backlog with Target Details'
                    Write-Information -MessageData $status
                    if ($Operation -contains 'ProvisionTarget')
                    {
                        $currentPNPGroup = Get-PnPMicrosoft365Group -Identity $currentGroup.ID -IncludeSiteUrl -Connection $PNPTarget
                        $setBIParams = @{
                            id                      = $currentItem.ID
                            LogMessage              = $status
                            TargetSiteURL           = $currentPNPGroup.SiteURL
                            TargetGroupMailNickname = $currentPNPGroup.MailNickname
                            TargetGroupMail         = $currentPNPGroup.Mail
                            TargetGroupID           = $currentPNPGroup.GroupID
                        }
                    }
                    if ($Operation -contains 'ProvisionTargetSite')
                    {
                        $setBIParams = @{
                            id            = $currentItem.ID
                            LogMessage    = $status
                            TargetSiteURL = $newSiteURL
                        }
                    }
                    $currentItem = Set-SPMBacklogItem @setBIParams
                }
                'PrepareTarget'
                {
                    try
                    {
                        $status = 'Add QA Site Collection Owners to Target Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Attempting: $status"
                        $null = Set-PnPTenantSite -Url $currentItem.TargetSiteURL -Owners $SPMConfiguration.TargetSiteCollectionAdmins -Connection $PNPTarget -ErrorAction Stop
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'ConnectSharegate'
                {
                    try
                    {
                        $status = 'Connect ShareGate to Source Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Attempting: $status"
                        $SGSourceSite = Connect-Site -Url $currentItem.SourceSiteURL -UseCredentialsFrom $SGSource -ErrorAction Stop
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                    try
                    {
                        $status = 'Connect ShareGate to Target Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Attempting: $status"
                        $SGTargetSite = Connect-Site -Url $currentItem.TargetSiteURL -UseCredentialsFrom $SGTarget -ErrorAction Stop
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'Copy-SitePermissions'
                {
                    try
                    {
                        $status = 'Perform ShareGate Copy-ObjectPermissions for Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Attempting: $status"
                        Write-Information -MessageData "$($StartTime | Get-Date -Format yyyyMMdd-HHmm) status Start: $status" -InformationAction Continue
                        Copy-ObjectPermissions -Source $SGSourceSite -Destination $SGTargetSite -MappingSettings $MappingSettings
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'Copy-Site'
                {
                    try
                    {
                        $status = 'Perform ShareGate Copy-Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Attempting: $status" -MigrationStatus $CopySiteStatus
                        $StartTime = Get-Date
                        $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
                        Write-Information -MessageData "$($StartTime | Get-Date -Format yyyyMMdd-HHmm) status Start: $status" -InformationAction Continue
                        $CopySite = Copy-Site -Site $SGSourceSite -DestinationSite $SGTargetSite -Merge -MappingSettings $MappingSettings -CopySettings $CopySettings -VersionLimit $SPMConfiguration.VersionLimit -TaskName $currentItem.ID -ErrorAction Stop
                        $StopWatch.Stop()
                        $EndTime = $StartTime.Add($StopWatch.Elapsed)
                        Write-Information -MessageData "$($EndTime | Get-Date -Format yyyyMMdd-HHmm) status Complete: $status" -InformationAction Continue
                        Write-Information -MessageData "status Elapsed Time in Minutes: $($stopWatch.Elapsed.TotalMinutes)" -InformationAction Continue
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Succeeded: $status" -MigrationStatus $CopySiteCompletedStatus
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'Report'
                {
                    try
                    {
                        $FileName = 'InitialDataMigration-' + $currentItem.SourceGroupMailNickname + '-CompletedAt' + $($EndTime | Get-Date -Format yyyyMMdd-HHmm) + '.xlsx'
                        $FilePath = Join-Path -Path $SPMConfiguration.Reports -ChildPath $FileName
                        $status = "Export ShareGate Copy-Site Report to $($SPMConfiguration.hostname) $FilePath"
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Attempting: $status"
                        $null = Export-Report -CopyResult $CopySite -Path $FilePath -ErrorAction Stop
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                    try
                    {
                        $status = "Upload ShareGate Copy-Site Report $FileName to Migration Report Library"
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Attempting: $status"
                        $null = Add-PnPFile -Path $FilePath -Folder $SPMConfiguration.ReportLibraryFolder -Values @{MigrationWave = $currentItem.MigrationWave} -Connection $PNPTarget
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
            }
        }
        catch
        {
            $currentItem = Set-SPMBacklogItem -Id $currentItem.ID -LogMessage $_.ToString()
        }
    }
    Complete-xProgress -Identity $xProgressID
}