<# =====================================================================
파일명: mcp-installer.ps1
기능 요약: MCP (Model Context Protocol) 서버 자동 설치 및 설정 스크립트
          Windows PowerShell 5+ / PowerShell 7+ 환경에서 동작

File History:
  2025.01.03 PM04:30 초기 버전 생성 - MCP 설치/등록 자동화 구현
  2025.01.03 PM04:45 파일명 수정 및 코드 점검
  2025.01.03 PM05:38 보안 검증 로직 추가 - JSON 스키마/명령어 검증

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
  [switch]$DryRun,                 # 파일 쓰기/명령 실행 없이 사전 미리보기
  [switch]$TrustSource              # 외부 JSON을 신뢰하고 확인 건너뛰기 (주의 필요)
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
    Write-Err "Node check failed: $_"
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
    Write-Err "Claude CLI check failed: $_"
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
    Write-Info "(DryRun) JSON to be saved:"
    ($obj | ConvertTo-Json -Depth 10) | Write-Host
    return
  }
  if (-not (Test-Path (Split-Path $path))) {
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
  }
  $obj | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -Path $path
  Write-Info "Saved: $path"
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

# 2-1) 보안 검증 함수들
# 허용된 명령어 화이트리스트
$SafeCommands = @{
  "npx" = $true
  "node" = $true
  "python" = $true
  "python3" = $true
  "python.exe" = $true
  "cmd.exe" = $true
  "cmd" = $true
  "powershell.exe" = $true
  "powershell" = $true
  "pwsh.exe" = $true
  "pwsh" = $true
  "uvx" = $true
}

# 위험한 인자 패턴 블랙리스트
$DangerousPatterns = @(
  "rm -rf"
  "del /f /s /q"
  "format "
  "> nul"
  "| cmd"
  "| powershell"
  "&& cmd"
  "&& powershell"
  ";"
  "``"
  "`$("
  "eval("
  "-encodedcommand"
  "-exec"
  "--eval"
  "<("
  ">(" 
)

function Test-SafeCommand($cmd) {
  # 명령어 정규화 (경로 제거, 소문자 변환)
  $normalizedCmd = Split-Path -Leaf $cmd
  $normalizedCmd = $normalizedCmd.ToLower()
  
  # 화이트리스트 확인
  if (-not $SafeCommands[$normalizedCmd]) {
    Write-Warn "Disallowed command: $cmd"
    return $false
  }
  return $true
}

function Test-SafeArgs($argList) {
  if (-not $argList) { return $true }
  
  $argsString = $argList -join " "
  foreach ($pattern in $DangerousPatterns) {
    if ($argsString -like "*$pattern*") {
      Write-Warn "Dangerous argument pattern detected: $pattern"
      return $false
    }
  }
  
  # 절대 경로 실행 파일 차단 (npx의 패키지 제외)
  foreach ($arg in $argList) {
    # Windows 절대 경로
    if ($arg -match "^[A-Za-z]:\\" -and $arg -match "\.(exe|bat|cmd|ps1|vbs|js)$") {
      Write-Warn "Blocked absolute path execution: $arg"
      return $false
    }
    # Unix 절대 경로
    if ($arg -match "^/" -and $arg -notmatch "^/[cC]/") {
      # npm 패키지 형식 허용
      if ($arg -notmatch "^\@[a-zA-Z0-9\-]+/[a-zA-Z0-9\-]+$") {
        Write-Warn "Blocked absolute path execution: $arg"
        return $false
      }
    }
    # 상대 경로로 상위 디렉토리 접근 차단
    if ($arg -match "\.\./") {
      Write-Warn "Blocked path traversal: $arg"
      return $false
    }
    # 실행 파일 확장자 직접 실행 차단
    if ($arg -match "\.(exe|bat|cmd|ps1|vbs|js|sh)$" -and -not ($arg -match "^\@")) {
      Write-Warn "Blocked direct executable: $arg"
      return $false
    }
  }
  return $true
}

function Test-McpServerConfig($name, $config) {
  # 필수 필드 확인
  if (-not $config.type) {
    Write-Err "[$name] Missing 'type' field"
    return $false
  }
  if ($config.type -ne "stdio") {
    Write-Warn "[$name] Unsupported type: $($config.type)"
    return $false
  }
  
  if (-not $config.command) {
    Write-Err "[$name] Missing 'command' field"
    return $false
  }
  
  # 명령어 안전성 검증
  if (-not (Test-SafeCommand $config.command)) {
    return $false
  }
  
  # 인자 안전성 검증
  if ($config.args -and -not (Test-SafeArgs $config.args)) {
    return $false
  }
  
  Write-Info "[$name] Security validation passed"
  return $true
}

function Confirm-UntrustedSource($configPath) {
  Write-Warn "Untrusted config file: $configPath"
  Write-Host "About to install the following servers:" -ForegroundColor Yellow
  
  $cfg = Read-Json $configPath
  $servers = if ($cfg.mcpServers) { $cfg.mcpServers } else { $cfg }
  
  foreach ($name in $servers.PSObject.Properties.Name) {
    $server = $servers.$name
    Write-Host "  - $name : $($server.command) $($server.args -join ' ')" -ForegroundColor Gray
  }
  
  $response = Read-Host "Continue? (y/N)"
  return ($response -eq "y" -or $response -eq "Y")
}

# 3) mcp-installer 추가 (CLAUDE.md의 Windows 설정 가이드라인 준수)
function Add-McpInstaller($cfg){
  if ($cfg.mcpServers.'mcp-installer') {
    Write-Info "mcp-installer already exists"
    return $cfg
  }
  # CLAUDE.md 권장: Windows에서 npx -y 옵션 사용
  $cfg.mcpServers.'mcp-installer' = @{
    type    = "stdio"
    command = "cmd.exe"
    args    = @("/c","npx","-y","@anaisbetts/mcp-installer")
  }
  Write-Info "Added mcp-installer entry (user scope)"
  return $cfg
}

# 4) 외부 JSON(사용자 제공) 병합 - 보안 검증 추가
function Merge-Servers($cfg, $importPath){
  if (-not (Test-Path $importPath)) { throw "Config file not found: $importPath" }
  
  # 신뢰되지 않은 소스 경고 및 확인 (TrustSource 플래그가 없을 때만)
  if (-not $TrustSource) {
    if (-not (Confirm-UntrustedSource $importPath)) {
      Write-Warn "User cancelled installation."
      return $cfg
    }
  } else {
    Write-Warn "Using -TrustSource flag: skipping security check"
  }
  
  $imp = Read-Json $importPath
  # 허용 형태: { "mcpServers": { ... } } 또는 { "<name>": { ... } }
  $servers = @{}
  if ($imp.mcpServers){ $servers = $imp.mcpServers }
  else { $servers = $imp }  # 루트에 서버 키들이 바로 있는 형태 지원

  $failedCount = 0
  $successCount = 0
  
  foreach($k in $servers.PSObject.Properties.Name){
    $serverConfig = $servers.$k
    
    # 보안 검증
    if (Test-McpServerConfig $k $serverConfig) {
      $cfg.mcpServers | Add-Member -MemberType NoteProperty -Name $k -Value $serverConfig -Force
      Write-Info "Registered/Updated: $k"
      $successCount++
    } else {
      Write-Err "[$k] Security validation failed - skipped"
      $failedCount++
    }
  }
  
  Write-Info "Result: Success $successCount, Failed $failedCount"
  
  if ($failedCount -gt 0) {
    Write-Warn "Some servers were blocked by security policy."
  }
  
  return $cfg
}

# 5) Verify 절차 - CLAUDE.md 기준에 맞게 수정
function Verify-Run {
  try {
    Write-Info "Checking installed list: claude mcp list"
    & claude mcp list
  } catch { Write-Warn "claude mcp list execution failed: $_" }

  try {
    Write-Info "Running in debug mode to verify MCP operation..."
    if (-not $DryRun) {
      # Task를 통한 디버그 모드 실행 (CLAUDE.md 가이드라인 준수)
      Write-Info "Starting debug mode (observe for up to 2 minutes)"
      $debugProcess = Start-Process -FilePath "powershell" -ArgumentList @(
        "-NoLogo", "-NoProfile", "-Command",
        "claude --debug"
      ) -PassThru -NoNewWindow
      
      # 10초 대기 후 /mcp 명령 전송
      Start-Sleep -Seconds 10
      Write-Info "Verifying actual operation with /mcp command..."
      echo "/mcp" | claude --debug
      
      # 프로세스 정리
      if (-not $debugProcess.HasExited) {
        Stop-Process -Id $debugProcess.Id -Force -ErrorAction SilentlyContinue
      }
    } else {
      Write-Info "(DryRun) Skipping debug test"
    }
  } catch {
    Write-Warn "Debug test failed: $_"
  }
}

# === 실행 시퀀스 ===
$nodeOk = Test-Node
$claudeOk = Test-Claude
if (-not ($nodeOk -and $claudeOk)) {
  Write-Err "Required dependency check failed. Aborting."
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
  Write-Warn "No external -Config specified: mcpServers unchanged"
}

Write-Json $cfg $ClaudeCfg

if ($Verify){ Verify-Run }
Write-Info "Complete"
