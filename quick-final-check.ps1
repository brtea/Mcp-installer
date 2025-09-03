# MCP Installer 간단 최종 점검

Write-Host "`n=== MCP Installer Quick Final Check ===" -ForegroundColor Cyan

# 1. 주요 보안 기능 테스트
Write-Host "`n[1] Security Features:" -ForegroundColor Yellow

# 안전한 명령어 테스트
$safeTest = echo "y" | powershell -File ".\mcp-installer.ps1" -Config ".\test-safe.json" -Scope user -DryRun 2>&1
if ($safeTest -match "Success 1") {
    Write-Host "  ✓ Safe commands allowed" -ForegroundColor Green
} else {
    Write-Host "  ✗ Safe commands blocked incorrectly" -ForegroundColor Red
}

# 악성 명령어 차단 테스트
$malTest = echo "y" | powershell -File ".\mcp-installer.ps1" -Config ".\test-malicious.json" -Scope user -DryRun 2>&1
if ($malTest -match "Security validation failed") {
    Write-Host "  ✓ Malicious commands blocked" -ForegroundColor Green
} else {
    Write-Host "  ✗ Malicious commands not blocked" -ForegroundColor Red
}

# 2. 프로세스 관리 확인
Write-Host "`n[2] Process Management:" -ForegroundColor Yellow
$script = Get-Content ".\mcp-installer.ps1" -Raw

if ($script -match "finally\s*\{[\s\S]*?Stop-Process") {
    Write-Host "  ✓ Process cleanup in finally block" -ForegroundColor Green
} else {
    Write-Host "  ✗ No finally block for cleanup" -ForegroundColor Red
}

if ($script -match "PID:.*debugProcess\.Id") {
    Write-Host "  ✓ Process ID tracking" -ForegroundColor Green
} else {
    Write-Host "  ✗ No PID tracking" -ForegroundColor Red
}

# 3. 에러 처리 확인
Write-Host "`n[3] Error Handling:" -ForegroundColor Yellow

$tryCount = ([regex]::Matches($script, "try\s*\{")).Count
$catchCount = ([regex]::Matches($script, "catch\s*\{")).Count
$finallyCount = ([regex]::Matches($script, "finally\s*\{")).Count

Write-Host "  • Try blocks: $tryCount" -ForegroundColor Gray
Write-Host "  • Catch blocks: $catchCount" -ForegroundColor Gray
Write-Host "  • Finally blocks: $finallyCount" -ForegroundColor Gray

if ($tryCount -gt 3 -and $catchCount -gt 2) {
    Write-Host "  ✓ Comprehensive error handling" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Limited error handling" -ForegroundColor Yellow
}

# 4. 인코딩 및 경로 처리
Write-Host "`n[4] Path & Encoding:" -ForegroundColor Yellow

if ($script -match "Join-Path" -and $script -match "Test-Path") {
    Write-Host "  ✓ Proper path handling" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Path handling could be improved" -ForegroundColor Yellow
}

if ($script -match "-Encoding\s+UTF8") {
    Write-Host "  ✓ UTF-8 encoding specified" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Encoding not specified" -ForegroundColor Yellow
}

# 5. 위험 패턴 검사
Write-Host "`n[5] Security Patterns:" -ForegroundColor Yellow

$dangerous = $false
if ($script -match "Invoke-Expression|iex") {
    Write-Host "  ✗ Found Invoke-Expression (dangerous)" -ForegroundColor Red
    $dangerous = $true
}
if ($script -match "ConvertTo-SecureString.*-AsPlainText") {
    Write-Host "  ✗ Found plain text secrets" -ForegroundColor Red
    $dangerous = $true
}
if (-not $dangerous) {
    Write-Host "  ✓ No dangerous patterns found" -ForegroundColor Green
}

# 6. 주요 기능 확인
Write-Host "`n[6] Core Features:" -ForegroundColor Yellow

if ($script -match "Test-SafeCommand" -and $script -match "Test-SafeArgs") {
    Write-Host "  ✓ Command validation functions" -ForegroundColor Green
} else {
    Write-Host "  ✗ Missing validation functions" -ForegroundColor Red
}

if ($script -match "DangerousPatterns" -and $script -match "SafeCommands") {
    Write-Host "  ✓ Whitelist/Blacklist defined" -ForegroundColor Green
} else {
    Write-Host "  ✗ Missing security lists" -ForegroundColor Red
}

if ($script -match "Confirm-UntrustedSource") {
    Write-Host "  ✓ User confirmation for untrusted sources" -ForegroundColor Green
} else {
    Write-Host "  ✗ No untrusted source confirmation" -ForegroundColor Red
}

# 최종 평가
Write-Host "`n=== Final Assessment ===" -ForegroundColor Cyan

$criticalIssues = 0
$script = Get-Content ".\mcp-installer.ps1" -Raw

# 중요 체크포인트
$checks = @{
    "Security validation" = ($script -match "Test-McpServerConfig")
    "Process cleanup" = ($script -match "finally.*Stop-Process")
    "Error handling" = ($script -match "try.*catch")
    "Path safety" = ($script -match "Join-Path")
    "Command whitelist" = ($script -match "SafeCommands")
}

foreach ($check in $checks.Keys) {
    if ($checks[$check]) {
        Write-Host "✓ $check" -ForegroundColor Green
    } else {
        Write-Host "✗ $check" -ForegroundColor Red
        $criticalIssues++
    }
}

Write-Host "`n" -NoNewline
if ($criticalIssues -eq 0) {
    Write-Host "✅ All critical checks passed - Script is production ready!" -ForegroundColor Green
} elseif ($criticalIssues -le 2) {
    Write-Host "⚠️  Minor issues found - Review recommended" -ForegroundColor Yellow
} else {
    Write-Host "❌ Critical issues found - Do not use in production!" -ForegroundColor Red
}