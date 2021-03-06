function Initialize-Module {
    [cmdletbinding()]
    param (
        [parameter(Position = 1, Mandatory = $false)]
        $initCfg = $script:Config,

        [parameter(Position = 2, Mandatory = $false)]
        [switch]
        $Reset
    )
    try {

        #Create output folder
        $Path = $initCfg.Path
        If(!(Test-Path -Path $Path)) {
            New-Item -Path $Path -ItemType Directory | Out-Null
        }

        $ConfigFile = 
            If($initCfg.ConfigFile) {
                $initCfg.ConfigFile
            }
            Else {
                "$($Path)\Config.json"
            }

            Write-Host " + Creating $($ConfigFile).. " -ForegroundColor Cyan -NoNewline
        if ((Test-Path $ConfigFile -ErrorAction SilentlyContinue) -and (!($Reset.IsPresent))) {
            Write-Warning "Already created - no need to run this again.."
        }
        else {
            $initCfgJSON = $initCfg | ConvertTo-Json -Depth 20
            $initCfgJSON | Out-File $ConfigFile -Encoding ascii -Force
            $ConfigFile | Out-File $initCfg.UserConfigFile -Encoding ascii -Force
            Write-Host $script:tick -ForegroundColor Green
        }
    }
    catch {
        Write-Warning $_
    }
}