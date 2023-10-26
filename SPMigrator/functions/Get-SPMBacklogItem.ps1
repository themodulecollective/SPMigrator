function Get-SPMBacklogItem
{
    param(
        [parameter(Mandatory)]
        [string]$Id
        <#
        [string]$MigrationStatus
        ,
        [parameter()]
        [string]$MigrationHost
        ,
        [parameter()]
        [string]$TargetSiteURL
        ,
        [parameter()]
        [string]$TargetGroupMailNickname
        ,
        [parameter()]
        [string]$TargetGroupMail
        ,
        [parameter()]
        [string]$TargetGroupID
#>
    )

    $Item = Get-PnPListItem -Connection $PNPTarget -List $SPMConfiguration.BacklogList -Id $Id |
    Select-Object -ExpandProperty FieldValues

    New-Object -TypeName psobject -Property $Item
}