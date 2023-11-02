function Get-EntraIDGroupMember
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipelineByPropertyName)]
        [string]$GroupID
        ,
        [switch]$Recurse
    )

    $members = @(Get-AzureADGroupMember -ObjectId $GroupID -All $true)

    $results = @(
        foreach ($m in $members)
        {

            switch ($m.ObjectType)
            {
                'User'
                {$m}
                'Group'
                {
                    if ($Recurse)
                    {Get-EntraIDGroupMember -GroupID $m.ObjectId}
                    else
                    {$m}
                }
                Default
                {$m}
            }
        }
    )

    # Get Unique Results
    $results | Sort-Object -Unique | Select-Object -Unique
}