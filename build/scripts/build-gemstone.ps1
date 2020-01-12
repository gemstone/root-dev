# Call the script with the path to the project directory as an argument:
#     .\build-gemstone.ps1 "C:\Projects\gemstone"

# Optionally call with skip build switch to only update shared content:
#     .\build-gemstone.ps1 "C:\Projects\gemstone" -skipBuild

param([string]$projectDir)
param([switch]$skipBuild = $false)
param([switch]$skipDocsBuild = $false)
param([string]$buildConfig = "Release")

# Uncomment the following line to hardcode the project directory for testing
$projectDir = "C:\Projects\gembuild"

# Uncomment the following line to use WSL instead of Git for Windows
#function git { & wsl git $args }

# Validate script parameters
if ([string]::IsNullOrWhiteSpace($projectDir)) {
    throw “projectDir parameter was not provided, script terminated.”
}

function Clone-Repository($url) {
    & git clone $url
}

function Tag-Repository($tagName) {
    & git tag $tagName
    & git push --tags
}

function Update-Repository($file, $message, $push = $true) {
    & git add $file
    & git commit -m "$message"

    if ($push) {
        & git push
    }
}

function Reset-Repository {
    & git gc
    & git fetch
    & git reset --hard HEAD
    & git checkout master
    & git reset --hard origin/master
    & git clean -f -d -x
}

function Test-RepositoryChanged {
    $latestTag = & git describe --abbrev=0 --tags

    if ($latestTag -eq $null) {
        return $true
    }

    $commitsSinceTag = & git log --pretty=oneline "$latestTag.."
    return $commitsSinceTag.Count -ne 0
}

# Define script constants
Set-Variable githubOrgSite     -Option Constant -Scope Script -Value "https://github.com/gemstone"
Set-Variable rootDevRepo       -Option Constant -Scope Script -Value "root-dev"
Set-Variable sharedContentRepo -Option Constant -Scope Script -Value "shared-content"
Set-Variable templateRepo      -Option Constant -Scope Script -Value "gemtem"
Set-Variable cloneCommandsFile -Option Constant -Scope Script -Value "clone-commands.txt"
Set-Variable prefixLength      -Option Constant -Scope Script -Value ("git clone ".Length + 1)
Set-Variable suffixLength      -Option Constant -Scope Script -Value ".git".Length
Set-Variable libBuildFolder    -Option Constant -Scope Script -Value "build\$buildConfig"
Set-Variable appBuildFolder    -Option Constant -Scope Script -Value "bin\$buildConfig\netcoreapp3.1"
Set-Variable toolsFolder       -Option Constant -Scope Script -Value "$projectDir\$rootDevRepo\tools"
Set-Variable readVersion       -Option Constant -Scope Script -Value "$toolsFolder\ReadVersion\$appBuildFolder\ReadVersion.exe"
Set-Variable updateVersion     -Option Constant -Scope Script -Value "$toolsFolder\UpdateVersion\$appBuildFolder\UpdateVersion.exe"
Set-Variable docProject        -Option Constant -Scope Script -Value "src\DocGen\docgen.shfbproj"

# Get latest root-dev project
Set-Location $projectDir
Clone-Repository "$githubOrgSite/$rootDevRepo.git"
Set-Location $rootDevRepo
Reset-Repository

# Load repo list from clone-commands.txt - this is expected to be in desired build dependency order
$repos = [IO.File]::ReadAllLines("$projectDir\$rootDevRepo\$cloneCommandsFile")

# Remove any comment lines from loaded repo list
$repos = $repos | Where-Object { -not ($_.Trim().StartsWith("REM") -or [string]::IsNullOrWhiteSpace($_)) }

# Extract only repo name
for ($i=0; $i -le $repos.Length; $i++) {
    $repos[$i] = $repos[$i].Substring($prefixLength + $githubOrgSite.Length).Trim()
    $repos[$i] = $repos[$i].Substring(0, $repos[$i].Length - $suffixLength)
}

Set-Location $projectDir

# Clone all repositories
foreach ($repo in $repos) {
    Clone-Repository "$githubOrgSite/$repo.git"
}

# Remove shared-content from repo list
$repos = $repos | Where-Object { $_ -ne $sharedContentRepo }

# Check for changes in shared-content repo
Set-Location "$projectDir\$sharedContentRepo"
Reset-Repository
$changed = Test-RepositoryChanged

if ($changed) {
    $changed = $false

    # Tag repo to mark new changes
    Tag-Repository $(get-date).ToString("yyyyMMddHHmmss")

    $exclude = @("README.md")

    # Update all repos with shared-content updates
    foreach ($repo in $repos) {
        $src = "$projectDir\$sharedContentRepo"
        $dst = "$projectDir\$repo"

        Get-ChildItem -Path $src -Recurse -Exclude $exclude | Copy-Item -Destination {
            if ($_.PSIsContainer) {
                Join-Path $dst $_.Parent.FullName.Substring($src.length)
            } else {
                Join-Path $dst $_.FullName.Substring($src.length)
            }
        } -Force -Exclude $exclude

        Set-Location $dst
        
        Update-Repository "." "Updated shared content"
    }
}

if ($skipBuild) {
    "Build skipped per command line switch."
    return
}

# Fetch all primary repos and check for changes
foreach ($repo in $repos) {
    Set-Location "$projectDir\$repo"
    Reset-Repository
    $changed = $changed -or (Test-RepositoryChanged)
}

if ($changed) {
    "Building versioning tools..."

    Set-Location "$toolsFolder\ReadVersion"
    dotnet build -c $buildConfig "ReadVersion.csproj"

    Set-Location "$toolsFolder\UpdateVersion"
    dotnet build -c $buildConfig "UpdateVersion.csproj"

    # Get current repo version - "Gemstone.Common" defines version for all repos
    $version = & "$readVersion" "$projectDir\common" | Out-String
    $version = $version.Trim()

    "Current Gemstone Libraries version = $version"

    # Increment build number
    $lastDotIndex = $version.LastIndexOf(".") + 1
    $buildNumber = $version.Substring($lastDotIndex) -as [int]
    $buildNumber++
    $version = $version.Substring(0, $lastDotIndex) + $buildNumber

    "Updated Gemstone Libraries version = $version"

    # Handle versioning and building of each repo
    foreach ($repo in $repos) {
        # Update version in project file
        & "$updateVersion" "$projectDir\$repo" "$version"

        # Check-in version update
        Set-Location "$projectDir\$repo"
        Update-Repository "." "Updated gemstone/$repo version to $version" -push = $skipDocsBuild

        # Build new version
        dotnet build -c $buildConfig src

        if (-not $skipDocsBuild) {
            msbuild -p:Configuration=$buildConfig $docProject
            Update-Repository "." "Built v$version documentation"
        }

        # Tag new version
        Tag-Repository "v$version"

        # Skip package push for template repository
        if ($repo -eq $templateRepo) {
            continue
        }

        # Query file system for package file to get proper casing
        $packages = [IO.Directory]::GetFiles("$projectDir\$repo\$libBuildFolder", "*.nupkg")

        if ($packages.Length -gt 0) {
            $package = $packages[0]

            # Push package to NuGet if API key is defined
            if ($env:GemstoneNuGetApiKey -ne $null) {
                dotnet nuget push $package -k $env:GemstoneNuGetApiKey -s https://api.nuget.org/v3/index.json
            }

            # Push package to GitHub Packages
            if ($env:GHPackagesUser -ne $null -and $env:GHPackagesToken -ne $null) {
                # This is a work around: https://github.com/NuGet/Home/issues/8580#issuecomment-555696372
                & curl -vX PUT -u "$env:GHPackagesUser:$env:GHPackagesToken" -F package=@$package https://nuget.pkg.github.com/gemstone/
            }

            # Use this method when GitHub Packages for NuGet is fixed
            #dotnet nuget push $package --source "github"
        }
        else {
            "No package found, build failure?"
        }
    }
}
else {
    "Build skipped, no repos changed."
}

Set-Location $projectDir