function Test-MultiThread {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)][psobject[]]
        $sourceTeams,
        [Parameter(Mandatory = $true)][psobject[]]
        $teamNames,
        [Parameter(Mandatory = $true)][int]
        $ConcurrentCopys,
        [Parameter(Mandatory = $false)][int]
        $currentCount,
        [Parameter(Mandatory = $True)][String]
        $LogFilePath
    )
    switch ($currentCount -gt 0) {
        $true {
            [int]$count = $currentCount - 1
        }
        $false {
            [int]$count = 0
        }
    }
    foreach ($copyTeam in $sourceTeams) {
        $Jobs = Get-Job
        $runningJobs = $Jobs.where({ ($_.State -eq 'Running') -or ($_.State -eq 'NotStarted') })
        while ($runningJobs.count -ge $ConcurrentCopys ) {
            $Jobs = Get-Job
            $runningJobs = $Jobs.where({ ($_.State -eq 'Running') -or ($_.State -eq 'NotStarted') })
        }
        [string]$currentCount = ++$count
        $newName = $teamNames.where({
                $copyTeam.name -eq $_.sourceName
            })
        $targetName = $newName.targetName
        $taskName = $currentCount + ". " + $targetName
        $copyTeamName = $copyTeam.name
        $jobParams = @{
            scriptblock = [scriptblock]::Create(
                '$getTeam = get-team -name $using:copyTeamName -tenant $using:sourceTenant
                start-sleep 20
                $getteam | export-csv -Path $using:LogFilePath -Append -NoTypeInformation
                '
            )
            Name        = $taskName
        }
        start-threadjob @jobParams | Select-Object id, Name
    }
}