function Copy-<XXXXXXXX>MultiThread {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)][psobject[]]
        $DATA,
        [Parameter(Mandatory = $false)][int]
        $currentCount,
        [Parameter(Mandatory = $False)][Int]
        $ValidationLimit,
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
    foreach ($i in $DATA) {
        # Create TaskName
        [string]$currentCount = ++$count
        switch ($PSBoundParameters.Keys -contains 'PreCheck') {
            $true {
                $taskName = $currentCount + ". " + "Pre-check on " + $<TASKVARIABLE>
            }
            $false {
                $taskName = $currentCount + ". " + $<TASKVARIABLE>
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
                Write-Information "Validation Limit Set. No Task Initiated" -InformationAction Continue
            }
            $false {
                $jobParams = @{
                    scriptblock = [scriptblock]::Create(
                        '$results | export-csv -Path $using:LogFilePath -Append -NoTypeInformation'
                    )
                    Name        = $taskName
                }
                start-threadjob @jobParams | Select-Object id, Name
            }
        }
    }
}