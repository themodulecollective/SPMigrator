function Copy-SGOneDriveIndividualIncremental {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)][String]
        $SourceUserPrincipalName,
        [Parameter(Mandatory = $True)][String]
        $TargetUserPrincipalName
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

    $taskName = "Ind " + $TargetUserPrincipalName
    # Setup Source User Site
    $sourceoneDriveUrl = Get-OneDriveUrl -Tenant $sourceTenant.site -Email $SourceUserPrincipalName
    $null = Add-SiteCollectionAdministrator -CentralAdmin $sourceTenant.Site -SiteUrl $sourceoneDriveUrl
    $sourceOneDriveSite = Connect-Site -Url $sourceoneDriveUrl -UseCredentialsFrom $sourceTenant
    $sourceOneDriveList = Get-List -Site $sourceOneDriveSite -Name "Documents"
    # Setup Target User Site
    $targetoneDriveUrl = Get-OneDriveUrl -Tenant $targetTenant.site -Email $targetUserPrincipalName
    $null = Add-SiteCollectionAdministrator -CentralAdmin $targetTenant.Site -SiteUrl $targetoneDriveUrl
    $targetOneDriveSite = Connect-Site -Url $targetoneDriveUrl -UseCredentialsFrom $targetTenant
    $targetOneDriveList = Get-List -Site $targetOneDriveSite -Name "Documents"
    # Copy Content from Source to Target
    $copysettings = New-CopySettings -OnContentItemExists IncrementalUpdate
    Copy-Content -SourceList $sourceOneDriveList -DestinationList $targetOneDriveList -TaskName $taskName -CopySettings $copysettings

    # Remove Permissions from Source and Target
    $null = Remove-SiteCollectionAdministrator -CentralAdmin $sourceTenant.Site -SiteUrl $sourceoneDriveUrl 
    $null = Remove-SiteCollectionAdministrator -CentralAdmin $targetTenant.Site -SiteUrl $targetoneDriveUrl
    # Print TaskName
    $taskName
}
