# CADMUS-CR-14 - make the lab tools available in this session (and new ones).
#
# The tools (JDK, Maven, Git, Node, Snyk, SQLMap, Python) are installed and the
# machine PATH is correct, but a desktop session started at boot can carry a
# stale/partial PATH, so some commands aren't found. This loads the full
# machine+user PATH into the CURRENT session and also persists the tool folders
# into the user PATH so new windows have them too.
#
# Run in PowerShell on SC1 as 'user':
#   irm https://raw.githubusercontent.com/aradovanJava/cadmus-cr-14-sandbox-definition/main/tools/fix-sc1-path.ps1 | iex

# 1) Authoritative PATH for THIS session (registry machine + user).
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$jdk = (Get-ChildItem 'C:\Program Files\Java' -Directory -Filter 'jdk-*' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1).FullName
if ($jdk) { $env:JAVA_HOME = $jdk }

# 2) Persist the tool folders into the USER PATH (no admin needed).
$mvnBin = (Get-ChildItem 'C:\ProgramData\chocolatey\lib\maven' -Recurse -Filter 'mvn.cmd' -ErrorAction SilentlyContinue |
           Select-Object -First 1).DirectoryName
$want = @()
if ($jdk)    { $want += "$jdk\bin" }
$want += 'C:\ProgramData\chocolatey\bin','C:\Program Files\Git\cmd','C:\Program Files\nodejs','C:\Tools\bin'
if ($mvnBin) { $want += $mvnBin }
$up   = [Environment]::GetEnvironmentVariable('Path','User'); if (-not $up) { $up = '' }
$have = ($up.TrimEnd(';')).Split(';') | Where-Object { $_ }
$add  = $want | Where-Object { (Test-Path $_) -and ($have -notcontains $_) }
if ($add) { [Environment]::SetEnvironmentVariable('Path', (($have + $add) -join ';'), 'User') }

# 3) Report what resolves in this session.
Write-Host "`nTool check (this session):`n" -ForegroundColor Cyan
$allok = $true
foreach ($t in 'java','javac','mvn','git','node','npm','python','snyk','sqlmap') {
    $c = Get-Command $t -ErrorAction SilentlyContinue
    if ($c) { Write-Host ("  {0,-8} OK    {1}" -f $t, $c.Source) -ForegroundColor Green }
    else    { Write-Host ("  {0,-8} MISSING" -f $t) -ForegroundColor Red; $allok = $false }
}
if ($allok) {
    Write-Host "`nAll tools resolve. You're set - and new PowerShell windows will have them too." -ForegroundColor Green
} else {
    Write-Host "`nSomething still missing above - send the output to the instructor." -ForegroundColor Yellow
}
