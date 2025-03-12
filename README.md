# Centralized Date-Based Versioning System for .NET Framework

This is a centralized, reusable versioning system for .NET Framework 4.0-4.8 projects that works with both C# and VB.NET. It automatically generates version numbers based on the current date and time, ensuring unique and traceable builds.

## Features

- **Centralized Configuration**: Store version settings in a single JSON file
- **Best Practice Versioning**: Follows .NET versioning best practices for binary compatibility
- **Date-Based Build Numbers**: Automatically generate build numbers based on the current date
- **Auto-Incrementing Revision**: Revision numbers that increment throughout the day and reset each day
- **Automatic Copyright Year**: Copyright year is automatically updated to the current year
- **Cross-Language Support**: Works with both C# and VB.NET projects
- **Compatible with .NET Framework 4.0-4.8**: Works with all recent versions of .NET Framework
- **MSBuild Integration**: Automatically runs during the build process
- **Manual Update Option**: Includes a batch file for manual updates
- **Robust Error Handling**: Provides detailed error messages and fallback mechanisms

## Installation

### Prerequisites

- Visual Studio 2017, 2019, or 2022
- Text Template Transformation Toolkit (installed with Visual Studio)

### Installing in a C# Project

1. Copy the `VersioningSystem` folder to a location accessible to your projects
2. Open PowerShell and navigate to the `VersioningSystem` folder
3. Run the installation script:

```powershell
.\Install-CSharp.ps1 -ProjectPath "C:\Path\To\Your\Project.csproj"
```

Optionally, you can specify a custom configuration file:

```powershell
.\Install-CSharp.ps1 -ProjectPath "C:\Path\To\Your\Project.csproj" -ConfigPath "C:\Path\To\Your\CustomConfig.json"
```

### Installing in a VB.NET Project

1. Copy the `VersioningSystem` folder to a location accessible to your projects
2. Open PowerShell and navigate to the `VersioningSystem` folder
3. Run the installation script:

```powershell
.\Install-VBNet.ps1 -ProjectPath "C:\Path\To\Your\Project.vbproj"
```

Optionally, you can specify a custom configuration file:

```powershell
.\Install-VBNet.ps1 -ProjectPath "C:\Path\To\Your\Project.vbproj" -ConfigPath "C:\Path\To\Your\CustomConfig.json"
```

## Using the Versioning System

### Configuration

The versioning system uses a JSON configuration file (`SharedVersioning.json`) with the following settings:

```json
{
  "MajorVersion": 4,
  "MinorVersion": 8,
  "InformationalVersionSuffix": "SQL",
  "CompanyName": "Your Company",
  "ProductName": "Your Product"
}
```

- **MajorVersion**: The major version number (0-65535)
- **MinorVersion**: The minor version number (0-65535)
- **InformationalVersionSuffix**: A suffix for the informational version (optional)
- **CompanyName**: The company name for copyright and assembly info (optional)
- **ProductName**: The product name for assembly info (optional)

### Versioning Strategy

This system implements a best-practice versioning strategy that balances binary compatibility with detailed build tracking:

#### 1. AssemblyVersion (Major.0.0.0)

```csharp
[assembly: AssemblyVersion("4.0.0.0")]
```

- Used by the CLR for binding and binary compatibility
- Kept stable within a major version to maintain binary compatibility
- Only increments when making breaking changes
- Format: `MajorVersion.0.0.0`

#### 2. AssemblyFileVersion (Major.Minor.YYMM.DDxxx)

```csharp
[assembly: AssemblyFileVersion("4.8.2307.12345")]
```

- Used by Windows Explorer to display file version info
- Doesn't affect runtime behavior
- Provides detailed tracking of builds
- Format: `Major.Minor.Build.Revision`
  - **Major**: Manually configurable version number (range: 0-65535)
  - **Minor**: Manually configurable version number (range: 0-65535)
  - **Build**: Date-based number in YYMM format (e.g., 2403 for March 2024) (range: 0-65535)
  - **Revision**: Combines day of month with a counter in format DDxxx (range: 0-65535)
    - DD: Day of month (01-31)
    - xxx: Counter that increments throughout the day (based on time)

#### 3. AssemblyInformationalVersion (Human-Readable)

```csharp
[assembly: AssemblyInformationalVersion("4.8.0 SQL Build 2307.12345")]
```

- Can contain any string (not limited to numeric format)
- Visible to users in file properties
- Includes additional context like suffixes or build metadata
- Format: `Major.Minor.0 [InformationalVersionSuffix] Build Build.Revision`

### Automatic Updates

The version information is automatically updated when you build your project in Visual Studio. The T4 template reads the configuration file, calculates the version numbers based on the current date and time, and generates the appropriate assembly attributes.

### Manual Updates

If you need to update the version information outside of the build process, you can run the included `UpdateVersion.bat` script. This script will:

1. Find your Visual Studio installation
2. Run the TextTransform tool to process the T4 template
3. Generate an updated version file

### Sharing Configuration Across Projects

To share the same version information across multiple projects:

1. Place the `SharedVersioning.json` file in a common location accessible to all projects
2. Install the versioning system in each project using the installation scripts
3. Update the `SharedVersioning.json` file when you want to change the version information

## Benefits of This Versioning Strategy

### 1. Binary Compatibility

By keeping `AssemblyVersion` stable (Major.0.0.0), you avoid breaking binary compatibility between builds. This means:

- Assemblies don't need to be recompiled against new versions
- Fewer binding redirects needed in app.config/web.config
- Less "DLL Hell" issues in complex applications

### 2. Detailed Build Tracking

The date-based `AssemblyFileVersion` provides detailed tracking of builds:

- Year and month in the build number
- Day and time-based counter in the revision
- Unique version numbers for each build
- Easy to determine when a build was created

### 3. Human-Readable Information

The `AssemblyInformationalVersion` provides additional context:

- Product suffixes or edition information
- Pre-release labels
- Build metadata
- Easily readable by end-users

## Troubleshooting

### Common Issues

1. **"The 'TransformTemplates' task returned false but did not log an error"**
   - Make sure the Text Template Transformation Toolkit is installed in Visual Studio
   - Try running the `UpdateVersion.bat` script manually

2. **"TextTransform.exe not found"**
   - The script tries to find TextTransform.exe in several locations
   - If it still can't find it, make sure Visual Studio is installed correctly

3. **Compilation warnings about unused variables**
   - These are harmless and can be ignored
   - The template includes fallback mechanisms for different environments

### Getting Help

If you encounter issues not covered here, please check:
- The Visual Studio documentation on T4 templates
- The error messages in the Output window
- The detailed error output from the `UpdateVersion.bat` script

## Customization

### Modifying the T4 Template

You can customize the T4 template (`SharedVersionInfo.tt` or `SharedVersionInfo.vb.tt`) to change how version numbers are generated. For example:

- Change the format of the build number
- Use a different algorithm for the revision number
- Add additional assembly attributes
- Modify the versioning strategy for specific needs

### Adding Support for Other Project Types

The versioning system can be extended to support other project types by:

1. Creating a new installation script based on the existing ones
2. Modifying the T4 template to generate the appropriate output
3. Updating the project file to include the necessary MSBuild targets

## License

This versioning system is provided under the MIT License. Feel free to use, modify, and distribute it as needed.