function Set-SPMConfiguration
{
    <#
    .SYNOPSIS
        Configure the SPM configuration using key value pairs
    .DESCRIPTION
        Configure the SPM configuration using key value pairs
    .EXAMPLE
        Set-SPMConfiguration -Attribute Key -Value Value
        Adds Key: Value to the SPM Configuration file
    #>

    param(
        #
        [string]$Attribute
        ,
        #
        [psobject]$Value
    )

    switch (Test-Path -Path variable:script:SPMConfiguration)
    {
        $true
        {
            $Script:SPMConfiguration.$Attribute = $Value
        }
        $false
        {
            $Script:SPMConfiguration = @{}
            $Script:SPMConfiguration.$Attribute = $Value
        }
    }
}