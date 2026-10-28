@{
    RootModule           = 'OneDriveReport.psm1'
    ModuleVersion        = '0.2.1'
    GUID                 = '958e3e3a-eb35-4471-9bf8-01100bfa7b29'
    Author               = 'Mike Campbell'
    Description          = "Reports users' OneDrive URL, storage use, and quota state through Microsoft Graph."
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules      = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0' }
        @{ ModuleName = 'Microsoft.Graph.Files'; ModuleVersion = '2.0.0' }
        @{ ModuleName = 'Microsoft.Graph.Sites'; ModuleVersion = '2.0.0' }
        @{ ModuleName = 'Microsoft.Graph.Users'; ModuleVersion = '2.0.0' }
    )
    FunctionsToExport    = @(
        'Get-OneDriveUsage'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
}
