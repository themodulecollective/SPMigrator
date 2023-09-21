function Copy-TeamRename {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)][psobject[]]
        $sourceTeams,
        [Parameter(Mandatory = $true)][psobject[]]
        $teamNames,
        [Parameter(Mandatory = $true)][int]
        $ConcurrentCopys,
        [Parameter(Mandatory = $false)][int]
        $currentCount
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
        $sessions = Find-CopySessions
        $runningSessions = $sessions.where({ $_.HasEnded -eq $False })
        while (($runningsessions.count -ge $ConcurrentCopys )) {
            $sessions = Find-CopySessions
            $runningSessions = $sessions.where({ $_.HasEnded -eq $False })
            Start-Sleep 60
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
                $getTeam'
            )
            Name        = $taskName
        }
        start-job @jobParams
        
    }
}

# copy-team -team $using:getTeam -TeamTitle $using:targetName -DestinationTenant $using:targetTenant -MappingSettings $using:mappingSettings -TaskName $using:taskName
function Copy-TeamRename {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)][psobject[]]
        $sourceTeams,
        [Parameter(Mandatory = $true)][psobject[]]
        $teamNames,
        [Parameter(Mandatory = $true)][int]
        $ConcurrentCopys,
        [Parameter(Mandatory = $false)][int]
        $currentCount
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
        $sessions = Find-CopySessions
        $runningSessions = $sessions.where({ $_.HasEnded -eq $False })
        while (($runningsessions.count -ge $ConcurrentCopys )) {
            $sessions = Find-CopySessions
            $runningSessions = $sessions.where({ $_.HasEnded -eq $False })
            Start-Sleep 60
        }
        [string]$currentCount = ++$count
        $newName = $teamNames.where({
                $copyTeam.name -eq $_.sourceName
            })
        $targetName = $newName.targetName
        $taskName = $currentCount + ". " + $targetName
        $getTeam = get-team -name $copyTeam.name -tenant $sourceTenant
        $jobParams = @{
            argumentList = @(
                $getTeam
                $targetName
                $targetTenant
                $mappingSettings
                $taskName
            )
            scriptblock  = {
                copy-team -team $args[0] -TeamTitle $args[1] -DestinationTenant $args[2] -MappingSettings $args[3] -TaskName $args[4]
            }
            Name         = $taskName
        }
        start-job @jobParams
        
    }
}

function Copy-TeamRename {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)][psobject[]]
        $sourceTeams,
        [Parameter(Mandatory = $true)][psobject[]]
        $teamNames,
        [Parameter(Mandatory = $true)][int]
        $ConcurrentCopys,
        [Parameter(Mandatory = $false)][int]
        $currentCount
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
        $sessions = Find-CopySessions
        $runningSessions = $sessions.where({ $_.HasEnded -eq $False })
        while (($runningsessions.count -ge $ConcurrentCopys )) {
            $sessions = Find-CopySessions
            $runningSessions = $sessions.where({ $_.HasEnded -eq $False })
            Start-Sleep 60
        }
        [string]$currentCount = ++$count
        $newName = $teamNames.where({
                $copyTeam.name -eq $_.sourceName
            })
        $targetName = $newName.targetName
        $taskName = $currentCount + ". " + $targetName
        $getTeam = get-team -name $copyTeam.name -tenant $sourceTenant
        copy-team -team $getTeam -TeamTitle $targetName -DestinationTenant $targetTenant -MappingSettings $mappingSettings -TaskName $taskName
        $taskName
    }
}