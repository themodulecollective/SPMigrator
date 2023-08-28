function Export-ComplianceRetentionPolicy{
    <#
    .SYNOPSIS
        Get all existing Compliance Retention Policies (and Rules) from a Tenant and export to an Excel file
    .DESCRIPTION
        Export all Active Directory user to an XML file. Optional Zip export using $compressoutput switch param. Can specify additional properties to be included in the user export using CustomProperty param.
    .EXAMPLE
        Export-ComplianceRetentionPolicy -OutputFolderPath "C:\Users\UserName\Documents"
        All Compliance Retention Policies in the connected tenant will be exported to a date stamped file with a name like RetentionPoliciesAsOfyyyyMMddhhmmss.xlsx
    #>

    [cmdletbinding()]
    param(
        # Folder path for the XML or Zip export
        [parameter(Mandatory)]
        [string]$OutputFolderPath
        ,
        # Specify a delimiter, 1 character in length.  Default is '|'.
        [parameter()]
        [ValidateLength(1,1)]
        [string]$Delimiter = '|'
    )

    $PolicyProperties = @(
        'Name'
        'Comment'
        'Identity'
        @{
            n='GUID';e={$_.Guid.guid}
        }
        'Priority'
        'Type'
        'Enabled'
        'Mode'
        'RestrictiveRetention'
        'IsSimulation'
        'IsAdaptivePolicy'
        'PriorityCleanup'
        'ItemStatistics'
        'HasRules'
        'Workload'
        'TeamsPolicy'
        'LastStatusUpdateTime'
        'ModificationTimeUTC'
        'WhenChangedUTC'
        'WhenCreatedUTC'
        'CreationTimeUTC'
        @{
            n='RetentionRuleTypes';e={$_.RetentionRuleTypes -join " $Delimiter "}
        }
        @{
            n='Applications';e={$_.Applications -join " $Delimiter "}
        }
        @{
            n='SharePointLocation'
            e={$_.SharePointLocation -join " $Delimiter "}
        }
        @{
            n='SharePointLocationException'
            e={$_.SharePointLocationException -join " $Delimiter "}
        }
        @{
            n='ExchangeLocation'
            e={$_.ExchangeLocation -join " $Delimiter "}
        }
        @{
            n='ExchangeLocationException'
            e={$_.ExchangeLocationException -join " $Delimiter "}
        }
        @{
            n='ModernGroupLocation'
            e={$_.ModernGroupLocation -join " $Delimiter "}
        }
        @{
            n='ModernGroupLocationException'
            e={$_.ModernGroupLocationException -join " $Delimiter "}
        }
        @{
            n='OneDriveLocation'
            e={$_.OneDriveLocation -join " $Delimiter "}
        }
        @{
            n='OneDriveLocationException'
            e={$_.OneDriveLocationException -join " $Delimiter "}
        }
        @{
            n='TeamsChatLocation'
            e={$_.TeamsChatLocation -join " $Delimiter "}
        }
        @{
            n='TeamsChatLocationException'
            e={$_.TeamsChatLocationException -join " $Delimiter "}
        }
        @{
            n='TeamsChannelLocation'
            e={$_.TeamsChannelLocation -join " $Delimiter "}
        }
        @{
            n='TeamsChannelLocationException'
            e={$_.TeamsChannelLocationException -join " $Delimiter "}
        }
        @{
            n='AdaptiveScopeLocation'
            e={$_.AdaptiveScopeLocation -join " $Delimiter "}
        }
    )

    $RuleProperties = @(
        'Name'
        'Comment'
        @{
            n='Guid'
            e={$_.guid.guid}
        }
        'Identity'
        'ImmutableId'
        'DistinguishedName'
        @{
            n='Policy'
            e={$_.Policy.guid}
        }
        'Priority'
        'Disabled'
        'ContentDateFrom'
        'ContentDateTo'
        'ContentMatchQuery'
        'RetentionComplianceAction'
        'RetentionDuration'
        'RetentionDurationDisplayHint'
        'ComplianceTagProperty'
        'ApplyComplianceTag'
        'ContentContainsSensitiveInformation'
        'Workload'
        'ExchangeObjectId'
        'ExchangeVersion'
        @{
            n='ExcludedItemClasses'
            e={$_.ExcludedItemClasses -join " $Delimiter "}
        }
        @{
            n='IRMRiskyUserProfiles'
            e={$_.IRMRiskyUserProfiles -join " $Delimiter "}
        }
        @{
            n='MachineLearningModelIDs'
            e={$_.MachineLearningModelIDs -join " $Delimiter "}
        }
        'ExpirationDateOption'
        'ExternalIdentity'
        'IsValid'
        'LogicalWorkload'
        'Mode'
        'PriorityCleanup'
        'PublishComplianceTag'
        'ReadOnly'
        'RetainCloudAttachment'
        'WhenChangedUTC'
        'WhenCreatedUTC'
    )

        $DateString = Get-Date -Format yyyyMMddhhmmss

    $OutputFileName = 'M365RetentionPolicies' + 'AsOf' + $DateString
    $OutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath $($OutputFileName + '.xlsx')

    $Policies = Get-RetentionCompliancePolicy -RetentionRuleTypes -DistributionDetail | Select-Object -property $PolicyProperties
    $Rules = Get-RetentionComplianceRule | Select-Object -property $RuleProperties

    $Policies | Export-Excel -Path $OutputFilePath -WorksheetName 'Policies' -tablename 'Policies' -tablestyle Medium11
    $Rules | Export-Excel -Path $OutputFilePath -WorksheetName 'Rules' -tablename 'Rules' -tablestyle Medium11

}