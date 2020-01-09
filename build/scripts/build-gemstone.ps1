# Call the script with the path to the project directory as an argument:
#     .\build-gemstone.ps1 "C:\Projects\gemstone"
param([string]$projectDir)

# Uncomment the following line to hardcode the project directory for testing
#$projectDir = "C:\Projects\gemstone"

# Uncomment the following line to use WSL instead of Git for Windows
#function git { & wsl git $args }

function Clone-Repository($url) {
    & git clone $url
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
    $commitsSinceTag = & git log --pretty=oneline "$latestTag.."
    $latestTag -eq $null -or $commitsSinceTag.Count -ne 0
}

Set-Location $projectDir
Clone-Repository git@github.com:gemstone/root-dev.git

Set-Location root-dev
Reset-Repository

# This script needs to maintain a list of repositories so they can be built in the right order
# When that list is implemented, this line can be replaced
Start-Process -NoNewWindow clone-all.cmd

Set-Location $projectDir
$repositories = Get-ChildItem $projectDir -Directory |
    Where-Object { $_.Name -notin ("root-dev", "shared-content", "test") }
$repositories

# Check for changes
$repositories | ForEach-Object {
    $repository = $_
    Set-Location "$projectDir\$repository"
    Reset-Repository
    $changed = $changed -or Test-RepositoryChanged
}

If ($changed) {
    # Need to update version numbers

    # The following statement can be used to build a project...
    #dotnet build -c Release "C:\Projects\gemstone\common\src\Gemstone.Common.sln"
}