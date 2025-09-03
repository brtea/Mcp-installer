<# =====================================================================
파일명: mcp-installer.ps1
기능 요약: MCP (Model Context Protocol) 서버 자동 설치 및 설정 스크립트
          Windows PowerShell 5+ / PowerShell 7+ 환경에서 동작

File History:
  2025.01.03 PM04:30 초기 버전 생성 - MCP 설치/등록 자동화 구현
  2025.01.03 PM04:45 파일명 수정 및 코드 점검
  2025.01.03 PM05:38 보안 검증 로직 추가 - JSON 스키마/명령어 검증
  2025.01.03 PM06:25 프로세스 누수 방지 - try-finally 및 타임아웃 관리
  2025.09.03 AM10:15 Test-Node 함수 보안 취약점 수정 - 강건한 버전 파싱 및 매개변수화
  2025.01.03 PM10:00 프로젝트 루트 계산 개선 및 크로스 플랫폼 지원 추가

사용예:
  pwsh -File .\mcp-installer.ps1 -Config .\mcp.windows.json -Scope user -Verify
  pwsh -File .\mcp-installer.ps1 -AddInstaller
  pwsh -File .\mcp-installer.ps1 -Rollback
  pwsh -File .\mcp-installer.ps1 -RollbackTo "config_20250103_143025_before_merge.json"
===================================================================== #>

[CmdletBinding()]
param(
  [string]$Config,                 # JSON 파일 경로 (mcpServers 객체 구조)
  [ValidateSet("user","project")]
  [string]$Scope = "user",         # 등록 범위
  [switch]$AddInstaller,           # mcp-installer 엔트리만 추가
  [switch]$Verify,                 # 설치 후 동작 점검 수행
  [switch]$DryRun,                 # 파일 쓰기/명령 실행 없이 사전 미리보기
  [switch]$TrustSource,            # 외부 JSON을 신뢰하고 확인 건너뛰기 (주의 필요)
  [switch]$Rollback,               # 마지막 백업으로 롤백
  [string]$RollbackTo,             # 특정 백업 파일로 롤백 (파일명 또는 전체 경로)
  [string]$ProjectRoot             # 프로젝트 루트 디렉토리 (기본: 스크립트 위치)
)

function Write-Info($msg){ Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host "[ERR ] $msg" -ForegroundColor Red }

# 0) 경로 계산
$HOME_DIR = [Environment]::GetFolderPath('UserProfile')

# 프로젝트 루트 결정 - 스크립트 위치를 기본값으로 사용
if (-not $ProjectRoot) {
  # 스크립트가 위치한 디렉토리를 프로젝트 루트로 사용 (더 안정적)
  if ($PSScriptRoot) {
    $ProjectRoot = $PSScriptRoot
  } else {
    # 폴백: 현재 작업 디렉토리 사용
    $ProjectRoot = (Get-Location).Path
  }
  Write-Info "프로젝트 루트 자동 감지: $ProjectRoot"
}

if ($Scope -eq "user") {
  $ClaudeDir = Join-Path $HOME_DIR ".claude"
} else {
  $ClaudeDir = Join-Path $ProjectRoot ".claude"
}
$ClaudeCfg = Join-Path $ClaudeDir "config.json"

# 1) 사전 점검
function Test-Node {
  param(
    [string]$MinimumVersion = "16.0.0"  # 기본값: Node 16 LTS (더 유연한 호환성)
  )
  
  try {
    $nodeOutput = (& node -v) 2>$null
    if (-not $nodeOutput) { 
      throw "Node.js가 설치되지 않았거나 PATH에서 찾을 수 없습니다"
    }
    
    # 버전 파싱: v18.0.0, v18.0.0-pre, 18.0.0 등 다양한 형식 지원
    $versionMatch = [regex]::Match($nodeOutput, '^v?(\d+)\.(\d+)\.(\d+)(?:[-.](.+))?$')
    if (-not $versionMatch.Success) {
      throw "Node.js 버전 형식을 파싱할 수 없습니다: $nodeOutput"
    }
    
    $major = [int]$versionMatch.Groups[1].Value
    $minor = [int]$versionMatch.Groups[2].Value  
    $patch = [int]$versionMatch.Groups[3].Value
    $prerelease = $versionMatch.Groups[4].Value
    
    $currentVersion = [System.Version]::new($major, $minor, $patch)
    
    # 최소 버전 요구사항 파싱
    $minVersionMatch = [regex]::Match($MinimumVersion, '^v?(\d+)\.(\d+)\.(\d+)$')
    if (-not $minVersionMatch.Success) {
      throw "최소 버전 형식이 잘못되었습니다: $MinimumVersion"
    }
    
    $minMajor = [int]$minVersionMatch.Groups[1].Value
    $minMinor = [int]$minVersionMatch.Groups[2].Value
    $minPatch = [int]$minVersionMatch.Groups[3].Value
    $minimumVersionObj = [System.Version]::new($minMajor, $minMinor, $minPatch)
    
    # 버전 비교
    if ($currentVersion -lt $minimumVersionObj) {
      throw "Node.js >= $MinimumVersion 이 필요하지만 $nodeOutput 가 설치되어 있습니다"
    }
    
    # 프리릴리즈 버전에 대한 경고
    if ($prerelease) {
      Write-Warn "프리릴리즈 버전이 감지되었습니다: $nodeOutput (안정성 문제가 있을 수 있음)"
    }
    
    Write-Info "Node.js 버전 확인 완료: $nodeOutput (최소요구: $MinimumVersion)"
    return $true
    
  } catch {
    Write-Err "Node.js 버전 확인 실패: $_"
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
  if (-not (Test-Path $path)) { 
    Write-Warn "File not found: $path"
    return $null 
  }
  
  try {
    $content = Get-Content -Raw -Path $path -ErrorAction Stop
    
    if ([string]::IsNullOrWhiteSpace($content)) {
      Write-Warn "Empty file: $path"
      return $null
    }
    
    try {
      $json = $content | ConvertFrom-Json -ErrorAction Stop
      
      if (-not $json) {
        # 이 경우는 거의 발생하지 않지만, 만약을 대비
        throw "Parsed JSON is null or empty."
      }
      
      return $json
    } catch {
      # JSON 파싱 실패 - 모든 ConvertFrom-Json 오류를 JSON 오류로 처리
      Write-Err "JSON parsing error in '$path': Invalid syntax"
      Write-Err "  Details: $($_.Exception.Message)"
      throw "Failed to parse JSON content."
    }
  } catch {
    Write-Err "Failed to read file '$path': $($_.Exception.Message)"
    throw
    return $null
  }
}
function Write-Json($obj, $path){
  if ($DryRun){
    Write-Info "(DryRun) JSON to be saved:"
    ($obj | ConvertTo-Json -Depth 10) | Write-Host
    return
  }
  
  # 디렉토리 확인 및 생성
  $directory = Split-Path $path
  if ($directory -and -not (Test-Path $directory)) {
    try {
      New-Item -ItemType Directory -Force -Path $directory -ErrorAction Stop | Out-Null
    } catch {
      Write-Err "Failed to create directory: $directory"
      Write-Err "Error: $($_.Exception.Message)"
      throw
    }
  }
  
  # 백업 파일 생성 (기존 파일이 있을 경우)
  $backupPath = $null
  if (Test-Path $path) {
    $backupPath = "$path.bak"
    try {
      Copy-Item -Path $path -Destination $backupPath -Force -ErrorAction Stop
      Write-Info "Backup created: $backupPath"
    } catch {
      Write-Err "Failed to create backup: $backupPath"
      Write-Err "Error: $($_.Exception.Message)"
      # 백업 실패해도 계속 진행 (경고만 표시)
      Write-Warn "Continuing without backup..."
      $backupPath = $null
    }
  }
  
  # 임시 파일 경로 생성
  $tempPath = "$path.tmp"
  $tempPath2 = "$path.tmp2"  # 대체 임시 파일 (첫 번째가 실패할 경우)
  
  $savedSuccessfully = $false
  $errorMessage = $null
  
  try {
    # JSON 변환
    $jsonContent = $obj | ConvertTo-Json -Depth 10 -ErrorAction Stop
    
    # 임시 파일에 저장 (원자적 쓰기)
    try {
      # 첫 번째 시도: 같은 디렉토리의 임시 파일
      $jsonContent | Set-Content -Encoding UTF8 -Path $tempPath -Force -ErrorAction Stop
      
      # 임시 파일 검증
      $verification = Get-Content -Raw -Path $tempPath -ErrorAction Stop
      if ([string]::IsNullOrWhiteSpace($verification)) {
        throw "Temporary file is empty after write"
      }
      
      # JSON 유효성 재검증
      $null = $verification | ConvertFrom-Json -ErrorAction Stop
      
      # 원자적 교체 (Move-Item은 같은 볼륨 내에서 원자적)
      Move-Item -Path $tempPath -Destination $path -Force -ErrorAction Stop
      $savedSuccessfully = $true
      
    } catch {
      # 첫 번째 임시 파일 실패 시 정리
      if (Test-Path $tempPath) {
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
      }
      
      # 두 번째 시도: 대체 방법
      try {
        Write-Warn "First atomic write failed, trying alternative method..."
        
        # 대체 임시 파일에 저장
        $jsonContent | Set-Content -Encoding UTF8 -Path $tempPath2 -Force -ErrorAction Stop
        
        # 검증
        $verification = Get-Content -Raw -Path $tempPath2 -ErrorAction Stop
        $null = $verification | ConvertFrom-Json -ErrorAction Stop
        
        # Windows에서 Move-Item이 실패할 경우를 대비한 처리
        if (Test-Path $path) {
          # 기존 파일이 있으면 삭제 후 이동
          Remove-Item -Path $path -Force -ErrorAction Stop
        }
        Move-Item -Path $tempPath2 -Destination $path -Force -ErrorAction Stop
        $savedSuccessfully = $true
        
      } catch {
        # 두 번째 시도도 실패
        $errorMessage = $_.Exception.Message
        
        # 최후의 시도: 직접 쓰기 (원자성 포기)
        try {
          Write-Warn "Atomic write failed, falling back to direct write..."
          $jsonContent | Set-Content -Encoding UTF8 -Path $path -Force -ErrorAction Stop
          
          # 직접 쓰기 후 검증
          $finalCheck = Get-Content -Raw -Path $path -ErrorAction Stop
          $null = $finalCheck | ConvertFrom-Json -ErrorAction Stop
          $savedSuccessfully = $true
          Write-Warn "Direct write succeeded (non-atomic)"
          
        } catch {
          $errorMessage = $_.Exception.Message
          throw "All write attempts failed: $errorMessage"
        }
      }
    }
    
  } catch {
    $errorMessage = $_.Exception.Message
    Write-Err "Failed to save JSON to: $path"
    Write-Err "Error: $errorMessage"
    
    # 백업에서 복원 시도
    if ($backupPath -and (Test-Path $backupPath)) {
      try {
        Write-Warn "Attempting to restore from backup..."
        Copy-Item -Path $backupPath -Destination $path -Force -ErrorAction Stop
        Write-Info "Restored from backup: $backupPath"
      } catch {
        Write-Err "Failed to restore from backup: $($_.Exception.Message)"
      }
    }
    
    throw
    
  } finally {
    # 임시 파일 정리
    if (Test-Path $tempPath) {
      Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $tempPath2) {
      Remove-Item -Path $tempPath2 -Force -ErrorAction SilentlyContinue
    }
  }
  
  if ($savedSuccessfully) {
    Write-Info "Saved: $path"
  }
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

# 허용된 npx 패키지 화이트리스트
$SafeNpxPackages = @(
  "@anaisbetts/mcp-installer",
  "@modelcontextprotocol/server-filesystem",
  "youtube-data-mcp-server",
  "@modelcontextprotocol/server-github"
)

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

function Test-SafeArgs($command, $argList) {
  if (-not $argList) { return $true }
  
  $argsString = $argList -join " "
  foreach ($pattern in $DangerousPatterns) {
    if ($argsString -like "*$pattern*") {
      Write-Warn "Dangerous argument pattern detected: $pattern"
      return $false
    }
  }

  # npx 명령어의 경우, 패키지 화이트리스트 검사
  if ((Split-Path -Leaf $command) -eq "npx") {
    # -y 옵션은 무시하고 패키지 이름 찾기
    $packageName = $argList | Where-Object { $_ -ne "-y" } | Select-Object -First 1
    if ($packageName -and $SafeNpxPackages -notcontains $packageName) {
      Write-Warn "Disallowed npx package: $packageName"
      Write-Warn "Allowed packages: $($SafeNpxPackages -join ', ')"
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
    # npx 패키지 이름(@scope/package)이 Unix 경로로 오인되지 않도록 수정
    if ($arg -match "^/" -and $arg -notmatch "^/[cC]/" -and $arg -notmatch "^\@[a-zA-Z0-9\-_/]+$") {
      Write-Warn "Blocked absolute path execution: $arg"
      return $false
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
  # 기본 스키마 검증
  if (-not $config -or $config.GetType().Name -ne "PSCustomObject") {
    Write-Err "[$name] Invalid configuration object"
    return $false
  }
  
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
  
  # command가 문자열인지 확인
  if ($config.command.GetType().Name -ne "String") {
    Write-Err "[$name] 'command' must be a string"
    return $false
  }
  
  # args가 있다면 배열인지 확인
  if ($config.args) {
    if ($config.args -isnot [System.Array] -and $config.args.GetType().Name -ne "Object[]") {
      Write-Err "[$name] 'args' must be an array"
      return $false
    }
  }
  
  # env가 있다면 객체인지 확인
  if ($config.env) {
    if ($config.env.GetType().Name -ne "PSCustomObject") {
      Write-Err "[$name] 'env' must be an object"
      return $false
    }
  }
  
  # 명령어 안전성 검증
  if (-not (Test-SafeCommand $config.command)) {
    return $false
  }
  
  # 인자 안전성 검증
  if ($config.args -and -not (Test-SafeArgs $config.command $config.args)) {
    return $false
  }
  
  Write-Info "[$name] Security validation passed"
  return $true
}

function Confirm-UntrustedSource($configPath) {
  Write-Warn "Untrusted config file: $configPath"
  $cfg = $null
  try {
      $cfg = Read-Json $configPath
  } catch {
      Write-Err "Cannot proceed with untrusted source confirmation. $_"
      return $false
  }
  
  Write-Host "About to install the following servers:" -ForegroundColor Yellow
  
  $servers = if ($cfg.mcpServers) { $cfg.mcpServers } else { $cfg }
  
  # 빈 서버 목록 체크
  if (-not $servers -or $servers.PSObject.Properties.Count -eq 0) {
    Write-Warn "No servers found in config file"
    return $false
  }
  
  foreach ($name in $servers.PSObject.Properties.Name) {
    $server = $servers.$name
    if ($server -and $server.command) {
      Write-Host "  - $name : $($server.command) $($server.args -join ' ')" -ForegroundColor Gray
    } else {
      Write-Host "  - $name : [Invalid configuration]" -ForegroundColor Red
    }
  }
  
  $response = Read-Host "Continue? (y/N)"
  return ($response -eq "y" -or $response -eq "Y")
}

# 3) mcp-installer 추가 (크로스 플랫폼 지원)
function Add-McpInstaller($cfg){
  if ($cfg.mcpServers.'mcp-installer') {
    Write-Info "mcp-installer already exists"
    return $cfg
  }
  
  # 플랫폼별 명령어 설정
  $mcpInstallerConfig = @{
    type = "stdio"
  }
  
  # OS 감지 및 적절한 명령어 설정
  if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
    # Windows 환경
    $mcpInstallerConfig.command = "cmd.exe"
    $mcpInstallerConfig.args = @("/c","npx","-y","@anaisbetts/mcp-installer")
  } elseif ($IsMacOS) {
    # macOS 환경
    $mcpInstallerConfig.command = "npx"
    $mcpInstallerConfig.args = @("-y","@anaisbetts/mcp-installer")
  } elseif ($IsLinux) {
    # Linux 환경
    $mcpInstallerConfig.command = "npx"
    $mcpInstallerConfig.args = @("-y","@anaisbetts/mcp-installer")
  } else {
    # 기본값 (Unix-like)
    $mcpInstallerConfig.command = "npx"
    $mcpInstallerConfig.args = @("-y","@anaisbetts/mcp-installer")
  }
  
  $cfg.mcpServers.'mcp-installer' = $mcpInstallerConfig
  Write-Info "Added mcp-installer entry (플랫폼: $($PSVersionTable.Platform ?? 'Windows'))"
  return $cfg
}

# 4) 외부 JSON(사용자 제공) 병합 - 보안 검증 및 데이터 무결성 강화
function Merge-Servers($cfg, $importPath){
  if (-not (Test-Path $importPath)) { throw "Config file not found: $importPath" }
  
  # 병합 전 전체 백업 생성 (타임스탬프 포함)
  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $backupDir = Join-Path (Split-Path $ClaudeCfg) "backups"
  if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
  }
  $backupPath = Join-Path $backupDir "config_${timestamp}_before_merge.json"
  
  if (Test-Path $ClaudeCfg) {
    Copy-Item -Path $ClaudeCfg -Destination $backupPath -Force
    Write-Info "Pre-merge backup created: $backupPath"
  }
  
  # 신뢰되지 않은 소스 경고 및 확인 (TrustSource 플래그가 없을 때만)
  if (-not $TrustSource) {
    if (-not (Confirm-UntrustedSource $importPath)) {
      Write-Warn "User cancelled installation."
      return $cfg
    }
  } else {
    Write-Warn "Using -TrustSource flag: skipping security check for '$importPath'"
  }
  
  $imp = Read-Json $importPath
  # 허용 형태: { "mcpServers": { ... } } 또는 { "<name>": { ... } }
  $servers = @{}
  if ($imp.mcpServers){ $servers = $imp.mcpServers }
  else { $servers = $imp }  # 루트에 서버 키들이 바로 있는 형태 지원

  $failedCount = 0
  $successCount = 0
  $skippedCount = 0
  $overwrittenList = @()
  $addedList = @()
  
  # 충돌 사전 분석
  $conflicts = @()
  foreach($k in $servers.PSObject.Properties.Name){
    if ($cfg.mcpServers.PSObject.Properties[$k]) {
      $conflicts += $k
    }
  }
  
  if ($conflicts.Count -gt 0) {
    Write-Warn "=== Conflict Detection Report ==="
    Write-Warn "Found $($conflicts.Count) existing configurations that will be affected:"
    foreach ($name in $conflicts) {
      Write-Host "  - $name" -ForegroundColor Yellow
    }
    Write-Warn "================================="
    
    if (-not $DryRun) {
      $batchResponse = Read-Host "How to handle conflicts? (a)ll overwrite, (s)kip all, (i)ndividual choice [default: i]"
      if (-not $batchResponse) { $batchResponse = "i" }
    } else {
      Write-Info "(DryRun) Would prompt for conflict resolution"
      $batchResponse = "s"
    }
  } else {
    $batchResponse = "i"  # 충돌 없음
  }
  
  foreach($k in $servers.PSObject.Properties.Name){
    $serverConfig = $servers.$k
    
    # 보안 검증
    if (Test-McpServerConfig $k $serverConfig) {
      # 키 충돌 검사
      if ($cfg.mcpServers.PSObject.Properties[$k]) {
        $existingConfig = $cfg.mcpServers.$k | ConvertTo-Json -Compress
        $newConfig = $serverConfig | ConvertTo-Json -Compress
        
        # 동일한 설정인지 확인
        if ($existingConfig -eq $newConfig) {
          Write-Info "[$k] Identical config - skipped"
          $skippedCount++
          continue
        }
        
        Write-Warn "Conflict detected for '$k'"
        Write-Host "  Existing: $existingConfig" -ForegroundColor DarkGray
        Write-Host "  New:      $newConfig" -ForegroundColor Gray
        
        $overwrite = $false
        switch ($batchResponse) {
          "a" { $overwrite = $true }
          "s" { $overwrite = $false }
          "i" {
            $overwriteResponse = Read-Host "Do you want to overwrite '$k'? (y/N)"
            $overwrite = ($overwriteResponse -eq 'y' -or $overwriteResponse -eq 'Y')
          }
        }
        
        if ($overwrite) {
          # 개별 백업 저장
          $individualBackup = @{
            name = $k
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            oldValue = $cfg.mcpServers.$k
            newValue = $serverConfig
          }
          $overwrittenList += $individualBackup
          
          $cfg.mcpServers.$k = $serverConfig
          Write-Info "Overwritten: $k"
          $successCount++
        } else {
          Write-Info "Skipped (preserved existing): $k"
          $skippedCount++
        }
      } else {
        $cfg.mcpServers | Add-Member -MemberType NoteProperty -Name $k -Value $serverConfig
        Write-Info "Added new: $k"
        $addedList += $k
        $successCount++
      }
    } else {
      Write-Err "[$k] Security validation failed - skipped"
      $failedCount++
    }
  }
  
  # 변경 사항 요약 보고
  Write-Host "`n=== Merge Summary ===" -ForegroundColor Cyan
  Write-Host "  Added:      $($addedList.Count) servers" -ForegroundColor Green
  Write-Host "  Overwritten: $($overwrittenList.Count) servers" -ForegroundColor Yellow
  Write-Host "  Skipped:    $skippedCount servers" -ForegroundColor Gray
  Write-Host "  Failed:     $failedCount servers" -ForegroundColor Red
  Write-Host "  Total Success: $successCount servers" -ForegroundColor Green
  Write-Host "=====================" -ForegroundColor Cyan
  
  # 변경 로그 저장 (롤백용)
  if ($overwrittenList.Count -gt 0 -and -not $DryRun) {
    $changeLogPath = Join-Path $backupDir "changelog_${timestamp}.json"
    $changeLog = @{
      timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
      backupFile = $backupPath
      changes = $overwrittenList
    }
    $changeLog | ConvertTo-Json -Depth 10 | Set-Content -Path $changeLogPath -Encoding UTF8
    Write-Info "Change log saved: $changeLogPath"
  }
  
  if ($failedCount -gt 0) {
    Write-Warn "Some servers were blocked by security policy."
  }
  
  return $cfg
}

# 5) 롤백 기능
function Restore-Config {
  param(
    [string]$BackupPath
  )
  
  $backupDir = Join-Path (Split-Path $ClaudeCfg) "backups"
  
  if (-not $BackupPath) {
    # 마지막 백업 찾기
    if (-not (Test-Path $backupDir)) {
      Write-Err "No backup directory found at: $backupDir"
      return $false
    }
    
    $latestBackup = Get-ChildItem -Path $backupDir -Filter "config_*_before_merge.json" | 
                    Sort-Object LastWriteTime -Descending | 
                    Select-Object -First 1
    
    if (-not $latestBackup) {
      Write-Err "No backup files found in: $backupDir"
      return $false
    }
    
    $BackupPath = $latestBackup.FullName
    Write-Info "Found latest backup: $($latestBackup.Name)"
  } else {
    # 특정 백업 파일 처리
    if (-not [System.IO.Path]::IsPathRooted($BackupPath)) {
      # 상대 경로인 경우 백업 디렉토리에서 찾기
      $BackupPath = Join-Path $backupDir $BackupPath
    }
    
    if (-not (Test-Path $BackupPath)) {
      Write-Err "Backup file not found: $BackupPath"
      
      # 사용 가능한 백업 목록 표시
      if (Test-Path $backupDir) {
        $availableBackups = Get-ChildItem -Path $backupDir -Filter "*.json" | 
                           Sort-Object LastWriteTime -Descending
        if ($availableBackups) {
          Write-Info "Available backups:"
          foreach ($backup in $availableBackups) {
            Write-Host "  - $($backup.Name) ($(Get-Date $backup.LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
          }
        }
      }
      return $false
    }
  }
  
  # 백업 파일 유효성 검사
  $backupContent = $null
  try {
    $backupContent = Read-Json $BackupPath
  } catch {
    Write-Err "Invalid backup file: $BackupPath"
    return $false
  }
  
  if (-not $backupContent -or -not $backupContent.mcpServers) {
    Write-Err "Backup file doesn't contain valid mcpServers configuration"
    return $false
  }
  
  # 현재 설정 백업 (롤백의 롤백용)
  if (Test-Path $ClaudeCfg) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $rollbackBackup = Join-Path $backupDir "config_${timestamp}_before_rollback.json"
    Copy-Item -Path $ClaudeCfg -Destination $rollbackBackup -Force
    Write-Info "Current config backed up to: $(Split-Path $rollbackBackup -Leaf)"
  }
  
  # 롤백 실행
  if ($DryRun) {
    Write-Info "(DryRun) Would restore from: $BackupPath"
    Write-Info "(DryRun) Configuration to be restored:"
    $backupContent | ConvertTo-Json -Depth 10 | Write-Host
    return $true
  }
  
  try {
    Write-Json $backupContent $ClaudeCfg
    Write-Info "Successfully restored configuration from backup"
    
    # 롤백 로그 저장
    $rollbackLog = @{
      timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
      restoredFrom = $BackupPath
      action = "rollback"
    }
    $rollbackLogPath = Join-Path $backupDir "rollback_${timestamp}.json"
    $rollbackLog | ConvertTo-Json | Set-Content -Path $rollbackLogPath -Encoding UTF8
    Write-Info "Rollback log saved: $(Split-Path $rollbackLogPath -Leaf)"
    
    return $true
  } catch {
    Write-Err "Failed to restore configuration: $_"
    return $false
  }
}

# 6) Verify 절차 - 프로세스 누수 방지 개선
function Verify-Run {
  try {
    Write-Info "Checking installed list: claude mcp list"
    & claude mcp list
  } catch { 
    Write-Warn "claude mcp list execution failed: $_" 
  }

  if ($DryRun) {
    Write-Info "(DryRun) Skipping debug test"
    return
  }

  $debugJob = $null
  
  try {
    Write-Info "Running in debug mode to verify MCP operation..."
    
    # Start-Job을 사용하여 백그라운드에서 claude --debug 실행
    $scriptBlock = { 
        param($Cmd)
        & $Cmd --debug 
    }
    $debugJob = Start-Job -ScriptBlock $scriptBlock -ArgumentList "claude"
    
    if (-not $debugJob) {
      throw "Failed to start debug process"
    }
    
    Write-Info "Debug job started (ID: $($debugJob.Id), Name: $($debugJob.Name))"
    
    # 10초간 MCP 서버 초기화 대기
    Start-Sleep -Seconds 10
    
    if ($debugJob.State -eq 'Running') {
      Write-Info "Verifying actual operation with /mcp command..."
      $testResult = echo "/mcp" | claude 2>&1
      
      if ($testResult) {
        Write-Info "MCP command test completed"
      }
      
      # 추가 5초 대기
      Start-Sleep -Seconds 5
    }
    
  } catch {
    Write-Warn "Debug test failed: $_"
  } finally {
    # 백그라운드 작업 정리
    if ($debugJob) {
      try {
        Write-Info "Stopping and removing debug job (ID: $($debugJob.Id))..."
        Stop-Job -Job $debugJob -Force
        Remove-Job -Job $debugJob -Force
        Write-Info "Debug job cleaned up successfully."
      } catch {
        Write-Warn "Error cleaning up debug job: $_"
      }
    }
    
    # Start-Job이 생성한 자식 프로세스(claude) 정리
    try {
      Get-Process -Name "claude" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
      Write-Info "Cleaned up any orphaned 'claude' processes."
    } catch {
      Write-Warn "Could not clean up all processes: $_"
    }
  }
}

# === 실행 시퀀스 ===

# 롤백 처리 (다른 작업보다 우선)
if ($Rollback -or $RollbackTo) {
  Write-Info "Starting rollback process..."
  
  if (-not (Test-Claude)) {
    Write-Err "Claude CLI check failed. Aborting rollback."
    exit 1
  }
  
  $result = Restore-Config -BackupPath $RollbackTo
  
  if ($result) {
    Write-Info "Rollback completed successfully"
    if ($Verify) { Verify-Run }
  } else {
    Write-Err "Rollback failed"
    exit 1
  }
  exit 0
}

# MCP 서버 실행에는 Node.js 18+가 권장되지만, 16 LTS도 대부분 호환 가능
$nodeOk = Test-Node -MinimumVersion "18.0.0"
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
