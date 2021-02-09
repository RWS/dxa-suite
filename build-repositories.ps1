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
   [Parameter(Mandatory=$false, HelpMessage="Github model-service branch name")]
   [string]$modelServiceBranch = "develop",

   # The Github branch name to clone
   [Parameter(Mandatory=$false, HelpMessage="Github dxa-web-application-java branch name")]
   [string]$webappJavaBranch = "develop",

   # The Github branch name to clone
   [Parameter(Mandatory=$false, HelpMessage="Force update if repository already cloned")]
   [bool]$update = $false,

   # True if we should first clone the repositories (they may already be cloned from a previous run)
   [Parameter(Mandatory=$false, HelpMessage="Indicate if this script should first clone the repositories.")]
   [bool]$clone = $true,

   # True if we should build the repositories (they may already be built from a previous run)
   [Parameter(Mandatory=$false, HelpMessage="Indicate if this script should build the repositories.")]
   [bool]$build = $true,

   # True if we should build the model-service
   [Parameter(Mandatory=$false, HelpMessage="Indicate if this script should build the model-service.")]
   [bool]$buildModelService = $false,

   # True if we should clean out all previously cloned repositories and built artifacts
   [Parameter(Mandatory=$false, HelpMessage="Indicate if this script should clean out any previously cloned repositories or built artifacts.")]
   [bool]$clean = $false
)


#Terminate script on first occurred exception
$ErrorActionPreference = "Stop"

$PSScriptDir = Split-Path $MyInvocation.MyCommand.Path

# Import msbuild helper module
Import-Module -Name "$PSScriptDir/utils/Invoke-MsBuild.psm1"

function CloneRepo($repo, $branchName) {
   Write-Output "> Cloning github repository $repo ..."
   $dst = "./repositories/$repo"
   $github_repo_url = "https://github.com/sdl"
   if(!(Test-Path -Path $dst)) {
      $cmd = "git clone --branch $branchName --recursive $github_repo_url/$repo.git ./repositories/$repo"
      Invoke-Expression $cmd
   }
   else {    
      if($update) {
         Write-Output "> Updating existing cloned repository ..."
         Invoke-Expression "git checkout -- ." 
         Invoke-Expression "git checkout $branchName"         
      } else {
         Write-Output "> Already cloned repository ..."
         Invoke-Expression "git checkout $branchName"
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

function BuildJava($pomFileLocation, $buildCmd) {
   Push-Location
   Set-Location $pomFileLocation
   Invoke-Expression "$buildCmd"
   Pop-Location
}

# Sanity check : if you are building a release branch and the major version component is not the same as that specified by the version param to script then
# exit
$versionParts = $version.split('.') | % {iex $_}
if($branch.StartsWith("release/")) {
    $branchVersionParts = $branch.Replace("release/", "").split('.') | % {iex $_}
    if($branchVersionParts[0] -ne $versionParts[0]) {
        Write-Output "You are attempting to build a release branch with a different major version as specified by the version parameter !"
        Exit
    }
}

if($branch -like "develop" -and $version.StartsWith("1.")) {
   Write-Output "You are trying to build the develop branch and tag to 1.x.. This isnt a good idea!"
   Exit
}

if($branch -like "release/1." -and $versionParts[0] -gt 1) {
   Write-Output "You are trying to build a release/1.x branch and tag with a major version greater than 1 !"
   Exit
}

$isLegacy = $branch.StartsWith("release/1.") -or $version.StartsWith("1.")

if($clean) {
   Write-Output "Cleaning previously cloned+built repositories & artifacts"
   if(Test-Path "./artifacts") {
      Remove-Item -LiteralPath "./artifacts" -Recurse -Force | Out-Null
   }   

   if(Test-Path "./repositories") {
      Remove-Item -LiteralPath "./repositories" -Recurse -Force | Out-Null
   }
   Write-Output "Cleaning is done."
   Write-Output ""
   Write-Output ""
}

# Clone all dotnet/java repositories required
if($clone) {
   Write-Output ""
   Write-Output "Cloning github .NET/Java repository ..."
   CloneRepo "dxa-modules" "$branch"

   Write-Output ""
   Write-Output "Cloning github .NET repositories ..."
   CloneRepo "dxa-web-application-dotnet" "$branch"
   CloneRepo "dxa-content-management" "$branch"
   CloneRepo "dxa-html-design" "$branch"
   if(!$isLegacy) {
      # model-service & graphql client does not exist in DXA 1.x (legacy DXA versions)
      CloneRepo "graphql-client-dotnet" "$branch"
   }
   Write-Output ""
   Write-Output "Cloning github Java repositories ..."
   CloneRepo "dxa-web-application-java" "$webappJavaBranch"
   if(!$isLegacy) {
      if($buildModelService)
      {
         CloneRepo "dxa-model-service" "$modelServiceBranch"
      }
      CloneRepo "graphql-client-java" "$modelServiceBranch"
   }
   Write-Output "Cloning is done."
   Write-Output ""
   Write-Output ""
}

# Build each dotnet repository and generate artifacts
if($build) {
   Write-Output "Building .NET (DXA framework) ..."
   BuildDotnet "./repositories/dxa-web-application-dotnet/ciBuild.proj" $true
   Write-Output "Building .NET (CM) ..."
   BuildDotnet "./repositories/dxa-content-management/ciBuild.proj" $true
   Write-Output "Building .NET (DXA modules) ..."
   BuildDotnet "./repositories/dxa-modules/webapp-net/ciBuild.proj" $true

   if(!$isLegacy) {
      Write-Output "Building .NET (GraphQL client) ..."
      BuildDotnet "./repositories/graphql-client-dotnet/net/Build.csproj" $false
   }
   Write-Output ""
   Write-Output ""
   Write-Output "Building Java (DXA framework) ..."
   BuildJava "./repositories/dxa-web-application-java" 'mvn clean install -DskipTests'
   Write-Output "Building Java (DXA modules) ..."
   BuildJava "./repositories/dxa-modules/webapp-java" 'mvn clean install -DskipTests'

   if(!$isLegacy) {
      if($buildModelService) {
         Write-Output "Building Java (DXA model service) ..."
         BuildJava "./repositories/dxa-model-service" 'mvn clean install -DskipTests'
         #BuildJava "./repositories/dxa-model-service" 'mvn clean install -DskipTests -P in-process'
      }
      Write-Output "Building PCA (GraphQL) client ..."
      BuildJava "./repositories/graphql-client-java" 'mvn clean install -DskipTests'
   }

   Write-Output "Building is done."
   Write-Output ""
   Write-Output ""
}

$packageVersion = $version.Substring(0, $version.LastIndexOf("."))

# Copy artifacts out to /artifacts folder
# * all artifacts generated from each repository
Write-Output "Packaging up Java artifacts ..."
Write-Output "  \artifacts\java will contain all DXA java artifacts ..."

if(Test-Path -Path "./artifacts/java/tmp") {
   Remove-Item -LiteralPath "./artifacts/java/tmp" -Force -Recurse | Out-Null
}

# Copy all modules
Write-Output "  copying modules ..."
if(Test-Path -Path "./artifacts/java/module_packages") {
   Remove-Item -LiteralPath "./artifacts/java/module_packages" -Force -Recurse | Out-Null
}
New-Item -ItemType Directory -Force -Path "artifacts/java/module_packages" | Out-Null
$dir = Get-ChildItem "./repositories/dxa-modules/webapp-java/"
$dir | ForEach-Object {
   $sourcePath = $_.FullName + "/target/"
   if (Test-Path -Path $sourcePath)
   {
      Get-ChildItem $sourcePath -Filter *.jar |
              Foreach-Object {
                 $targetPath = "artifacts/java/module_packages/" + $_.Name
                 Write-Output $_.FullName

                 Copy-Item -Path $sourcePath -Destination $targetPath
              }
   }
}

Write-Output "Processing DXA Model Service  ..."
New-Item -ItemType Directory -Force -Path "artifacts/java/cis/dxa-model-service/" | Out-Null
if (Test-Path -Path "./artifacts/java/cis/dxa-model-service/")
{
   Remove-Item -LiteralPath "./artifacts/java/cis/dxa-model-service/" -Force -Recurse | Out-Null
}

Write-Output "Unpacking DXA MS standalone ..."
$dir = "./repositories/dxa-model-service/dxa-model-service-assembly/target/dxa-model-service.zip"
Expand-Archive -Path $dir -DestinationPath "artifacts/java/tmp/ms-assembly/" -Force
Move-Item -Path "artifacts/java/tmp/ms-assembly/" -Destination "artifacts/java/cis/dxa-model-service/"

Write-Output "Unpacking DXA MS standalone-in-process ..."
$dir = "./repositories/dxa-model-service/dxa-model-service-assembly-in-process/target/dxa-model-service.zip"
Expand-Archive -Path $dir -DestinationPath "artifacts/java/tmp/ms-assembly/" -Force
Move-Item -Path "artifacts/java/tmp/ms-assembly/standalone-in-process/" -Destination "artifacts/java/cis/dxa-model-service/"

Remove-Item -LiteralPath "./artifacts/java/tmp/ms-assembly/" -Force -Recurse | Out-Null

Write-Output "Unpacking UDP Content Service DXA extension ..."
New-Item -ItemType Directory -Force -Path "artifacts/java/cis/udp-content-dxa-extension/" | Out-Null
Write-Warning "udp-content-dxa-extension.jar is not provided FTM"

Write-Output "Processing DXA-suite web installer ..."
Write-Warning "/web/installer/ is not provided FTM"
# \SDL DXA Java 2.2\web\installer\

Write-Output "DXA MS prepared in /cis"
Write-Output ""
Write-Output ""


Remove-Item -LiteralPath "./artifacts/java/tmp/" -Force -Recurse | Out-Null
$exclude = @("tmp")
$files = Get-ChildItem -Path "artifacts/java" -Exclude $exclude
$dxa_output_archive = "SDL.DXA.Java.$packageVersion.zip"
Compress-Archive -Path $files -DestinationPath "artifacts/java/$dxa_output_archive" -CompressionLevel Fastest -Force

Write-Output "Packaging Java is done."
Write-Output ""
Write-Output ""


# Copy artifacts out to /artifacts folder
# * all nuget packages
# * all artifacts generated from each repository
# * build zip(s)
Write-Output "Packaging up .NET artifacts ..."
Write-Output "  \artifacts\dotnet will contain all DXA dotnet artifacts ..."

if (Test-Path -Path "./artifacts/dotnet/tmp")
{
   Remove-Item -LiteralPath "./artifacts/dotnet/tmp" -Force -Recurse | Out-Null
}

# Copy nuget packages from repositories
Write-Output "  copying nuget packages ..."
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/nuget" | Out-Null
if (Test-Path -Path "./repositories/dxa-content-management/_nuget")
{
   Copy-Item -Path "./repositories/dxa-content-management/_nuget/*.$packageVersion*.nupkg" -Destination "artifacts/dotnet/nuget"
}
if (Test-Path -Path "./repositories/dxa-web-application-dotnet/_nuget")
{
   Copy-Item -Path "./repositories/dxa-web-application-dotnet/_nuget/*.$packageVersion*.nupkg" -Destination "artifacts/dotnet/nuget"
}
if (Test-Path -Path "./repositories/dxa-web-application-dotnet/_nuget/Sdl.Dxa.Framework")
{
   Copy-Item -Path "./repositories/dxa-web-application-dotnet/_nuget/Sdl.Dxa.Framework/*.$packageVersion*.nupkg" -Destination "artifacts/dotnet/nuget"
}
if (Test-Path -Path "./repositories/graphql-client-dotnet/net/_nuget")
{
   Copy-Item -Path "./repositories/graphql-client-dotnet/net/_nuget/*.$packageVersion*.nupkg" -Destination "artifacts/dotnet/nuget"
}


# Copy all modules
Write-Output "  copying modules ..."
New-Item -ItemType Directory -Force -Path "artifacts/dotnet/module_packages" | Out-Null
if (Test-Path -Path "./repositories/dxa-modules/webapp-net/dist")
{
   Copy-Item -Path "./repositories/dxa-modules/webapp-net/dist/*.$packageVersion*.zip" -Destination "artifacts/dotnet/module_packages" -Recurse -Force
}

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
if (Test-Path -Path "./artifacts/dotnet/tmp")
{
   Remove-Item -LiteralPath "./artifacts/dotnet/tmp" -Force -Recurse | Out-Null
}

# Copy DXA web application
if (Test-Path -Path "./repositories/dxa-web-application-dotnet/dist/web")
{
   Write-Output "  copying DXA web application ..."
   New-Item -ItemType Directory -Force -Path "artifacts/dotnet/web" | Out-Null
   Copy-Item -Path "./repositories/dxa-web-application-dotnet/dist/web/*" -Destination "artifacts/dotnet/web" -Recurse -Force
}


# Copy CMS side artifacts (TBBs, Resolver, CMS content, Import/Export scripts)
if (Test-Path -Path "./repositories/dxa-content-management/dist")
{
   Write-Output "  copying CMS components ..."
   New-Item -ItemType Directory -Force -Path "artifacts/dotnet/cms" | Out-Null
   New-Item -ItemType Directory -Force -Path "artifacts/dotnet/ImportExport" | Out-Null
   Copy-Item -Path "./repositories/dxa-content-management/dist/cms/*" -Destination "artifacts/dotnet/cms" -Recurse -Force
   Copy-Item -Path "./repositories/dxa-content-management/dist/ImportExport/*" -Destination "artifacts/dotnet/ImportExport" -Recurse -Force
}

# Copy html design src
if (Test-Path -Path "./repositories/dxa-html-design")
{
   Write-Output "  copying html design ..."
   New-Item -ItemType Directory -Force -Path "artifacts/dotnet/html" | Out-Null
   New-Item -ItemType Directory -Force -Path "artifacts/dotnet/html/design" | Out-Null
   New-Item -ItemType Directory -Force -Path "artifacts/dotnet/html/design/src" | Out-Null
   New-Item -ItemType Directory -Force -Path "artifacts/dotnet/html/whitelabel" | Out-Null
   Copy-Item -Path "./repositories/dxa-html-design/src/*" -Destination "artifacts/dotnet/html/design/src" -Recurse -Force -ErrorAction SilentlyContinue
   Copy-Item -Path "./repositories/dxa-html-design/.bowerrc" -Destination "artifacts/dotnet/html/design" -Recurse -Force -ErrorAction SilentlyContinue
   Copy-Item -Path "./repositories/dxa-html-design/bower.json" -Destination "artifacts/dotnet/html/design" -Recurse -Force -ErrorAction SilentlyContinue
   Copy-Item -Path "./repositories/dxa-html-design/BUILD.md" -Destination "artifacts/dotnet/html/design" -Recurse -Force -ErrorAction SilentlyContinue
   Copy-Item -Path "./repositories/dxa-html-design/Gruntfile.js" -Destination "artifacts/dotnet/html/design" -Recurse -Force -ErrorAction SilentlyContinue
   Copy-Item -Path "./repositories/dxa-html-design/package.json" -Destination "artifacts/dotnet/html/design" -Recurse -Force -ErrorAction SilentlyContinue
   Copy-Item -Path "./repositories/dxa-html-design/README.md" -Destination "artifacts/dotnet/html/design" -Recurse -Force -ErrorAction SilentlyContinue
   if (Test-Path "./artifacts/dotnet/html-design.zip")
   {
      Remove-Item -LiteralPath "./artifacts/dotnet/html-design.zip" | Out-Null
   }
   Compress-Archive -Path "./artifacts/dotnet/html/design/*" -DestinationPath "artifacts/dotnet/cms/html-design.zip" -CompressionLevel Fastest -Force
   if (Test-Path "./repositories/dxa-html-design/dist")
   {
      Copy-Item -Path "./repositories/dxa-html-design/dist/*" -Destination "artifacts/dotnet/html/whitelabel" -Recurse -Force
   }
}

# Copy CIS artifacts (model-service standalone and in-process and udp-context-dxa-extension)
# only for non-legacy (DXA 2.x+)
if (!$isLegacy)
{
   if (Test-Path "./repositories/dxa-model-service/dxa-model-service-assembly/target/dxa-model-service.zip")
   {
      Write-Output "  copying CIS components ..."
      New-Item -ItemType Directory -Force -Path "artifacts/dotnet/cis" | Out-Null
      New-Item -ItemType Directory -Force -Path "artifacts/dotnet/cis/dxa-model-service" | Out-Null
      Expand-Archive -Path "./repositories/dxa-model-service/dxa-model-service-assembly/target/dxa-model-service.zip" -DestinationPath "artifacts/dotnet/cis/dxa-model-service" -Force
   }
}

# Build final distribution package for DXA
$dxa_output_archive = "SDL.DXA.NET.$packageVersion.zip"
$collapsedVersion = $packageVersion -replace '[.]', ''

Write-Output "  building final distribution package $dxa_output_archive ..."

# Remove old one if it exists
if (Test-Path "./artifacts/dotnet/$dxa_output_archive")
{
   Remove-Item -LiteralPath "./artifacts/dotnet/$dxa_output_archive" | Out-Null
}

$exclude = @("nuget", "module_packages", "tmp")
$files = Get-ChildItem -Path "artifacts/dotnet" -Exclude $exclude
Compress-Archive -Path $files -DestinationPath "artifacts/dotnet/$dxa_output_archive" -CompressionLevel Fastest -Force

Write-Output "Packaging .NET is done."
Write-Output ""
Write-Output ""


