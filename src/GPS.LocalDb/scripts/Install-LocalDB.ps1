using namespace System.Management.Automation

param (
    [string]$Destination = "$env:ProgramFiles\LocalDB",
    [switch]$Uninstall = $false,
    [switch]$Verbose = $false
)

if($uninstall) {
    return . Uninstall-LocalDB.ps1 -Verbose:$Verbose
}

$cwd = Get-Location

Push-Location

try {
    if ($cwd.Path -ieq 'E:\GPS\GPS.LocalDB.Installer') {
        Set-Location src/GPS.LocalDB/Scripts
        Write-Host ("CurrentLocation: " + (Get-Location))
    }

    $module = Get-Module Powershell-yaml

    if (-not $module) {
        Install-Module Powershell-yaml -Scope CurrentUser
    }

    Import-Module Powershell-yaml

    function Read-Yaml {
        param(
            [string]$YamlFileName = $null
        )

        if (-not $YamlFileName) {
            throw "No value defined for `$yamlFilename"
        }

        [string]$fileContent = Get-Content $YamlFileName -Raw
        return ConvertFrom-Yaml $fileContent
    }

    function WriteYaml {
        param(
            [string]$YamlFileName=$null,
            $contents=$null
        )

        if(-not $YamlFileName -or -not $contents){
            throw "Cannot save YAML with provided values."
        }

        ConvertTo-Yaml $contents | Out-File $YamlFileName

        return Test-Path $YamlFileName
    }

    $configuration = Read-Yaml -YamlFileName .\Configuration.yaml

    $binn = 'C:\Program Files\Microsoft SQL Server\150\Tools\Binn'

    $foundUtil = Get-Command "$binn\SqlLocalDB.exe"

    if ((-not $configuration.Configuration.InstallationStatus.IsInstalled) `
            -or (-not $foundUtil)) {

        $fileName = '../dist/SqlLocalDB.msi'

        if (Test-Path $filename) {
            $command = Get-Command msiexec.exe

            $logFile = "$tempFolder\install.log"

            $logFile = Get-Item $logFile -ErrorAction SilentlyContinue

            if (-not $logFile) {
                $logFile = "$tempFolder\install.log"
            }
            else {
                Remove-Item -Path $logfile.ToString()
            }

            $secondaraParameters = (`
                    'IACCEPTSQLLOCALDBLICENSETERMS=YES' + `
                    " INSTALLPATH=`"$Destination`"" `
            )

            $filePath = [System.IO.Path]::GetDirectoryName($filename)

            Push-Location

            Set-Location $filePath

            $filename = [System.IO.Path]::GetFileName($filename)

            $parameters = @(`
                    '/package', `
                    "$filename", `
                    '/qf', `
                    '/promptrestart', `
                    '/l*!', `
                    $logFile, `
                    $secondaraParameters `
            )

            $result = Start-Process $command `
                -ArgumentList $parameters `
                -NoNewWindow `
                -Wait `
                -Verbose

            $ec = $LASTEXITCODE

            if ($ec -and $ec -ne 0) {
                $nl = [System.Environment]::NewLine
                Write-Error "Exit Code of $ec indicates failure.$nl$result"
            }

            if ($Verbose -and (Test-Path $logFile)) {
                Get-Content $logFile
            }

            $ec ??= 0

            Pop-Location

            $sqlLocalDbCommand = Get-Command "$binn\SqlLocalDB.exe"

            if($ec -eq 0 -and $sqlLocalDbCommand) {
                $configuration.Configuration.InstallationStatus.IsInstalled = $true
                $configuration.Configuration.InstallationStatus.InstallPath = $binn
                $configuration.Configuration.InstallationStatus.InstalledOn = [System.DateTimeOffset]::Now.ToLocalTime().ToString("g")
                $configuration.Configuration.InstallationStatus.InstalledVersion = "2019"

                WriteYaml -YamlFileName .\Configuration.yaml -contents $configuration
            }

            return $ec
        }
    }
}
finally {
    Pop-Location
}
