<img align="right" src="img/gemstone-wide-600.png" alt="gemstone logo">
<br/><br/><br/>

# root-dev


### GPA Gemstone Root Development Solution

This repository contains a multi-project Visual Studio solution used for development and debugging of related Gemstone libraries.

#### Relative Project Paths

The Visual Studio solution file [gemstone.sln](gemstone.sln) found in this respostitory references all Gemstone library projects with a common relative parent path. For example, assuming all cloned repositories (including this one) for the [gemstone](https://github.com/gemstone) organizational site have the same root folder, e.g., `C:\Projects\gemstone\` and each project folder matches the repo name, e.g., `C:\Projects\gemstone\threading\` for the [threading](https://github.com/gemstone/threading) library, then opening the `C:\Projects\gemstone\root-dev\gemstone.sln` from within Visual Studio will properly open and cross-reference all gemstone libraries.

#### Local Project References

The [gemstone.sln](gemstone.sln) uses a single build configuration called `Development`. The `Development` build configuration is used to associate local "project" references instead of NuGet-based "package" references that are only active when using this solution. For example, a project referencing both the [common](https://github.com/gemstone/common) and [expressions](https://github.com/gemstone/expressions) gemstone libraries would conditionally use local "project" references using the following in the `.csproj` file:

```
<ItemGroup>
  <ProjectReference Include="..\..\..\common\src\gemstone\gemstone.common.csproj" Condition="'$(Configuration)'=='Development'" />
  <PackageReference Include="gemstone.common" Version="1.0.0" Condition="'$(Configuration)'!='Development'" />

  <ProjectReference Include="..\..\..\expressions\src\gemstone.expressions\gemstone.expressions.csproj" Condition="'$(Configuration)'=='Development'" />
  <PackageReference Include="gemstone.expressions" Version="1.0.0" Condition="'$(Configuration)'!='Development'" />
</ItemGroup>
```

#### Managing git for Multiple Repositories

In this example, dependencies are referenced as project references only for the `Development` build configuration, otherwise any other build configuration, e.g., the common `Release` or `Debug`, will reference the associated NuGet package.

When developing using the [gemstone.sln](gemstone.sln) be mindful that only one GitHub repository can be active at once from within Visual Studio. To check-in changes to a particular repo, click the :electric_plug: icon for "Manage Connections" on the "Team Explorer" window. When the "Manage Connections" panel is opened, navigate to the "Local Git Repositories" list visible at the bottom of the panel, then right-click on desired repo and select "Open". The selected repo will now be active, procede as normal for GitHub operations on that project repository.
