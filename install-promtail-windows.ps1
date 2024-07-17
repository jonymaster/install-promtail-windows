#############################################################################################
# This script downloads, if necessary, Promtail and its WinSW (Windows Service wrapper),
# creates default configuration and creates Windows service.
# It's a decision based script.
#
# ↓ ↓ ↓ ↓       HELPER FUNCTIONS    ↓ ↓ ↓ ↓
# ↓↓↓↓↓↓↓       PROCESSING CODE     ↓↓↓↓↓↓↓
#############################################################################################

function Prompt-User {
    param(
        [string]$Prompt,
        [object]$Default
    )

    if (-not [string]::IsNullOrEmpty($Default)) {
        if ($Default -is [bool]) {
            $Prompt += " [$(if ($Default) {'True'} else {'False'})]"
        }
        else {
            $Prompt += " [$Default]"
        }
    }

    $input = Read-Host -Prompt $Prompt

    if ([string]::IsNullOrEmpty($input)) {
        $input = $Default
    }
    else {
        if ($Default -is [bool]) {
            $input = [bool]::Parse($input)
        }
        elseif ($Default -is [int]) {
            $input = [int]::Parse($input)
        }
        elseif ($Default -is [string]) {
            # No conversion needed for string
        }
        else {
            throw "Unsupported default value type: $($Default.GetType().FullName)"
        }

        if ($input.GetType() -ne $Default.GetType()) {
            throw "Entered value type doesn't match default value type"
        }
    }

    return $input
}

function Ensure-Directory {
    param(
        [string]$Path
    )

    if (-not [System.IO.Directory]::Exists($Path)) {
        [System.IO.Directory]::CreateDirectory($Path) | Out-Null
    }
}

function New-DefaultConfig {
    param (
        # Parameter help description
        [Parameter(Mandatory)]
        [string]$fullConfigPath,
        [Parameter(Mandatory)]
        [string]$runPath
    )

    Write-Output "Writing default config to $fullConfigPath"

    $positionsFullpath = $runPath + "\positions.yaml"

    $content = @"
# 1. Update positions.yaml path
# 2. Update client's url - this is the url of Loki service - update or remove basic_auth
# 3. Update what logs should be scraped


server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: C:\Promtail\positions.yaml

clients:
  - url: "https://loki-url/loki/api/v1/push"
# The tenant ID used by default to push logs to Loki. If omitted or empty
# it assumes Loki is running in single-tenant mode and no X-Scope-OrgID header
# is sent.
    basic_auth:
      username: "loki-username"
      password: "loki-password"
      #To use a variable such as `$`{LOKI_AUTH} refer to the readme of this repo.


scrape_configs:
  - job_name: windows-application-logs
    windows_events:
      eventlog_name: "Application"
      xpath_query: "*"
      poll_interval: "1m"
      use_incoming_timestamp: false
      bookmark_path: "./bookmark_application_logs.xml"
      labels:
        service: windows-test-logs

  - job_name: windows-security-logs
    windows_events:
      eventlog_name: "Security"
      xpath_query: "*"
      poll_interval: "1m"
      use_incoming_timestamp: false
      bookmark_path: "./bookmark_security_logs.xml"
      labels:
        service: windows-test-logs

  - job_name: windows-system-logs
    windows_events:
      eventlog_name: "System"
      xpath_query: "*"
      poll_interval: "1m"
      use_incoming_timestamp: false
      bookmark_path: "./bookmark_system_logs.xml"
      labels:
        service: windows-test-logs
"@

    Set-Content -Path $fullConfigPath -Value $content
}

function New-DefaultWinSWConfig {
    param (
        # Parameter help description
        [Parameter(Mandatory)]
        [string]$fullConfigPath,
        [Parameter(Mandatory)]
        [string]$fullPromtailBinPath,
        [Parameter(Mandatory)]
        [string]$fullPromtailConfigPath,
        [Parameter(Mandatory)]
        [string]$serviceName,
        [Parameter(Mandatory)]
        [string]$serviceDisplayName
    )

    Write-Output "Writing default WinSW config to $fullConfigPath"

    $content = "
    <!--
    You can find more information about the configuration options here: https://github.com/kohsuke/winsw/blob/master/doc/xmlConfigFile.md
    Full example: https://github.com/kohsuke/winsw/blob/master/examples/sample-allOptions.xml
   -->
   <service>

     <!-- ID of the service. It should be unique across the Windows system-->
     <id>$serviceName</id>
     <!-- Display name of the service -->
     <name>$serviceDisplayName</name>
     <!-- Service description -->
     <description>Starts a local Promtail service and scrapes logs according to configuration file: $fullPromtailConfigPath</description>

     <!-- Path to the executable, which should be started -->
     <executable>""$fullPromtailBinPath""</executable>

     <arguments>--config.file=""$fullPromtailConfigPath"" --config.expand-env=true</arguments>

   </service>
"

    Set-Content -Path $fullConfigPath -Value $content
}


#############################################
# ↑ ↑ ↑ ↑   HELPER FUNCTIONS          ↑ ↑ ↑ ↑
#
#
# ↓ ↓ ↓ ↓   PROCESSING CODE           ↓ ↓ ↓ ↓
#############################################


Write-Warning -Message "This script creates a Window Service for Promtail log scraper. It is necessary to run it with Admin priviledges.

It can download necessary files from the Internet, but you can also put already downloaded files directly to proper directories."

# Variables
$latestReleaseUrl = "https://github.com/grafana/loki/releases/latest"
$repoUrl = "https://github.com/grafana/loki"
$downloadWinSWUrl = "https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe"
$winSWFilename = "WinSW-x64.exe"
$binFilename = "promtail-windows-amd64.exe"
$configFilename = "promtail.yml"
$winSWConfigFilename = "WinSW-x64.xml"

# Get the latest release version number from the redirect URL
$redirectedUrl = (Invoke-WebRequest -Uri $latestReleaseUrl -UseBasicParsing).BaseResponse.ResponseUri.AbsoluteUri
$latestVersion = ($redirectedUrl -split '/tag/')[-1].Trim('/')

# Construct the download URL
$installerName = "promtail-windows-amd64.exe.zip"
$downloadUrl = "$repoUrl/releases/download/$latestVersion/$installerName"

$runPath = Prompt-User -Prompt "Run directory" -Default "C:\Promtail"
$fullBinPath = Join-Path -Path $runPath -ChildPath $binFilename
$fullWinSWBinPath = Join-Path -Path $runPath -ChildPath $winSWFilename
$downloadWinSWPath = $runPath

$shouldDownloadPromtail = Prompt-User -Prompt "Should we download Promtail?" -Default $true

if ($shouldDownloadPromtail) {
    $downloadUrl = Prompt-User -Prompt "Download url" -Default $downloadUrl
    $downloadPath = Prompt-User -Prompt "Download directory" -Default $runPath

    Ensure-Directory -Path $downloadPath

    $filename = $downloadUrl.Split("/")[-1]
    $fullPath = Join-Path -Path $downloadPath -ChildPath $filename

    Write-Host "Downloading archive..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $downloadUrl -OutFile $fullPath


    Write-Host "Expanding archive..."
    Expand-Archive -LiteralPath $fullPath -DestinationPath $runPath -Force
}
else {
    if (-not [System.IO.File]::Exists($fullBinPath)) {
        throw "Could not find $fullBinPath"
    }
}

$shouldCreateConfig = Prompt-User -Prompt "Create default promtail.yml config?" -Default $true
$configFullpath = Join-Path -Path $runPath -ChildPath $configFilename

if ($shouldCreateConfig) {
    New-DefaultConfig -fullConfigPath $configFullpath -runPath $runPath
}
else {
    $configFullpath = Prompt-User -Prompt "Promtail configuration file path" -Default $configFullpath

    if (-not [System.IO.File]::Exists($configFullpath)) {
        throw "Could not find $configFullpath"
    }
}

$shouldCreateService = Prompt-User -Prompt "Create Promtail Windows service?" -Default $false

if ($shouldCreateService) {

    $shouldDownloadWinSWUrl = Prompt-User -Prompt "Should we download Windows Service wrapper (WinSWUrl)?" -Default $true

    if ($shouldDownloadWinSWUrl) {
        $downloadUrl = Prompt-User -Prompt "Download url" -Default $downloadWinSWUrl
        $downloadWinSWPath = Prompt-User -Prompt "Download directory" -Default $runPath

        Ensure-Directory -Path $downloadPath

        $filename = $winSWFilename
        $fullWinSWBinPath = Join-Path -Path $downloadWinSWPath -ChildPath $filename

        Write-Host "Downloading WinSW exe file..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $fullWinSWBinPath
    }
    else {
        if (-not [System.IO.File]::Exists($fullWinSWBinPath)) {
            throw "Could not find $fullWinSWBinPath"
        }
    }


    $winSWconfigFullpath = Join-Path -Path $downloadWinSWPath -ChildPath $winSWConfigFilename
    $shouldCreateWinSWConfig = Prompt-User -Prompt "Create WinSW config as $winSWconfigFullpath ?" -Default $true

    if ($shouldCreateWinSWConfig) {
        $serviceName = Prompt-User -Prompt "Service name" -Default "Promtail"
        $serviceDisplayName = Prompt-User -Prompt "Service name" -Default "Promtail Logs scraper"

        New-DefaultWinSWConfig -fullConfigPath $winSWconfigFullpath -fullPromtailBinPath $fullBinPath -fullPromtailConfigPath $configFullpath -serviceName $serviceName -serviceDisplayName $serviceDisplayName
    }
    else {
        if (-not [System.IO.File]::Exists($winSWconfigFullpath)) {
            throw "Could not find $winSWconfigFullpath"
        }
    }

    Write-Host "Installing Promtail Windows Service"

    Start-Process -FilePath $fullWinSWBinPath -ArgumentList @("install") -NoNewWindow

    Write-Host "Promtail Windows Service Installed (hopefully)"
}
