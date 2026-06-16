param(
  [switch]$Claude,
  [switch]$Codex
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Info {
  param([string]$Message)
  Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-WarnMessage {
  param([string]$Message)
  Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Fail {
  param([string]$Message)
  throw $Message
}

function Test-CommandExists {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Guard-AgainstSudo {
  if (-not [string]::IsNullOrWhiteSpace($env:SUDO_USER)) {
    Fail 'Run this script without sudo so CLI packages are installed for your user.'
  }
}

function Get-IsWindowsPlatform {
  if ($PSVersionTable.PSEdition -eq 'Desktop') {
    return $true
  }

  if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
    return [bool]$IsWindows
  }

  return [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

function Install-ClaudeCode {
  if (Test-CommandExists -Name 'claude') {
    Write-Info 'Claude Code is already installed.'
    return
  }

  Write-Info 'Installing Claude Code with Anthropic native installer...'

  if (Get-IsWindowsPlatform) {
    Invoke-Expression (Invoke-RestMethod 'https://claude.ai/install.ps1')
  }
  else {
    if (-not (Test-CommandExists -Name 'bash')) {
      Fail 'Bash is required to install Claude Code on Unix-like systems.'
    }
    if (-not (Test-CommandExists -Name 'curl')) {
      Fail 'curl is required to install Claude Code on Unix-like systems.'
    }

    & bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'
    if ($LASTEXITCODE -ne 0) {
      Fail 'Claude Code native installer failed.'
    }
  }

  if (Test-CommandExists -Name 'claude') {
    Write-Info 'Claude Code installed successfully.'
    return
  }

  Write-WarnMessage "Claude Code was installed, but 'claude' is not visible in PATH in this shell yet."
}

function Install-CodexCli {
  if (Test-CommandExists -Name 'codex') {
    Write-Info 'Codex is already installed.'
    return
  }

  Write-Info 'Installing Codex with OpenAI official installer...'

  if (Get-IsWindowsPlatform) {
    Invoke-Expression (Invoke-RestMethod 'https://chatgpt.com/codex/install.ps1')
  }
  else {
    if (-not (Test-CommandExists -Name 'sh')) {
      Fail 'sh is required to install Codex on Unix-like systems.'
    }
    if (-not (Test-CommandExists -Name 'curl')) {
      Fail 'curl is required to install Codex on Unix-like systems.'
    }

    & sh -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'
    if ($LASTEXITCODE -ne 0) {
      Fail 'Codex official installer failed.'
    }
  }

  if (Test-CommandExists -Name 'codex') {
    Write-Info 'Codex installed successfully.'
    return
  }

  Write-WarnMessage "Codex was installed, but 'codex' is not visible in PATH in this shell yet."
}

function Main {
  $installClaude = $Claude.IsPresent
  $installCodex = $Codex.IsPresent

  if (-not $installClaude -and -not $installCodex) {
    $installClaude = $true
    $installCodex = $true
  }

  Guard-AgainstSudo

  Write-Host ''
  Write-Host '=== AI CLI installation ==='

  if ($installClaude) {
    Install-ClaudeCode
  }

  if ($installCodex) {
    Install-CodexCli
  }

  Write-Host ''
  Write-Host '=== Done ==='
  Write-Host 'Processed components:'
  if ($installClaude) {
    Write-Host '  Claude Code -> claude'
    Write-Host '    Installed via https://claude.ai/install.ps1'
  }
  if ($installCodex) {
    Write-Host '  Codex -> codex'
    Write-Host '    Installed via https://chatgpt.com/codex/install.ps1'
  }
}

Main
