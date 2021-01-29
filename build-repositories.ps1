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
   [string]$version = "0.0.0.0"
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


CloneRepo "dxa-web-application-dotnet"
CloneRepo "dxa-modules"
CloneRepo "dxa-content-management"
CloneRepo "graphql-client-dotnet"

BuildDotnet "./repositories/dxa-web-application-dotnet/ciBuild.proj" $true
BuildDotnet "./repositories/dxa-content-management/ciBuild.proj" $true
BuildDotnet "./repositories/dxa-modules/webapp-net/ciBuild.proj" $true
BuildDotnet "./repositories/graphql-client-dotnet/net/Build.csproj" $false

# Copy artifacts out to /artifacts folder
# * all nuget packages
# * all artifacts generated from each repository
# * build zip(s)
