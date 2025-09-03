<# =====================================================================
파일명: mcp-installer.ps1
기능 요약: MCP (Model Context Protocol) 서버 자동 설치 및 설정 스크립트
          Windows PowerShell 5+ / PowerShell 7+ 환경에서 동작

File History:
  2025.01.03 PM04:30 초기 버전 생성 - MCP 설치/등록 자동화 구현
  2025.01.03 PM04:45 파일명 수정 및 코드 점검

사용예:
  pwsh -File .\mcp-installer.ps1 -Config .\mcp.windows.json -Scope user -Verify
  pwsh -File .\mcp-installer.ps1 -AddInstaller
===================================================================== #>

[CmdletBinding()]
param(
  [string]$Config,                 # JSON 파일 경로 (mcpServers 객체 구조)
  [ValidateSet("user","project")]
  [string]$Scope = "user",         # 등록 범위
  [switch]$AddInstaller,           # mcp-installer 엔트리만 추가
  [switch]$Verify,                 # 설치 후 동작 점검 수행
  [switch]$DryRun                  # 파일 쓰기/명령 실행 없이 사전 미리보기
)

function Write-Info($msg){ Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host "[ERR ] $msg" -ForegroundColor Red }

# 0) 경로 계산
$HOME_DIR = [Environment]::GetFolderPath('UserProfile')
$ProjectRoot = (Get-Location).Path
if ($Scope -eq "user") {
  $ClaudeDir = Join-Path $HOME_DIR ".claude"
} else {
  $ClaudeDir = Join-Path $ProjectRoot ".claude"
}
$ClaudeCfg = Join-Path $ClaudeDir "config.json"

# 1) 사전 점검
function Test-Node {
  try {
    $v = (& node -v) 2>$null
    if (-not $v) { throw "Node not found" }
    $clean = $v.TrimStart("v")
    $maj = [int]($clean.Split(".")[0])
    if ($maj -lt 18) { throw "Node >= 18 required, found $v" }
    Write-Info "Node OK: $v"
    return $true
  } catch {
    Write-Err "Node 확인 실패: $_"
    return $false
  }
}

function Test-Claude {
  try {
    $out = (& claude -v) 2>$null
    if (-not $out) { throw "Claude CLI not found" }
    Write-Info "Claude CLI OK: $out"
    return $true
  } catch {
    Write-Err "Claude CLI 확인 실패: $_"
    return $false
  }
}

# 2) JSON 유틸
function Read-Json($path){
  if (-not (Test-Path $path)) { return $null }
  Get-Content -Raw -Path $path | ConvertFrom-Json
}
function Write-Json($obj, $path){
  if ($DryRun){
    Write-Info "(DryRun) 아래 JSON이 저장될 예정:"
    ($obj | ConvertTo-Json -Depth 10) | Write-Host
    return
  }
  if (-not (Test-Path (Split-Path $path))) {
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
  }
  $obj | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -Path $path
  Write-Info "저장 완료: $path"
}

function Ensure-ConfigSkeleton {
  $cfg = Read-Json $ClaudeCfg
  if (-not $cfg){
    $cfg = @{ mcpServers = @{} }
  } elseif (-not $cfg.mcpServers){
    $cfg.mcpServers = @{}
  }
  return $cfg
}

# 3) mcp-installer 추가 (CLAUDE.md의 Windows 설정 가이드라인 준수)
function Add-McpInstaller($cfg){
  if ($cfg.mcpServers.'mcp-installer') {
    Write-Info "mcp-installer 이미 존재"
    return $cfg
  }
  # CLAUDE.md 권장: Windows에서 npx -y 옵션 사용
  $cfg.mcpServers.'mcp-installer' = @{
    type    = "stdio"
    command = "cmd.exe"
    args    = @("/c","npx","-y","@anaisbetts/mcp-installer")
  }
  Write-Info "mcp-installer 엔트리 추가 (user 스코프)"
  return $cfg
}

# 4) 외부 JSON(사용자 제공) 병합
function Merge-Servers($cfg, $importPath){
  if (-not (Test-Path $importPath)) { throw "Config 파일 없음: $importPath" }
  $imp = Read-Json $importPath
  # 허용 형태: { "mcpServers": { ... } } 또는 { "<name>": { ... } }
  $servers = @{}
  if ($imp.mcpServers){ $servers = $imp.mcpServers }
  else { $servers = $imp }  # 루트에 서버 키들이 바로 있는 형태 지원

  foreach($k in $servers.PSObject.Properties.Name){
    $cfg.mcpServers[$k] = $servers[$k]
    Write-Info "등록/갱신: $k"
  }
  return $cfg
}

# 5) Verify 절차 - CLAUDE.md 기준에 맞게 수정
function Verify-Run {
  try {
    Write-Info "설치 목록 확인: claude mcp list"
    & claude mcp list
  } catch { Write-Warn "claude mcp list 실행 실패: $_" }

  try {
    Write-Info "디버그 모드로 실행하여 MCP 작동 확인 중..."
    if (-not $DryRun) {
      # Task를 통한 디버그 모드 실행 (CLAUDE.md 가이드라인 준수)
      Write-Info "디버그 모드 시작 (최대 2분 관찰)"
      $debugProcess = Start-Process -FilePath "powershell" -ArgumentList @(
        "-NoLogo", "-NoProfile", "-Command",
        "claude --debug"
      ) -PassThru -NoNewWindow
      
      # 10초 대기 후 /mcp 명령 전송
      Start-Sleep -Seconds 10
      Write-Info "/mcp 명령으로 실제 작동 확인 중..."
      echo "/mcp" | claude --debug
      
      # 프로세스 정리
      if (-not $debugProcess.HasExited) {
        Stop-Process -Id $debugProcess.Id -Force -ErrorAction SilentlyContinue
      }
    } else {
      Write-Info "(DryRun) 디버그 테스트 생략"
    }
  } catch {
    Write-Warn "디버그 테스트 실패: $_"
  }
}

# === 실행 시퀀스 ===
$nodeOk = Test-Node
$claudeOk = Test-Claude
if (-not ($nodeOk -and $claudeOk)) {
  Write-Err "필수 의존성 확인 실패. 중단."
  exit 1
}

$cfg = Ensure-ConfigSkeleton

if ($AddInstaller){
  $cfg = Add-McpInstaller $cfg
  Write-Json $cfg $ClaudeCfg
  if ($Verify){ Verify-Run }
  exit 0
}

if ($Config){
  $cfg = Merge-Servers $cfg $Config
} else {
  Write-Warn "외부 -Config 미지정: mcpServers 변경 없음"
}

Write-Json $cfg $ClaudeCfg

if ($Verify){ Verify-Run }
Write-Info "완료"
