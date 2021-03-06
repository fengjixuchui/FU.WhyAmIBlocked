﻿[cmdletbinding()]
param (
    [parameter(Mandatory = $true)]
    [System.IO.FileInfo]$modulePath,

    [parameter(Mandatory = $false)]
    [switch]$buildLocal
)

try {

    $ModuleName = "FU.WhyAmIBlocked"
    $Author = "Adam Gross (@AdamGrossTX)"
    $CompanyName = "A Square Dozen"
    $Prefix = "fu"
    $Path = "C:\FeatureUpdateBlocks"
    $ProjectUri = "https://github.com/AdamGrossTX/FU.WhyAmIBlocked"

    
     #region Generate a new version number
     $moduleName = Split-Path $modulePath -Leaf
     [Version]$exVer = Find-Module $moduleName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Version
     if ($buildLocal) {
         $rev = ((Get-ChildItem $PSScriptRoot\bin\release\ -ErrorAction SilentlyContinue).Name | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) + 1
         $newVersion = New-Object Version -ArgumentList 1, 0, 0, $rev
     }
     else {
         $newVersion = if ($exVer) {
             $rev = ($exVer.Revision + 1)
             New-Object version -ArgumentList $exVer.Major, $exVer.Minor, $exVer.Build, $rev
         }
         else {
             $rev = ((Get-ChildItem $PSScriptRoot\bin\release\ -ErrorAction SilentlyContinue).Name | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) + 1
             New-Object Version -ArgumentList 1, 0, 0, $rev 
         }
     }
     $releaseNotes = (Get-Content .\$moduleName\ReleaseNotes.txt -Raw -ErrorAction SilentlyContinue).Replace("{{NewVersion}}",$newVersion)
     $releaseNotes = $exVer ? $releaseNotes.Replace("{{LastVersion}}","$($exVer.ToString())") : $releaseNotes.Replace("{{LastVersion}}","")
     #endregion

    #region Build out the release
    $relPath = "$PSScriptRoot\bin\release\$rev\$moduleName"
    "Version is $newVersion"
    "Module Path is $modulePath"
    "Module Name is $moduleName"
    "Release Path is $relPath"
    if (!(Test-Path $relPath)) {
        New-Item -Path $relPath -ItemType Directory -Force | Out-Null
    }

    Copy-Item "$modulePath\*" -Destination "$relPath" -Recurse -Exclude ".gitKeep","releaseNotes.txt","description.txt","*.psm1","*.psd1"

    $Manifest = @{
        Path = "$($relPath)\$($ModuleName).psd1"
        RootModule = "$($ModuleName).psm1"
        Author = $Author
        CompanyName = $CompanyName
        ModuleVersion = $newVersion
        Description = (Get-Content .\$moduleName\description.txt -raw).ToString()
        FunctionsToExport = (Get-ChildItem -Path ("$ModulePath\Public\*.ps1") -Recurse).BaseName
        DefaultCommandPrefix = $Prefix.ToUpper()
        CmdletsToExport = @()
        VariablesToExport = '*'
        AliasesToExport = @()
        DscResourcesToExport = @()
        ReleaseNotes = $releaseNotes
        ProjectUri = $ProjectUri
    }

    #https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/new-modulemanifest?view=powershell-7
    New-ModuleManifest @Manifest

$ModuleFunctionScript = "
    `$Public = @(Get-ChildItem -Path `"`$(`$PSScriptRoot)\Public\*.ps1`" -ErrorAction SilentlyContinue)
    `$Private = @(Get-ChildItem -Path `"`$(`$PSScriptRoot)\Private\*.ps1`" -ErrorAction SilentlyContinue)
    `$script:Prefix = `"$($Prefix)`"
    `$script:Path = `"$($Path)`"
    `$initCfg = @{
        Path = `"`$(`$script:Path)`"
        ConfigFile = `"`$(`$script:Path)\Config.json`"
        SDBCab = `"Appraiser_AlternateData.cab`"
        SDBUnPackerFile = Join-Path -Path `$PSScriptRoot -ChildPath `"SDBUnpacker.py`"
        sdb2xmlPath = Join-Path -Path `$PSScriptRoot -ChildPath `"sdb2xml.exe`"
        UserConfigFile = `"`$(`$env:USERPROFILE)\.`$(`$script:Prefix)cfgpath`"
    }
    `$cfg = Get-Content `$initCfg[`"UserConfigFile`"] -ErrorAction SilentlyContinue
    `$script:tick = [char]0x221a

    if (`$cfg) {
        if (Get-Content -Path `$cfg -raw -ErrorAction SilentlyContinue) {
            `$script:Config = Get-Content -Path `$cfg -raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        }
        else {
            `$script:Config = `$initCfg
        }
    }
    else {
        `$script:Config = `$initCfg
    }

    #endregion
    #region Dot source the files
    foreach (`$import in @(`$Public + `$Private)) {
        try {
            . `$import.FullName
        }
        catch {
            Write-Error -Message `"Failed to import function `$(`$import.FullName): `$_`"
        }
    }
    #endregion

    Try {
        `$pythonVersion = & python --version
        If(`$pythonVersion) {
            [switch]`$script:PythonInstalled = `$true
        }
        Else {
            Throw `"Python is not installed. Install Pyton before proceeding.`"
        }
    }
    Catch {
        [switch]`$script:PythonInstalled = `$false
        Write-Warning `$_.Exception.Message
    }

"
   $ModuleFunctionScript | Out-File -FilePath "$($relPath)\$($ModuleName).psm1" -Encoding utf8 -Force
    
    #endregion
    #region Generate a list of public functions and update the module manifest
    #$functions = @(Get-ChildItem -Path $relPath\Public\*.ps1 -ErrorAction SilentlyContinue).basename
    #$params = @{
    #    Path = "$relPath\$ModuleName.psd1"
    #    ModuleVersion = $newVersion
    #    Description = (Get-Content .\$moduleName\description.txt -raw).ToString()
    #    FunctionsToExport = $functions
    #    ReleaseNotes = $releaseNotes.ToString()
    #}
    #Update-ModuleManifest @params
    #endregion
}
catch {
    $_
}
