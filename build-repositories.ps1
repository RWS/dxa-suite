<#
.SYNOPSIS
   Builds the DXA repositories required to generate all required artifacts
.EXAMPLE
   & .\build-repositories.ps1 -branch=BRANCH_NAME (i.e, develop or release/x.y) -version=x.y.z.w
#>

[CmdletBinding( SupportsShouldProcess=$true, PositionalBinding=$false)]
param (
   # Version to tag with
   [Parameter(Mandatory=$true, HelpMessage="Version to tag build with. In the form of <major>.<minor>.<patch>.<build> (i.e, 2.2.9.0).")]
   [string]$version = "0.0.0.0",
   
   # The Github branch name to clone
   [Parameter(Mandatory=$false, HelpMessage="Github branch name")]
   [string]$branch = "develop",

   # The Github branch name to clone
   [Parameter(Mandatory=$false, HelpMessage="Force update if repository already cloned")]
   [bool]$update = $false,

   # True if we should first clone the repositories (they may already be cloned from a previous run)
   [Parameter(Mandatory=$false, HelpMessage="Indicate if this script should first clone the repositories.")]
   [bool]$clone = $true,

   # True if we should build the repositories (they may already be built from a previous run)
   [Parameter(Mandatory=$false, HelpMessage="Indicate if this script should build the repositories.")]
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
   CloneRepo "dxa-html-design"
   CloneRepo "dxa-model-service"
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

if(Test-Path -Path "./artifacts/dotnet/tmp") {
   Remove-Item -LiteralPath "./artifacts/dotnet/tmp" -Force -Recurse | Out-Null
}

# Copy nuget packages from repositories
Write-Output "  copying nuget packages ..."
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/nuget" | Out-Null
Copy-Item -Path "./repositories/graphql-client-dotnet/net/_nuget/*.$packageVersion*.nupkg" -Destination "artifacts/dotnet/nuget"
Copy-Item -Path "./repositories/dxa-content-management/_nuget/*.$packageVersion*.nupkg" -Destination "artifacts/dotnet/nuget"
Copy-Item -Path "./repositories/dxa-web-application-dotnet/_nuget/*.$packageVersion*.nupkg" -Destination "artifacts/dotnet/nuget"
Copy-Item -Path "./repositories/dxa-web-application-dotnet/_nuget/Sdl.Dxa.Framework/*.$packageVersion*.nupkg" -Destination "artifacts/dotnet/nuget"

# Copy all modules
Write-Output "  copying modules ..."
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/module_packages" | Out-Null
Copy-Item -Path "./repositories/dxa-modules/webapp-net/dist/*.$packageVersion*.zip" -Destination "artifacts/dotnet/module_packages" -Recurse -Force

# Extract all modules
Write-Output "  extracting modules to /modules folder ..."
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/modules" | Out-Null
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/tmp" | Out-Null
Get-ChildItem "./artifacts/dotnet/module_packages" -Filter *.zip | 
Foreach-Object {
   $dstFolder = $_.BaseName
   Expand-Archive -Path $_.FullName -DestinationPath "artifacts/dotnet/tmp/$dstFolder" -Force
   Copy-Item -Path "./artifacts/dotnet/tmp/$dstFolder/modules/*" -Destination "artifacts/dotnet/modules" -Recurse -Force
}
if(Test-Path -Path "./artifacts/dotnet/tmp") {
   Remove-Item -LiteralPath "./artifacts/dotnet/tmp" -Force -Recurse | Out-Null
}

# Copy DXA web application
Write-Output "  copying DXA web application ..."
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/web" | Out-Null
Copy-Item -Path "./repositories/dxa-web-application-dotnet/dist/web/*" -Destination "artifacts/dotnet/web" -Recurse -Force

# Copy CMS side artifacts (TBBs, Resolver, CMS content, Import/Export scripts)
Write-Output "  copying CMS components ..."
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/cms" | Out-Null
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/ImportExport" | Out-Null
Copy-Item -Path "./repositories/dxa-content-management/dist/cms/*" -Destination "artifacts/dotnet/cms" -Recurse -Force
Copy-Item -Path "./repositories/dxa-content-management/dist/ImportExport/*" -Destination "artifacts/dotnet/ImportExport" -Recurse -Force

# Copy html design src
Write-Output "  copying html design ..."
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/html" | Out-Null
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/html/design" | Out-Null
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/html/design/src" | Out-Null
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/html/whitelabel" | Out-Null
Copy-Item -Path "./repositories/dxa-html-design/src/*" -Destination "artifacts/dotnet/html/design/src" -Recurse -Force
Copy-Item -Path "./repositories/dxa-html-design/.bowerrc" -Destination "artifacts/dotnet/html/design" -Recurse -Force
Copy-Item -Path "./repositories/dxa-html-design/bower.json" -Destination "artifacts/dotnet/html/design" -Recurse -Force
Copy-Item -Path "./repositories/dxa-html-design/BUILD.md" -Destination "artifacts/dotnet/html/design" -Recurse -Force
Copy-Item -Path "./repositories/dxa-html-design/Gruntfile.js" -Destination "artifacts/dotnet/html/design" -Recurse -Force
Copy-Item -Path "./repositories/dxa-html-design/package.json" -Destination "artifacts/dotnet/html/design" -Recurse -Force
Copy-Item -Path "./repositories/dxa-html-design/README.md" -Destination "artifacts/dotnet/html/design" -Recurse -Force
if(Test-Path "./artifacts/dotnet/html-design.zip") {
   Remove-Item -LiteralPath "./artifacts/dotnet/html-design.zip" | Out-Null
}
Compress-Archive -Path "./artifacts/dotnet/html/design/*" -DestinationPath "artifacts/dotnet/cms/html-design.zip" -CompressionLevel Fastest -Force
if(Test-Path "./repositories/dxa-html-design/dist") {
   Copy-Item -Path "./repositories/dxa-html-design/dist/*" -Destination "artifacts/dotnet/html/whitelabel" -Recurse -Force
}

# Copy CIS artifacts (model-service standalone and in-process and udp-context-dxa-extension)
Write-Output "  copying CIS components ..."
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/cis" | Out-Null
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/cis/dxa-model-service" | Out-Null
if(Test-Path "./repositories/dxa-model-service/dxa-model-service-assembly/target/dxa-model-service.zip") {
   Expand-Archive -Path "./repositories/dxa-model-service/dxa-model-service-assembly/target/dxa-model-service.zip" -DestinationPath "artifacts/dotnet/cis/dxa-model-service" -Force
}


# Build final distribution package for DXA
$dxa_output_archive = "SDL.DXA.NET.$packageVersion.zip"
$collapsedVersion = $packageVersion -replace '[.]',''

Write-Output "  building final distribution package $dxa_output_archive ..."

# Remove old one if it exists
if(Test-Path "./artifacts/dotnet/$dxa_output_archive") {
   Remove-Item -LiteralPath "./artifacts/dotnet/$dxa_output_archive" | Out-Null
}

$exclude = @("nuget", "module_packages", "tmp")
$files = Get-ChildItem -Path "artifacts/dotnet" -Exclude $exclude
Compress-Archive -Path $files -DestinationPath "artifacts/dotnet/$dxa_output_archive" -CompressionLevel Fastest -Force

Write-Output "finished"