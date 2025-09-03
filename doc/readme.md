# MCP Installer 사용 매뉴얼

## 개요
MCP (Model Context Protocol) 서버를 Windows 환경에서 쉽게 설치하고 설정할 수 있도록 돕는 PowerShell 스크립트입니다.

## 사전 준비사항

### 필수 요구사항
- **Windows PowerShell 5.0+** 또는 **PowerShell 7+**
- **Node.js v18 이상** ([다운로드](https://nodejs.org/))
- **Claude CLI** 설치 필요

### 환경 확인
```powershell
# Node.js 버전 확인
node -v

# Claude CLI 확인
claude -v

# PowerShell 버전 확인
$PSVersionTable.PSVersion
```

## 설치 방법

### 1. 기본 설치 (mcp-installer만 추가)
```powershell
# mcp-installer 엔트리만 추가
pwsh -File .\mcp-installer.ps1 -AddInstaller

# 설치 후 검증까지 수행
pwsh -File .\mcp-installer.ps1 -AddInstaller -Verify
```

### 2. 커스텀 MCP 서버 설치
```powershell
# JSON 설정 파일을 사용한 설치
pwsh -File .\mcp-installer.ps1 -Config .\mcp.windows.json -Scope user -Verify

# 프로젝트 스코프로 설치
pwsh -File .\mcp-installer.ps1 -Config .\mcp.windows.json -Scope project
```

### 3. 테스트 실행 (DryRun)
```powershell
# 실제 변경 없이 미리보기
pwsh -File .\mcp-installer.ps1 -Config .\mcp.windows.json -DryRun
```

## 파라미터 설명

| 파라미터 | 설명 | 기본값 |
|---------|------|--------|
| `-Config` | MCP 설정이 포함된 JSON 파일 경로 | - |
| `-Scope` | 설치 범위 (`user` 또는 `project`) | `user` |
| `-AddInstaller` | mcp-installer 엔트리만 추가 | `false` |
| `-Verify` | 설치 후 동작 검증 수행 | `false` |
| `-DryRun` | 실제 변경 없이 미리보기 | `false` |

## JSON 설정 파일 형식

### 예시: mcp.windows.json
```json
{
  "mcpServers": {
    "youtube-mcp": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "youtube-data-mcp-server"],
      "env": {
        "YOUTUBE_API_KEY": "YOUR_API_KEY_HERE",
        "YOUTUBE_TRANSCRIPT_LANG": "ko"
      }
    },
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem"],
      "env": {
        "FILESYSTEM_ROOT": "D:\\Projects"
      }
    }
  }
}
```

## 설정 파일 위치

### User 스코프 (기본값)
```
C:\Users\{사용자명}\.claude\config.json
```

### Project 스코프
```
{프로젝트폴더}\.claude\config.json
```

## 검증 프로세스

스크립트는 `-Verify` 옵션 사용 시 다음 검증을 수행합니다:

1. **설치 목록 확인**
   ```powershell
   claude mcp list
   ```

2. **디버그 모드 실행**
   - Claude를 디버그 모드로 시작
   - 최대 2분간 MCP 서버 초기화 관찰

3. **작동 확인**
   - `/mcp` 명령으로 실제 작동 여부 확인

## 문제 해결

### Node.js를 찾을 수 없음
```powershell
# Node.js 설치 확인
where node

# PATH 환경변수에 추가
[Environment]::SetEnvironmentVariable("PATH", "$env:PATH;C:\Program Files\nodejs", "User")
```

### Claude CLI를 찾을 수 없음
```powershell
# Claude CLI 설치
npm install -g @anthropic/claude-cli
```

### MCP 서버가 시작되지 않음
1. 디버그 모드로 상세 로그 확인:
   ```powershell
   claude --debug
   ```

2. 설치된 MCP 목록 확인:
   ```powershell
   claude mcp list
   ```

3. 설정 파일 직접 확인:
   ```powershell
   Get-Content "$env:USERPROFILE\.claude\config.json" | ConvertFrom-Json | ConvertTo-Json -Depth 10
   ```

### API KEY 설정
API KEY가 필요한 MCP의 경우:
1. 먼저 가상 키로 설치
2. 설정 파일에서 실제 키로 변경
3. Claude 재시작

## 주요 MCP 서버 예시

### 1. Filesystem MCP
파일 시스템 접근 제공
```json
{
  "filesystem": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem"]
  }
}
```

### 2. YouTube MCP
YouTube 데이터 및 자막 접근
```json
{
  "youtube-mcp": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "youtube-data-mcp-server"],
    "env": {
      "YOUTUBE_API_KEY": "YOUR_KEY"
    }
  }
}
```

### 3. GitHub MCP
GitHub 저장소 접근
```json
{
  "github": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"],
    "env": {
      "GITHUB_TOKEN": "YOUR_TOKEN"
    }
  }
}
```

## 사용 예시

### 전체 설치 워크플로우
```powershell
# 1. 스크립트 다운로드
git clone https://github.com/brtea/Mcp-installer.git
cd Mcp-installer

# 2. 환경 확인
node -v
claude -v

# 3. mcp-installer 추가
pwsh -File .\mcp-installer.ps1 -AddInstaller

# 4. 커스텀 MCP 추가 (옵션)
# mcp.windows.json 파일 생성 후
pwsh -File .\mcp-installer.ps1 -Config .\mcp.windows.json -Verify

# 5. 설치 확인
claude mcp list
```

## 주의사항

1. **Windows 경로 처리**: JSON 파일 내 경로는 백슬래시를 두 번 사용 (`\\`)
2. **관리자 권한**: 일반적으로 불필요하나, 특정 MCP는 필요할 수 있음
3. **방화벽**: 일부 MCP는 네트워크 접근 필요
4. **재시작**: 설정 변경 후 Claude 재시작 필요

## 추가 리소스

- [MCP 공식 문서](https://modelcontextprotocol.io)
- [Claude CLI 문서](https://docs.anthropic.com/claude/docs/claude-cli)
- [프로젝트 GitHub](https://github.com/brtea/Mcp-installer)

## 문의 및 지원

이슈 발생 시 [GitHub Issues](https://github.com/brtea/Mcp-installer/issues)에 보고해 주세요.