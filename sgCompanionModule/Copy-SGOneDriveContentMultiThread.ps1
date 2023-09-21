function Copy-SGOneDriveContentMultiThread {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)][psobject[]]
        $UserSiteData,
        [Parameter(Mandatory = $True)][String]
        $SourceUserPrincipalNameHeader,
        [Parameter(Mandatory = $True)][String]
        $TargetUserPrincipalNameHeader,
        [Parameter(Mandatory = $false)][int]
        $currentCount,
        [Parameter(Mandatory = $False)][Int]
        $ValidationLimit,
        [Parameter(Mandatory = $False)][switch]
        $PreCheck,
        [Parameter(Mandatory = $true)][int]
        $ConcurrentCopys,
        [Parameter(Mandatory = $True)][String]
        $LogFilePath
    )
    if ($sourceTenant) {
    }
    else {
        Write-Information "No source tenant found. Please run Connect-BothTenant before using this function" -InformationAction Continue
        exit
    }
    if ($targetTenant) {
    }
    else {
        Write-Information "No target tenant found. Please run Connect-BothTenant before using this function" -InformationAction Continue
        exit
    }
    switch ($currentCount -gt 0) {
        $true {
            [int]$count = $currentCount - 1
        }
        $false {
            [int]$count = 0
        }
    }
    switch ($PSBoundParameters.Keys -contains 'ValidationLimit') {
        $true {
            $limit = $ValidationLimit - 1
            $UserSiteData = $UserSiteData[0..$limit]
        }
    }
    foreach ($User in $UserSiteData) {
        # Create TaskName
        [string]$currentCount = ++$count
        switch ($PSBoundParameters.Keys -contains 'PreCheck') {
            $true {
                $taskName = $currentCount + ". " + "Pre-check on " + $User.$TargetUserPrincipalNameHeader
            }
            $false {
                $taskName = $currentCount + ". " + $User.$TargetUserPrincipalNameHeader
            }
        }
        # Limit Sessions to Concurrent Copies param
        $Jobs = Get-Job
        $runningJobs = $Jobs.where({ ($_.State -eq 'Running') -or ($_.State -eq 'NotStarted') })
        while ($runningJobs.count -ge $ConcurrentCopys) {
            $Jobs = Get-Job
            $runningJobs = $Jobs.where({ ($_.State -eq 'Running') -or ($_.State -eq 'NotStarted') })
            Start-Sleep 60
        }
        # Copy Content from Source to Target
        switch ($PSBoundParameters.Keys -contains 'ValidationLimit') {
            $true {
                Write-Information "Validation Limit Set. No Copy or PreCheck initiated" -InformationAction Continue
            }
            $false {
                switch ($PSBoundParameters.Keys -contains 'PreCheck') {
                    $true {
                        $sourceUserEmail = $User.$SourceUserPrincipalNameHeader
                        $sourceTenantSite = $sourceTenant.site
                        $targetUserEmail = $User.$targetUserPrincipalNameHeader
                        $targetTenantSite = $targetTenant.site
                        $jobParams = @{
                            scriptblock = [scriptblock]::Create(
                                '# Setup Source User Site
                                $sourceoneDriveUrl = Get-OneDriveUrl -Tenant $using:sourceTenantSite -Email $using:sourceUserEmail
                                $null = Add-SiteCollectionAdministrator -CentralAdmin $using:sourceTenantSite -SiteUrl $sourceoneDriveUrl
                                $sourceOneDriveSite = Connect-Site -Url $sourceoneDriveUrl -UseCredentialsFrom $using:sourceTenant
                                $sourceOneDriveList = Get-List -Site $sourceOneDriveSite -Name "Documents"
                                # Setup Target User Site
                                $targetoneDriveUrl = Get-OneDriveUrl -Tenant $using:targetTenantSite -Email $using:targetUserEmail
                                $null = Add-SiteCollectionAdministrator -CentralAdmin $using:targetTenantSite -SiteUrl $targetoneDriveUrl
                                $targetOneDriveSite = Connect-Site -Url $targetoneDriveUrl -UseCredentialsFrom $using:targetTenant
                                $targetOneDriveList = Get-List -Site $targetOneDriveSite -Name "Documents"
                                $results = Copy-Content -SourceList $sourceOneDriveList -DestinationList $targetOneDriveList -TaskName $using:taskName -whatif
                                $results = $results | select-object @{ Name = "TaskName";  Expression = {$using:taskName}},*
                                $results | export-csv -Path $using:LogFilePath -Append -NoTypeInformation
                                # Remove Permissions from Source and Target
                                $null = Remove-SiteCollectionAdministrator -CentralAdmin $using:sourceTenantSite -SiteUrl $sourceoneDriveUrl 
                                $null = Remove-SiteCollectionAdministrator -CentralAdmin $using:targetTenantSite -SiteUrl $targetoneDriveUrl'
                            )
                            Name        = $taskName
                        }
                        start-threadjob @jobParams | Select-Object id, Name
                        
                    }
                    $false {
                        $sourceUserEmail = $User.$SourceUserPrincipalNameHeader
                        $sourceTenantSite = $sourceTenant.site
                        $targetUserEmail = $User.$targetUserPrincipalNameHeader
                        $targetTenantSite = $targetTenant.site
                        $jobParams = @{
                            scriptblock = [scriptblock]::Create(
                                '# Setup Source User Site
                                $sourceoneDriveUrl = Get-OneDriveUrl -Tenant $using:sourceTenantSite -Email $using:sourceUserEmail
                                $null = Add-SiteCollectionAdministrator -CentralAdmin $using:sourceTenantSite -SiteUrl $sourceoneDriveUrl
                                $sourceOneDriveSite = Connect-Site -Url $sourceoneDriveUrl -UseCredentialsFrom $using:sourceTenant
                                $sourceOneDriveList = Get-List -Site $sourceOneDriveSite -Name "Documents"
                                # Setup Target User Site
                                $targetoneDriveUrl = Get-OneDriveUrl -Tenant $using:targetTenantSite -Email $using:targetUserEmail
                                $null = Add-SiteCollectionAdministrator -CentralAdmin $using:targetTenantSite -SiteUrl $targetoneDriveUrl
                                $targetOneDriveSite = Connect-Site -Url $targetoneDriveUrl -UseCredentialsFrom $using:targetTenant
                                $targetOneDriveList = Get-List -Site $targetOneDriveSite -Name "Documents"
                                $results = Copy-Content -SourceList $sourceOneDriveList -DestinationList $targetOneDriveList -TaskName $using:taskName
                                $results = $results | select-object @{ Name = "TaskName";  Expression = {$using:taskName}},*
                                $results | export-csv -Path $using:LogFilePath -Append -NoTypeInformation
                                # Remove Permissions from Source and Target
                                $null = Remove-SiteCollectionAdministrator -CentralAdmin $using:sourceTenantSite -SiteUrl $sourceoneDriveUrl 
                                $null = Remove-SiteCollectionAdministrator -CentralAdmin $using:targetTenantSite -SiteUrl $targetoneDriveUrl'
                            )
                            Name        = $taskName
                        }
                        start-threadjob @jobParams | Select-Object id, Name
                        
                    }
                }
            }
        }
    }
}