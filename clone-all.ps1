param([string]$rootDevDir)

# Validate script parameters
if ([string]::IsNullOrWhiteSpace($rootDevDir)) {
    $rootDevDir = Get-Location
}

# Script Constants
Set-Variable githubOrgSite  -Option Constant -Scope Script -Value "https://github.com/gemstone"
Set-Variable reposFile      -Option Constant -Scope Script -Value "repos.txt"

# Script Functions
function Clone-Repository($url) {
    & git clone $url
}

# Load repo list from repos.txt - this is expected to be in desired build dependency order
$repos = [IO.File]::ReadAllLines("$rootDevDir\$reposFile")

# Remove any comment lines from loaded repo list
$repos = $repos | Where-Object { -not ([string]::IsNullOrWhiteSpace($_) -or $_.Trim().StartsWith("::")) }

Set-Location ".."

# Clone all repositories
foreach ($repo in $repos) {
    Clone-Repository "$githubOrgSite/$repo.git"
}

Set-Location $rootDevDir