Connect-AzureAD -Credential $SPMConfiguration.TargetSACredential
$PNPTarget = Connect-PnPOnline -ReturnConnection -Url $SPMConfiguration.MigrationTrackingSite -Credentials $SPMConfiguration.TargetSACredential
$PNPSource = Connect-PnPOnline -ReturnConnection -Url $SPMConfiguration.SourceSharePointAdminSite -Credentials $SPMConfiguration.SourceSACredential
$SGTarget = Connect-Site -Url $SPMConfiguration.MigrationTrackingSite -DisableSSO -Browser
$SGSource = Connect-Site -Url $SPMConfiguration.DefaultSourceSite -DisableSSO -Browser
