# CADMUS-CR-14 - repair the PATH on SC1 so the lab tools resolve.
#
# The tools (JDK, Maven, Git, Node, Snyk, SQLMap) are installed, but their
# folders are missing from the session PATH. This adds them to the user's
# PATH (persistent, no admin needed), fixes the current session, and re-runs
# the environment check.
#
# Run in PowerShell on SC1 as 'user':
#   irm https://raw.githubusercontent.com/aradovanJava/cadmus-cr-14-sandbox-definition/main/tools/fix-sc1-path.ps1 | iex

$ErrorActionPreference = 'Continue'

$userPath = [Environment]::GetEnvironmentVariable('Path','User')
$machPath = [Environment]::GetEnvironmentVariable('Path','Machine')
if (-not $userPath) { $userPath = '' }
Write-Host ("USER PATH    ({0}): {1}" -f $userPath.Length, $userPath)
Write-Host ("MACHINE PATH ({0}): {1}" -f $machPath.Length, $machPath)

$jdk = (Get-ChildItem 'C:\Program Files\Java' -Directory -Filter 'jdk-*' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1).FullName
$want = @()
if ($jdk) { $want += "$jdk\bin" }
$want += 'C:\ProgramData\chocolatey\bin','C:\Program Files\Git\cmd','C:\Program Files\nodejs','C:\Tools\bin'

Write-Host "`nON DISK:"
$want | ForEach-Object { Write-Host ("  {0,-45} {1}" -f $_, (Test-Path $_)) }

$have = (($userPath + ';' + $machPath).TrimEnd(';')).Split(';') | Where-Object { $_ }
$add  = $want | Where-Object { (Test-Path $_) -and ($have -notcontains $_) }

if ($add) {
    $newUser = ((@($userPath.TrimEnd(';')) + $add) | Where-Object { $_ }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newUser, 'User')
    $env:Path = (($add + $env:Path.Split(';')) | Where-Object { $_ } | Select-Object -Unique) -join ';'
    if ($jdk -and -not $env:JAVA_HOME) { $env:JAVA_HOME = $jdk }
    Write-Host "`nADDED TO USER PATH:" -ForegroundColor Green
    $add | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "`nNothing to add - dirs already on PATH, or missing on disk (see ON DISK above)." -ForegroundColor Yellow
}

Write-Host "`n--- Re-running the environment check in this session ---`n" -ForegroundColor Cyan
if (Test-Path 'C:\Lab\verify-cr-env.ps1') { & 'C:\Lab\verify-cr-env.ps1' }
else { Write-Host 'C:\Lab\verify-cr-env.ps1 not found; open a NEW PowerShell and test: javac -version; mvn -v; git --version' }
