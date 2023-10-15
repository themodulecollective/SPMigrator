function Invoke-SPMMigration
{
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [psobject[]]$ToProcess
        ,
        [parameter(Mandatory)]
        [ValidateSet('HostSelection', 'PrepareSource', 'ProvisionTarget', 'UpdateBacklog', 'PrepareTarget', 'ConnectSharegate', 'Copy-SitePermissions', 'Copy-Site', 'Report')]
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
    )

    Write-Information -MessageData 'Creating MappingSettings'
    $MappingSettings = Import-UserAndGroupMapping -Path $SPMConfiguration.UserMappingFile
    #$MappingSettings = Set-UserAndGroupMapping -MappingSettings $MappingSettings -UnresolvedUserOrGroup -Destination 'RMR-SR-Mig-Usr2@multihosp.net'
    Write-Information -MessageData 'Creating CopySettings'
    $CopySettings = New-CopySettings -OnContentItemExists Overwrite
    Write-Information -MessageData "Entering Processing Loop with $($ToProcess.count) Items"
    $xProgressID = New-xProgress -ArrayToProcess $ToProcess -CalculatedProgressInterval 1Percent -Activity 'Initial Data Migration'
    :nextprocess foreach ($i in $ToProcess)
    {
        $currentItem = Set-SPMBacklogItem -ID $i.ID -LogMessage "MigrationHost Processing:$($SPMConfiguration.hostname)"
        $status = "Processing Site $($currentItem.SourceGroupMail)"
        Set-xProgress -Status $status -Activity 'Process Migration Operations' -Identity $xProgressID
        Write-xProgress -Identity $xProgressID
        Write-Information -MessageData $status

        try
        {
            switch ($Operation)
            {
                'HostSelection'
                {
                    Set-xProgress -Identity $xProgressID -CurrentOperation $_
                    Write-xProgress -Identity $xProgressID -DoNotIncrement

                    switch ([string]::IsNullOrWhiteSpace($currentItem.MigrationHost))
                    {
                        $true
                        {
                            $currentItem = Set-SPMBacklogItem -ID $currentItem.ID -MigrationHost $SPMConfiguration.Hostname -LogMessage "MigrationHost Nominated:$($SPMConfiguration.hostname)"
                            Start-Sleep -Seconds $SPMConfiguration.ItemClaimSleep
                            $currentItem = Get-SPMBacklogItem -ID $currentItem.ID
                            switch ($currentItem.MigrationHost -eq $SPMConfiguration.Hostname)
                            {
                                $true
                                {
                                    $currentItem = Set-SPMBacklogItem -ID $currentItem.ID -LogMessage "MigrationHost Confirmed:$($SPMConfiguration.hostname)"
                                    Write-Information -MessageData 'MigrationHost Confirmed'
                                }
                                $false
                                {
                                    $currentItem = Set-SPMBacklogItem -ID $currentItem.ID -LogMessage "MigrationHost Yielded:$($SPMConfiguration.hostname)"
                                    continue nextprocess
                                }
                            }
                        }
                        $false
                        {
                            $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "MigrationHost Not Contested:$($SPMConfiguration.hostname)"
                            continue nextprocess
                        }
                    }
                }
                'PrepareSource'
                {
                    Set-xProgress -Identity $xProgressID -CurrentOperation $_
                    Write-xProgress -Identity $xProgressID -DoNotIncrement
                    #Prepare Source
                    try
                    {
                        $status = 'Add QA Site Collection Owners to Source Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Attempting: $status"
                        $null = Set-PnPTenantSite -Url $currentItem.SourceSiteURL -Owners $SPMConfiguration.SourceSiteCollectionAdmins -Connection $PNPSource
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'ProvisionTarget'
                {
                    Set-xProgress -Identity $xProgressID -CurrentOperation $_
                    Write-xProgress -Identity $xProgressID -DoNotIncrement
                    #Provision Target
                    try
                    {
                        $status = 'Create Target Unified Group'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Attempting: $status" -MigrationStatus ProvisionTarget
                        $currentGroup = New-SPMTargetGroup -SourceRecord $currentItem -Method AzureAD
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'UpdateBacklog'
                {
                    Set-xProgress -Identity $xProgressID -CurrentOperation $_
                    Write-xProgress -Identity $xProgressID -DoNotIncrement
                    $status = 'Update Backlog with Target Details'
                    Write-Information -MessageData $status
                    $currentPNPGroup = Get-PnPMicrosoft365Group -Identity $currentGroup.ID -IncludeSiteUrl -Connection $PNPTarget
                    $setBIParams = @{
                        id                      = $currentItem.ID
                        LogMessage              = $status
                        TargetSiteURL           =  $currentPNPGroup.SiteURL
                        TargetGroupMailNickname = $currentPNPGroup.MailNickname
                        TargetGroupMail         = $currentPNPGroup.Mail
                        TargetGroupID           = $currentPNPGroup.GroupID
                    }
                    $currentItem = Set-SPMBacklogItem @setBIParams
                }
                'PrepareTarget'
                {
                    Set-xProgress -Identity $xProgressID -CurrentOperation $_
                    Write-xProgress -Identity $xProgressID -DoNotIncrement
                    try
                    {
                        $status = 'Add QA Site Collection Owners to Target Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Attempting: $status"
                        $null = Set-PnPTenantSite -Url $currentItem.TargetSiteURL -Owners $SPMConfiguration.TargetSiteCollectionAdmins -Connection $PNPTarget -ErrorAction Stop
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'ConnectSharegate'
                {
                    Set-xProgress -Identity $xProgressID -CurrentOperation $_
                    Write-xProgress -Identity $xProgressID -DoNotIncrement
                    try
                    {
                        $status = 'Connect ShareGate to Source Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Attempting: $status"
                        $SGSourceSite = Connect-Site -Url $currentItem.SourceSiteURL -UseCredentialsFrom $SGSource -ErrorAction Stop
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                    try
                    {
                        $status = 'Connect ShareGate to Target Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Attempting: $status"
                        $SGTargetSite = Connect-Site -Url $currentItem.TargetSiteURL -UseCredentialsFrom $SGTarget -ErrorAction Stop
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'Copy-SitePermissions'
                {
                    Set-xProgress -Identity $xProgressID -CurrentOperation $_
                    Write-xProgress -Identity $xProgressID -DoNotIncrement
                    try
                    {
                        $status = 'Perform ShareGate Copy-ObjectPermissions for Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Attempting: $status"
                        Write-Information -MessageData "$($StartTime | Get-Date -Format yyyyMMdd-HHmm) status Start: $status" -InformationAction Continue
                        Copy-ObjectPermissions -Source $SGSourceSite -Destination $SGTargetSite -MappingSettings $MappingSettings
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'Copy-Site'
                {
                    Set-xProgress -Identity $xProgressID -CurrentOperation $_
                    Write-xProgress -Identity $xProgressID -DoNotIncrement
                    try
                    {
                        $status = 'Perform ShareGate Copy-Site'
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Attempting: $status" -MigrationStatus $CopySiteStatus
                        $StartTime = Get-Date
                        $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
                        Write-Information -MessageData "$($StartTime | Get-Date -Format yyyyMMdd-HHmm) status Start: $status" -InformationAction Continue
                        $CopySite = Copy-Site -Site $SGSourceSite -DestinationSite $SGTargetSite -Merge -MappingSettings $MappingSettings -CopySettings $CopySettings -VersionLimit $SPMConfiguration.VersionLimit -TaskName $currentItem.TargetGroupMail -ErrorAction Stop
                        $StopWatch.Stop()
                        $EndTime = $StartTime.Add($StopWatch.Elapsed)
                        Write-Information -MessageData "$($EndTime | Get-Date -Format yyyyMMdd-HHmm) status Complete: $status" -InformationAction Continue
                        Write-Information -MessageData "status Elapsed Time in Minutes: $($stopWatch.Elapsed.TotalMinutes)" -InformationAction Continue
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Succeeded: $status" -MigrationStatus QualityAssurance
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
                'Report'
                {
                    Set-xProgress -Identity $xProgressID -CurrentOperation $_
                    Write-xProgress -Identity $xProgressID -DoNotIncrement
                    try
                    {
                        $FileName = 'InitialDataMigration-' + $currentItem.SourceGroupMailNickname + '-CompletedAt' + $($EndTime | Get-Date -Format yyyyMMdd-HHmm) + '.xlsx'
                        $FilePath = Join-Path -Path $SPMConfiguration.Reports -ChildPath $FileName
                        $status = "Export ShareGate Copy-Site Report to $($SPMConfiguration.hostname) $FilePath"
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Attempting: $status"
                        $null = Export-Report -CopyResult $CopySite -Path $FilePath -ErrorAction Stop
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                    try
                    {
                        $status = "Upload ShareGate Copy-Site Report $FileName to Migration Report Library"
                        Write-Information -MessageData $status
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Attempting: $status"
                        $null = Add-PnPFile -Path $FilePath -Folder $SPMConfiguration.ReportLibraryFolder -Values @{MigrationWave = $currentItem.MigrationWave} -Connection $PNPTarget
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Succeeded: $status"
                    }
                    catch
                    {
                        $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage "Failed: $status"
                        throw($_)
                    }
                }
            }
        }
        catch
        {
            $currentItem = Set-SPMBacklogItem -id $currentItem.ID -LogMessage $_.ToString()
        }
    }
    Complete-xProgress -Identity $xProgressID
}