using namespace System.Management.Automation

param (
    [switch]$Verbose = $false
)

$cwd = Get-Location

Push-Location

try {
    if ($cwd.Path -ieq 'E:\GPS\GPS.LocalDB.Installer') {
        Set-Location src/GPS.LocalDB/Scripts
        Write-Host ('CurrentLocation: ' + (Get-Location))
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
            [string]$YamlFileName = $null,
            $contents = $null
        )

        if (-not $YamlFileName -or -not $contents) {
            throw 'Cannot save YAML with provided values.'
        }

        ConvertTo-Yaml $contents | Out-File $YamlFileName

        return Test-Path $YamlFileName
    }

    $configuration = Read-Yaml -YamlFileName .\Configuration.yaml

    $binn = 'C:\Program Files\Microsoft SQL Server\150\Tools\Binn'

    $foundUtil = Get-Command "$binn\SqlLocalDB.exe" -ErrorAction SilentlyContinue

    if ($foundUtil) {
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

            $secondaraParameters = 'IACCEPTSQLLOCALDBLICENSETERMS=YES'

            $filePath = [System.IO.Path]::GetDirectoryName($filename)

            Push-Location

            Set-Location $filePath

            $filename = [System.IO.Path]::GetFileName($filename)

            $parameters = @(`
                    '/uninstall', `
                    "$filename", `
                    '/quiet', `
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

            $configuration.Configuration.InstallationStatus.IsInstalled = $false
            $configuration.Configuration.InstallationStatus.InstallPath = $null
            $configuration.Configuration.InstallationStatus.InstalledOn = $null
            $configuration.Configuration.InstallationStatus.InstalledVersion = $null

            WriteYaml -YamlFileName .\Configuration.yaml -contents $configuration

            return $ec
        }
    }
}
finally {
    Pop-Location
}
