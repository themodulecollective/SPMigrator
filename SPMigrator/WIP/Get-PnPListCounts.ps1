#get library/list counts from Centura sites, export to CSV and upload to Migration Site, run before migrations

param(
	[string]$wavefilename = $(throw "-wavefilename is required")

	[Int]$wavenum = $(throw "-wavenum is required")
	,
	[string]$migrationSite #full URL to migration site (e.g. https://tenant.sharepoint.com/sites/migrationsite)
	,
	[string]$reportsLib #name of migration reports library (e.g. Migration Reports/SourceItemCounts)
	,
	[string]$backlogList #name of migration backlog list (e.g. Migration Backlog)
)
$csvfile = "C:\SPMigration\CSVFiles\$($wavefilename)"
#Config Variables

#$migSiteConn = Connect-PnPOnline -Url $migrationSite -Interactive -ReturnConnection #add connection method

$sites = Import-Csv $csvfile
foreach($row in $sites){

	Try {
		#Connect to PnP Online
		write-host "connection to $($row.SrcUrl)"
		$conn = Connect-PnPOnline -Url $row.SrcUrl -UseWebLogin -ReturnConnection

		#Get All Webs from the site collection
		#$SubWebs = Get-PnPSubWeb -Recurse -IncludeRootWeb
		$ListInventory= @()
		#Foreach ($Web in $SubWebs)
		#{
			Write-host -f Yellow "Getting List Item count from site:" $conn.URL
			#Connect to Subweb
			#$webConn = Connect-PnPOnline -Url $Web.URL -Interactive -ReturnConnection
			$web = Get-PnPWeb -Connection $conn
			$CSVFile = "C:\SPMigration\MigrationReports\$($web.Title)_ListItemCount.csv"
			#Get all lists and libraries of the Web
			$ExcludedLists  = @("Reusable Content","Content and Structure Reports","Form Templates","Workflow History","Workflow Tasks", "Preservation Hold Library")
			#$Lists= Get-PnPList | Where {$_.Hidden -eq $False -and $ExcludedLists -notcontains $_.Title}
			$Lists= Get-PnPList -Connection $conn | Where {$_.Hidden -eq $False}
			foreach ($List in $Lists)
			{
				$Data = new-object PSObject
				$Data | Add-member NoteProperty -Name "Site Name" -Value $web.Title
				$Data | Add-member NoteProperty -Name "Site URL" -Value $conn.Url
				$Data | Add-member NoteProperty -Name "List Title" -Value $List.Title
				$Data | Add-member NoteProperty -Name "List URL" -Value $List.RootFolder.ServerRelativeUrl
				$Data | Add-member NoteProperty -Name "List Item Count" -Value $List.ItemCount
				$ListInventory += $Data
			}

			#Disconnect-PnPOnline -Connection $webConn
		#}
		Disconnect-PnPOnline -Connection $conn
		$ListInventory | Export-CSV $CSVFile -NoTypeInformation
		Write-host -f Green "List Inventory Exported to Excel Successfully!"
		<#if(!$migSiteConn){
			$migSiteConn = Connect-PnPOnline -Url $migrationSite -ReturnConnection -Interactive			#add connection method
		}
		Add-PnPFile -Path $CSVFile -Folder $reportsLib -Connection $migSiteConn -Values @{MigrationWave=$wavenum}
		#$migrationItem = Get-PnPListItem -List $backlogList -Query $listQuery -Connection $migSiteConn
		#Set-PnPListItem -List $backlogList -Identity $migrationItem -Values @{"MigrationStatus" = "QA"} -Connection $migSiteConn
		#>
	}
	Catch {
		write-host "Error: $($_.Exception.Message)" -foregroundcolor Red
	}
}
if($migSiteConn){
	Disconnect-PnPOnline -Connection $migSiteConn
}