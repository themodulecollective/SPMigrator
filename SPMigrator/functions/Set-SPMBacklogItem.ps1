function Set-SPMBacklogItem
{
    param(
        [parameter(Mandatory)]
        [string]$Id
        ,
        [parameter()]
        [string]$LogMessage
        ,
        [parameter()]
        [ValidateSet(
            'Do Not Migrate',
            'Queued',
            'Scheduled',
            'PrepareSource',
            'ProvisionTarget',
            'InitialDataMigration',
            'QualityAssurance',
            'DeltaDataMigration',
            'UserAcceptanceTesting',
            'Complete'
        )]
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
        ,
        [switch]$NoOutput
    )

    [hashtable]$Values = $PSBoundParameters
    $null = $Values.remove('Id')
    if ($Values.ContainsKey('LogMessage'))
    {
        $null = $values.remove('LogMessage')
        $values.add('MigrationStatusLog',$LogMessage)
    }
    
    $result = Set-PnPListItem -Connection $PNPTarget -List $SPMConfiguration.BacklogList -Identity $Id -Values $Values | Select-Object -ExpandProperty FieldValues

    switch ($NoOutput)
    {
        $true
        {}
        $false
        {$result}
    }

}