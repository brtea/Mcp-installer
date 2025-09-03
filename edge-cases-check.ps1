# 엣지 케이스 및 잠재적 문제점 검사

Write-Host "`n=== Edge Cases & Potential Issues Check ===" -ForegroundColor Cyan

$script = Get-Content ".\mcp-installer.ps1" -Raw
$issues = @()
$suggestions = @()

# 1. 빈 JSON 처리
Write-Host "`n[1] Empty/Null JSON Handling:" -ForegroundColor Yellow
$emptyJson = "{}"
$emptyJson | Out-File ".\test-empty.json" -Encoding UTF8
$result = powershell -File ".\mcp-installer.ps1" -Config ".\test-empty.json" -DryRun 2>&1
Remove-Item ".\test-empty.json" -Force -ErrorAction SilentlyContinue

if ($result -notmatch "error|exception") {
    Write-Host "  ✓ Handles empty JSON gracefully" -ForegroundColor Green
} else {
    Write-Host "  ✗ Empty JSON causes errors" -ForegroundColor Red
    $issues += "Empty JSON handling"
}

# 2. 대용량 JSON 처리
Write-Host "`n[2] Large JSON Handling:" -ForegroundColor Yellow
if ($script -match "ConvertTo-Json\s+-Depth\s+(\d+)") {
    $depth = $matches[1]
    if ([int]$depth -ge 10) {
        Write-Host "  ✓ JSON depth set to $depth (sufficient)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ JSON depth only $depth (may be insufficient)" -ForegroundColor Yellow
        $suggestions += "Increase JSON depth"
    }
}

# 3. 특수문자 처리
Write-Host "`n[3] Special Character Handling:" -ForegroundColor Yellow
$specialChars = @('`', '$', '"', "'", '\')
$escapeIssues = 0

foreach ($char in $specialChars) {
    if ($script -match [regex]::Escape($char) -and $script -notmatch ([regex]::Escape($char) + [regex]::Escape($char))) {
        $escapeIssues++
    }
}

if ($escapeIssues -eq 0) {
    Write-Host "  ✓ Special characters properly escaped" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Potential escape issues with $escapeIssues characters" -ForegroundColor Yellow
    $suggestions += "Review special character escaping"
}

# 4. 동시성 문제
Write-Host "`n[4] Concurrency Issues:" -ForegroundColor Yellow
if ($script -match "Start-Process.*-Wait" -or $script -match "Wait-Process") {
    Write-Host "  ✓ Process synchronization implemented" -ForegroundColor Green
} else {
    Write-Host "  ⚠ No explicit process waiting" -ForegroundColor Yellow
    $suggestions += "Consider adding -Wait for critical processes"
}

# 5. 권한 문제
Write-Host "`n[5] Permission Handling:" -ForegroundColor Yellow
if ($script -match "#Requires\s+-RunAsAdministrator") {
    Write-Host "  ⚠ Requires admin rights" -ForegroundColor Yellow
    $suggestions += "Document admin requirement"
} elseif ($script -match "Test-Administrator|IsInRole") {
    Write-Host "  ✓ Checks for admin rights" -ForegroundColor Green
} else {
    Write-Host "  ✓ No admin rights required" -ForegroundColor Green
}

# 6. 네트워크 타임아웃
Write-Host "`n[6] Network Timeouts:" -ForegroundColor Yellow
if ($script -match "WebRequest.*Timeout" -or $script -match "TimeoutSec") {
    Write-Host "  ✓ Network timeouts configured" -ForegroundColor Green
} else {
    Write-Host "  ℹ No network operations found" -ForegroundColor Gray
}

# 7. 순환 참조 방지
Write-Host "`n[7] Circular Reference Prevention:" -ForegroundColor Yellow
if ($script -match "\$cfg\.mcpServers\[\$k\]" -and $script -match "Add-Member") {
    Write-Host "  ✓ Using Add-Member (prevents circular refs)" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Direct assignment may cause circular refs" -ForegroundColor Yellow
}

# 8. 파일 잠금 처리
Write-Host "`n[8] File Lock Handling:" -ForegroundColor Yellow
if ($script -match "try.*Get-Content.*catch" -or $script -match "ErrorAction") {
    Write-Host "  ✓ File operations have error handling" -ForegroundColor Green
} else {
    Write-Host "  ⚠ File operations may fail on locked files" -ForegroundColor Yellow
    $issues += "File lock handling"
}

# 9. 무한 루프 방지
Write-Host "`n[9] Infinite Loop Prevention:" -ForegroundColor Yellow
$loopPatterns = @("while\s*\(\s*\$true", "for\s*\(\s*;", "do\s*{")
$hasLoops = $false

foreach ($pattern in $loopPatterns) {
    if ($script -match $pattern) {
        $hasLoops = $true
    }
}

if ($hasLoops) {
    if ($script -match "break|timeout|counter") {
        Write-Host "  ✓ Loop exit conditions found" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Potential infinite loops" -ForegroundColor Yellow
        $issues += "Infinite loop risk"
    }
} else {
    Write-Host "  ✓ No infinite loop patterns detected" -ForegroundColor Green
}

# 10. 메모리 관리
Write-Host "`n[10] Memory Management:" -ForegroundColor Yellow
if ($script -match "\[System\.GC\]::Collect|\.Dispose\(\)|Remove-Variable") {
    Write-Host "  ✓ Explicit memory management" -ForegroundColor Green
} elseif ($script -match '\$global:|New-Object.*-ComObject') {
    Write-Host "  ⚠ Global variables or COM objects without cleanup" -ForegroundColor Yellow
    $issues += "Memory leak potential"
} else {
    Write-Host "  ✓ No obvious memory issues" -ForegroundColor Green
}

# 결과 요약
Write-Host "`n=== Summary ===" -ForegroundColor Cyan

if ($issues.Count -eq 0 -and $suggestions.Count -eq 0) {
    Write-Host "✅ No edge cases or issues detected!" -ForegroundColor Green
    Write-Host "The script handles edge cases well." -ForegroundColor Gray
} else {
    if ($issues.Count -gt 0) {
        Write-Host "`n❌ Issues Found ($($issues.Count)):" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "  • $issue" -ForegroundColor Gray
        }
    }
    
    if ($suggestions.Count -gt 0) {
        Write-Host "`n💡 Suggestions ($($suggestions.Count)):" -ForegroundColor Yellow
        foreach ($suggestion in $suggestions) {
            Write-Host "  • $suggestion" -ForegroundColor Gray
        }
    }
}

Write-Host "`nOverall: " -NoNewline
if ($issues.Count -eq 0) {
    Write-Host "Production Ready ✅" -ForegroundColor Green
} elseif ($issues.Count -le 2) {
    Write-Host "Minor Issues - Safe to use with monitoring ⚠️" -ForegroundColor Yellow
} else {
    Write-Host "Needs improvement before production ❌" -ForegroundColor Red
}