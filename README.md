<img align="right" src="img/gemstone-wide-600.png" alt="gemstone logo">
<br/><br/><br/>

# root-dev


### GPA Gemstone Root Development Solution

This repository contains a multi-project solution used for development and debugging of related Gemstone libraries.

#### Project References

The [Gemstone Solution](gemstone.sln) references all Gemstone library packages using a build configuration called `Development` .

The `Development` build configuration is then used to associate "project" references instead of "package" references when using this solution, e.g.:

```
<ItemGroup>
  <ProjectReference Include="..\..\..\common\src\gemstone\gemstone.common.csproj" Condition="'$(Configuration)'=='Development'" />
  <PackageReference Include="gemstone.common" Version="1.0.0" Condition="'$(Configuration)'!='Development'" />

  <ProjectReference Include="..\..\..\expressions\src\gemstone.expressions\gemstone.expressions.csproj" Condition="'$(Configuration)'=='Development'" />
  <PackageReference Include="gemstone.expressions" Version="1.0.0" Condition="'$(Configuration)'!='Development'" />
</ItemGroup>
```

#### Managing Multiple Repositories

In this example, dependencies are referenced as project references only for the `Development` build configuration, otherwise any other build configuration, e.g., the common `Release` or `Debug`, will reference the associated NuGet package.

When using the `Gemstone Solution` be mindful that only one GitHub repository can be active at once. To check-in changes to a particular repo, click the :electric_plug: icon for "Manage Connections" on the "Team Explorer". From the "Local Git Repositories" list at the bottom, right click on desired repo and select "Open" and procede as normal for GitHub operations on that project repository.
