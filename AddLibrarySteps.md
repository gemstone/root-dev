### Create new Gemstone Library based on Template

1. Create a new repo based on [Gemstone.GemTem Template](https://github.com/gemstone/gemtem/generate)
2. Description should be similar to "Gemstone Security Library"
3. Once template is created, clone locally and run "RenameProject.bat" script
4. Type a PascalCase named like "Security" (no quotes)
5. After rename completes, delete "RenameProject.bat" file and "build /tools" folder in new repo
6. Check-in renamed project with a commit message like "Renamed template to Gemstone.Security"
7. Click on "Settings" from repo home page on GitHub, then
   a. Click "Edit" under Social preview and select "Upload an image..." and select "docs/img/gemstone-social-preview.png" from new repo
   b. Select "master branch / docs folder" under GitHub Pages Source
8. From repo home page on GitHub, click on "environment" then click on "View deployment"
   a. Copy URL for repo's GitHub pages site, should be similar to https://gemstone.github.io/security/
   b. Return to repo home page on GitHub and click the "Edit" button (will be to right of repo description, like ""Gemstone Security Library")
   c. Paste in GitHub pages URL under "Website" and click "Save"
9. Add new repo's git URL to the [clone-all](https://github.com/gemstone/root-dev/blob/master/clone-commands.txt) script source 

### Add New Library to Root Development Solution

1. Open "...\gemstone\root-dev\Gemstone.sln" from Visual Studio
2. Right-click on root "Gemstone" solution in "Solution Explorer" and select "Add > New Solution Folder" - name should match repo, PascalCase
3. Right-click on new repo solution folder and select "Add > Existing Project..." for each of the following C# project files similar to the following:
 a. "...\gemstone\security\src\gemstone.security\Gemstone.Security.csproj"
 b. "...\gemstone\security\src\UnitTests\Gemstone.Security.UnitTests.csproj"
4. Right-click on new repo solution folder and select "Add > Existing Item..." for "...\gemstone\security\docs\README.md"
5. Save solution and close Visual Studio
6. Open "...gemstone\root-dev\Gemstone.sln" in a text editor, e.g., Notepad++
7. Move the "Project" sections related to new repo to better alpha locations in file, Locate  best peer section for each:
   a. First section will look similar to:
        ```xml
        Project("{2150E333-8FDC-42A3-9474-1A3956D46DE8}") = "Security", "Security", "{AC074377-1D21-43EA-8CC6-280FD0B613AD}"
            ProjectSection(SolutionItems) = preProject
                ..\security\docs\README.md = ..\security\docs\README.md
            EndProjectSection
        EndProject
        ```
   b. Second section will look similar to:
        ```xml
        Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "Gemstone.Security", "..\security\src\Gemstone.Security\Gemstone.Security.csproj", "{1D1987D0-3CA1-4FAA-839A-F3510FA3A4A4}"
        EndProject
        Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "Gemstone.Security.UnitTests", "..\security\src\UnitTests\Gemstone.Security.UnitTests.csproj", "{3DAC8F1B-00F9-4D83-B155-249D093662BC}"
        EndProject
        ```
8. The root-dev solution is only for development purposes and Visual Studio will now have added all possible build configurations :-p
   a. Change the following:
        ```xml
        GlobalSection(SolutionConfigurationPlatforms) = preSolution
            Debug|Any CPU = Debug|Any CPU
            Development|Any CPU = Development|Any CPU
            Release|Any CPU = Release|Any CPU
        EndGlobalSection
        ```
   b. To a section with only the `Development` build configuration:
        ```xml
        GlobalSection(SolutionConfigurationPlatforms) = preSolution
            Development|Any CPU = Development|Any CPU
        EndGlobalSection
        ```
9. Now remove all solution configurations related to `Debug` and `Release` leaving only build configurations for `Development`, for example:
   a. The following:
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
   b. Would become:
        ```xml
        {721D3830-2CD7-45DE-A288-4FAF1D53CEC6}.Development|Any CPU.ActiveCfg = Development|Any CPU
        {721D3830-2CD7-45DE-A288-4FAF1D53CEC6}.Development|Any CPU.Build.0 = Development|Any CPU
        {41B5D5D3-9A97-48ED-840C-188A0CA95480}.Development|Any CPU.ActiveCfg = Development|Any CPU
        {41B5D5D3-9A97-48ED-840C-188A0CA95480}.Development|Any CPU.Build.0 = Development|Any CPU
        ```
10. Complete all removals:
    a. from `GlobalSection(ProjectConfigurationPlatforms) = postSolution`
    b. to associated `EndGlobalSection`.
11. Failing to remove the `Debug` and `Release` build configruations will cause new clones of `root-dev` to auto-open the `Debug` build configuration which causes NuGet `package` based references instead of desired `project` based references for cross-project debugging - defeating the purpose of the solution.
12. Re-open root-dev solution to verify that the manual changes succeeded
13. Commit updates with a message like "Added Gemstone.Security project to root-dev solution with project-based references"
14. Check-in updates

### Setup Continuous Integration Process for New Library

1. Project should be added to [AppVeyor](https://www.appveyor.com/) for build testing and configured with similar settings to another Gemstone project, e.g., [Gemstone.Common](https://ci.appveyor.com/project/ritchiecarroll/common)
   a. Once the AppVeyor project exists, click on "Badges" under "Settings" and copy the "Sample markdown code"
   b. Edit "docs/README.md" on the repo and update the "Build status" link with the copied markdown

### Updated Documentation for New Library

Note that build documentation will require [Sandcastle Help File Builder](https://github.com/EWSoftware/SHFB/releases) tools and visual studio plug-in.
Make sure this tool is installed before proceeding with documentation.

1. Update "docs/README.md" om the repo to properly describe library purpose (you can update class links later)
2. Assuming some code with XML comments has been added, open local solution file, e.g., "...\gemstone\security\src\Gemstone.Security.sln"
3. Build Gemstone library, then navigate to "docs/help" in the solution and build the "docgen" project
4. Monitor for warnings here - it will show you what documentation comments you may have missed
5. You can check out your locally compiled documentation by navigating to "...\gemstone\security\docs\help\" and opening "index.html" in a browser
6. Check-in documenation when complete, GitHub pages will auto-deploy updates within a couple minutes
7. After documentation has been posted, update "docs/README.md" home page again and add a few links to commonly used library classes
8. Note that the home page content of the automated documentation comes from the [shared-content](https://github.com/gemstone/shared-content) repo, if the new library should be added to the list,
   a. Add link to [common.tokens](https://github.com/gemstone/shared-content/blob/master/src/DocGen/common.tokens)
   b. Shared content udpates will be rolled into all Gemstone library repos as part of the nightly build process
