# deploy-record.ps1
# If record.html changed, copy it into this repo as index.html, commit, and push
# to GitHub Pages. Does nothing when unchanged. Run periodically by Task Scheduler.
# Log: %LOCALAPPDATA%\qotd-deploy.log
# NOTE: keep this file ASCII-only. It sits in a folder with non-ASCII characters
# in its path; $PSScriptRoot resolves that correctly at runtime, so no hardcoded path.

$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot
$base = Split-Path -LiteralPath $repo   # -Parent is the default
$src  = Join-Path $base "record.html"
$dst  = Join-Path $repo "index.html"
$log  = Join-Path $env:LOCALAPPDATA "qotd-deploy.log"

function Log($m) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" |
        Out-File -LiteralPath $log -Append -Encoding utf8
}

try {
    if (-not (Test-Path -LiteralPath $src)) { Log "SKIP: record.html not found at $src"; exit 0 }

    $srcHash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    $dstHash = if (Test-Path -LiteralPath $dst) { (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash } else { "" }
    if ($srcHash -eq $dstHash) { exit 0 }   # no change -> quiet exit

    Copy-Item -LiteralPath $src -Destination $dst -Force

    & git -C $repo add -A 2>&1 | Out-Null
    & git -C $repo diff --cached --quiet
    if ($LASTEXITCODE -eq 0) { Log "SKIP: nothing staged"; exit 0 }

    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    Log "change detected -> commit/push"
    (& git -C $repo commit -m "auto: sync record.html ($stamp)" 2>&1) | ForEach-Object { Log "  $_" }
    (& git -C $repo push 2>&1) | ForEach-Object { Log "  $_" }
    if ($LASTEXITCODE -eq 0) { Log "OK: deployed -> https://mmiracleu.github.io/qotd-record/" }
    else { Log "ERROR: git push failed (code $LASTEXITCODE). GitHub login may have expired -> run one manual push." }
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
