SDL Digital Experience Accelerator Suite
===

Prerequisites
-------------
For building .NET repositories you must have the following installed:
- Visual Studio 2019
- .NET Framework 4.5.2 (DXA 1.8)
- .NET Framework 4.6.2 (DXA 2.0 +)

For building Java repositories you must have the following installed:
- Maven 3.2+
- Maven should be available in the system PATH
- Java 1.8

About
-----
The dxa-suite repository contains tools and scripts required to build all DXA repositories and package up the artifacts from each repository into a form that is releasable or easy to install.

The main script 'build-repositories.ps1' lets you clone/build all the repositories given a specified branch name, tag with a version number and generate all artifacts in the /artifacts folder.

i.e,
```
PS> .\build-repositories -clean $true -clone $true -build $true -buildModelService $true -branch release/2.2 -webappJavaBranch develop -version 2.2.9.0
```

The generated artifacts will be output into an /artifacts folder with the following structure:

```
/artifacts
    /dotnet
        /cis
            Model service (standalone, in-process) and dxa extension
        /cms
            CMS content, import/export scripts, custom resolver, UI extension and template building blocks
        /html
            Whitelabel html design
        /ImportExport
            Scripts/dependencies for working with CM core services for import
        /module_packages
            All DXA modules packaged individually in zip archives. Self contained with install scripts and CMS content/import scripts.
        /modules
            Extracted modules for easy installation
        /nuget
            All nuget packages that can be published to nuget.org
        /web
            Example web application                
        
        SDL.DXA.NET.x.y.z.zip (full archive for releasing on github)
    /java
        /cis
            Model service (standalone, in-process) and dxa extension
        /cms
            CMS content, import/export scripts, custom resolver, UI extension and template building blocks
        /html
            Whitelabel html design
        /ImportExport
            Scripts/dependencies for working with CM core services for import
        /modules
            All DXA modules packaged individually in zip archives. Self contained with install scripts and CMS content/import scripts.
        /nuget
            All nuget packages that can be published to nuget.org
        /web
            Example web application                
        
        SDL.DXA.Java.x.y.z.zip (full archive for releasing on github)
```

Support
---------------
At SDL we take your investment in Digital Experience very seriously, if you encounter any issues with the Digital Experience Accelerator, please use one of the following channels:

- Report issues directly in [this repository](https://github.com/sdl/dxa-suite/issues)
- Ask questions 24/7 on the SDL Tridion Community at https://tridion.stackexchange.com
- Contact SDL Professional Services for DXA release management support packages to accelerate your support requirements


License
-------
Copyright (c) 2014-2021 SDL Group.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.