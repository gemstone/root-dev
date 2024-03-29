# Adding a New Gemstone Library

### Philosophies

As its name infers, the Gemstone Libraries site is for "libraries", i.e., sets of reusable code that can be packaged and referenced by other libraries and applications. As such, an "application" project is not commonly a suitable project type. However, an exception to this rule is that the application is directly related to a particular Gemstone library; case in point: [`pqdif-explorer`](https://github.com/gemstone/pqdif-explorer). Also, it is certainly fine if libraries contain helper applications as part of their source code, but the primary project should normally be a library, i.e., `<OutputType>Library</OutputType>`.

Each new library in Gemstone should be as standalone as possible to make it readily accessible as a package and usable by a variety of projects. It is OK to reference other Gemstone libraries as well as other packages, but this should be limited to exactly what is needed. External package sources should be limited to either NuGet or GitHub.

When choosing external packages to reference, care should be taken to evaluate the source quality. Consequently, only libraries that are open source should be used so that source quality _can_ be evaluated. Additionally, make sure the license of referenced packages is compatible with the [Gemstone MIT license]( https://github.com/gemstone/root-dev/blob/master/LICENSE).

Currently Gemstone libraries target [.NET Standard 2.1]( https://dotnet.microsoft.com/platform/dotnet-standard), in addition to .NET 7.0, to make the library more widely accessible. However, it is expected that this code-base will eventually only target newer versions of .NET and the standard libraries will be abandoned so code can properly accommodate new language and runtime features that may not be available to .NET Standard.

Ideally Gemstone libraries should [target multiple frameworks]( https://docs.microsoft.com/en-us/dotnet/standard/frameworks) to accommodate more deployment options. As new C# and/or .NET features become available that improve a library's security, performance, or portability, dropping older _less used_ target frameworks should be preferred to using [`#if/#else/endif` preprocessor directives]( https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/preprocessor-directives/preprocessor-if) for multiple code implementations, as this becomes more difficult to maintain. If the change separates one or more _highly used_ framework targets, use your best judgment, as a primary goal is always to make the library widely usable.

### Create new Gemstone Library based on Template
 
1. Create a new repo based on [Gemstone.GemTem Template](https://github.com/gemstone/gemtem/generate)
2. Description should be similar to "Gemstone Security Library"
3. Once template is created, clone locally and run "RenameProject.bat" script
4. Type a PascalCase named like "Security" (no quotes)
5. After renaming completes, delete "RenameProject.bat" file and "build /tools" folder in new repo
6. Commit renamed project with a message like "Renamed template to Gemstone.Security", and push to GitHub
7. Click on "Settings" from repo home page on GitHub, then
   1. Click "Edit" under Social preview and select "Upload an image..." and select "docs/img/gemstone-social-preview.png" from new repo
   2. Select "master branch / docs folder" under GitHub Pages Source
   3. Click "Collaborators & teams" tab on the left, then click "Add a team" and select "Dev Team" from the list
   4. Change the "Dev Team" permission level to "Write" - this gives developers write access to this repo
8. From repo home page on GitHub, click on "environment" then click on "View deployment"
   1. Copy URL for repo's GitHub pages site, should be similar to https://gemstone.github.io/security/
   2. Return to repo home page on GitHub and click the "Edit" button (will be to right of repo description, like "Gemstone Security Library")
   3. Paste in GitHub pages URL under "Website" and click "Save"
9. Add new repository name, e.g., `security`, to [repos.txt](https://github.com/gemstone/root-dev/blob/master/repos.txt) in build dependency order
 
### Add New Library to Root Development Solution
 
1. Open "...\gemstone\root-dev\Gemstone.sln" from Visual Studio
2. Right-click on root "Gemstone" solution in "Solution Explorer" and select "Add > New Solution Folder" - name should match repo, PascalCase
3. Right-click on new repo solution folder and select "Add > Existing Project..." for each of the following C# project files similar to the following:
   1. "...\gemstone\security\src\gemstone.security\Gemstone.Security.csproj"
   2. "...\gemstone\security\src\UnitTests\Gemstone.Security.UnitTests.csproj"
4. Right-click on new repo solution folder and select "Add > Existing Item..." for "...\gemstone\security\docs\README.md". Repeat for:
   1. "...\gemstone\security\appveyor.yml"
   2. "...\gemstone\security\.github\workflows\codeql-analysis.yml"
5. Now remove the `Debug` and `Release` configurations that were added to the solution:
   1. Open the `Configuration Manager...` from Visual Studio
   2. Select the drop-down for "Active solution configuration:" and select `<Edit...>`
   3. Remove the `Debug` and `Release` configurations, leaving only `Development`
   4. Save configuration updates and save Visual Studio
6. Failing to remove the `Debug` and `Release` build configurations will cause new clones of `root-dev` to auto-open the `Debug` build configuration which causes NuGet `package` based references instead of desired `project` based references for cross-project debugging - defeating the purpose of the solution. See [Relative Project Paths](README.md#relative-project-paths) info.
7. Commit updates with a message like "Added Gemstone.Security project to root-dev solution with project-based references"
8. Check-in updates
 
### Setup Continuous Integration Process for New Library
 
1. Project should be added to [AppVeyor](https://www.appveyor.com/) for build testing and configured with similar settings to another Gemstone project, e.g., [Gemstone.Common](https://ci.appveyor.com/project/ritchiecarroll/common)
   1. Once the AppVeyor project exists, click on "Badges" under "Settings" and copy the "Sample markdown code"
   2. Edit "docs/README.md" on the repo and update the "Build status" link with the copied markdown
 
### Updated Documentation for New Library
 
Note that build documentation will require [Sandcastle Help File Builder](https://github.com/EWSoftware/SHFB/releases) tools and visual studio plug-in.
Make sure this tool is installed before proceeding with documentation.
 
1. Update "docs/README.md" in the repo to properly describe library purpose (you can update class links later)
2. Assuming some code with XML comments has been added, open local solution file, e.g., "...\gemstone\security\src\Gemstone.Security.sln"
3. Build Gemstone library, then navigate to "docs/help" in the solution and build the "docgen" project
4. Monitor for warnings here - it will show you what documentation comments you may have missed
5. You can check out your locally compiled documentation by navigating to "...\gemstone\security\docs\help\" and opening "index.html" in a browser
6. Check-in documentation when complete, GitHub pages will auto-deploy updates within a couple minutes
7. After documentation has been posted, update "docs/README.md" home page again and add a few links to commonly used library classes
8. Note that the home page content of the automated documentation comes from the [shared-content](https://github.com/gemstone/shared-content) repo, if the new library should be added to the list,
   1. Add link to [common.tokens](https://github.com/gemstone/shared-content/blob/master/src/DocGen/common.tokens)
   2. Shared content updates will be rolled into all Gemstone library repos as part of the nightly build process

#### Old Steps for Manual Removal of Debug/Release Build Configurations:

1. Save solution and close Visual Studio
2. Open "...gemstone\root-dev\Gemstone.sln" in a text editor, e.g., Notepad++
3. Move the "Project" sections related to new repo to better alpha locations in file. Locate best peer section for each:
   1. First section will look similar to:   
   ```xml
        Project("{2150E333-8FDC-42A3-9474-1A3956D46DE8}") = "Security", "Security", "{AC074377-1D21-43EA-8CC6-280FD0B613AD}"
            ProjectSection(SolutionItems) = preProject
                ..\security\docs\README.md = ..\security\docs\README.md
            EndProjectSection
        EndProject
   ```   
   2. Second section will look similar to:   
   ```xml
        Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "Gemstone.Security", "..\security\src\Gemstone.Security\Gemstone.Security.csproj", "{1D1987D0-3CA1-4FAA-839A-F3510FA3A4A4}"
        EndProject
        Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "Gemstone.Security.UnitTests", "..\security\src\UnitTests\Gemstone.Security.UnitTests.csproj", "{3DAC8F1B-00F9-4D83-B155-249D093662BC}"
        EndProject
   ```
4. The root-dev solution is only for development purposes and Visual Studio will now have added all possible build configurations :-p
   1. Change the following:   
   ```xml
        GlobalSection(SolutionConfigurationPlatforms) = preSolution
            Debug|Any CPU = Debug|Any CPU
            Development|Any CPU = Development|Any CPU
            Release|Any CPU = Release|Any CPU
        EndGlobalSection
   ```   
   2. To a section with only the `Development` build configuration:
   ```xml
        GlobalSection(SolutionConfigurationPlatforms) = preSolution
            Development|Any CPU = Development|Any CPU
        EndGlobalSection
   ```   
5. Now remove all solution configurations related to `Debug` and `Release` leaving only build configurations for `Development`, for example:
   1. The following:
   ```xml
        {721D3830-2CD7-45DE-A288-4FAF1D53CEC6}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
        {721D3830-2CD7-45DE-A288-4FAF1D53CEC6}.Debug|Any CPU.Build.0 = Debug|Any CPU
        {721D3830-2CD7-45DE-A288-4FAF1D53CEC6}.Development|Any CPU.ActiveCfg = Development|Any CPU
        {721D3830-2CD7-45DE-A288-4FAF1D53CEC6}.Development|Any CPU.Build.0 = Development|Any CPU
        {721D3830-2CD7-45DE-A288-4FAF1D53CEC6}.Release|Any CPU.ActiveCfg = Release|Any CPU
        {721D3830-2CD7-45DE-A288-4FAF1D53CEC6}.Release|Any CPU.Build.0 = Release|Any CPU
        {41B5D5D3-9A97-48ED-840C-188A0CA95480}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
        {41B5D5D3-9A97-48ED-840C-188A0CA95480}.Debug|Any CPU.Build.0 = Debug|Any CPU
        {41B5D5D3-9A97-48ED-840C-188A0CA95480}.Development|Any CPU.ActiveCfg = Development|Any CPU
        {41B5D5D3-9A97-48ED-840C-188A0CA95480}.Development|Any CPU.Build.0 = Development|Any CPU
   ```   
   2. Would become:
   ```xml
        {721D3830-2CD7-45DE-A288-4FAF1D53CEC6}.Development|Any CPU.ActiveCfg = Development|Any CPU
        {721D3830-2CD7-45DE-A288-4FAF1D53CEC6}.Development|Any CPU.Build.0 = Development|Any CPU
        {41B5D5D3-9A97-48ED-840C-188A0CA95480}.Development|Any CPU.ActiveCfg = Development|Any CPU
        {41B5D5D3-9A97-48ED-840C-188A0CA95480}.Development|Any CPU.Build.0 = Development|Any CPU
   ```
6. Complete all `Debug` and `Release` removals:
    1. From `GlobalSection(ProjectConfigurationPlatforms) = postSolution`
    2. To associated `EndGlobalSection`
7. Re-open `root-dev` "Gemstone.sln" solution file to verify that the manual changes succeeded