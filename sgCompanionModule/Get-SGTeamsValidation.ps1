function Get-SGTeamValidation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        $ImportPath,
        [Parameter(Mandatory = $True)]
        $DisplayNameHeaderValueSource,
        [Parameter(Mandatory = $True)]
        $DisplayNameHeaderValueTarget,
        [Parameter(Mandatory = $False)][switch]
        $ValidateSource,
        [Parameter(Mandatory = $False)][switch]
        $ValidateTarget,
        [Parameter(Mandatory = $False)][Int]$ValidationLimit
    )
    switch ($PSBoundParameters.Keys -contains 'ValidateSource') {
        $true {
            if ($sourceTenant) {
            }
            else {
                Write-Information "No source tenant found. Please run Connect-BothTenant before using this function" -InformationAction Continue
                exit
            }
        }
    }
    switch ($PSBoundParameters.Keys -contains 'ValidateSource') {
        $true {
            if ($targetTenant) {
            }
            else {
                Write-Information "No target tenant found. Please run Connect-BothTenant before using this function" -InformationAction Continue
                exit
            }
        }
    }
    
    $importData = import-csv -Path $ImportPath
    switch ($PSBoundParameters.Keys -contains 'ValidationLimit') {
        $true {
            $limit = $ValidationLimit - 1
            $importData = $importData[0..$limit]
        }
    }
    switch ($PSBoundParameters.Keys -contains 'ValidateSource') {
        $true {
            $script:missingSourceTeams = New-Object System.Collections.Generic.List[psobject]
            $script:sourceTeams = @(foreach ($team in $importData) {
                    try {
                        get-team -tenant $sourceTenant -Name $team.$DisplayNameHeaderValueSource
                    }
                    catch {
                        $script:missingSourceTeams.add($team)
                    }
                })
        }
    }
    switch ($PSBoundParameters.Keys -contains 'ValidateSource') {
        $true {
            $script:missingTargetTeams = New-Object System.Collections.Generic.List[psobject]
            $script:targetTeams = @(foreach ($team in $importData) {
                    try {
                        get-team -tenant $TargetTenant -Name $team.$DisplayNameHeaderValueTarget
                    }
                    catch {
                        $script:missingTargetTeams.add($team)
                    }
                })
        }
    }
    $resultsObject = [pscustomobject]@{
        sourceTeams        = $sourceTeams.count
        missingSourceTeams = $missingSourceTeams.count
        targetTeams        = $targetTeams.count
        missingTargetTeams = $missingTargetTeams.count
    }
    Write-Information 'The outputs are stored in the varibles listed in the results below. Example: $sourceTeams contains all existing teams found in the source.' -InformationAction Continue
    $resultsObject | Format-List
}