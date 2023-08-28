Function Update-SPMSPOMigrationList
{
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        $SiteID
        ,
        [parameter(Mandatory)]
        $ListID

    )

    # get sharepoint list columns
    $SPOListColumns = Get-MgSiteListColumn -SiteId $SiteID -ListId $ListID |
    Select-Object DisplayName, Name |
    Where-Object {$_.Name -match $('\bID\b|\bTitle\b|\bField_\d')}

    # get migration list from Database
    $SPMMigrationList = Get-SPMMigrationList

    # get current sharepoint list items
    $SPOListItems = Get-OGSiteListItem -SiteID $SiteID -ListID $ListID

    # Prepare to Update the SPO list
    # SharePoitn List Columns Hashtable
    $ColHash = @{}
    $SPOListColumns.foreach({$ColHash.$($_.DisplayName) = $($_.Name)})

    # Exchange GUID Field
    $EGF = $ColHash.ExchangeGUID

    # SharePoint List Items Hashtable
    $SIHash = @{}
    $SPOListItems.foreach({$SIHash.$($_.$EGF) = $($_)})

    # SPM Migration List Items Hashtable
    $MLIHash = @{}
    $SPMMigrationList.foreach({$MLIHash.$($_.ExchangeGUID)=$($_)})

    # If item already exists in SI Hash, update, if not, add.
    # Later we'll look for orphaned items to delete

    $Updates = [System.Collections.Generic.List[PSObject]]::new()
    $Adds = [System.Collections.Generic.List[PSObject]]::new()
    #$Deletes = [System.Collections.Generic.List[PSObject]]::new()

    $SPMMigrationList.foreach({
            $item = $_
            switch ($SIHash.containskey($item.ExchangeGUID))
            {
                $true
                {
                    $Updates.add($item)
                }
                $false
                {
                    $Adds.add($item)
                }
            }
        })

    # SharePoint List items where the ExchangeGUID is no longer in the Migration List
    $Deletes = @($SPOListItems.where({-not $MLIHash.containskey($_.$($EGF))}).id)


    # Perform the Deletes
    $Deletes.foreach({
            Remove-MgSiteListItem -SiteId $SiteID -ListId $ListID -ListItemId $_
        })

    # Perform the Adds

    # Perform the Updates

}
