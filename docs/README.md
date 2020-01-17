<img align="right" src="img/gemstone-wide-600.png" alt="gemstone logo">
<br/><br/><br/>

# root-dev

The [Gemstone Libraries](https://github.com/gemstone), maintained by the [Grid Protection Alliance](https://gridprotectionalliance.org/) (GPA), are a collection of useful open source .NET code based on [continuous development since 2004](https://github.com/GridProtectionAlliance/gsf/graphs/contributors). These libraries represent a focused re-envisioning of the best code, i.e., the "gems", from the [Grid Solutions Framework](https://github.com/GridProtectionAlliance/gsf/) (GSF), which has long been in use by various open source projects and electric power utilities worldwide.

The Gemstone Libraries contain a large variety of code useful for any .NET project with of hundreds of class libraries that extend or expand the functionality provided with .NET, including many tools and protocol parsers that are useful for the electric power industry.

* **Learn:** _To start learning about the code available in the Gemstone Libraries, start with documentation for **[gemstone/common](https://gemstone.github.io/common/)**._

* **Use:** _To start using the Gemstone Libraries in an existing .NET application, reference one of the packages from **[NuGet](https://www.nuget.org/packages?q=Gemstone)** or **[GitHub](https://github.com/orgs/gemstone/packages)**._

* **Develop:** _To compile or develop with the Gemstone Libraries at a source code level, start with the following instructions:_

### GPA Gemstone Root Development Solution

This repository contains a multi-project Visual Studio solution used for development and debugging of related Gemstone libraries.

#### Getting Started

To begin development on Gemstone libraries, clone [this](https://github.com/gemstone/root-dev.git) repository first - it is recommended to put all the Gemstone library repositories into their own folder (see [Relative Project Paths](#relative-project-paths) below). For example, if a folder was created called `C:\Projects\gemstone\` to hold the Gemstone repositories, then after cloning, this repo would be in `C:\Projects\gemstone\root-dev`. After cloning, run the [clone-all.cmd](https://github.com/gemstone/root-dev/blob/master/clone-all.cmd) (or [clone-all.sh](https://github.com/gemstone/root-dev/blob/master/clone-all.sh) in POSIX environments) script to clone all other repositories.

Two other scripts, [pull-all.cmd](https://github.com/gemstone/root-dev/blob/master/pull-all.cmd) and [push-all.cmd](https://github.com/gemstone/root-dev/blob/master/push-all.cmd) (or [pull-all.sh](https://github.com/gemstone/root-dev/blob/master/pull-all.sh) and [push-all.sh](https://github.com/gemstone/root-dev/blob/master/push-all.sh) in POSIX environments) exist to assist with multi-project git repository operations.

To better ensure acceptance of pull requests, be sure to read the [coding style](https://gemstone.github.io/common/coding-style) document.

To add a new Gemstone library repsository, see the [Add Library Steps](AddLibrarySteps.md).

#### Relative Project Paths

The Visual Studio solution file [Gemstone.sln](https://github.com/gemstone/root-dev/blob/master/Gemstone.sln) found in this repository references all Gemstone library projects with a common relative parent path. For example, assuming all cloned repositories (including this one) for the [gemstone](https://github.com/gemstone) organizational site have the same root folder, e.g., `C:\Projects\gemstone\` and each project folder matches the repo name, e.g., `C:\Projects\gemstone\threading\` for the [threading](https://github.com/gemstone/threading) library, then opening the `C:\Projects\gemstone\root-dev\Gemstone.sln` from within Visual Studio will properly open and cross-reference all gemstone libraries.

#### Local Project References

The [Gemstone.sln](https://github.com/gemstone/root-dev/blob/master/Gemstone.sln) should be used with the build configuration called `Development`. The `Development` build configuration is used to associate local "project" references instead of "package" references (e.g., NuGet) that are only active when using this solution. For example, a project referencing both the [common](https://github.com/gemstone/common) and [expressions](https://github.com/gemstone/expressions) gemstone libraries would conditionally use local "project" references using the following in the `.csproj` file:

```xml
<ItemGroup>
  <ProjectReference Include="..\..\..\common\src\Gemstone\Gemstone.Common.csproj" Condition="'$(Configuration)'=='Development'" />
  <PackageReference Include="Gemstone.Common" Version="1.0.0" Condition="'$(Configuration)'!='Development'" />

  <ProjectReference Include="..\..\..\expressions\src\Gemstone.Expressions\Gemstone.Expressions.csproj" Condition="'$(Configuration)'=='Development'" />
  <PackageReference Include="Gemstone.Expressions" Version="1.0.0" Condition="'$(Configuration)'!='Development'" />
</ItemGroup>
```

In this example, dependencies are configured as local project references only for the `Development` build configuration. Otherwise, any other build configuration, e.g., the common `Release` or `Debug` configurations, will reference the dependency via the associated package repository, e.g., NuGet.

#### Managing git for Multiple Repositories

When developing using the [Gemstone.sln](https://github.com/gemstone/root-dev/blob/master/Gemstone.sln) be mindful that only one GitHub repository can be active at once from within Visual Studio, because of this command line Git operations may be simpler. To check-in changes to a particular repo from within Visual Studio, click the :electric_plug: icon for "Manage Connections" on the "Team Explorer" window. When the "Manage Connections" panel is opened, navigate to the "Local Git Repositories" list visible at the bottom of the panel, then right-click on desired repo and select "Open". The selected repo will now be active &mdash; proceed as normal for GitHub operations on that project repository.
