#requires -Version 7.0


function Assert-GraphConnection {
    <#
    .SYNOPSIS
        Throws a terminating error, attributed to the calling command, when no Microsoft Graph session exists.
    .EXAMPLE
        Assert-GraphConnection -Caller $PSCmdlet

        Called from a public function's begin block; the error names that public function, not this helper.
    #>
    [CmdletBinding()]
    param(
        # The calling advanced function's $PSCmdlet, so the error is attributed to the command the user ran.
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$Caller
    )

    if ($null -eq (Get-MgContext)) {
        $Caller.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new(
                    'Not connected to Microsoft Graph. Run Connect-MgGraph with the scopes listed in this ' +
                    "command's help first."
                ),
                'GraphNotConnected',
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $null
            )
        )
    }
}


function Get-PersonalSite {
    <#
    .SYNOPSIS
        Lists every OneDrive (personal) site in the tenant, across all geographies.
    .DESCRIPTION
        getAllSites has no documented server-side filter, so every site is read and personal sites are kept
        here. Get-MgAllSite cannot follow paging (it has no -All), so pages are followed by hand.
    .EXAMPLE
        Get-PersonalSite

        Returns one hashtable per personal site, with id and webUrl keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $uri = 'https://graph.microsoft.com/v1.0/sites/getAllSites'
    do {
        $page = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        foreach ($site in $page.value) {
            if ($site.isPersonalSite) {
                $site
            }
        }
        $uri = $page.'@odata.nextLink'
    } while ($uri)
}


function Write-UsageProgress {
    <#
    .SYNOPSIS
        Writes throttled progress for Get-OneDriveUsage, with a percentage only when the total is known.
    .EXAMPLE
        Write-UsageProgress -Processed 26 -Total 500 -CurrentOperation 'jdoe@contoso.com'

        Shows "26 of 500" at 5 percent.
    #>
    [CmdletBinding()]
    param(
        # How many items have been processed so far, including the current one.
        [Parameter(Mandatory)]
        [int]$Processed,

        # Total number of items, or 0 when it is not known (piped input).
        [Parameter(Mandatory)]
        [int]$Total,

        # The item being processed.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$CurrentOperation
    )

    # Progress rendering is slow enough to dominate a fast loop, so only every 25th item updates it.
    if ($Processed % 25 -eq 1) {
        $progressParameters = @{
            Activity         = 'Getting OneDrive usage'
            CurrentOperation = $CurrentOperation
            Status           = "$Processed processed"
        }
        if ($Total -gt 0) {
            $progressParameters.Status = "$Processed of $Total"
            $progressParameters.PercentComplete = 100 * $Processed / $Total
        }
        Write-Progress @progressParameters
    }
}


function Get-OneDriveUsage {
    <#
    .SYNOPSIS
        Reports OneDrive URL, storage use, quota state, and last-modified date for chosen users or the whole
        tenant.
    .DESCRIPTION
        For specific users (-UserPrincipalName, or piped input), looks up each user's default drive. The drive
        is found from the user, not by building a URL from the UPN, so it is correct even when the UPN changed
        after the OneDrive was created or SharePoint added a suffix to keep the URL unique. Every input user
        produces exactly one output row, so results always line up with an input CSV. A user whose OneDrive
        has never been provisioned gets an error row (Graph returns ResourceNotFound).

        With -All, reports every OneDrive in the tenant, including OneDrives whose owner has been deleted.
        UserPrincipalName is looked up from the drive owner's id; it is empty when the owner is no longer a
        user in the directory, which makes orphaned OneDrives easy to filter for.

        When a lookup fails, that row has Status 'Error' and the reason in ErrorMessage, and a non-terminating
        error is also written; use -ErrorAction SilentlyContinue to keep only the rows.

        Storage values are in bytes. QuotaState is Graph's normal, nearing, critical, or exceeded.

        Requires an existing app-only Connect-MgGraph session (a delegated admin can only read drives they
        have been given access to). Application permissions: Files.Read.All or Sites.Read.All for specific
        users; Sites.Read.All and User.Read.All for -All.
    .INPUTS
        System.String. User principal names, or objects with a UserPrincipalName property.
    .OUTPUTS
        OneDriveReport.UserDrive
    .EXAMPLE
        Connect-MgGraph -TenantId 'contoso.onmicrosoft.com' -ClientId $clientId -CertificateThumbprint $thumbprint
        Get-OneDriveUsage -All | Export-Csv -Path 'D:\Reports\OneDriveUsage.csv'

        Reports on every OneDrive in the tenant.
    .EXAMPLE
        Import-Csv -Path 'D:\Reports\Users.csv' |
            Get-OneDriveUsage |
            Export-Csv -Path 'D:\Reports\OneDriveUsage.csv'

        Reports on every user in a CSV that has a UserPrincipalName column.
    .EXAMPLE
        Get-OneDriveUsage -All -ErrorAction SilentlyContinue |
            Where-Object -FilterScript { $_.Status -eq 'OK' -and -not $_.UserPrincipalName }

        Lists orphaned OneDrives: drives whose owner is no longer a user in the directory.
    .EXAMPLE
        Get-MgUser -Filter "department eq 'Finance'" -All |
            Get-OneDriveUsage -ErrorAction SilentlyContinue |
            Where-Object -Property LastModifiedDateTime -LT -Value (Get-Date).AddDays(-180)

        Finds Finance users whose OneDrive has not changed in six months.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByUser')]
    [OutputType('OneDriveReport.UserDrive')]
    param(
        # The users to report on. Accepts UPNs or user object ids, from the pipeline or by property name.
        [Parameter(Mandatory, ParameterSetName = 'ByUser', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UPN')]
        [ValidateNotNullOrEmpty()]
        [string[]]$UserPrincipalName,

        # Report on every OneDrive in the tenant instead of specific users.
        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All
    )

    begin {
        Assert-GraphConnection -Caller $PSCmdlet

        <#
        Reading other users' OneDrives needs application permissions. getAllSites rejects delegated sessions
        outright (403), so fail -All before any Graph call; by-user lookups can still work delegated for
        drives the signed-in admin has been granted access to, so only warn.
        #>
        if ((Get-MgContext).AuthType -ne 'AppOnly') {
            $appOnlyHint = 'Connect with Connect-MgGraph -TenantId <tenant> -ClientId <app id> ' +
                '-CertificateThumbprint <thumbprint>, using an app registration with the Sites.Read.All and ' +
                'User.Read.All application permissions.'
            if ($All) {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        [System.InvalidOperationException]::new(
                            "-All needs an app-only Microsoft Graph connection; Graph's getAllSites API does " +
                            "not support delegated sign-in. $appOnlyHint"
                        ),
                        'AppOnlyConnectionRequired',
                        [System.Management.Automation.ErrorCategory]::PermissionDenied,
                        $null
                    )
                )
            }
            Write-Warning -Message (
                'Delegated Microsoft Graph session: only OneDrives you have been granted access to can be ' +
                "read, so most lookups will fail. $appOnlyHint"
            )
        }

        # Only an array passed directly has a known size; piped input arrives one item at a time.
        $totalCount = if ($PSCmdlet.MyInvocation.ExpectingInput) {
            0
        }
        else {
            @($UserPrincipalName).Count
        }
        $processedCount = 0
        $failedCount = 0
    }

    process {
        <#
        Each work item is one drive to look up, by user or by site, plus what is already known about it, so
        both modes share one lookup-and-emit loop.
        #>
        $workItems = switch ($PSCmdlet.ParameterSetName) {
            'ByUser' {
                foreach ($user in $UserPrincipalName) {
                    @{
                        Target            = $user
                        UserPrincipalName = $user
                        SiteId            = $null
                        WebUrl            = $null
                    }
                }
            }
            'All' {
                try {
                    $sites = @(Get-PersonalSite)
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($PSItem)
                }
                Write-Verbose -Message "Found [$($sites.Count)] OneDrive sites"
                $totalCount = $sites.Count

                # One bulk read indexed by id, rather than one user lookup per drive.
                $upnById = @{}
                try {
                    $directoryUsers = Get-MgUser -All -Property 'id', 'userPrincipalName' -ErrorAction Stop
                    foreach ($directoryUser in $directoryUsers) {
                        $upnById[$directoryUser.Id] = $directoryUser.UserPrincipalName
                    }
                }
                catch {
                    Write-Warning -Message (
                        "Could not read users, so UserPrincipalName will be empty: $($PSItem.Exception.Message)"
                    )
                }

                foreach ($site in $sites) {
                    @{
                        Target            = $site.webUrl
                        UserPrincipalName = $null
                        SiteId            = $site.id
                        WebUrl            = $site.webUrl
                    }
                }
            }
        }

        foreach ($workItem in $workItems) {
            $processedCount++
            Write-UsageProgress -Processed $processedCount -Total $totalCount -CurrentOperation $workItem.Target

            try {
                $drive = if ($workItem.SiteId) {
                    Get-MgSiteDefaultDrive -SiteId $workItem.SiteId -ErrorAction Stop
                }
                else {
                    Get-MgUserDefaultDrive -UserId $workItem.Target -ErrorAction Stop
                }
                $status = 'OK'
                $errorMessage = $null
            }
            catch {
                $lookupError = $PSItem
                $failedCount++
                $drive = $null
                $status = 'Error'
                $errorMessage = $lookupError.Exception.Message
                $PSCmdlet.WriteError(
                    [System.Management.Automation.ErrorRecord]::new(
                        $lookupError.Exception,
                        'OneDriveLookupFailed',
                        [System.Management.Automation.ErrorCategory]::ReadError,
                        $workItem.Target
                    )
                )
            }

            $ownerId = $drive.Owner.User.Id
            $userPrincipalNameColumn = if ($All -and $ownerId) {
                $upnById[$ownerId]
            }
            else {
                $workItem.UserPrincipalName
            }

            [PSCustomObject]@{
                PSTypeName            = 'OneDriveReport.UserDrive'
                UserPrincipalName     = $userPrincipalNameColumn
                Status                = $status
                WebUrl                = $drive.WebUrl ?? $workItem.WebUrl
                OwnerDisplayName      = $drive.Owner.User.DisplayName
                OwnerId               = $ownerId
                DriveId               = $drive.Id
                CreatedDateTime       = $drive.CreatedDateTime
                LastModifiedDateTime  = $drive.LastModifiedDateTime
                StorageUsedBytes      = $drive.Quota.Used
                StorageDeletedBytes   = $drive.Quota.Deleted
                StorageRemainingBytes = $drive.Quota.Remaining
                StorageTotalBytes     = $drive.Quota.Total
                QuotaState            = $drive.Quota.State
                ErrorMessage          = $errorMessage
            }
        }
    }

    end {
        Write-Progress -Activity 'Getting OneDrive usage' -Completed
        Write-Verbose -Message "Processed [$processedCount] OneDrives; [$failedCount] lookups failed"
    }
}
