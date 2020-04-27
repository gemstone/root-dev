# Call the script with the path to the project directory as an argument:
#     .\build-gemstone.ps1 "C:\Projects\gemstone"

# Optionally call with skip build switch to only update shared content:
#     .\build-gemstone.ps1 "C:\Projects\gemstone" -skipBuild

param(
    [string]$projectDir,
    [string]$buildConfig = "Release",
    [string]$deployDir = "",
    [switch]$skipBuild = $false,
    [switch]$skipDocsBuild = $false
)

# Uncomment the following line to hardcode the project directory for testing
#$projectDir = "C:\Projects\gembuild"

# Uncomment the following line to use WSL instead of Git for Windows
#function git { & wsl git $args }

# Validate script parameters
if ([string]::IsNullOrWhiteSpace($projectDir)) {
    throw "projectDir parameter was not provided, script terminated."
}

# Script Variables
Set-Variable version -Scope Script -Value "0.0.0"
[Collections.Generic.HashSet[string]] $binaryExtensions = (".ico", ".png", ".jpg", ".zip")

# Script Constants
Set-Variable githubOrgSite     -Option Constant -Scope Script -Value "https://github.com/gemstone"
Set-Variable rootDevRepo       -Option Constant -Scope Script -Value "root-dev"
Set-Variable sharedContentRepo -Option Constant -Scope Script -Value "shared-content"
Set-Variable sharedContentProj -Option Constant -Scope Script -Value "SharedContent"
Set-Variable templateRepo      -Option Constant -Scope Script -Value "gemtem"
Set-Variable reposFile         -Option Constant -Scope Script -Value "repos.txt"
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

function Commit-Repository($file, $message) {
    & git add $file
    & git commit -m "$message"
}

function Push-Repository {
    & git push
}

function Reset-RepositoryTarget($target) {
    & git checkout -- $target
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
    return $?
}

function Build-Documentation {
    & msbuild -p:Configuration=$buildConfig "src\DocGen\docgen.shfbproj"
    return $?
}

function Read-Version($target, [ref]$result) {
    $result.Value = & "$toolsFolder\ReadVersion\$appBuildFolder\ReadVersion.exe" $target | Out-String
    $result.Value = $result.Value.Trim()
    return $?
}

function Increment-Version($version) {
    $lastDotIndex = $version.LastIndexOf(".") + 1
    $buildNumber = $version.Substring($lastDotIndex) -as [int]
    $buildNumber++
    return $version.Substring(0, $lastDotIndex) + $buildNumber
}

function Update-Version($target, $newVersion) {
    & "$toolsFolder\UpdateVersion\$appBuildFolder\UpdateVersion.exe" $target $newVersion
    return $?
}

function Reset-NuGetCache {
    & nuget locals http-cache -clear
}

function Publish-Package($package) {
    # Push package to NuGet
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

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Method PUT -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines `
                          -Uri "https://nuget.pkg.github.com/gemstone/" -Headers $headers -Verbose
    }

    # Use this method when GitHub Packages for NuGet is fixed
    # & dotnet nuget push $package --source "github"
}

function Build-Repos($repos) {
    try {
        Write-Host "Building versioning tools..."

        Set-Location "$toolsFolder\ReadVersion"

        if (-not (Build-Code "ReadVersion.csproj")) {
            Write-Host "ERROR: Failed to build ReadVersion tool."
            return $false
        }

        Set-Location "$toolsFolder\UpdateVersion"

        if (-not (Build-Code "UpdateVersion.csproj")) {
            Write-Host "ERROR: Failed to build UpdateVersion tool."
            return $false
        }

        # Get current repo version - "Gemstone.Common" defines version for all repos
        if (-not (Read-Version "$projectDir\common" ([ref]$version))) {
            Write-Host "ERROR: Failed to read gemstone/common version."
            return $false
        }

        Write-Host "Current Gemstone Libraries version = $version"

        # Increment version build number
        $version = Increment-Version $version
        
        # Update outer scope variable
        $script:version = $version

        Write-Host "Updating Gemstone Libraries version to $version"
        
        # Update version number in each repo project file
        foreach ($repo in $repos) {        
            if (-not (Update-Version "$projectDir\$repo", $version)) {
                Write-Host "ERROR: Failed to update gemstone/$repo version."
                return $false
            }

            # Commit version update
            Set-Location "$projectDir\$repo"
            Commit-Repository "." "Updated gemstone/$repo version to $version"
        }

        # Repos at this point are clean with updated versions - create source code zip file
        Write-Host "Creating zip archive for all Gemstone Library v$version source code..."

        # Remove any existing zip file
        Remove-Item "$projectDir\Gemstone-Source.zip"

        # Add desired source items to new zip file
        Get-ChildItem -Path $projectDir -Exclude @("nuget.config") |
            Where { $_.Name -ne "bin" -and $_.Name -ne "obj" } |
            Where { $_.FullName -notlike "*\bin\*" -and $_.FullName -notlike "*\obj\*" } |
            Compress-Archive -DestinationPath "$projectDir\Gemstone-Source.zip" -CompressionLevel "Optimal"

        # Build each repo project
        foreach ($repo in $repos) {
            Set-Location "$projectDir\$repo"

            # Clear NuGet cache to force download of newest published packages
            Reset-NuGetCache

            # Build new library version using solution in "src" folder
            if (-not (Build-Code "src")) {
                Write-Host "ERROR: Failed to build gemstone/$repo."
                return $false
            }

            # Build library documentation
            if (-not $skipDocsBuild) {
                if (Build-Documentation) {
                    Commit-Repository "." "Built gemstone/$repo v$version documentation"
                }
                else {
                    Write-Host "ERROR: Failed while building gemstone/$repo v$version documentation."
                    Write-Host "RESUMING: Failure to build documentation is considered non-fatal, build will continue..."
                    Write-Host "Undoing changes to build documentation..."
                    Reset-RepositoryTarget "docs/help"
                }
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
                Write-Host "WARNING: No gemstone/$repo v$version package found, build failure? No package pushed."
            }
        }

        return $true
    }
    catch {
        Write-Host "ERROR: Failed while building gemstone libraries: $_"
        return $false
    }
}

function Push-Repos($repos) {
    foreach ($repo in $repos) {
        Set-Location "$projectDir\$repo"
        Push-Repository
    }
}

function Deploy-Repos($repos) {
    try {
        $dstPath = "$deployDir\release\v$version"
        $exclude = @("*.pdb")

        if ([IO.Directory]::Exists($dstPath)) {
            Write-Host "Deleting existing deployment at $dstPath..."
            [IO.Directory]::Delete($dstPath, $true)
        }

        Write-Host "Deploying libraries to $dstPath..."
    
        [IO.Directory]::CreateDirectory($dstPath)

        foreach ($repo in $repos) {            
            $srcPath ="$projectDir\$repo\$libBuildFolder"

            Get-ChildItem -Path $srcPath -Recurse -Exclude $exclude | Copy-Item -Destination {
                if ($_.PSIsContainer) {
                    Join-Path $dstPath $_.Parent.FullName.Substring($srcPath.length)
                } else {
                    Join-Path $dstPath $_.FullName.Substring($srcPath.length)
                }
            } -Force -Exclude $exclude
        }

        Write-Host "Deploying zip archive containing v$version Gemstone Library binaries..."
        Compress-Archive -Path "$dstPath\*" -DestinationPath "$dstPath\Gemstone-v$version-Binaries.zip" -CompressionLevel "Optimal"

        Write-Host "Deploying zip archive containing v$version Gemstone Library source code..."
        Copy-Item "$projectDir\Gemstone-Source.zip" -Destination "$dstPath\Gemstone-v$version-Source.zip"
    }
    catch {
        Write-Host "ERROR: Failed while deploying gemstone libraries: $_"
        Write-Host "RESUMING: Failure to deploy libraries is considered non-fatal, build will continue..."
    }
}

# --------- Start Script ---------

# Get latest root-dev project
Set-Location $projectDir
Clone-Repository "$githubOrgSite/$rootDevRepo.git"
Set-Location $rootDevRepo
Reset-Repository

# Load repo list from repos.txt - this is expected to be in desired build dependency order
$repos = [IO.File]::ReadAllLines("$projectDir\$rootDevRepo\$reposFile")

# Remove any comment lines from loaded repo list
$repos = $repos | Where-Object { -not $_.Trim().StartsWith("::") }
$projects = New-Object string[] $repos.Length;

# Separate repos names from project names
for ($i = 0; $i -lt $repos.Length; $i++) {
    $parts = $repos[$i].Trim().Split('/');

    if ($parts.Length -eq 2) {
        $repos[$i] = $parts[0].Trim()
        $projects[$i] = $parts[1].Trim()
    }
    else {
        $repos[$i] = ""
        $projects[$i] = ""
    }
}

$repos = $repos | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$projects = $projects | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

Set-Location $projectDir

# Clone all repositories
foreach ($repo in $repos) {
    Clone-Repository "$githubOrgSite/$repo.git"
}

# Remove shared-content from repo and project lists
$repos = $repos | Where-Object { $_ -ne $sharedContentRepo }
$projects = $projects | Where-Object { $_ -ne $sharedContentProj }

# Check for changes in shared-content repo
Set-Location "$projectDir\$sharedContentRepo"
Reset-Repository
$changed = Test-RepositoryChanged

if ($changed) {
    $changed = $false

    # Tag repo to mark new changes
    Tag-Repository $(get-date).ToString("yyyyMMddHHmmss")

    $srcPath = "$projectDir\$sharedContentRepo"
    $exclude = @("README.md")
    $tokens = @{
        "{sc:repo-name}"   = "<repo-name>";
        "{sc:ProjectName}" = "<ProjectName>";
        "{sc:year}"        = $(get-date).ToString("yyyy");
        "{sc:month}"       = $(get-date).ToString("MM");
        "{sc:day}"         = $(get-date).ToString("dd");
        "{sc:hour}"        = $(get-date).ToString("HH");
        "{sc:minute}"      = $(get-date).ToString("mm");
        "{sc:second}"      = $(get-date).ToString("ss")
    }

    # Update all repos with shared-content updates
    for ($i = 0; $i -lt $repos.Length; $i++) {
        $repo = $repos[$i]
        $dstPath = "$projectDir\$repo"
        $tokens["{sc:repo-name}"] = $repo
        $tokens["{sc:ProjectName}"] = $projects[$i]

        Set-Location $dstPath
        Reset-Repository

        Write-Host "Updating shared content in ""$dstPath""..."

        # Recursively copy all items replacing any encountered template parameters
        foreach ($srcFile in Get-ChildItem -Path $srcPath -Recurse -Exclude $exclude) {
            if ($srcFile.PSIsContainer) {
                # This is a folder, make sure it exists
                $dstDir = Join-Path $dstPath $srcFile.Parent.FullName.Substring($srcPath.length)

                if (-not [IO.Directory]::Exists($dstDir)) {
                    [IO.Directory]::CreateDirectory($dstDir)
                }
            }
            else {
                # This is a file, copy it to destination path
                $dstFile = Join-Path $dstPath $srcFile.FullName.Substring($srcPath.length)
                Copy-Item -Path $srcFile -Destination $dstFile -Force

                # Replace any tokens in file
                if (-not $binaryExtensions.Contains([IO.Path]::GetExtension($dstFile))) {
                    $data = [IO.File]::ReadAllText($dstFile)

                    foreach ($kvp in $tokens.GetEnumerator()) {
                        $data = $data.Replace($kvp.Key, $kvp.Value)
                    }

                    [IO.File]::WriteAllText($dstFile, $data)
                }
            }
        }

        Commit-Repository "." "Updated shared content"
        Push-Repository
    }
}

if ($skipBuild) {
    Write-Host "SKIPPED: Build skipped at " + $(get-date).ToString("yyyy-MM-dd HH:mm:ss") + " --  per command line switch."
    return
}

# Fetch clean primary repos and check for changes
foreach ($repo in $repos) {
    Set-Location "$projectDir\$repo"
    Reset-Repository
    $changed = $changed -or (Test-RepositoryChanged)
}

if ($changed) {    
    if (Build-Repos($repos)) {
        Write-Host "Completed building gemstone libraries, pushing changes to GitHub..."
        Push-Repos $repos

        if ([string]::IsNullOrWhiteSpace($deployDir)) {
            Write-Host "SKIPPED: Deployment skipped,  no deployment directory specified."
        }
        else {
            if ([IO.Directory]::Exists($deployDir)) {
                Deploy-Repos $repos
            } else {
                Write-Host "WARNING: Deployment skipped, deployment directory ""$deployDir"" does not exist."
            }
        }

        Write-Host "SUCCESS: Build complete at " + $(get-date).ToString("yyyy-MM-dd HH:mm:ss") + "."
    }
    else {
        Write-Host "FAILED: Build canceled at " + $(get-date).ToString("yyyy-MM-dd HH:mm:ss") + "."
    }
}
else {
    Write-Host "SKIPPED: Build skipped at " + $(get-date).ToString("yyyy-MM-dd HH:mm:ss") + " -- no repos changed."
}

Set-Location $projectDir