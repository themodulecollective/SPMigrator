function Copy-SGOneDriveContentSingleThread {
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
        $PreCheck
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
        # Setup Source User Site
        $sourceoneDriveUrl = Get-OneDriveUrl -Tenant $sourceTenant.site -Email $User.$SourceUserPrincipalNameHeader
        $null = Add-SiteCollectionAdministrator -CentralAdmin $sourceTenant.Site -SiteUrl $sourceoneDriveUrl
        $sourceOneDriveSite = Connect-Site -Url $sourceoneDriveUrl -UseCredentialsFrom $sourceTenant
        $sourceOneDriveList = Get-List -Site $sourceOneDriveSite -Name "Documents"
        # Setup Target User Site
        $targetoneDriveUrl = Get-OneDriveUrl -Tenant $targetTenant.site -Email $User.$targetUserPrincipalNameHeader
        $null = Add-SiteCollectionAdministrator -CentralAdmin $targetTenant.Site -SiteUrl $targetoneDriveUrl
        $targetOneDriveSite = Connect-Site -Url $targetoneDriveUrl -UseCredentialsFrom $targetTenant
        $targetOneDriveList = Get-List -Site $targetOneDriveSite -Name "Documents"
        # Copy Content from Source to Target
        switch ($PSBoundParameters.Keys -contains 'ValidationLimit') {
            $true {
                Write-Information "Validation Limit Set. No Copy or PreCheck initiated" -InformationAction Continue
            }
            $false {
                switch ($PSBoundParameters.Keys -contains 'PreCheck') {
                    $true {
                        Copy-Content -SourceList $sourceOneDriveList -DestinationList $targetOneDriveList -TaskName $taskName -whatif
                    }
                    $false {
                        Copy-Content -SourceList $sourceOneDriveList -DestinationList $targetOneDriveList -TaskName $taskName
                    }
                }
            }
        }
        # Remove Permissions from Source and Target
        $null = Remove-SiteCollectionAdministrator -CentralAdmin $sourceTenant.Site -SiteUrl $sourceoneDriveUrl 
        $null = Remove-SiteCollectionAdministrator -CentralAdmin $targetTenant.Site -SiteUrl $targetoneDriveUrl
        # Print TaskName
        $taskName
    }
}