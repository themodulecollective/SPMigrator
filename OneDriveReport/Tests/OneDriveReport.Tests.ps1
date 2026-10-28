#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    Offline smoke tests: every Graph cmdlet is mocked, so no tenant or connection is needed.
#>
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables set in BeforeAll/BeforeEach are read in It blocks, which the analyzer cannot see.'
)]
param()

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\OneDriveReport.psd1') -Force
    $moduleName = 'OneDriveReport'

    Mock -ModuleName $moduleName -CommandName Get-MgContext -MockWith {
        [PSCustomObject]@{ TenantId = 'tenant'; AuthType = 'AppOnly' }
    }
    Mock -ModuleName $moduleName -CommandName Get-MgUserDefaultDrive -ParameterFilter {
        $UserId -eq 'jdoe@contoso.com'
    } -MockWith {
        # The URL deliberately does not match the UPN, as after a UPN change.
        [PSCustomObject]@{
            Id                   = 'drive1'
            WebUrl               = 'https://contoso-my.sharepoint.com/personal/janed_contoso_com/Documents'
            Owner                = [PSCustomObject]@{ User = [PSCustomObject]@{ DisplayName = 'Jane Doe' } }
            CreatedDateTime      = [datetime]'2020-01-01'
            LastModifiedDateTime = [datetime]'2026-10-01'
            Quota                = [PSCustomObject]@{
                Used      = 1024
                Deleted   = 0
                Remaining = 2048
                Total     = 3072
                State     = 'normal'
            }
        }
    }
    Mock -ModuleName $moduleName -CommandName Get-MgUserDefaultDrive -ParameterFilter {
        $UserId -eq 'nodrive@contoso.com'
    } -MockWith {
        throw 'ResourceNotFound'
    }
}

Describe 'Get-OneDriveUsage' {
    It 'Reports the drive Graph returns rather than a URL built from the UPN' {
        $row = Get-OneDriveUsage -UserPrincipalName 'jdoe@contoso.com'

        $row.PSObject.TypeNames[0] | Should -Be 'OneDriveReport.UserDrive'
        $row.Status | Should -Be 'OK'
        $row.WebUrl | Should -BeLike '*/personal/janed_contoso_com/*'
        $row.OwnerDisplayName | Should -Be 'Jane Doe'
        $row.StorageUsedBytes | Should -Be 1024
        $row.QuotaState | Should -Be 'normal'
        $row.ErrorMessage | Should -BeNullOrEmpty
    }

    It 'Emits an error row and a non-terminating error for a failed lookup, then continues' {
        $usageParameters = @{
            UserPrincipalName = 'nodrive@contoso.com', 'jdoe@contoso.com'
            ErrorVariable     = 'lookupErrors'
            ErrorAction       = 'SilentlyContinue'
        }

        $rows = Get-OneDriveUsage @usageParameters

        $rows.Count | Should -Be 2
        $rows[0].Status | Should -Be 'Error'
        $rows[0].ErrorMessage | Should -BeLike '*ResourceNotFound*'
        $rows[0].WebUrl | Should -BeNullOrEmpty
        $rows[1].Status | Should -Be 'OK'
        # -ErrorVariable also collects the inner errors the function caught, so check only its own record.
        $ownErrors = $lookupErrors.Where({ $_.FullyQualifiedErrorId -like 'OneDriveLookupFailed*' })
        $ownErrors.Count | Should -Be 1
        $ownErrors[0].TargetObject | Should -Be 'nodrive@contoso.com'
    }

    It 'Binds UserPrincipalName from piped objects, such as rows from Import-Csv' {
        $rows = @(
            [PSCustomObject]@{ UserPrincipalName = 'jdoe@contoso.com'; Department = 'Finance' }
            [PSCustomObject]@{ UserPrincipalName = 'jdoe@contoso.com'; Department = 'Sales' }
        ) | Get-OneDriveUsage

        $rows.Count | Should -Be 2
        $rows.Status | Should -Be @('OK', 'OK')
    }

    It 'Does not fall back to a tenant-wide run when the pipeline is empty' {
        Mock -ModuleName $moduleName -CommandName Invoke-MgGraphRequest -MockWith { }

        $rows = @() | Get-OneDriveUsage

        $rows | Should -BeNullOrEmpty
        Should -Invoke -ModuleName $moduleName -CommandName Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'Warns once, but still runs, on a delegated session' {
        Mock -ModuleName $moduleName -CommandName Get-MgContext -MockWith {
            [PSCustomObject]@{ TenantId = 'tenant'; AuthType = 'Delegated' }
        }

        $row = Get-OneDriveUsage -UserPrincipalName 'jdoe@contoso.com' -WarningVariable authWarnings 3>$null

        $row.Status | Should -Be 'OK'
        $authWarnings.Count | Should -Be 1
        $authWarnings[0] | Should -BeLike '*Delegated*Sites.Read.All*'
    }

    It 'Throws a clear error when not connected' {
        Mock -ModuleName $moduleName -CommandName Get-MgContext -MockWith { }

        { Get-OneDriveUsage -UserPrincipalName 'jdoe@contoso.com' } |
            Should -Throw -ExpectedMessage '*Connect-MgGraph*'
    }
}

Describe 'Get-OneDriveUsage -All' {
    BeforeAll {
        $nextPageUri = 'https://graph.microsoft.com/v1.0/sites/getAllSites?$skiptoken=page2'
        $myHost = 'https://contoso-my.sharepoint.com'

        # Two pages, to prove paging is followed, with a non-personal site that must be skipped.
        Mock -ModuleName $moduleName -CommandName Invoke-MgGraphRequest -ParameterFilter {
            $Uri -eq 'https://graph.microsoft.com/v1.0/sites/getAllSites'
        } -MockWith {
            @{
                value             = @(
                    @{ id = 'root'; webUrl = 'https://contoso.sharepoint.com'; isPersonalSite = $false }
                    @{ id = 'od1'; webUrl = "$myHost/personal/jdoe"; isPersonalSite = $true }
                )
                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/sites/getAllSites?$skiptoken=page2'
            }
        }
        Mock -ModuleName $moduleName -CommandName Invoke-MgGraphRequest -ParameterFilter {
            $Uri -eq $nextPageUri
        } -MockWith {
            @{
                value = @(
                    @{ id = 'od2'; webUrl = "$myHost/personal/left"; isPersonalSite = $true }
                    @{ id = 'od3'; webUrl = "$myHost/personal/broken"; isPersonalSite = $true }
                )
            }
        }
        Mock -ModuleName $moduleName -CommandName Get-MgSiteDefaultDrive -ParameterFilter {
            $SiteId -eq 'od1'
        } -MockWith {
            [PSCustomObject]@{
                Id     = 'drive1'
                WebUrl = 'https://contoso-my.sharepoint.com/personal/jdoe/Documents'
                Owner  = [PSCustomObject]@{ User = [PSCustomObject]@{ Id = 'user1'; DisplayName = 'Jane Doe' } }
                Quota  = [PSCustomObject]@{ Used = 10; State = 'normal' }
            }
        }
        # Owned by a user who has since been deleted from the directory.
        Mock -ModuleName $moduleName -CommandName Get-MgSiteDefaultDrive -ParameterFilter {
            $SiteId -eq 'od2'
        } -MockWith {
            [PSCustomObject]@{
                Id     = 'drive2'
                WebUrl = 'https://contoso-my.sharepoint.com/personal/left/Documents'
                Owner  = [PSCustomObject]@{
                    User = [PSCustomObject]@{ Id = 'deleted'; DisplayName = 'Former User' }
                }
                Quota  = [PSCustomObject]@{ Used = 20; State = 'normal' }
            }
        }
        Mock -ModuleName $moduleName -CommandName Get-MgSiteDefaultDrive -ParameterFilter {
            $SiteId -eq 'od3'
        } -MockWith {
            throw 'Access denied'
        }
        Mock -ModuleName $moduleName -CommandName Get-MgUser -MockWith {
            [PSCustomObject]@{ Id = 'user1'; UserPrincipalName = 'jdoe@contoso.com' }
        }
    }

    It 'Refuses a delegated session before calling Graph' {
        Mock -ModuleName $moduleName -CommandName Get-MgContext -MockWith {
            [PSCustomObject]@{ TenantId = 'tenant'; AuthType = 'Delegated' }
        }

        { Get-OneDriveUsage -All } | Should -Throw -ExpectedMessage '*app-only*getAllSites*'
        Should -Invoke -ModuleName $moduleName -CommandName Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'Reports every personal site across pages, resolving owners to UPNs' {
        $rows = Get-OneDriveUsage -All -ErrorAction SilentlyContinue

        $rows.Count | Should -Be 3
        $rows[0].UserPrincipalName | Should -Be 'jdoe@contoso.com'
        $rows[0].OwnerId | Should -Be 'user1'
        $rows[0].StorageUsedBytes | Should -Be 10
        Should -Invoke -ModuleName $moduleName -CommandName Get-MgUser -Times 1 -Exactly
    }

    It 'Leaves UserPrincipalName empty for an orphaned OneDrive' {
        $rows = Get-OneDriveUsage -All -ErrorAction SilentlyContinue

        $rows[1].Status | Should -Be 'OK'
        $rows[1].UserPrincipalName | Should -BeNullOrEmpty
        $rows[1].OwnerDisplayName | Should -Be 'Former User'
    }

    It 'Keeps the site URL on an error row so the failed OneDrive can be identified' {
        $rows = Get-OneDriveUsage -All -ErrorAction SilentlyContinue

        $rows[2].Status | Should -Be 'Error'
        $rows[2].WebUrl | Should -Be 'https://contoso-my.sharepoint.com/personal/broken'
        $rows[2].ErrorMessage | Should -BeLike '*Access denied*'
    }

    It 'Still reports drives, with a warning, when users cannot be read' {
        Mock -ModuleName $moduleName -CommandName Get-MgUser -MockWith { throw 'Missing User.Read.All' }

        $usageParameters = @{
            All             = $true
            ErrorAction     = 'SilentlyContinue'
            WarningVariable = 'userWarnings'
            WarningAction   = 'SilentlyContinue'
        }

        $rows = Get-OneDriveUsage @usageParameters

        $rows.Count | Should -Be 3
        $rows[0].UserPrincipalName | Should -BeNullOrEmpty
        $rows[0].OwnerDisplayName | Should -Be 'Jane Doe'
        $userWarnings[0] | Should -BeLike '*Missing User.Read.All*'
    }
}
