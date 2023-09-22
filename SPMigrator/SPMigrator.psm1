#Requires -Version 5.1

$ModuleFolder = Split-Path $PSCommandPath -Parent

$Scripts = Join-Path -Path $ModuleFolder -ChildPath 'scripts'
$Functions = Join-Path -Path $ModuleFolder -ChildPath 'functions'
$SQLFolder = Join-Path -Path $ModuleFolder -ChildPath 'sql'

#Write-Information -MessageData "Scripts Path  = $Scripts" -InformationAction Continue
#Write-Information -MessageData "Functions Path  = $Functions" -InformationAction Continue
#Write-Information -MessageData "SQL Folder  = $SQLFolder" -InformationAction Continue

$Script:SQLFiles = @(
  #$(Join-Path -Path $(Join-Path -Path $SQLFolder -ChildPath 'reports') -ChildPath 'MigrationList.sql')
  #$(Join-Path -Path $(Join-Path -Path $SQLFolder -ChildPath 'reports') -ChildPath 'MigrationWaveList.sql')
  #$(Join-Path -Path $(Join-Path -Path $SQLFolder -ChildPath 'reports') -ChildPath 'SiteList.sql')
)

$Script:ModuleFiles = @(
  $(Join-Path -Path $Scripts -ChildPath 'Initialize.ps1')
  # Load Functions
  $(Join-Path -Path $functions -ChildPath Add-SiteCollectionAdmin.ps1)
  $(Join-Path -Path $functions -ChildPath Remove-SiteCollectionAdmin.ps1)
  $(Join-Path -Path $functions -ChildPath Export-ADUser.ps1)
  $(Join-Path -Path $functions -ChildPath Export-AzureADUser.ps1)
  $(Join-Path -Path $functions -ChildPath Export-AzureADGroup.ps1)
  $(Join-Path -Path $functions -ChildPath Export-UnifiedGroupDrive.ps1)
  $(Join-Path -Path $functions -ChildPath Export-UnifiedGroupOwner.ps1)
  $(Join-Path -Path $functions -ChildPath Export-UnifiedGroupMember.ps1)
  $(Join-Path -Path $functions -ChildPath Export-EntraIDGroupMember.ps1)
  $(Join-Path -Path $functions -ChildPath Export-AzureADLicensing.ps1)
  $(Join-Path -Path $functions -ChildPath Export-AzureADUserLicensing.ps1)
  $(Join-Path -Path $functions -ChildPath Export-ComplianceRetentionPolicy.ps1)
  $(Join-Path -Path $functions -ChildPath Export-SPOSite.ps1)
  $(Join-Path -Path $functions -ChildPath Export-SPOExternalUser.ps1)
  #$(Join-Path -Path $functions -ChildPath Get-SPMMigrationList.ps1)
  $(Join-Path -Path $functions -ChildPath New-SplitArrayRange.ps1)
  $(Join-Path -Path $functions -ChildPath New-Timer.ps1)
  $(Join-Path -Path $functions -ChildPath Group-Join.ps1)
  $(Join-Path -Path $functions -ChildPath Get-SortableSizeValue.ps1)
  $(Join-Path -Path $functions -ChildPath Get-SPMConfiguration.ps1)
  $(Join-Path -Path $functions -ChildPath Set-SPMConfiguration.ps1)
  $(Join-Path -Path $functions -ChildPath Export-SPMReport.ps1)
  # Finalize / Run any Module Functions defined above
  $(Join-Path -Path $Scripts -ChildPath 'RunFunctions.ps1')
)
foreach ($f in $ModuleFiles)
{
  . $f
}