function Connect-SGBothTenant {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)][string]
        $SourceDomain,
        [Parameter(Mandatory = $True)][string]
        $TargetDomain
    )
    Write-Information "connecting source tenant" -InformationAction Continue
    $Global:sourceTenant = connect-tenant -domain $SourceDomain -browser
    $sourceTenant
    Write-Information "connecting target tenant" -InformationAction Continue
    $Global:TargetTenant = connect-tenant -domain $TargetDomain -browser
    $TargetTenant
}