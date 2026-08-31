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

# Run git without letting its stderr (which git uses for normal progress output)
# trip $ErrorActionPreference='Stop'. Returns exit code + combined output text.
function Invoke-Git {
    param([string[]]$GitArgs)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & git -C $repo @GitArgs 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    [pscustomobject]@{ Code = $code; Out = $out.TrimEnd() }
}

try {
    if (-not (Test-Path -LiteralPath $src)) { Log "SKIP: record.html not found at $src"; exit 0 }

    $srcHash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    $dstHash = if (Test-Path -LiteralPath $dst) { (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash } else { "" }
    if ($srcHash -eq $dstHash) { exit 0 }   # no change -> quiet exit

    Copy-Item -LiteralPath $src -Destination $dst -Force

    Invoke-Git @('add','-A') | Out-Null
    if ((Invoke-Git @('diff','--cached','--quiet')).Code -eq 0) { Log "SKIP: nothing staged"; exit 0 }

    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    Log "change detected -> commit/push"

    $c = Invoke-Git @('commit','-m',"auto: sync record.html ($stamp)")
    Log $c.Out
    if ($c.Code -ne 0) { Log "ERROR: commit failed (code $($c.Code))"; exit 1 }

    $p = Invoke-Git @('push')
    Log $p.Out
    if ($p.Code -eq 0) { Log "OK: deployed -> https://mmiracleu.github.io/qotd-record/" }
    else { Log "ERROR: git push failed (code $($p.Code)). GitHub login may have expired -> run one manual push." ; exit 1 }
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
