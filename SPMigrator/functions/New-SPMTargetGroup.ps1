function New-SPMTargetGroup {
    
    param(
        [parameter(Mandatory)]
        [hashtable]$SourceRecord
        ,
        [parameter(Mandatory)]
        [validateSet('AzureAD')]
        [string]$method
    )

    switch ($method)
    {
        'AzureAD'
        {
            Write-Verbose -Message "Using AzureAD Module to provision target group: $($SourceRecord.SourceGroupMailNickName)"
            $NewAADMSGParams = @{
                Description     = $SourceRecord.SiteDescription
                DisplayName     = $SourceRecord.SourceGroupDisplayName
                MailEnabled     = $true
                MailNickname    = $SourceRecord.SourceGroupMailNickname
                GroupTypes      = 'Unified'
                Visibility      = $SourceRecord.SourceGroupVisibility
                SecurityEnabled = $true
            }
            New-AzureADMSGroup @NewAADMSGParams
        }
    }
}