function Get-SPMBacklog
{
    param(
        [parameter(Mandatory)]
        [PnP.PowerShell.Commands.Base.PnPConnection]$PNPConnection
    )
    $BacklogDictionaries = @(Get-PnPListItem -List $SPMConfiguration.BacklogList -Connection $PNPConnection |
        Select-Object -ExpandProperty FieldValues)

    $BacklogDictionaries.foreach({New-Object -TypeName psobject -Property $_})

}