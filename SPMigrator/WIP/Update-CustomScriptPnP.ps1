param(
	[string[]]$URL
	,
	$SharePointAdminSite

)

$connection = Connect-PnPOnline -Url $SharePointAdminSite -Interactive -ReturnConnection

Foreach ($row in $URL)
{
	$siteUrl = $row.SiteUrl

	#change switch to $true to disable custom script
	Set-PnPTenantSite -Identity $siteUrl -DenyAddAndCustomizePages:$false
	Write-Host "Updated $($siteUrl)"
}
Disconnect-PnPOnline