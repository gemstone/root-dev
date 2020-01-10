# Call the script with the path to the project directory as an argument:
#     .\build-gemstone.ps1 "C:\Projects\gemstone"
param([string]$projectDir)

# Uncomment the following line to hardcode the project directory for testing
$projectDir = "D:\Projects\gembuild"

# Uncomment the following line to use WSL instead of Git for Windows
#function git { & wsl git $args }

function Clone-Repository($url) {
    & git clone $url
}

function Tag-Repository($tagName) {
    & git tag $tagName
    & git push --tags
}

function Update-Repository($file, $message) {
    & git add $file
    & git commit -m "$message"
    & git push
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

# Get latest root-dev project
Set-Location $projectDir
Clone-Repository https://github.com/gemstone/root-dev.git

Set-Location root-dev
Reset-Repository

# Load repo list from clone-commands.txt - this is expected to be in desired build dependency order
$repos = [IO.File]::ReadAllLines("$projectDir\root-dev\clone-commands.txt")

# Remove any comment lines from loaded repo list
$repos = $repos | Where-Object { $_.StartsWith("REM") -ne $true }

# Extract only repo name
$githubOrgSite = "https://github.com/gemstone/"

For ($i=0; $i -le $repos.Length; $i++) {
    $repos[$i] = $repos[$i].Substring(10 + $githubOrgSite.Length).Trim()
    $repos[$i] = $repos[$i].Substring(0, $repos[$i].Length - 4)
}

Set-Location $projectDir

# Clone all repositories
$repos | ForEach-Object {
    Clone-Repository "$githubOrgSite$_.git"
}

# Remove shared-content from repo list
$repos = $repos | Where-Object { $_ -ne "shared-content" }

# Check for changes in shared-content repo
Set-Location "$projectDir\shared-content"
Reset-Repository
$changed = Test-RepositoryChanged

If ($changed) {
    $changed = $false

    # Tag repo to mark new changes
    Tag-Repository $(get-date).ToString("yyyyMMddHHmmss")

    $exclude = @("README.md")

    # Update all repos with shared-content updates
    $repos | ForEach-Object {
        $repo = $_
        $src = "$projectDir\shared-content"
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

# Check for changes in any of the primary repos
foreach ($repo in $repos) {
    Set-Location "$projectDir\$repo"
    Reset-Repository
    $changed = Test-RepositoryChanged

    if ($changed) {
        break
    }
}

If ($changed) {
    "Building versioning tools..."
    Set-Location "$projectDir\root-dev\tools\ReadVersion"
    dotnet build -c Release "ReadVersion.csproj"
    $readVersion = "$projectDir\root-dev\tools\ReadVersion\bin\Release\netcoreapp3.1\ReadVersion.exe"

    Set-Location "$projectDir\root-dev\tools\UpdateVersion"
    dotnet build -c Release "UpdateVersion.csproj"
    $updateVersion = "$projectDir\root-dev\tools\UpdateVersion\bin\Release\netcoreapp3.1\UpdateVersion.exe"

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
    $repos | ForEach-Object {
        $repo = $_
        & "$updateVersion" "$projectDir\$repo" "$version-beta"
    }
}
Else {
    "Build skipped, no repos changed."
}

Set-Location $projectDir