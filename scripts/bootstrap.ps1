param(
    [Parameter(Mandatory = $true)]
    [int] $NodeMajor,

    [Parameter(Mandatory = $true)]
    [string] $MxcSdkVersion,

    [Parameter(Mandatory = $true)]
    [string] $OpenClawPackage,

    [Parameter(Mandatory = $true)]
    [int] $GatewayPort
)

$ErrorActionPreference = "Stop"

$BootstrapRoot = "C:\bootstrap"
$OpenClawRoot = "C:\openclaw"
$ConfigDir = Join-Path $OpenClawRoot "config"
$StateDir = Join-Path $ConfigDir "state"
$WorkspaceDir = Join-Path $ConfigDir "workspace"
$LogFile = Join-Path $BootstrapRoot "bootstrap.log"
$ConfigFile = Join-Path $ConfigDir "openclaw.json"
$EnvFile = Join-Path $ConfigDir ".env"
$AccessFile = Join-Path $OpenClawRoot "gateway-access.txt"

function Write-Log {
    param([string] $Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Set-OpenClawEnvironment {
    $env:OPENCLAW_CONFIG_DIR = $ConfigDir
    $env:OPENCLAW_CONFIG_PATH = $ConfigFile
    $env:OPENCLAW_STATE_DIR = $StateDir
    $env:OPENCLAW_WORKSPACE_DIR = $WorkspaceDir

    [Environment]::SetEnvironmentVariable("OPENCLAW_CONFIG_DIR", $ConfigDir, "Machine")
    [Environment]::SetEnvironmentVariable("OPENCLAW_CONFIG_PATH", $ConfigFile, "Machine")
    [Environment]::SetEnvironmentVariable("OPENCLAW_STATE_DIR", $StateDir, "Machine")
    [Environment]::SetEnvironmentVariable("OPENCLAW_WORKSPACE_DIR", $WorkspaceDir, "Machine")
}

function Get-OrCreateGatewayToken {
    if (Test-Path $EnvFile) {
        $existing = Get-Content $EnvFile | Where-Object { $_ -match '^\s*OPENCLAW_GATEWAY_TOKEN=(.+)$' } | Select-Object -First 1
        if ($existing -match 'OPENCLAW_GATEWAY_TOKEN=(.+)') {
            return $Matches[1].Trim()
        }
    }

    $bytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return ([Convert]::ToBase64String($bytes) -replace '[+/=]', '').Substring(0, 32)
}

New-Item -ItemType Directory -Force -Path $BootstrapRoot | Out-Null
New-Item -ItemType Directory -Force -Path $OpenClawRoot | Out-Null
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
New-Item -ItemType Directory -Force -Path $WorkspaceDir | Out-Null

Write-Log "Starting MXC + OpenClaw bootstrap (gateway on lan)"

Write-Log "Enabling Windows features for WSL2 and Hyper-V (future MXC backends)"
$features = @(
    "Microsoft-Windows-Subsystem-Linux",
    "VirtualMachinePlatform",
    "Microsoft-Hyper-V-All"
)

foreach ($feature in $features) {
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart | Out-Null
        Write-Log "Enabled feature: $feature"
    }
    catch {
        Write-Log "Feature $feature may require reboot or is already enabled: $($_.Exception.Message)"
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Git from git-scm.com"
    $gitInstaller = Join-Path $BootstrapRoot "Git-64-bit.exe"
    Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v2.49.0.windows.1/Git-2.49.0-64-bit.exe" -OutFile $gitInstaller
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT /NORESTART" -Wait
    Refresh-Path
    Write-Log "Git install finished"
}
else {
    Write-Log "Git already installed"
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Node.js $NodeMajor from nodejs.org"
    $nodeIndex = Invoke-RestMethod -Uri "https://nodejs.org/dist/index.json"
    $nodeRelease = $nodeIndex | Where-Object { $_.version -match "^v$NodeMajor\." } | Select-Object -First 1
    if (-not $nodeRelease) {
        throw "No Node.js v$NodeMajor release found on nodejs.org"
    }

    $nodeMsi = "node-$($nodeRelease.version)-x64.msi"
    $nodeUrl = "https://nodejs.org/dist/$($nodeRelease.version)/$nodeMsi"
    $nodeInstaller = Join-Path $BootstrapRoot $nodeMsi
    Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeInstaller
    Start-Process msiexec.exe -ArgumentList "/i `"$nodeInstaller`" /qn" -Wait
    Refresh-Path
}
else {
    Write-Log "Node.js already installed: $(node --version)"
}

Write-Log "Node version: $(node --version)"
Write-Log "npm version: $(npm --version)"

Write-Log "Installing @microsoft/mxc-sdk@$MxcSdkVersion globally"
npm install -g "@microsoft/mxc-sdk@$MxcSdkVersion"

Write-Log "Installing OpenClaw package: $OpenClawPackage"
npm install -g $OpenClawPackage
Refresh-Path

Set-OpenClawEnvironment

$gatewayToken = Get-OrCreateGatewayToken
Write-Log "Gateway token ready (also written to $AccessFile)"

$config = @{
    gateway = @{
        mode   = "local"
        port   = $GatewayPort
        bind   = "lan"
        auth   = @{
            mode = "token"
        }
        reload = @{
            mode = "hybrid"
        }
    }
    agents = @{
        defaults = @{
            workspace = $WorkspaceDir
        }
    }
}

$config | ConvertTo-Json -Depth 6 | Set-Content -Path $ConfigFile -Encoding UTF8

$envLines = @(
    "OPENCLAW_GATEWAY_TOKEN=$gatewayToken"
    "OPENCLAW_GATEWAY_PORT=$GatewayPort"
    "# Add your AI provider key(s) below, then restart the gateway:"
    "# OPENAI_API_KEY=sk-..."
    "# ANTHROPIC_API_KEY=sk-ant-..."
)

if (Test-Path $EnvFile) {
    $preserved = Get-Content $EnvFile | Where-Object {
        $_ -notmatch '^\s*OPENCLAW_GATEWAY_TOKEN=' -and
        $_ -notmatch '^\s*OPENCLAW_GATEWAY_PORT=' -and
        $_.Trim().Length -gt 0
    }
    $envLines += $preserved
}

$envLines | Set-Content -Path $EnvFile -Encoding UTF8
[Environment]::SetEnvironmentVariable("OPENCLAW_GATEWAY_TOKEN", $gatewayToken, "Machine")

$publicIp = $null
for ($attempt = 1; $attempt -le 6; $attempt++) {
    try {
        $publicIp = Invoke-RestMethod `
            -Uri "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" `
            -Headers @{ Metadata = "true" } `
            -TimeoutSec 5
        if ($publicIp) { break }
    }
    catch {
        Start-Sleep -Seconds 5
    }
}
if (-not $publicIp) {
    $publicIp = "<vm-public-ip>"
}

@(
    "OpenClaw gateway access"
    "======================="
    ""
    "Control UI:  http://${publicIp}:$GatewayPort"
    "WebSocket:   ws://${publicIp}:$GatewayPort"
    ""
    "Gateway token (paste in Control UI Connect):"
    $gatewayToken
    ""
    "Config dir:  $ConfigDir"
    "Env file:    $EnvFile"
    ""
    "1. RDP to this VM and add OPENAI_API_KEY or ANTHROPIC_API_KEY to $EnvFile"
    "2. Restart gateway: powershell -File C:\openclaw\start-gateway.ps1 -Restart"
    "3. Open the Control UI URL above from your browser and paste the token"
    ""
    "MXC: configure processcontainer backend per @microsoft/mxc-sdk docs."
) | Set-Content -Path $AccessFile -Encoding UTF8

$acl = Get-Acl $AccessFile
$acl.SetAccessRuleProtection($true, $false)
$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "Administrators", "FullControl", "Allow"
)
$acl.SetAccessRule($adminRule)
Set-Acl -Path $AccessFile -AclObject $acl

$StartGatewayScript = Join-Path $OpenClawRoot "start-gateway.ps1"
@'
param(
    [switch] $Restart,
    [string] $ConfigDir = "C:\openclaw\config",
    [int] $Port = 18789
)

$ErrorActionPreference = "Stop"

$env:OPENCLAW_CONFIG_DIR = $ConfigDir
$env:OPENCLAW_CONFIG_PATH = Join-Path $ConfigDir "openclaw.json"
$env:OPENCLAW_STATE_DIR = Join-Path $ConfigDir "state"
$env:OPENCLAW_WORKSPACE_DIR = Join-Path $ConfigDir "workspace"

$envFile = Join-Path $ConfigDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $name = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            Set-Item -Path "Env:$name" -Value $value
        }
    }
}

if (-not (Get-Command openclaw -ErrorAction SilentlyContinue)) {
    throw "OpenClaw CLI not found on PATH."
}

if ($Restart) {
    openclaw gateway restart
    openclaw gateway status
    exit 0
}

openclaw gateway --bind lan --port $Port
'@ | Set-Content -Path $StartGatewayScript -Encoding UTF8

Write-Log "Opening Windows Firewall for OpenClaw gateway port $GatewayPort"
$firewallRuleName = "OpenClaw Gateway TCP $GatewayPort"
if (-not (Get-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $firewallRuleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $GatewayPort | Out-Null
}
Write-Log "Windows Firewall rule ensured: $firewallRuleName"

Write-Log "Removing legacy OpenClawAgent scheduled task if present"
Unregister-ScheduledTask -TaskName "OpenClawAgent" -Confirm:$false -ErrorAction SilentlyContinue

Write-Log "Installing OpenClaw gateway Windows service (Scheduled Task)"
try {
    openclaw config set gateway.mode local | Out-Null
    openclaw config set gateway.bind lan | Out-Null
    openclaw config set gateway.port $GatewayPort | Out-Null
}
catch {
    Write-Log "openclaw config set skipped: $($_.Exception.Message)"
}

openclaw gateway install --force
Start-Sleep -Seconds 5
openclaw gateway restart
Start-Sleep -Seconds 10

try {
    $status = openclaw gateway status 2>&1 | Out-String
    Write-Log $status.Trim()
}
catch {
    Write-Log "Gateway status check: $($_.Exception.Message)"
}

$Readme = Join-Path $OpenClawRoot "README.txt"
@(
    "OpenClaw + MXC VM bootstrap complete."
    ""
    "Gateway URL and token: C:\openclaw\gateway-access.txt"
    "Add AI keys to:        C:\openclaw\config\.env"
    "Restart gateway:       powershell -File C:\openclaw\start-gateway.ps1 -Restart"
    ""
    "Note: MXC is alpha preview; do not treat profiles as security boundaries."
) | Set-Content -Path $Readme -Encoding UTF8

Write-Log "Bootstrap finished. Reboot recommended for WSL2/Hyper-V features."
