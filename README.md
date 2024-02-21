RWS Digital Experience Accelerator Suite
===

Prerequisites
-------------
- Visual Studio 2019
- .NET Framework 4.5.2 (DXA 1.8)
- .NET Framework 4.6.2 (DXA 2.2)
- .NET Framework 4.8 (DXA 2.3 +)
- Maven 3.2+
- Maven should be available in the system PATH
- Java 1.8

About
-----
The dxa-suite repository contains tools and scripts required to build all DXA repositories and package up the artifacts from each repository into a form that is releasable or easy to install.

The main script 'build-repositories.ps1' lets you clone/build all the repositories given a specified branch name, tag with a version number and generate all artifacts in the /artifacts folder.

e.g,
```
PS> .\build-repositories -version 2.2.9.0 -buildType java
```

### Default behavior
* the dxa-model-service will not be part of the final artifact unless `-buildModelService $true` is present

The generated artifacts will be output into an /artifacts folder with the following structure:

```
/artifacts
    /dotnet
        /cis
            Model service (standalone, in-process)
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
            Model service (standalone, in-process)
        /cms
            CMS content, import/export scripts, custom resolver, UI extension and template building blocks
        /html
            Whitelabel html design
        /ImportExport
            Scripts/dependencies for working with CM core services for import
        /module_packages
            All DXA modules packaged individually in zip archives. Self contained with CMS content/import scripts.
        /modules
            Only Core/GoogleAnalytics modules packaged individually in zip archives. Self contained with only CMS content/import scripts.
        /web/installer
            A tool for creating a war (web application archive) of DXA                
        
        SDL.DXA.Java.x.y.z.zip (full archive for releasing on github)
```

Support
---------------
At RWS we take your investment in Digital Experience very seriously, if you encounter any issues with the Digital Experience Accelerator, please use one of the following channels:

- Report issues directly in [this repository](https://github.com/rws/dxa-suite/issues)
- Ask questions 24/7 on the RWS Tridion Community at https://tridion.stackexchange.com
- Contact RWS Professional Services for DXA release management support packages to accelerate your support requirements


License
-------
Copyright (c) 2014-2024 RWS Group.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
