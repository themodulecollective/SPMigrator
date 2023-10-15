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

    Get-PnPListItem -Connection $PNPTarget -List $SPMConfiguration.BacklogList -Identity $Id | Select-Object -ExpandProperty FieldValues

}