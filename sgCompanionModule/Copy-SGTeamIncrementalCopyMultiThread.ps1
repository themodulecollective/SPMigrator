function Copy-SGTeamIncrementalCopyMultiThread {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)][psobject[]]
        $ShareGateSessionData,
        [Parameter(Mandatory = $false)][int]
        $currentCount,
        [Parameter(Mandatory = $False)][Int]
        $ValidationLimit,
        [Parameter(Mandatory = $true)][int]
        $ConcurrentCopys,
        [Parameter(Mandatory = $False)][Switch]
        $ExcludeLoggedSessions,
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
            $ShareGateSessionData = $ShareGateSessionData[0..$limit]
        }
    }
    switch ($PSBoundParameters.Keys -contains 'ExcludeLoggedSessions') {
        $true {
            $log = import-csv -path $LogFilePath
            $ShareGateSessionData = $ShareGateSessionData.where({ $log.TaskName -notcontains $_.id })
        }
    }
    foreach ($Session in $ShareGateSessionData) {
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
                Write-Information "Validation Limit Set. No Task Initiated" -InformationAction Continue
            }
            $false {
                [string]$currentCount = ++$count
                $sessionID = $session.id
                $taskName = $currentCount + ". " + $sessionID
                $jobParams = @{
                    scriptblock = [scriptblock]::Create(
                        '$results = Copy-TeamIncremental -SessionId $using:sessionID -SourceTenant $using:sourceTenant -DestinationTenant $using:targetTenant
                        $results = $results | select-object @{Name = "TaskName"; Expression = { $using:TaskName } },*
                        $results | export-csv -Path $using:LogFilePath -Append -NoTypeInformation
                        $results'
                    )
                    Name        = $taskName
                }
                start-threadjob @jobParams | Select-Object id, Name
            }
        }
    }
}