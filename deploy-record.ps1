# deploy-record.ps1
# record.html 이 바뀌었으면 GitHub Pages 저장소로 복사 → 커밋 → 푸시.
# 안 바뀌었으면 아무것도 안 함. 윈도우 스케줄러가 주기적으로 실행.

$ErrorActionPreference = "Stop"
$base = "D:\(A)++MIRACLE ENGLISH++\A 클로드코드\Question of the Day"
$src  = Join-Path $base "record.html"
$repo = Join-Path $base "record-site"
$dst  = Join-Path $repo "index.html"
$log  = Join-Path $repo "deploy.log"

function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" | Out-File -FilePath $log -Append -Encoding utf8 }

try {
    if (-not (Test-Path $src))  { Log "SKIP: record.html 없음"; exit 0 }

    $srcHash = (Get-FileHash $src -Algorithm SHA256).Hash
    $dstHash = if (Test-Path $dst) { (Get-FileHash $dst -Algorithm SHA256).Hash } else { "" }
    if ($srcHash -eq $dstHash) { exit 0 }   # 변경 없음 → 조용히 종료

    Copy-Item $src $dst -Force
    Set-Location $repo

    git add -A 2>&1 | Out-Null
    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) { Log "SKIP: git 변경사항 없음"; exit 0 }

    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    git commit -m "auto: sync record.html ($stamp)" 2>&1 | Out-File -FilePath $log -Append -Encoding utf8
    git push 2>&1 | Out-File -FilePath $log -Append -Encoding utf8
    if ($LASTEXITCODE -eq 0) { Log "OK: 배포 완료 -> https://mmiracleu.github.io/qotd-record/" }
    else { Log "ERROR: git push 실패 (코드 $LASTEXITCODE). 로그인 만료일 수 있음." }
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
