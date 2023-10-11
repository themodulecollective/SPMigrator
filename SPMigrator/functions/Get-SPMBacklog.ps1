function Get-SPMBacklog
{
    param(
        [parameter(Mandatory)]
        [PnP.PowerShell.Commands.Base.PnPConnection]$PNPConnection
    )
    Get-PNPListItem -List $SPMConfiguration.BacklogList -Connection $PNPConnection
}