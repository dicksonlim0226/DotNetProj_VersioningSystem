param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = $null
)

# Ensure the project file exists
if (-not (Test-Path $ProjectPath)) {
    Write-Error "Project file not found: $ProjectPath"
    exit 1
}

# Get the project directory
$projectDir = Split-Path -Parent $ProjectPath
$propertiesDir = Join-Path $projectDir "Properties"

# Ensure Properties directory exists
if (-not (Test-Path $propertiesDir)) {
    Write-Host "Creating Properties directory..."
    New-Item -Path $propertiesDir -ItemType Directory | Out-Null
}

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Copy the T4 template
$templateSource = Join-Path $scriptDir "SharedVersionInfo.tt"
$templateDest = Join-Path $propertiesDir "VersionInfo.tt"

Write-Host "Copying T4 template to $templateDest..."
Write-Host "Note: The T4 template has been updated to not require Newtonsoft.Json.dll and includes full assembly references for System.Xml and other dependencies."
Copy-Item -Path $templateSource -Destination $templateDest -Force

# Copy the configuration file if specified, otherwise create a default one
if ($ConfigPath -and (Test-Path $ConfigPath)) {
    $configDest = Join-Path $projectDir "SharedVersioning.json"
    Write-Host "Copying configuration file to $configDest..."
    Copy-Item -Path $ConfigPath -Destination $configDest -Force
}
else {
    $configDest = Join-Path $projectDir "SharedVersioning.json"
    if (-not (Test-Path $configDest)) {
        Write-Host "Creating default configuration file..."
        @{
            MajorVersion = 1
            MinorVersion = 0
            SubPrefix = ""
            CompanyName = ""
            ProductName = ""
        } | ConvertTo-Json | Set-Content -Path $configDest
    }
}

# Load the project file as XML
$projectXml = [xml](Get-Content $ProjectPath)
$ns = $projectXml.Project.NamespaceURI

# Create a namespace manager for XPath queries
$nsManager = New-Object System.Xml.XmlNamespaceManager($projectXml.NameTable)
$nsManager.AddNamespace("ns", $ns)

# Check if the project already has the T4 template
$existingItem = $projectXml.SelectSingleNode("//ns:None[@Include='Properties\VersionInfo.tt']", $nsManager)

if (-not $existingItem) {
    Write-Host "Adding T4 template to project file..."

    # Create the None element for the T4 template
    $noneElement = $projectXml.CreateElement("None", $ns)
    $noneElement.SetAttribute("Include", "Properties\VersionInfo.tt")

    # Add Generator attribute
    $generatorAttr = $projectXml.CreateElement("Generator", $ns)
    $generatorAttr.InnerText = "TextTemplatingFileGenerator"
    $noneElement.AppendChild($generatorAttr)

    # Add LastGenOutput attribute
    $lastGenOutputAttr = $projectXml.CreateElement("LastGenOutput", $ns)
    $lastGenOutputAttr.InnerText = "VersionInfo.cs"
    $noneElement.AppendChild($lastGenOutputAttr)

    # Find the ItemGroup to add to
    $itemGroup = $projectXml.SelectSingleNode("//ns:ItemGroup[ns:None]", $nsManager)

    if (-not $itemGroup) {
        $itemGroup = $projectXml.SelectSingleNode("//ns:ItemGroup", $nsManager)
    }

    if ($itemGroup) {
        $itemGroup.AppendChild($noneElement)
    }
    else {
        # Create a new ItemGroup
        $itemGroup = $projectXml.CreateElement("ItemGroup", $ns)
        $itemGroup.AppendChild($noneElement)
        $projectXml.Project.AppendChild($itemGroup)
    }

    # Create the Compile element for the generated file
    $compileElement = $projectXml.CreateElement("Compile", $ns)
    $compileElement.SetAttribute("Include", "Properties\VersionInfo.cs")

    # Add AutoGen attribute
    $autoGenAttr = $projectXml.CreateElement("AutoGen", $ns)
    $autoGenAttr.InnerText = "True"
    $compileElement.AppendChild($autoGenAttr)

    # Add DesignTime attribute
    $designTimeAttr = $projectXml.CreateElement("DesignTime", $ns)
    $designTimeAttr.InnerText = "True"
    $compileElement.AppendChild($designTimeAttr)

    # Add DependentUpon attribute
    $dependentUponAttr = $projectXml.CreateElement("DependentUpon", $ns)
    $dependentUponAttr.InnerText = "VersionInfo.tt"
    $compileElement.AppendChild($dependentUponAttr)

    # Find the ItemGroup with Compile elements
    $compileItemGroup = $projectXml.SelectSingleNode("//ns:ItemGroup[ns:Compile]", $nsManager)

    if ($compileItemGroup) {
        $compileItemGroup.AppendChild($compileElement)
    }
    else {
        # Create a new ItemGroup
        $compileItemGroup = $projectXml.CreateElement("ItemGroup", $ns)
        $compileItemGroup.AppendChild($compileElement)
        $projectXml.Project.AppendChild($compileItemGroup)
    }
}

# Check if the project already has the TextTemplating service
$existingService = $projectXml.SelectSingleNode("//ns:Service[@Include='{508349B6-6B84-4DF5-91F0-309BEEBAD82D}']", $nsManager)

if (-not $existingService) {
    Write-Host "Adding TextTemplating service to project file..."

    # Create the Service element
    $serviceElement = $projectXml.CreateElement("Service", $ns)
    $serviceElement.SetAttribute("Include", "{508349B6-6B84-4DF5-91F0-309BEEBAD82D}")

    # Find or create the ItemGroup for services
    $serviceItemGroup = $projectXml.SelectSingleNode("//ns:ItemGroup[ns:Service]", $nsManager)

    if (-not $serviceItemGroup) {
        $serviceItemGroup = $projectXml.CreateElement("ItemGroup", $ns)
        $projectXml.Project.AppendChild($serviceItemGroup)
    }

    $serviceItemGroup.AppendChild($serviceElement)
}

# Check if the project already has the TextTemplating import
$existingImport = $projectXml.SelectSingleNode("//ns:Import[contains(@Project, 'TextTemplating')]", $nsManager)

if (-not $existingImport) {
    Write-Host "Adding TextTemplating import to project file..."

    # Create the Import element
    $importElement = $projectXml.CreateElement("Import", $ns)
    # Use single quotes to avoid PowerShell variable expansion
    $importElement.SetAttribute("Project", '$(MSBuildExtensionsPath)\Microsoft\VisualStudio\v$(VisualStudioVersion)\TextTemplating\Microsoft.TextTemplating.targets')
    # Use backtick to escape $ in the Condition attribute
    $importElement.SetAttribute("Condition", "Exists('`$(MSBuildExtensionsPath)\Microsoft\VisualStudio\v`$(VisualStudioVersion)\TextTemplating\Microsoft.TextTemplating.targets')")

    # Add after the CSharp.targets import
    $csharpImport = $projectXml.SelectSingleNode("//ns:Import[contains(@Project, 'CSharp.targets')]", $nsManager)

    if ($csharpImport) {
        $projectXml.Project.InsertAfter($importElement, $csharpImport)
    }
    else {
        $projectXml.Project.AppendChild($importElement)
    }

    # Add the TransformOnBuild property group
    $propertyGroup = $projectXml.CreateElement("PropertyGroup", $ns)

    $transformOnBuild = $projectXml.CreateElement("TransformOnBuild", $ns)
    $transformOnBuild.InnerText = "true"
    $propertyGroup.AppendChild($transformOnBuild)

    $transformOutOfDateOnly = $projectXml.CreateElement("TransformOutOfDateOnly", $ns)
    $transformOutOfDateOnly.InnerText = "false"
    $propertyGroup.AppendChild($transformOutOfDateOnly)

    $overwriteReadOnlyOutputFiles = $projectXml.CreateElement("OverwriteReadOnlyOutputFiles", $ns)
    $overwriteReadOnlyOutputFiles.InnerText = "true"
    $propertyGroup.AppendChild($overwriteReadOnlyOutputFiles)

    $projectXml.Project.AppendChild($propertyGroup)

    # Add the fallback BeforeBuild target
    $targetElement = $projectXml.CreateElement("Target", $ns)
    $targetElement.SetAttribute("Name", "BeforeBuild")
    # Use backtick to escape $ in the Condition attribute
    $targetElement.SetAttribute("Condition", "!Exists('`$(MSBuildExtensionsPath)\Microsoft\VisualStudio\v`$(VisualStudioVersion)\TextTemplating\Microsoft.TextTemplating.targets')")

    $execElement = $projectXml.CreateElement("Exec", $ns)
    # Use single quotes to avoid PowerShell variable expansion for MSBuild variables
    $execElement.SetAttribute("Command", 'if exist "$(ProjectDir)Properties\VersionInfo.tt" "$(DevEnvDir)TextTransform.exe" -out "$(ProjectDir)Properties\VersionInfo.cs" "$(ProjectDir)Properties\VersionInfo.tt"')
    $execElement.SetAttribute("ContinueOnError", "true")

    $targetElement.AppendChild($execElement)
    $projectXml.Project.AppendChild($targetElement)
}

# Save the project file
$projectXml.Save($ProjectPath)

# Create a batch file for manual updates
$batchFile = Join-Path $projectDir "UpdateVersion.bat"
Write-Host "Creating batch file for manual updates: $batchFile..."

@"
@echo off
setlocal enabledelayedexpansion

echo Updating version information...
echo.
echo This will generate a version number in the format: Major.Minor.Build.Revision
echo - Major and Minor: Manually configurable (0-65535)
echo - Build: Date-based in YYMM format (0-65535)
echo - Revision: Day + time-based counter (0-65535)
echo - AssemblyInformationalVersion: Major.Minor.Build.Revision SubPrefix
echo - Copyright: Automatically updated to current year
echo.

REM Check if the T4 template exists
if not exist "Properties\VersionInfo.tt" (
    echo Error: VersionInfo.tt template not found in Properties folder.
    exit /b 1
)

REM Find Visual Studio installation path from registry
for /f "tokens=2*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\SxS\VS7" /v "17.0" 2^>nul') do set "VS_PATH=%%b"

if "%VS_PATH%"=="" (
    echo Visual Studio 2022 not found, trying Visual Studio 2019...
    for /f "tokens=2*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\SxS\VS7" /v "16.0" 2^>nul') do set "VS_PATH=%%b"
)

if "%VS_PATH%"=="" (
    echo Visual Studio 2019 not found, trying Visual Studio 2017...
    for /f "tokens=2*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\SxS\VS7" /v "15.0" 2^>nul') do set "VS_PATH=%%b"
)

if "%VS_PATH%"=="" (
    echo Error: Could not find Visual Studio installation.
    echo.
    echo Trying alternative method with vswhere...

    REM Try to use vswhere if available
    if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
        for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -property installationPath`) do (
            set "VS_PATH=%%i\"
        )
    )

    if "!VS_PATH!"=="" (
        echo Error: Could not find Visual Studio using vswhere either.
        echo.
        echo Please make sure Visual Studio is installed with the Text Template Transformation toolkit.
        exit /b 1
    )
)

set "TEXTTRANSFORM=%VS_PATH%Common7\IDE\TextTransform.exe"

if not exist "%TEXTTRANSFORM%" (
    echo Error: TextTransform.exe not found at %TEXTTRANSFORM%
    echo.
    echo Trying to find TextTransform.exe in other locations...

    REM Try to find TextTransform.exe in other common locations
    for %%d in (
        "%VS_PATH%Common7\IDE\Extensions\Microsoft\TextTemplating\"
        "%VS_PATH%Common7\Tools\"
        "%VS_PATH%TextTemplating\"
    ) do (
        if exist "%%~d\TextTransform.exe" (
            set "TEXTTRANSFORM=%%~d\TextTransform.exe"
            echo Found TextTransform.exe at !TEXTTRANSFORM!
            goto :found_texttransform
        )
    )

    echo Error: Could not find TextTransform.exe in any known location.
    echo.
    echo Please install the Text Template Transformation toolkit in Visual Studio.
    exit /b 1
)

:found_texttransform
echo Using TextTransform from: %TEXTTRANSFORM%
echo.
echo Running transformation...

"%TEXTTRANSFORM%" -out "Properties\VersionInfo.cs" "Properties\VersionInfo.tt"

if %ERRORLEVEL% neq 0 (
    echo Error: Failed to transform T4 template.
    echo.
    echo Please check the template for errors and make sure the Text Template Transformation toolkit is installed.
    exit /b 1
)

echo.
echo Version information updated successfully.
echo.
echo To modify version settings, edit the SharedVersioning.json file.
exit /b 0
"@ | Set-Content -Path $batchFile

# Create a README file
$readmeFile = Join-Path $projectDir "VERSION_README.md"
Write-Host "Creating README file: $readmeFile..."

@"
# Centralized Date-Based Versioning System

This project uses a centralized date-based versioning system that follows best practices for .NET Framework applications. The version numbers are automatically generated during the build process using a T4 template.

## Version Number Format

The version number follows the standard .NET format with four components:

```
Major.Minor.Build.Revision
```

Where:

- **Major**: Manually configurable version number (range: 0-65535)
- **Minor**: Manually configurable version number (range: 0-65535)
- **Build**: Date-based number in YYMM format (e.g., 2403 for March 2024) (range: 0-65535)
- **Revision**: Combines day of month with a counter in format DDxxx (range: 0-65535)
  - DD: Day of month (01-31)
  - xxx: Counter that increments throughout the day (based on time)
  - Resets to a low value at the beginning of each new day

Additionally, an informational version is generated in the format:
```
Major.Minor.Build.Revision SubPrefix
```
Where SubPrefix is a manually configurable string.

## Automatic Copyright Year

The system also automatically updates the copyright year in the assembly metadata. The copyright statement is generated in the format:
```
Copyright © YYYY CompanyName
```
Where YYYY is the current year at build time. This ensures the copyright information is always up to date.

## Centralized Configuration

The version settings are stored in a central configuration file:
```
SharedVersioning.json
```

This file contains the following settings:
- MajorVersion: The major version number
- MinorVersion: The minor version number
- SubPrefix: The suffix for the informational version
- CompanyName: The company name for copyright and assembly info
- ProductName: The product name for assembly info

## How It Works

1. The versioning system uses a T4 template (`Properties\VersionInfo.tt`) that generates a C# file (`Properties\VersionInfo.cs`) containing the assembly version attributes.
2. The template reads settings from the `SharedVersioning.json` file.
3. The template is automatically processed during the build process in Visual Studio.
4. The generated version numbers are based on the current date and time at build time.
5. The revision number combines the day of month with a time-based counter to ensure uniqueness while resetting appropriately each day.
6. The copyright year is automatically set to the current year.

## Modifying Version Settings

To change version settings:

1. Open the `SharedVersioning.json` file
2. Modify the desired settings
3. Save the file
4. Build the project (or run the `UpdateVersion.bat` script)

## Manual Version Update

If you need to update the version outside of a build process, you can run the included `UpdateVersion.bat` script, which will:

1. Find your Visual Studio installation
2. Run the TextTransform tool to process the T4 template
3. Generate an updated `VersionInfo.cs` file

## Benefits of This Approach

- **Centralized**: Version settings are stored in a single configuration file
- **Automated**: Version numbers are updated automatically with each build
- **Traceable**: The build date is encoded in the version number
- **Unique**: The revision number includes a time-based counter for uniqueness within a day
- **Consistent**: Follows .NET versioning best practices and constraints
- **Flexible**: Major, minor, and informational version components can be manually controlled
- **Current**: Copyright year is always up to date
- **Reusable**: The same configuration can be used across multiple projects

## Implementation Details

The implementation uses:
- T4 text templates for code generation
- JSON configuration for centralized settings
- MSBuild integration for automatic processing during builds
- A standalone batch script for manual updates
- Validation to ensure all version components stay within valid ranges (0-65535)

## Note on Dependencies

The T4 template has been designed to work without external dependencies like Newtonsoft.Json.dll. It uses a simple built-in JSON parser that can handle the basic configuration format needed for versioning. The template includes full assembly references with version numbers and public key tokens for System.Xml and other required .NET Framework assemblies to ensure compatibility across different environments.
"@ | Set-Content -Path $readmeFile

Write-Host "Installation complete!"
Write-Host "The versioning system has been installed in $projectDir"
Write-Host "You can now build your project to generate the version information."
Write-Host "To modify version settings, edit the SharedVersioning.json file."