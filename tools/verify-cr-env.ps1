# CADMUS-CR-14 - sandbox environment check for SC1 (VM1, Windows workstation)
#
#   powershell -ExecutionPolicy Bypass -File C:\Lab\verify-cr-env.ps1
#
# Sandbox counterpart of tools\verify-env.ps1 in cadmus-vulnshop-cr. It knows
# that SonarQube runs on SQ1 and OWASP ZAP on OWZ1 rather than in a local
# Docker. If anything reports MISSING or DOWN, tell your instructor before
# starting the lab.

$ok = $true

function Check-Tool([string]$name, [scriptblock]$probe) {
    Write-Host -NoNewline ("{0,-18}" -f $name)
    try {
        $global:LASTEXITCODE = 0
        $out = & $probe 2>&1 | Where-Object { "$_".Trim() } | Select-Object -First 1
        if ($LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE" }
        Write-Host "OK    $out" -ForegroundColor Green
    } catch {
        Write-Host "MISSING" -ForegroundColor Red
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

Check-Tool "java"    { java -version }
Check-Tool "javac"   { javac -version }
Check-Tool "mvn"     { mvn -v }
Check-Tool "git"     { git --version }
Check-Tool "node"    { node --version }
Check-Tool "npm"     { npm --version }
Check-Tool "python"  { python --version }
Check-Tool "snyk"    { snyk --version }
Check-Tool "sqlmap"  { sqlmap --version }

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
if ($ok) { Write-Host "Sandbox ready." -ForegroundColor Green }
else     { Write-Host "Something is missing or down - raise it now." -ForegroundColor Red }
Write-Host "vulnshop is DOWN until you start it with tools\run-app.ps1 - that is expected.`n"
