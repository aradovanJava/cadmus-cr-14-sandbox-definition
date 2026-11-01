# CADMUS-CR-14 - sandbox environment check for SC1 (VM1, Windows workstation)
#
#   powershell -ExecutionPolicy Bypass -File C:\Lab\verify-cr-env.ps1
#
# Sandbox counterpart of tools\verify-env.ps1 in cadmus-vulnshop-cr. It knows
# that SonarQube runs on SQ1 and OWASP ZAP on OWZ1 rather than in a local
# Docker. If anything reports MISSING or DOWN, tell your instructor before
# starting the lab.
#
# The check first reloads PATH and JAVA_HOME from the registry. A desktop
# session that was opened before the tools were installed keeps an old PATH,
# and every window started from it inherits that PATH; this script reports
# that case instead of reporting the tools as missing. Every probe has a time
# limit, so a slow or hanging tool cannot stall the check.

$ok = $true

# --- 1. PATH as stored in the registry ----------------------------------------
$sessionPath = @($env:Path -split ';' | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') })
$machineJavaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
if ($machineJavaHome) { $env:JAVA_HOME = $machineJavaHome }
$env:Path = (@([Environment]::GetEnvironmentVariable('Path', 'Machine'),
               [Environment]::GetEnvironmentVariable('Path', 'User')) | Where-Object { $_ }) -join ';'
$stale = @($env:Path -split ';' | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') } |
           Where-Object { $sessionPath -notcontains $_ })

function Invoke-Probe([string]$command, [string]$arguments, [int]$timeoutSec) {
    $app = Get-Command $command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $app) { return @{ Ok = $false; Text = 'not on PATH' } }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($app.Source -match '\.(cmd|bat)$') {
        $psi.FileName = $env:ComSpec
        $psi.Arguments = '/d /c ""' + $app.Source + '" ' + $arguments + '"'
    } else {
        $psi.FileName = $app.Source
        $psi.Arguments = $arguments
    }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    try { $p = [System.Diagnostics.Process]::Start($psi) }
    catch { return @{ Ok = $false; Text = "cannot start $($app.Source)" } }
    $stdout = $p.StandardOutput.ReadToEndAsync()
    $stderr = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($timeoutSec * 1000)) {
        try { $p.Kill() } catch { }
        return @{ Ok = $false; Text = "no answer within $timeoutSec s ($($app.Source))" }
    }
    $first = (($stdout.Result + "`n" + $stderr.Result) -split "`r?`n" |
              Where-Object { $_.Trim() } | Select-Object -First 1)
    if ($p.ExitCode -ne 0) { return @{ Ok = $false; Text = "exit code $($p.ExitCode): $first" } }
    return @{ Ok = $true; Text = "$first" }
}

function Check-Tool([string]$name, [string]$command, [string]$arguments, [int]$timeoutSec = 30) {
    Write-Host -NoNewline ("{0,-18}" -f $name)
    $r = Invoke-Probe $command $arguments $timeoutSec
    if ($r.Ok) {
        Write-Host "OK    $($r.Text)" -ForegroundColor Green
    } else {
        Write-Host "MISSING  $($r.Text)" -ForegroundColor Red
        $script:ok = $false
    }
}

function Check-Url([string]$name, [string]$url, [switch]$Optional) {
    Write-Host -NoNewline ("{0,-18}" -f $name)
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
        $body = "$($r.Content)"
        if ($body.Length -gt 60) { $body = "HTTP $($r.StatusCode)" }
        Write-Host "OK    $body" -ForegroundColor Green
    } catch {
        if ($Optional) {
            Write-Host "DOWN  (optional) $url" -ForegroundColor Yellow
        } else {
            Write-Host "DOWN  $url" -ForegroundColor Red
            $script:ok = $false
        }
    }
}

Write-Host "`nCADMUS-CR-14 - sandbox environment check (SC1)`n" -ForegroundColor Cyan

Check-Tool "java"    "java"    "-version"
Check-Tool "javac"   "javac"   "-version"
Check-Tool "mvn"     "mvn"     "-v"       60
Check-Tool "git"     "git"     "--version"
Check-Tool "node"    "node"    "--version"
Check-Tool "npm"     "npm"     "--version" 60
Check-Tool "python"  "python"  "--version"
Check-Tool "snyk"    "snyk"    "--version" 60
Check-Tool "sqlmap"  "sqlmap"  "--version" 90

Write-Host -NoNewline ("{0,-18}" -f "intellij idea")
$idea = Get-ChildItem "C:\Program Files\JetBrains" -Directory -Filter "IntelliJ IDEA*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($idea) { Write-Host "OK    $($idea.Name)" -ForegroundColor Green }
else { Write-Host "MISSING" -ForegroundColor Red; $ok = $false }

Write-Host -NoNewline ("{0,-18}" -f "postman")
if (Test-Path "$env:LOCALAPPDATA\Postman\Postman.exe") { Write-Host "OK" -ForegroundColor Green }
else { Write-Host "not installed for this user (optional)" -ForegroundColor Yellow }

Write-Host -NoNewline ("{0,-18}" -f "application")
if (Test-Path "C:\Lab\cadmus-vulnshop-cr\pom.xml") { Write-Host "OK    C:\Lab\cadmus-vulnshop-cr" -ForegroundColor Green }
else { Write-Host "MISSING  git clone https://github.com/aradovanJava/cadmus-vulnshop-cr.git C:\Lab\cadmus-vulnshop-cr" -ForegroundColor Red; $ok = $false }

Write-Host ""
Check-Url "sonarqube (SQ1)" "http://localhost:9000/api/system/status"
Check-Url "zap ui (OWZ1)"   "http://owz1:8080/zap/"
Check-Url "vulnshop"        "http://127.0.0.1:8080/actuator/health" -Optional

Write-Host ""
if ($stale.Count -gt 0) {
    Write-Host "This window had an outdated PATH ($($stale.Count) folder(s) missing), so the check used" -ForegroundColor Yellow
    Write-Host "the PATH stored in the registry. Close this window and open a new PowerShell window;" -ForegroundColor Yellow
    Write-Host "if a tool is still not found there, sign out of Windows and sign in again." -ForegroundColor Yellow
    Write-Host ""
}
if ($ok) { Write-Host "Sandbox ready." -ForegroundColor Green }
else     { Write-Host "Something is missing or down - raise it now." -ForegroundColor Red }
Write-Host "vulnshop is DOWN until you start it with tools\run-app.ps1 - that is expected.`n"
