<#
.SYNOPSIS
   Builds the DXA repositories required to generate all required artifacts
.EXAMPLE
   & .\build-repositories.ps1 -branch=BRANCH_NAME (i.e, develop or release/x.y) -version=x.y.z.w
#>

[CmdletBinding( SupportsShouldProcess=$true, PositionalBinding=$false)]
param (
   # The Github branch name to clone
   [Parameter(Mandatory=$false, HelpMessage="Github branch name")]
   [string]$branch = "develop",

   # The Github branch name to clone
   [Parameter(Mandatory=$false, HelpMessage="Force update if repository already cloned")]
   [bool]$update = $false,

   # Version to tag with
   [string]$version = "0.0.0.0",

   # True if we should first clone the repositories (they may already be cloned from a previous run)
   [bool]$clone = $true,

   # True if we should build the repositories (they may already be built from a previous run)
   [bool]$build = $true
)


#Terminate script on first occurred exception
$ErrorActionPreference = "Stop"

$PSScriptDir = Split-Path $MyInvocation.MyCommand.Path

# Import msbuild helper module
Import-Module -Name "$PSScriptDir/utils/Invoke-MsBuild.psm1"

function CloneRepo($repo) {
   Write-Output "> Cloning github repository $repo ..."
   $dst = "./repositories/$repo"
   $github_repo_url = "https://github.com/sdl"
   if(!(Test-Path -Path $dst)) {
      $cmd = "git clone --branch $branch --recursive $github_repo_url/$repo.git ./repositories/$repo"
      Invoke-Expression $cmd
   }
   else {    
      if($update) {
         Write-Output "> Updating existing cloned repository ..."
         Invoke-Expression "git checkout -- ." 
         Invoke-Expression "git checkout $branch"         
      } else {
         Write-Output "> Already cloned repository ..."
         Invoke-Expression "git checkout $branch"
      }
   }
}
function RunMsBuild($buildFile, $buildParams) {   
   Invoke-MsBuild -Path $buildFile -MsBuildParameters $buildParams -ShowBuildOutputInCurrentWindow  
}

function BuildDotnet($buildFileLocation, $generateArtifacts) {
   $location = Split-Path -Path $buildFileLocation
   $buildFile = Split-Path -Path $buildFileLocation -Leaf
   Push-Location
   Set-Location $location
 
   RunMsBuild $buildFile "/t:Restore"
   RunMsBuild $buildFile "/t:Build /p:Version=$version"
   if($generateArtifacts) {
      RunMsBuild $buildFile "/t:Artifacts /p:Version=$version"
   }

   Pop-Location
}

# Clone all dotnet repositories required
if($clone) {
   CloneRepo "dxa-web-application-dotnet"
   CloneRepo "dxa-modules"
   CloneRepo "dxa-content-management"
   CloneRepo "graphql-client-dotnet"
}

# Build each dotnet repository and generate artifacts
if($build) {
   BuildDotnet "./repositories/dxa-web-application-dotnet/ciBuild.proj" $true
   BuildDotnet "./repositories/dxa-content-management/ciBuild.proj" $true
   BuildDotnet "./repositories/dxa-modules/webapp-net/ciBuild.proj" $true
   BuildDotnet "./repositories/graphql-client-dotnet/net/Build.csproj" $false
}

# Copy artifacts out to /artifacts folder
# * all nuget packages
# * all artifacts generated from each repository
# * build zip(s)
Write-Output "Packaging up artifacts ..."
Write-Output "  \artifacts\dotnet will contain all DXA dotnet artifacts ..."
$packageVersion = $version.Substring(0, $version.LastIndexOf("."))

# Copy nuget packages from repositories
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/nuget" | Out-Null
Copy-Item -Path "./repositories/graphql-client-dotnet/net/_nuget/*.$packageVersion*.nupkg" -Destination "artifacts/dotnet/nuget"
Copy-Item -Path "./repositories/dxa-content-management/_nuget/*.$packageVersion*.nupkg" -Destination "artifacts/dotnet/nuget"
Copy-Item -Path "./repositories/dxa-web-application-dotnet/_nuget/*.$packageVersion*.nupkg" -Destination "artifacts/dotnet/nuget"
Copy-Item -Path "./repositories/dxa-web-application-dotnet/_nuget/Sdl.Dxa.Framework/*.$packageVersion*.nupkg" -Destination "artifacts/dotnet/nuget"


# Copy all modules
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/modules" | Out-Null
Copy-Item -Path "./repositories/dxa-modules/webapp-net/dist/*.$packageVersion*.zip" -Destination "artifacts/dotnet/modules" -Force

# Copy DXA web application
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/web" | Out-Null
Copy-Item -Path "./repositories/dxa-web-application-dotnet/dist/web/*" -Destination "artifacts/dotnet/web" -Recurse -Force

# Copy CMS side artifacts (TBBs, Resolver, CMS content, Import/Export scripts)
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/cms" | Out-Null
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/ImportExport" | Out-Null
Copy-Item -Path "./repositories/dxa-content-management/dist/cms/*" -Destination "artifacts/dotnet/cms" -Recurse -Force
Copy-Item -Path "./repositories/dxa-content-management/dist/ImportExport/*" -Destination "artifacts/dotnet/ImportExport" -Recurse -Force


$exclude = @("nuget")
$files = Get-ChildItem -Path "artifacts/dotnet" -Exclude $exclude
$collapsedVersion = $packageVersion -replace '[.]',''
Compress-Archive -Path $files -DestinationPath "artifacts/dotnet/CM_DXA$collapsedVersion.zip" -CompressionLevel Fastest -Update