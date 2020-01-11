# Call the script with the path to the project directory as an argument:
#     .\build-gemstone.ps1 "C:\Projects\gemstone"
param([string]$projectDir)

# Uncomment the following line to hardcode the project directory for testing
$projectDir = "C:\Projects\gembuild"

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

Set-Variable githubOrgSite -Option Constant -Scope Script -Value "https://github.com/gemstone"
Set-Variable rootDevRepo -Option Constant -Scope Script -Value "root-dev"
Set-Variable commonRepo -Option Constant -Scope Script -Value "common"
Set-Variable sharedContentRepo -Option Constant -Scope Script -Value "shared-content"
Set-Variable cloneCommandsFile -Option Constant -Scope Script -Value "clone-commands.txt"
Set-Variable prefixLength -Option Constant -Scope Script -Value ("git clone ".Length + 1)
Set-Variable buildConfig -Option Constant -Scope Script -Value "Release"

# Get latest root-dev project
Set-Location $projectDir
Clone-Repository "$githubOrgSite/$rootDevRepo.git"
Set-Location $rootDevRepo
Reset-Repository

# Load repo list from clone-commands.txt - this is expected to be in desired build dependency order
$repos = [IO.File]::ReadAllLines("$projectDir\$rootDevRepo\$cloneCommandsFile")

# Remove any comment lines from loaded repo list
$repos = $repos | Where-Object { ($_.Trim().StartsWith("REM") -or [string]::IsNullOrWhiteSpace($_)) -ne $true }

# Extract only repo name
for ($i=0; $i -le $repos.Length; $i++) {
    $repos[$i] = $repos[$i].Substring($prefixLength + $githubOrgSite.Length).Trim()
    $repos[$i] = $repos[$i].Substring(0, $repos[$i].Length - 4)
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

If ($changed) {
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

# Fetch all primary repos and check for changes
foreach ($repo in $repos) {
    Set-Location "$projectDir\$repo"
    Reset-Repository
    $changed = $changed -or (Test-RepositoryChanged)
}

if ($changed) {
    Set-Variable toolsFolder -Option Constant -Scope Script -Value "$projectDir\$rootDevRepo\tools"
    Set-Variable appBuildFolder -Option Constant -Scope Script -Value "bin\$buildConfig\netcoreapp3.1"

    Set-Variable readVersion -Option Constant -Scope Script -Value "ReadVersion"
    Set-Variable readVersionApp -Option Constant -Scope Script -Value "$toolsFolder\$readVersion\$appBuildFolder\$readVersion.exe"

    Set-Variable updateVersion -Option Constant -Scope Script -Value "UpdateVersion"
    Set-Variable updateVersionApp -Option Constant -Scope Script -Value "$toolsFolder\$updateVersion\$appBuildFolder\$updateVersion.exe"
    
    "Building versioning tools..."

    Set-Location "$toolsFolder\$readVersion"
    dotnet build -c $buildConfig "$readVersion.csproj"

    Set-Location "$toolsFolder\$updateVersion"
    dotnet build -c $buildConfig "$updateVersion.csproj"

    # Get current repo version - "Gemstone.Common" defines version for all repos
    $version = & "$readVersionApp" "$projectDir\$commonRepo" | Out-String
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
        & "$updateVersionApp" "$projectDir\$repo" "$version-beta"
    }
}
else {
    "Build skipped, no repos changed."
}

Set-Location $projectDir