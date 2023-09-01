#Requires -Version 5.1
###############################################################################################
# Module Variables
###############################################################################################
$ModuleVariableNames = ('SPMigratorConfiguration', 'SQLScripts')
$ModuleVariableNames.ForEach( { Set-Variable -Scope Script -Name $_ -Value $null })
# enum InstallManager { Chocolatey; Git; PowerShellGet; Manual; WinGet }

$SQLScripts = @{}

foreach ($s in $SQLFiles)
{
  $item = Get-Item -Path $s
  $key = $item.BaseName
  $SQLScripts.$key = $(Get-Content -Path $item.FullName -Raw)
}

###############################################################################################
# Module Removal
###############################################################################################
#Clean up objects that will exist in the Global Scope due to no fault of our own . . . like PSSessions

$OnRemoveScript = {
  # perform cleanup
  Write-Verbose -Message 'Removing Module Items from Global Scope'
  #Remove-WaveDataGlobalVariable
}

$ExecutionContext.SessionState.Module.OnRemove += $OnRemoveScript
