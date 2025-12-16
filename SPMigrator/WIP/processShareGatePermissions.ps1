$Properties = @(
    'Type', 'SiteName', 'SiteURL', 'Inheritance', 'Detail', 'IdentityDisplayName', 'PrincipalType', 'PermissionSource',
    @{n='IdentityName'; e={$_.IdentityName.split('|')[-1]}},
    @{n='Permissions'; e={Get-ConcatenatedPermissions -FromRecord $_}}
)

function Get-ConcatenatedPermissions
{
    [cmdletbinding()]
    param(
        [pscustomobject]$FromRecord
        ,
        [string[]]$Attributes = @()
        ,
        [string]$Delimiter = '|'
    )

    $Permissions = [System.Collections.Generic.List[string]]::new()

    switch ($Attributes)
    {
        $_
        {
            $Permission = $_
            if ($FromRecord.$Permission -eq 'x')
            {
                $Permissions.add($Permission)
            }
        }
    }

    [string]$ConcatenatedPermissions = $Permissions -join $Delimiter

    $ConcatenatedPermissions

}
