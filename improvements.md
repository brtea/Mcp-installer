# MCP Installer 추가 개선 사항

## 즉시 적용 가능한 개선

### 1. 프로세스 정리 개선
```powershell
# 현재 세션의 claude 프로세스만 종료
$currentSessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
Get-Process -Name "claude" -ErrorAction SilentlyContinue | 
  Where-Object { $_.SessionId -eq $currentSessionId } | 
  Stop-Process -Force -ErrorAction SilentlyContinue
```

### 2. 환경 변수 검증 추가
```powershell
function Test-SafeEnvVars($env) {
  foreach ($key in $env.PSObject.Properties.Name) {
    $value = $env.$key
    # 위험한 환경 변수 값 검사
    if ($value -match '[\$`";|&<>]') {
      Write-Warn "Suspicious characters in env var '$key'"
      return $false
    }
    # PATH 변수 조작 방지
    if ($key -eq "PATH" -or $key -eq "Path") {
      Write-Warn "PATH manipulation detected"
      return $false
    }
  }
  return $true
}
```

### 3. npx 패키지 화이트리스트 확장
```powershell
$SafeNpxPackages = @(
  "@anaisbetts/mcp-installer",
  "@modelcontextprotocol/server-filesystem",
  "@modelcontextprotocol/server-github",
  "@modelcontextprotocol/server-memory",
  "@modelcontextprotocol/server-postgres",
  "@modelcontextprotocol/server-sqlite",
  "youtube-data-mcp-server",
  "mcp-server-fetch",
  "@kimtaeyoon83/mcp-server-notion"
)
```

### 4. Windows 특화 위험 패턴 추가
```powershell
$DangerousPatterns = @(
  # 기존 패턴들...
  "Remove-Item -Recurse"
  "rd /s"
  "Invoke-Expression"
  "IEX"
  "[System.Reflection.Assembly]::Load"
  "Add-Type"
  "-WindowStyle Hidden"
  "DownloadString"
  "WebClient"
)
```

## 중장기 개선 사항

### 1. 백업 관리 정책
- 백업 파일 개수 제한 (최대 10개)
- 30일 이상된 백업 자동 삭제
- 백업 압축 옵션

### 2. 설정 검증 강화
- JSON Schema 기반 검증
- 서버 의존성 체크
- 포트 충돌 검사

### 3. 로깅 시스템
- 상세 로그 파일 생성
- 로그 레벨 설정 (DEBUG/INFO/WARN/ERROR)
- 로그 로테이션

### 4. 테스트 자동화
- Pester 기반 단위 테스트
- CI/CD 파이프라인 통합
- 회귀 테스트 스위트

## 보안 권장사항

### 1. 코드 서명
```powershell
# 스크립트 실행 전 서명 확인
$signature = Get-AuthenticodeSignature -FilePath .\mcp-installer.ps1
if ($signature.Status -ne "Valid") {
  Write-Warning "Script is not digitally signed!"
}
```

### 2. 실행 정책 확인
```powershell
# 최소 RemoteSigned 정책 권장
if ((Get-ExecutionPolicy) -eq "Unrestricted") {
  Write-Warning "Execution policy is too permissive"
}
```

### 3. 감사 로그
```powershell
# 모든 설치/변경 작업을 Windows Event Log에 기록
Write-EventLog -LogName Application -Source "MCP-Installer" `
  -EventId 1000 -EntryType Information `
  -Message "MCP server '$name' installed by $env:USERNAME"
```

## 사용성 개선

### 1. 대화형 모드
```powershell
param(
  [switch]$Interactive  # 대화형 설치 모드
)

if ($Interactive) {
  # 메뉴 기반 선택
  Show-Menu
  $selection = Read-Host "Select option"
  # ...
}
```

### 2. 설정 템플릿
```powershell
# 자주 사용하는 MCP 서버 조합 템플릿 제공
.\mcp-installer.ps1 -Template "development"
# filesystem, github, memory 서버 자동 설치
```

### 3. 상태 대시보드
```powershell
.\mcp-installer.ps1 -Status
# 현재 설치된 서버, 버전, 상태 표시
```

## 성능 최적화

### 1. 병렬 처리
```powershell
# 여러 서버 동시 검증
$servers | ForEach-Object -Parallel {
  Test-McpServerConfig $_.Name $_.Config
} -ThrottleLimit 5
```

### 2. 캐싱
```powershell
# Node/Claude 버전 캐싱 (5분)
$script:NodeVersion = Get-CachedValue "NodeVersion" {
  & node -v
} -ExpirationMinutes 5
```

### 3. 지연 로딩
```powershell
# 필요할 때만 백업 디렉토리 생성
function Get-BackupDir {
  if (-not $script:BackupDir) {
    $script:BackupDir = Initialize-BackupDirectory
  }
  return $script:BackupDir
}
```