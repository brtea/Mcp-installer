# 종합 보안 검증 테스트

Write-Host "`n=== Comprehensive Security Test ===" -ForegroundColor Cyan
Write-Host "Testing mcp-installer.ps1 security features`n" -ForegroundColor Gray

$testResults = @()

# 테스트 1: 안전한 NPM 패키지
Write-Host "[1] Testing safe NPM package..." -ForegroundColor Yellow
$result1 = echo "y" | powershell -File ".\mcp-installer.ps1" -Config ".\test-safe.json" -Scope user -DryRun 2>&1
if ($result1 -match "Success 1, Failed 0") {
    Write-Host "  ✓ Safe package correctly allowed" -ForegroundColor Green
    $testResults += $true
} else {
    Write-Host "  ✗ Safe package incorrectly blocked" -ForegroundColor Red
    $testResults += $false
}

# 테스트 2: 악성 명령어들
Write-Host "`n[2] Testing malicious commands..." -ForegroundColor Yellow
$result2 = echo "y" | powershell -File ".\mcp-installer.ps1" -Config ".\test-malicious.json" -Scope user -DryRun 2>&1
$blocked = ($result2 -match "Failed 3") -or ($result2 -match "Security validation failed")
if ($blocked) {
    Write-Host "  ✓ Malicious commands correctly blocked" -ForegroundColor Green
    $testResults += $true
} else {
    Write-Host "  ✗ Malicious commands incorrectly allowed" -ForegroundColor Red
    $testResults += $false
}

# 테스트 3: 명령 주입 시도
Write-Host "`n[3] Testing command injection..." -ForegroundColor Yellow
$injectionConfig = @{
    "mcpServers" = @{
        "injection" = @{
            "type" = "stdio"
            "command" = "npx"
            "args" = @("-y", "@safe/package; rm -rf /")
        }
    }
} | ConvertTo-Json -Depth 10 | Out-File -FilePath ".\test-injection.json" -Encoding UTF8

$result3 = echo "y" | powershell -File ".\mcp-installer.ps1" -Config ".\test-injection.json" -Scope user -DryRun 2>&1
if ($result3 -match "Dangerous argument pattern detected") {
    Write-Host "  ✓ Command injection correctly blocked" -ForegroundColor Green
    $testResults += $true
} else {
    Write-Host "  ✗ Command injection not detected" -ForegroundColor Red
    $testResults += $false
}
Remove-Item ".\test-injection.json" -Force -ErrorAction SilentlyContinue

# 테스트 4: TrustSource 플래그
Write-Host "`n[4] Testing TrustSource flag..." -ForegroundColor Yellow
$result4 = powershell -File ".\mcp-installer.ps1" -Config ".\test-safe.json" -Scope user -DryRun -TrustSource 2>&1
if ($result4 -match "Using -TrustSource flag: skipping security check") {
    Write-Host "  ✓ TrustSource flag works correctly" -ForegroundColor Green
    $testResults += $true
} else {
    Write-Host "  ✗ TrustSource flag not working" -ForegroundColor Red
    $testResults += $false
}

# 테스트 5: 알 수 없는 실행 파일
Write-Host "`n[5] Testing unknown executable..." -ForegroundColor Yellow
$unknownConfig = @{
    "mcpServers" = @{
        "unknown" = @{
            "type" = "stdio"
            "command" = "unknown.exe"
            "args" = @()
        }
    }
} | ConvertTo-Json -Depth 10 | Out-File -FilePath ".\test-unknown.json" -Encoding UTF8

$result5 = echo "y" | powershell -File ".\mcp-installer.ps1" -Config ".\test-unknown.json" -Scope user -DryRun 2>&1
if ($result5 -match "Disallowed command") {
    Write-Host "  ✓ Unknown executable correctly blocked" -ForegroundColor Green
    $testResults += $true
} else {
    Write-Host "  ✗ Unknown executable not blocked" -ForegroundColor Red
    $testResults += $false
}
Remove-Item ".\test-unknown.json" -Force -ErrorAction SilentlyContinue

# 결과 요약
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
$passCount = ($testResults | Where-Object {$_}).Count
$totalCount = $testResults.Count
$passRate = [math]::Round(($passCount / $totalCount) * 100, 1)

Write-Host "Passed: $passCount/$totalCount ($passRate%)" -ForegroundColor $(if ($passRate -ge 80) {"Green"} elseif ($passRate -ge 60) {"Yellow"} else {"Red"})

if ($passRate -eq 100) {
    Write-Host "`n✓ All security validations working perfectly!" -ForegroundColor Green
} elseif ($passRate -ge 80) {
    Write-Host "`n⚠ Most security features working, minor issues detected" -ForegroundColor Yellow
} else {
    Write-Host "`n✗ Security validation needs improvement" -ForegroundColor Red
}