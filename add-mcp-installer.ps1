# Claude Code CLI .claude.json에 mcp-installer 추가 스크립트
# 2025.09.04 PM11:05 생성

$claudeJsonPath = "C:\Users\brian_qs0\.claude.json"

Write-Host "[INFO] .claude.json 파일 읽기 시작..." -ForegroundColor Cyan

try {
    # JSON 파일 읽기
    $json = Get-Content -Path $claudeJsonPath -Raw | ConvertFrom-Json
    
    # mcp-installer가 이미 있는지 확인
    if ($json.mcpServers.PSObject.Properties.Name -contains "mcp-installer") {
        Write-Host "[INFO] mcp-installer가 이미 존재합니다." -ForegroundColor Yellow
    } else {
        # mcp-installer 설정 생성
        $mcpInstallerConfig = @{
            type = "stdio"
            command = "cmd.exe"
            args = @("/c", "npx", "-y", "@anaisbetts/mcp-installer")
        }
        
        # PSCustomObject로 변환
        $mcpInstallerObj = [PSCustomObject]$mcpInstallerConfig
        
        # mcpServers에 추가
        $json.mcpServers | Add-Member -MemberType NoteProperty -Name "mcp-installer" -Value $mcpInstallerObj
        
        # JSON 파일 저장
        $jsonString = $json | ConvertTo-Json -Depth 10
        $jsonString | Set-Content -Path $claudeJsonPath -Encoding UTF8
        
        Write-Host "[SUCCESS] mcp-installer가 추가되었습니다!" -ForegroundColor Green
        Write-Host "[INFO] 백업 파일: .claude.json.backup_20250904_110517" -ForegroundColor Cyan
    }
    
    Write-Host "`n현재 등록된 MCP 서버들:" -ForegroundColor Cyan
    $json.mcpServers.PSObject.Properties.Name | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "[ERROR] 오류 발생: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[INFO] Claude Code를 재시작하면 변경사항이 적용됩니다." -ForegroundColor Yellow