# Call the script with the path to the project directory as an argument:
#     .\build-gemstone.ps1 "C:\Projects\gemstone"

# Optionally call with skip build switch to only update shared content:
#     .\build-gemstone.ps1 "C:\Projects\gemstone" -skipBuild

param([string]$projectDir, [switch]$skipBuild = $false, [switch]$skipDocsBuild = $false, [string]$buildConfig = "Release")

# Uncomment the following line to hardcode the project directory for testing
#$projectDir = "C:\Projects\gembuild"

# Uncomment the following line to use WSL instead of Git for Windows
#function git { & wsl git $args }

# Validate script parameters
if ([string]::IsNullOrWhiteSpace($projectDir)) {
    throw “projectDir parameter was not provided, script terminated.”
}

# Script Constants
Set-Variable githubOrgSite     -Option Constant -Scope Script -Value "https://github.com/gemstone"
Set-Variable rootDevRepo       -Option Constant -Scope Script -Value "root-dev"
Set-Variable sharedContentRepo -Option Constant -Scope Script -Value "shared-content"
Set-Variable templateRepo      -Option Constant -Scope Script -Value "gemtem"
Set-Variable cloneCommandsFile -Option Constant -Scope Script -Value "clone-commands.txt"
Set-Variable libBuildFolder    -Option Constant -Scope Script -Value "build\$buildConfig"
Set-Variable appBuildFolder    -Option Constant -Scope Script -Value "bin\$buildConfig\netcoreapp3.1"
Set-Variable toolsFolder       -Option Constant -Scope Script -Value "$projectDir\$rootDevRepo\tools"

# Script Functions
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

function Build-Code($target) {
    & dotnet build -c $buildConfig $target
}

function Build-Documentation {
    & msbuild -p:Configuration=$buildConfig "src\DocGen\docgen.shfbproj"
}

function Read-Version($target) {
    $result = & "$toolsFolder\ReadVersion\$appBuildFolder\ReadVersion.exe" $target | Out-String
    return $result.Trim()
}

function Increment-Version($version) {
    $lastDotIndex = $version.LastIndexOf(".") + 1
    $buildNumber = $version.Substring($lastDotIndex) -as [int]
    $buildNumber++
    return $version.Substring(0, $lastDotIndex) + $buildNumber
}

function Update-Version($target, $newVersion) {
    & "$toolsFolder\UpdateVersion\$appBuildFolder\UpdateVersion.exe" $target $newVersion
}

function Reset-NuGetCache {
    & nuget locals http-cache -clear
}

function Publish-Package($package) {
    # Push package to NuGet if API key is defined
    if ($env:GemstoneNuGetApiKey -ne $null) {
        & dotnet nuget push $package -k $env:GemstoneNuGetApiKey -s "https://api.nuget.org/v3/index.json"
    }

    # Push package to GitHub Packages
    if ($env:GHPackagesUser -ne $null -and $env:GHPackagesToken -ne $null) {
        # This is a work around: https://github.com/NuGet/Home/issues/8580#issuecomment-555696372
        $fileName = [IO.Path]::GetFileName($package)
        $fileBytes = [IO.File]::ReadAllBytes($package)
        $encodedData = [Text.Encoding]::GetEncoding("ISO-8859-1").GetString($fileBytes)
        $boundary = [Guid]::NewGuid().ToString()
        $lineFeed = "`r`n"

        $bodyLines = ( 
            "--$boundary",
            "Content-Disposition: form-data; name=`"package`"; filename=`"$fileName`"",
            "Content-Type: application/octet-stream$lineFeed",
            $encodedData,
            "--$boundary--" 
        ) -join $lineFeed

        $credentials = "${env:GHPackagesUser}:${env:GHPackagesToken}"
        $encodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($credentials))
        $headers = @{ Authorization = "Basic $encodedCreds" }

        Invoke-WebRequest -Method PUT -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines `
                          -Uri "https://nuget.pkg.github.com/gemstone/" -Headers $headers -Verbose
    }

    # Use this method when GitHub Packages for NuGet is fixed
    # & dotnet nuget push $package --source "github"
}

# --------- Start Script ---------

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
$prefixLength = ("git clone ".Length + 1)
$suffixLength = ".git".Length

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

    $src = "$projectDir\$sharedContentRepo"
    $exclude = @("README.md")

    # Update all repos with shared-content updates
    foreach ($repo in $repos) {
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
    Build-Code "ReadVersion.csproj"

    Set-Location "$toolsFolder\UpdateVersion"
    Build-Code "UpdateVersion.csproj"

    # Get current repo version - "Gemstone.Common" defines version for all repos
    $version = Read-Version "$projectDir\common"

    "Current Gemstone Libraries version = $version"

    # Increment version build number
    $version = Increment-Version $version

    "Updated Gemstone Libraries version = $version"

    # Handle versioning and building of each repo
    foreach ($repo in $repos) {
        # Update version in project file
        Update-Version "$projectDir\$repo" "$version"

        # Check-in version update
        Set-Location "$projectDir\$repo"
        Update-Repository "." "Updated gemstone/$repo version to $version" -push $skipDocsBuild

        # Clear NuGet cache to force download of newest published packages
        Reset-NuGetCache

        # Build new library version using solution in "src" folder
        Build-Code "src"

        if (-not $skipDocsBuild) {
            Build-Documentation
            Update-Repository "." "Built gemstone/$repo v$version documentation"
        }

        # Tag new version
        Tag-Repository "v$version"

        # Skip package push for template repository
        if ($repo -eq $templateRepo) {
            continue
        }

        # Query file system for package file to get proper casing
        $packages = [IO.Directory]::GetFiles("$projectDir\$repo\$libBuildFolder", "*.$version.nupkg")

        if ($packages.Length -gt 0) {
            Publish-Package $packages[0]
        }
        else {
            "No package found, build failure?"
        }
    }

    "Build complete at " + $(get-date).ToString("yyyy-MM-dd HH:mm:ss") + "."
}
else {
    "Build skipped, no repos changed."
}

Set-Location $projectDir