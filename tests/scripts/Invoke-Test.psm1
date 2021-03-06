
Function Invoke-Test {
    Param(
        [string]$RocksLocation,
        [string]$RocksHost,
        [string]$SitecoreVersion,
        [string]$DataFolder = "App_Data"
    )

    Push-Location $PSScriptRoot\..\.. 
    try {

        # Deploy Hard Rocks and Unicorn Config
        & msbuild .\src\Sitecore.Rocks.Server\Sitecore.Rocks.Server.csproj /p:Configuration=Debug /p:Platform=AnyCPU /p:DeployOnBuild=true /p:PublishProfile=FilesystemPublish /p:DebugType=None /p:publishUrl="$RocksLocation" /p:DeleteExistingFiles=False /restore /v:m
        & msbuild .\tests\code\instance\UnicornConfig.csproj /p:Configuration=Debug /p:Platform=AnyCPU /p:DeployOnBuild=true /p:PublishProfile=FilesystemPublish /p:DebugType=None /p:publishUrl="$RocksLocation" /p:DeleteExistingFiles=False /restore /v:m

        # Warm up the instance
        Write-Host "Warming up Sitecore instance at $RocksHost"
        $warmup = Invoke-WebRequest -Uri "$RocksHost/sitecore/service/keepalive.aspx" -TimeoutSec 3000
        Write-Host "$($warmup.StatusCode) $($warmup.StatusDescription)"

        # Copy test data and sync
        Import-Module .\tests\scripts\unicorn\Unicorn.psm1
        $secret = ([xml](Get-Content -Raw .\tests\code\instance\App_Config\Include\zzz\RocksTestData.config)).configuration.sitecore.unicorn.authenticationProvider.SharedSecret
        if (Test-Path "$RocksLocation\$DataFolder\unicorn") {
            Remove-Item -r -Force $RocksLocation\$DataFolder\unicorn\*
        } else {
            New-Item -Type Directory $RocksLocation\$DataFolder\unicorn
        }
        Copy-Item -r -Force .\tests\serialization\* $RocksLocation\$DataFolder\unicorn\
        Sync-Unicorn -ControlPanelUrl "$RocksHost/unicorn.aspx" -SharedSecret $secret -DebugSecurity -InformationAction Continue

        # Build Tests
        & msbuild .\tests\code\tests\Sitecore.Rocks.Server.IntegrationTests.csproj /p:Configuration=Debug /p:Platform=AnyCPU /restore /v:m

        # Install xunit and run tests
        $xunitLocation = "$env:temp\rocks_xunit"
        & nuget install xunit.runner.console -Version 2.4.1 -o "$env:temp\rocks_xunit"
        $env:HardRocksHost = $RocksHost
        $env:SitecoreVersion = $SitecoreVersion
        Write-Host "Executing integration tests on $RocksHost..." -ForegroundColor green
        & "$env:temp\rocks_xunit\xunit.runner.console.2.4.1\tools\net472\xunit.console.exe" .\tests\code\tests\bin\Debug\Sitecore.Rocks.Server.IntegrationTests.dll -verbose

        # Resync Unicorn to clear changes
        Write-Host "Cleaning up changes to test data..." -ForegroundColor green
        Sync-Unicorn -ControlPanelUrl "$RocksHost/unicorn.aspx" -SharedSecret $secret -WarningAction SilentlyContinue
    } finally {
        Pop-Location
    }

}

Export-ModuleMember *-*