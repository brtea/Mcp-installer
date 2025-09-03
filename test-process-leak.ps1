# 프로세스 누수 테스트 스크립트

Write-Host "`n=== Process Leak Prevention Test ===" -ForegroundColor Cyan

# 테스트 전 claude 프로세스 확인
Write-Host "`n[1] Checking for existing claude processes..." -ForegroundColor Yellow
$initialProcesses = Get-Process -Name "claude" -ErrorAction SilentlyContinue
if ($initialProcesses) {
    Write-Host "  Found $($initialProcesses.Count) existing claude process(es)" -ForegroundColor Yellow
    foreach ($proc in $initialProcesses) {
        Write-Host "    - PID: $($proc.Id), StartTime: $($proc.StartTime)" -ForegroundColor Gray
    }
} else {
    Write-Host "  No existing claude processes found" -ForegroundColor Green
}

# 테스트 1: 정상 실행
Write-Host "`n[2] Testing normal verification run..." -ForegroundColor Yellow
try {
    # Verify 옵션으로 실행
    $result = & powershell -File ".\mcp-installer.ps1" -Verify -DryRun 2>&1
    Write-Host "  Verification completed" -ForegroundColor Green
} catch {
    Write-Host "  Error during verification: $_" -ForegroundColor Red
}

Start-Sleep -Seconds 3

# 테스트 후 프로세스 확인
Write-Host "`n[3] Checking for leftover processes..." -ForegroundColor Yellow
$afterProcesses = Get-Process -Name "claude" -ErrorAction SilentlyContinue
$leftoverCount = 0

if ($afterProcesses) {
    foreach ($proc in $afterProcesses) {
        # 테스트 시작 후 생성된 프로세스만 확인
        if (-not $initialProcesses -or -not ($initialProcesses.Id -contains $proc.Id)) {
            Write-Host "  WARNING: Found leftover process - PID: $($proc.Id)" -ForegroundColor Red
            $leftoverCount++
        }
    }
}

if ($leftoverCount -eq 0) {
    Write-Host "  ✓ No process leaks detected" -ForegroundColor Green
} else {
    Write-Host "  ✗ Found $leftoverCount leaked process(es)" -ForegroundColor Red
}

# 테스트 2: 예외 상황 시뮬레이션
Write-Host "`n[4] Testing exception handling..." -ForegroundColor Yellow

# Verify-Run 함수만 테스트하기 위한 간단한 래퍼
$testScript = @'
. .\mcp-installer.ps1 -DryRun
try {
    # 강제로 예외 발생시키기 위해 잘못된 경로 사용
    $env:PATH = "INVALID_PATH"
    Verify-Run
} finally {
    Write-Host "Finally block executed"
}
'@

$testScript | Out-File -FilePath ".\test-verify-temp.ps1" -Encoding UTF8
$exceptionResult = & powershell -File ".\test-verify-temp.ps1" 2>&1
Remove-Item ".\test-verify-temp.ps1" -Force -ErrorAction SilentlyContinue

# 최종 프로세스 상태 확인
Write-Host "`n[5] Final process check..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
$finalProcesses = Get-Process -Name "claude" -ErrorAction SilentlyContinue
$finalLeaks = 0

if ($finalProcesses) {
    foreach ($proc in $finalProcesses) {
        if (-not $initialProcesses -or -not ($initialProcesses.Id -contains $proc.Id)) {
            Write-Host "  WARNING: Process still running - PID: $($proc.Id)" -ForegroundColor Red
            $finalLeaks++
            
            # 테스트용 프로세스 정리
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                Write-Host "    Cleaned up test process" -ForegroundColor Gray
            } catch {}
        }
    }
}

# 결과 요약
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
if ($leftoverCount -eq 0 -and $finalLeaks -eq 0) {
    Write-Host "✓ Process leak prevention working correctly!" -ForegroundColor Green
    Write-Host "  - try-finally blocks ensure cleanup" -ForegroundColor Gray
    Write-Host "  - No orphaned processes detected" -ForegroundColor Gray
} else {
    Write-Host "✗ Process leaks detected!" -ForegroundColor Red
    Write-Host "  - Normal run leaks: $leftoverCount" -ForegroundColor Yellow
    Write-Host "  - Exception handling leaks: $finalLeaks" -ForegroundColor Yellow
}