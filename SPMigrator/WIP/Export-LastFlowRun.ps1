function Export-LastFlowRun
{
    [cmdletbinding()]
    param(
        $Flows
        ,
        $OutputFolderPath
    )
}

Add-PowerAppsAccount

$FlowResults = @()

foreach($flow in $flows)
{
    $flowName = $flow.FlowId
    $f = Get-AdminFlow -FlowName $flowName
    Get-FlowRun -FlowName $f.FlowName | Select-Object -First 1 -Property DisplayName, FlowName, StartTime, Status
}
$FlowResults | Export-Excel