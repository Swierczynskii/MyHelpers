Param(
  [string]$ScriptPath = (Join-Path -Path $PSScriptRoot -ChildPath 'NetworkInterfaceSwitch.ps1'),
  [string]$ShortcutName = 'Network Interface Switch (Admin).lnk',
  [ValidateSet('WindowsPowerShell','PowerShell7')]
  [string]$Host = 'WindowsPowerShell'
)

# Resolve PowerShell host executable
switch ($Host) {
  'WindowsPowerShell' { $psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" }
  'PowerShell7'       { $psExe = "$env:ProgramFiles\PowerShell\7\pwsh.exe" }
  default             { throw "Unsupported Host: $Host" }
}

if (-not (Test-Path -LiteralPath $ScriptPath)) {
  throw "Script not found: $ScriptPath"
}
$ScriptPath = (Resolve-Path -LiteralPath $ScriptPath).Path

$desktop = [Environment]::GetFolderPath('Desktop')
$lnkPath = Join-Path $desktop $ShortcutName

# Build an elevated launch command:
#  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath '<psExe>' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"<script>\"' "
$psExeQuoted = '"' + $psExe + '"'
$scriptQuoted = '"' + $ScriptPath + '"'
$elevArgList = "-NoProfile -ExecutionPolicy Bypass -File $scriptQuoted"
$cmd = "Start-Process -WindowStyle Normal -Verb RunAs -FilePath $psExeQuoted -ArgumentList '$elevArgList'"
$shortcutArgs = "-NoProfile -ExecutionPolicy Bypass -Command $cmd"

$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($lnkPath)
$sc.TargetPath = $psExe
$sc.Arguments = $shortcutArgs
$sc.WorkingDirectory = (Split-Path -Path $ScriptPath -Parent)
$sc.Description = "Run NetworkInterfaceSwitch.ps1 elevated"
# Optional icon (network icon-ish)
$sc.IconLocation = "$env:SystemRoot\System32\shell32.dll, 265"
$sc.Save()

Write-Host "Shortcut created:" $lnkPath
Write-Host "Target: $($sc.TargetPath)"
Write-Host "Arguments: $($sc.Arguments)"
Write-Host "WorkingDirectory: $($sc.WorkingDirectory)"
