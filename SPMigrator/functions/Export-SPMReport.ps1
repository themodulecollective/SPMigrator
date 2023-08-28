function Export-SPMReport
{
    <#
    .SYNOPSIS
        Exports data from SPM Migration Database to Microsoft Excel Report File
    .DESCRIPTION
        Exports data from SPM Migration Database to a basic or compound excel spreadsheet depending on the specified report. Common uses include identifying double mailboxes and delegate reporting.
    .EXAMPLE
        Export-SPMReport -Report MigrationList -OutputFolderPath "C:\Users\UserName\Documents"
        The example exports the current Migration List to the specified folder
    #>

    [cmdletbinding(DefaultParameterSetName = 'basicReport')]
    param(
        #
        [parameter(Mandatory, ParameterSetName = 'basicReport')]
        [ValidateSet(
            'MigrationList'
        )]
        [string[]]$Report
        ,
        #
        [parameter(Mandatory, ParameterSetName = 'compoundReport')]
        [ValidateSet(
            'MigrationList',
            'MigrationWaveList'
        )]
        [string[]]$compoundReport
        ,
        #
        [parameter()]
        [hashtable]$ReportParams
        ,
        #
        [parameter(ParameterSetName = 'compoundReport', Mandatory)]
        [parameter(ParameterSetName = 'basicReport')]
        [validatescript({ Test-Path -Path $_ -PathType Container })]
        [string]$OutputFolderPath
    )

    $Configuration = Get-SPMConfiguration

    $dbParams = @{
        SQLInstance = $Configuration.SQLInstance
        Database    = $Configuration.Database
    }

    $ReportMeta = @{
        PermissionCountByTrustee = @{
            reportType     = 'basic'
            requiredParams = @('permissionType')
        }
        <#         MigrationList            = @{
            reportType      = 'compound'
            requiredParams  = @()
            includedReports = @{
                'MigrationList'        = @{
                    Sheet      = 'List'
                    Table      = 'List'
                    TableStyle = 'Medium21'
                }
                'MigrationListChanges' = @{
                    Sheet      = 'Changes'
                    Table      = 'Changes'
                    TableStyle = 'Medium19'

                }
                'MigrationListSummary' = @{
                    Sheet      = 'Summary'
                    Table      = 'Summary'
                    TableStyle = 'Dark2'
                }
            }
        } #>
        MigrationList            = @{
            reportType     = 'basic'
            requiredParams = @()
        }
        MigrationWaveList        = @{
            reportType     = 'basic'
            requiredParams = @('AssignedWave')
        }
    }

    switch ($PSCmdlet.ParameterSetName)
    {
        'basicReport'
        {

            foreach ($r in $Report)
            {

                Write-Information -Message "Running Report $r"
                # set up query params
                $idbqParams = @{
                    query = $SQLScripts.$r
                    AS    = 'PSObjectArray'
                }
                $SQLParameter = @{}
                switch ($ReportMeta.$r.requiredParams)
                {
                    { $null -eq $_ }
                    { break }
                    { $null -ne $ReportParams -and $ReportParams.ContainsKey($_) }
                    {
                        $SQLParameter.$_ = $ReportParams.$_
                        $idbqParams.SQLParameter = $SQLParameter
                    }
                    { $null -eq $ReportParams -or -not $ReportParams.ContainsKey($_) }
                    {
                        throw("Required Report Parameter $_ was not provided using -ReportParams parameter")
                    }
                }
                # run the query
                Write-Information -Message "Running report query: $($idbqParams.query)"
                $Results = Invoke-DbaQuery @dbparams @idbqParams
                Write-Information -Message "Report contains $($Results.count) records"


                # export the results
                switch ([string]::IsNullOrWhiteSpace($OutputFolderPath))
                {
                    $true
                    {
                        $Results
                    }
                    $false
                    {
                        # set up export params
                        $DateString = Get-Date -Format yyyyMMddHHmmss
                        $filename = $DateString + '_' + $r + '.xlsx'
                        $filepath = Join-Path -Path $OutputFolderPath -ChildPath $filename
                        $eParams = @{
                            Path          = $filepath
                            FreezeTopRow  = $true
                            TableStyle    = 'Medium21'
                            TableName     = $r
                            WorksheetName = $r
                            AutoSize      = $true
                        }
                        Export-Excel @eParams -InputObject $Results
                        Write-Information -Message "Report $r exported to $FilePath"
                    }
                }
            }
        }
        'compoundReport'
        {
            $DateString = Get-Date -Format yyyyMMddHHmmss
            foreach ($r in $compoundReport)
            {
                $filename = $DateString + '_' + $r + '.xlsx'
                $filepath = Join-Path -Path $OutputFolderPath -ChildPath $filename

                foreach ($ir in $ReportMeta.$r.includedReports.getenumerator())
                {
                    # set up query params
                    $idbqParams = @{
                        query = $SQLScripts.$($ir.name)
                        AS    = 'PSObjectArray'
                    }
                    # run the query
                    Write-Information -Message "Running report query: $($idbqParams.query)"
                    $Results = Invoke-DbaQuery @dbparams @idbqParams
                    Write-Information -Message "Report $($ir.name) contains $($Results.count) records"

                    $eParams = @{
                        Path          = $filepath
                        FreezeTopRow  = $true
                        TableStyle    = $ir.value.TableStyle
                        TableName     = $ir.value.Table
                        WorksheetName = $ir.value.Sheet
                        AutoSize      = $true
                    }
                    # export the results
                    Export-Excel @eParams -InputObject $Results
                    Write-Information -Message "Report $r exported to $FilePath"
                }
            }

        }
    }

}
