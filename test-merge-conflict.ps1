<# =====================================================================
파일명: test-merge-conflict.ps1
기능 요약: mcp-installer.ps1의 병합 충돌 처리 및 롤백 기능 테스트

File History:
  2025.01.03 PM09:12 테스트 스크립트 생성 - 충돌 처리 및 롤백 검증
===================================================================== #>

Write-Host "`n===== MCP Installer 병합 충돌 및 롤백 테스트 =====" -ForegroundColor Cyan

# 테스트 준비
$TestDir = Join-Path $PSScriptRoot "test-merge"
$TestConfig = Join-Path $TestDir "claude\config.json"
$TestBackupDir = Join-Path $TestDir "claude\backups"

# 테스트 디렉토리 초기화
if (Test-Path $TestDir) {
    Remove-Item -Path $TestDir -Recurse -Force
}
New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
New-Item -ItemType Directory -Path "$TestDir\claude" -Force | Out-Null

Write-Host "`n[1] 초기 설정 생성" -ForegroundColor Yellow

# 초기 config.json 생성
$initialConfig = @{
    mcpServers = @{
        "existing-server" = @{
            type = "stdio"
            command = "node"
            args = @("server1.js")
        }
        "another-server" = @{
            type = "stdio"
            command = "python"
            args = @("server2.py")
        }
    }
}
$initialConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $TestConfig -Encoding UTF8
Write-Host "  ✓ 초기 config.json 생성 완료" -ForegroundColor Green

Write-Host "`n[2] 충돌 있는 병합 테스트" -ForegroundColor Yellow

# 충돌 발생시킬 JSON 생성
$conflictJson = @{
    mcpServers = @{
        "existing-server" = @{
            type = "stdio"
            command = "python"  # 변경: node -> python
            args = @("new-server1.py")  # 변경: server1.js -> new-server1.py
        }
        "new-server" = @{
            type = "stdio"
            command = "npx"
            args = @("-y", "@modelcontextprotocol/server-filesystem")
        }
    }
}

$conflictJsonPath = Join-Path $TestDir "conflict.json"
$conflictJson | ConvertTo-Json -Depth 10 | Set-Content -Path $conflictJsonPath -Encoding UTF8
Write-Host "  ✓ 충돌 테스트용 JSON 생성" -ForegroundColor Green

# 병합 테스트 실행 (DryRun 모드)
Write-Host "`n[3] DryRun 모드로 충돌 감지 테스트" -ForegroundColor Yellow
Write-Host "  실행: -Config conflict.json -Scope project -DryRun" -ForegroundColor Gray

# 실제 테스트 명령 실행을 위한 스크립트 블록
$scriptPath = Join-Path $PSScriptRoot "mcp-installer.ps1"
$testScript = {
    param($ScriptPath, $ConfigPath, $TestDir)
    
    Push-Location $TestDir
    try {
        & $ScriptPath -Config $ConfigPath -Scope project -DryRun
    } finally {
        Pop-Location
    }
}

# DryRun 테스트
Write-Host "`n  DryRun 실행 중..." -ForegroundColor Cyan
& $testScript $scriptPath $conflictJsonPath $TestDir

Write-Host "`n[4] 실제 병합 테스트 (사용자 입력 시뮬레이션)" -ForegroundColor Yellow

# 실제 병합을 위한 테스트 입력 파일 생성
$inputFile = Join-Path $TestDir "test-input.txt"
@"
y
i
y
n
"@ | Set-Content -Path $inputFile -Encoding UTF8

Write-Host "  시뮬레이션된 사용자 입력:" -ForegroundColor Gray
Write-Host "    - 신뢰되지 않은 소스 계속: y" -ForegroundColor DarkGray
Write-Host "    - 충돌 처리 방식: i (개별 선택)" -ForegroundColor DarkGray
Write-Host "    - existing-server 덮어쓰기: y" -ForegroundColor DarkGray
Write-Host "    - another-server 덮어쓰기: n" -ForegroundColor DarkGray

# 실제 병합 실행
$mergeScript = {
    param($ScriptPath, $ConfigPath, $TestDir, $InputFile)
    
    Push-Location $TestDir
    try {
        Get-Content $InputFile | & $ScriptPath -Config $ConfigPath -Scope project
    } finally {
        Pop-Location
    }
}

Write-Host "`n  실제 병합 실행 중..." -ForegroundColor Cyan
& $mergeScript $scriptPath $conflictJsonPath $TestDir $inputFile

Write-Host "`n[5] 병합 결과 검증" -ForegroundColor Yellow

if (Test-Path $TestConfig) {
    $mergedConfig = Get-Content -Raw $TestConfig | ConvertFrom-Json
    
    Write-Host "  병합된 서버 목록:" -ForegroundColor Gray
    foreach ($serverName in $mergedConfig.mcpServers.PSObject.Properties.Name) {
        $server = $mergedConfig.mcpServers.$serverName
        Write-Host "    - $serverName : $($server.command) $($server.args -join ' ')" -ForegroundColor DarkGray
    }
    
    # 검증
    $tests = @(
        @{
            Name = "existing-server가 업데이트됨"
            Pass = $mergedConfig.mcpServers.'existing-server'.command -eq "python"
        },
        @{
            Name = "another-server가 보존됨"
            Pass = $mergedConfig.mcpServers.'another-server'.command -eq "python"
        },
        @{
            Name = "new-server가 추가됨"
            Pass = $null -ne $mergedConfig.mcpServers.'new-server'
        }
    )
    
    Write-Host "`n  검증 결과:" -ForegroundColor Gray
    foreach ($test in $tests) {
        if ($test.Pass) {
            Write-Host "    ✓ $($test.Name)" -ForegroundColor Green
        } else {
            Write-Host "    ✗ $($test.Name)" -ForegroundColor Red
        }
    }
}

Write-Host "`n[6] 백업 파일 확인" -ForegroundColor Yellow

if (Test-Path $TestBackupDir) {
    $backups = Get-ChildItem -Path $TestBackupDir -Filter "*.json"
    Write-Host "  생성된 백업 파일:" -ForegroundColor Gray
    foreach ($backup in $backups) {
        Write-Host "    - $($backup.Name) ($(Get-Date $backup.LastWriteTime -Format 'HH:mm:ss'))" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  백업 디렉토리가 없습니다." -ForegroundColor Red
}

Write-Host "`n[7] 롤백 테스트" -ForegroundColor Yellow

# 롤백 전 상태 저장
$beforeRollback = Get-Content -Raw $TestConfig | ConvertFrom-Json

# 롤백 실행
$rollbackScript = {
    param($ScriptPath, $TestDir)
    
    Push-Location $TestDir
    try {
        & $ScriptPath -Rollback -Scope project
    } finally {
        Pop-Location
    }
}

Write-Host "  롤백 실행 중..." -ForegroundColor Cyan
& $rollbackScript $scriptPath $TestDir

# 롤백 결과 확인
if (Test-Path $TestConfig) {
    $afterRollback = Get-Content -Raw $TestConfig | ConvertFrom-Json
    
    Write-Host "`n  롤백 후 서버 목록:" -ForegroundColor Gray
    foreach ($serverName in $afterRollback.mcpServers.PSObject.Properties.Name) {
        $server = $afterRollback.mcpServers.$serverName
        Write-Host "    - $serverName : $($server.command) $($server.args -join ' ')" -ForegroundColor DarkGray
    }
    
    # 롤백 검증
    if ($afterRollback.mcpServers.'existing-server'.command -eq "node") {
        Write-Host "    ✓ 롤백 성공: existing-server가 원래 상태로 복원됨" -ForegroundColor Green
    } else {
        Write-Host "    ✗ 롤백 실패: existing-server가 복원되지 않음" -ForegroundColor Red
    }
}

Write-Host "`n[8] 특정 백업으로 롤백 테스트" -ForegroundColor Yellow

# 새로운 변경 생성
$anotherChange = @{
    mcpServers = @{
        "test-server" = @{
            type = "stdio"
            command = "node"
            args = @("test.js")
        }
    }
}
$anotherJsonPath = Join-Path $TestDir "another.json"
$anotherChange | ConvertTo-Json -Depth 10 | Set-Content -Path $anotherJsonPath -Encoding UTF8

# 추가 병합
$mergeAgainScript = {
    param($ScriptPath, $ConfigPath, $TestDir)
    
    Push-Location $TestDir
    try {
        "y" | & $ScriptPath -Config $ConfigPath -Scope project -TrustSource
    } finally {
        Pop-Location
    }
}

Write-Host "  추가 변경 적용 중..." -ForegroundColor Cyan
& $mergeAgainScript $scriptPath $anotherJsonPath $TestDir

# 특정 백업 파일 찾기
if (Test-Path $TestBackupDir) {
    $firstBackup = Get-ChildItem -Path $TestBackupDir -Filter "config_*_before_merge.json" | 
                   Sort-Object LastWriteTime | 
                   Select-Object -First 1
    
    if ($firstBackup) {
        Write-Host "  첫 번째 백업으로 롤백: $($firstBackup.Name)" -ForegroundColor Gray
        
        $specificRollbackScript = {
            param($ScriptPath, $TestDir, $BackupName)
            
            Push-Location $TestDir
            try {
                & $ScriptPath -RollbackTo $BackupName -Scope project
            } finally {
                Pop-Location
            }
        }
        
        & $specificRollbackScript $scriptPath $TestDir $firstBackup.Name
        
        # 결과 확인
        $finalConfig = Get-Content -Raw $TestConfig | ConvertFrom-Json
        if (-not $finalConfig.mcpServers.'test-server') {
            Write-Host "    ✓ 특정 백업 롤백 성공: test-server가 제거됨" -ForegroundColor Green
        } else {
            Write-Host "    ✗ 특정 백업 롤백 실패" -ForegroundColor Red
        }
    }
}

Write-Host "`n===== 테스트 완료 =====" -ForegroundColor Cyan
Write-Host "테스트 디렉토리: $TestDir" -ForegroundColor Gray
Write-Host "정리하려면: Remove-Item '$TestDir' -Recurse -Force" -ForegroundColor DarkGray