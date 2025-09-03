## 클로드 코드에서의 mcp-installer를 사용한 MCP (Model Context Protocol) 설치 및 설정 가이드

### 🔒 보안 기능
mcp-installer.ps1은 다음과 같은 보안 기능을 포함합니다:
- **명령어 화이트리스트**: 승인된 명령어만 실행 허용 (npx, node, python, uvx 등)
- **NPX 패키지 화이트리스트**: 검증된 NPX 패키지만 설치 허용
- **위험 패턴 차단**: 파일 삭제, 디스크 포맷, 명령 체이닝 등 위험한 패턴 차단
- **경로 검증**: 절대 경로 실행 차단, npm 패키지 형식만 허용
- **JSON 검증**: 잘못된 JSON으로 인한 시스템 오류 방지
- **원자적 파일 쓰기**: 설정 파일 손상 방지를 위한 3단계 복구 전략
- **자동 백업/복원**: 설정 변경 전 자동 백업 및 롤백 기능

공통 주의사항

1. 현재 사용 환경은 doc 폴더안에 env-pc.md, ide-addon.md, mcp-setting.md를 참고한다.
2. OS(윈도우,리눅스,맥) 및 환경들(WSL,파워셀,명령프롬프트등)을 파악해서 그에 맞게 세팅할 것. 모르면 doc 폴더안에 env-pc.md, ide-addon.md, mcp-setting.md를 참고한다.
3. mcp-installer을 이용해 필요한 MCP들을 설치할 것
   (user 스코프로 설치 및 적용할것)
4. 특정 MCP 설치시, 바로 설치하지 말고, WebSearch 도구로 해당 MCP의 공식 사이트 확인하고 현재 OS 및 환경 매치하여, 공식 설치법부터 확인할 것
5. 공식 사이트 확인 후에는 context7 MCP 존재하는 경우, context7으로 다시 한번 확인할 것
6. MCP 설치 후, task를 통해 디버그 모드로 서브 에이전트 구동한 후, /mcp 를 통해 실제 작동여부를 반드시 확인할 것
7. 설정 시, API KEY 환경 변수 설정이 필요한 경우, 가상의 API 키로 디폴트로 설치 및 설정 후, 올바른 API 키 정보를 입력해야 함을 사용자에게 알릴 것
8. Mysql MCP와 같이 특정 서버가 구동중 상태여만 정상 작동한 것은 에러가 나도 재설치하지 말고, 정상 구동을 위한 조건을 사용자에게 알릴 것
9. 현재 클로드 코드가 실행되는 환경이야.
10. 설치 요청 받은 MCP만 설치하면 돼. 혹시 이미 설치된 다른 MCP 에러 있어도, 그냥 둘 것
11. 일단, 터미널에서 설치하려는 MCP 작동 성공한 경우, 성공 시의 인자 및 환경 변수 이름을 활용해, 올바른 위치의 json 파일에 MCP 설정을 직접할 것

_윈도우에서의 주의사항_

1. 설정 파일 직접 세팅시, Windows 경로 구분자는 백슬래시(\)이며, JSON 내에서는 반드시 이스케이프 처리(\\\\)해야 해.
   ** OS 공통 주의사항**
2. Node.js가 %PATH%에 등록되어 있는지, 버전이 최소 v18 이상인지 확인할 것. doc 폴더안에 env-pc.md, ide-addon.md, mcp-setting.md를 참고한다.\*\*\*\*
3. npx -y 옵션을 추가하면 버전 호환성 문제를 줄일 수 있음

### 크로스 플랫폼 지원
mcp-installer.ps1은 다음 환경을 자동으로 감지하고 지원합니다:
- **Windows**: PowerShell 5.1+, PowerShell Core 7+
- **macOS**: PowerShell Core 7+ (brew install powershell)
- **Linux**: PowerShell Core 7+ (snap/apt/yum install powershell)
- **WSL**: Windows Subsystem for Linux 환경 지원

### MCP 서버 설치 순서

1.  기본 설치 - mcp-installer.ps1 사용
    ```powershell
    # 설정 파일을 통한 설치 (권장)
    pwsh -File .\mcp-installer.ps1 -Config .\mcp.windows.json -Scope user
    
    # 검증 모드 (디버그 테스트 포함)
    pwsh -File .\mcp-installer.ps1 -Config .\mcp.windows.json -Scope user -Verify
    
    # 드라이런 (미리보기)
    pwsh -File .\mcp-installer.ps1 -Config .\mcp.windows.json -Scope user -DryRun
    
    # 신뢰할 수 있는 소스 (확인 생략)
    pwsh -File .\mcp-installer.ps1 -Config .\mcp.windows.json -Scope user -TrustSource
    ```

2.  설치 후 정상 설치 여부 확인하기
    ```powershell
    # 설치 목록 확인
    claude mcp list
    
    # 자동 검증 (mcp-installer.ps1의 -Verify 옵션 사용)
    pwsh -File .\mcp-installer.ps1 -Config .\mcp.windows.json -Scope user -Verify
    
    # 수동 검증
    claude --debug  # 디버그 모드 실행 (최대 2분 관찰)
    echo "/mcp" | claude --debug  # MCP 작동 확인
    ```

3.  문제 있을때 다음을 통해 직접 설치할 것

    _User 스코프로 claude mcp add 명령어를 통한 설정 파일 세팅 예시_
    예시1:
    claude mcp add --scope user youtube-mcp \
     -e YOUTUBE_API_KEY=$YOUR_YT_API_KEY \

    -e YOUTUBE_TRANSCRIPT_LANG=ko \
     -- npx -y youtube-data-mcp-server

4.  정상 설치 여부 확인 하기
    claude mcp list 으로 설치 목록에 포함되는지 내용 확인한 후,
    task를 통해 디버그 모드로 서브 에이전트 구동한 후 (claude --debug), 최대 2분 동안 관찰한 후, 그 동안의 디버그 메시지(에러 시 관련 내용이 출력됨)를 확인하고, /mcp 를 통해(Bash(echo "/mcp" | claude --debug)) 실제 작동여부를 반드시 확인할 것

5.  문제 있을때 공식 사이트 다시 확인후 권장되는 방법으로 설치 및 설정할 것
    (npm/npx 패키지를 찾을 수 없는 경우) pm 전역 설치 경로 확인 : npm config get prefix
    권장되는 방법을 확인한 후, npm, pip, uvx, pip 등으로 직접 설치할 것

    #### uvx 명령어를 찾을 수 없는 경우

    # uv 설치 (Python 패키지 관리자)

    curl -LsSf https://astral.sh/uv/install.sh | sh

    #### npm/npx 패키지를 찾을 수 없는 경우

    # npm 전역 설치 경로 확인

    npm config get prefix

    #### uvx 명령어를 찾을 수 없는 경우

    # uv 설치 (Python 패키지 관리자)

    curl -LsSf https://astral.sh/uv/install.sh | sh

    ## 설치 후 터미널 상에서 작동 여부 점검할 것

    ## 위 방법으로, 터미널에서 작동 성공한 경우, 성공 시의 인자 및 환경 변수 이름을 활용해서, 클로드 코드의 올바른 위치의 json 설정 파일에 MCP를 직접 설정할 것

    설정 예시
    (설정 파일 위치)
    **_리눅스, macOS 또는 윈도우 WSL 기반의 클로드 코드인 경우_** - **User 설정**: `~/.claude/` 디렉토리 - **Project 설정**: 프로젝트 루트/.claude

        ***윈도우 네이티브 클로드 코드인 경우***
        - **User 설정**: `C:\Users\{사용자명}\.claude` 디렉토리
        - **Project 설정**: 프로젝트 루트\.claude

        1. npx 사용

        {
          "youtube-mcp": {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "youtube-data-mcp-server"],
            "env": {
              "YOUTUBE_API_KEY": "YOUR_API_KEY_HERE",
              "YOUTUBE_TRANSCRIPT_LANG": "ko"
            }
          }
        }


        2. cmd.exe 래퍼 + 자동 동의)
        {
          "mcpServers": {
            "mcp-installer": {
              "command": "cmd.exe",
              "args": ["/c", "npx", "-y", "@anaisbetts/mcp-installer"],
              "type": "stdio"
            }
          }
        }

        3. 파워셀예시
        {
          "command": "powershell.exe",
          "args": [
            "-NoLogo", "-NoProfile",
            "-Command", "npx -y @anaisbetts/mcp-installer"
          ]
        }

        4. npx 대신 node 지정
        {
          "command": "node",
          "args": [
            "%APPDATA%\\npm\\node_modules\\@anaisbetts\\mcp-installer\\dist\\index.js"
          ]
        }

        5. args 배열 설계 시 체크리스트
        토큰 단위 분리: "args": ["/c","npx","-y","pkg"] 와
        	"args": ["/c","npx -y pkg"] 는 동일해보여도 cmd.exe 내부에서 따옴표 처리 방식이 달라질 수 있음. 분리가 안전.
        경로 포함 시: JSON에서는 \\ 두 번. 예) "C:\\tools\\mcp\\server.js".
        환경변수 전달:
        	"env": { "UV_DEPS_CACHE": "%TEMP%\\uvcache" }
        타임아웃 조정: 느린 PC라면 MCP_TIMEOUT 환경변수로 부팅 최대 시간을 늘릴 수 있음 (예: 10000 = 10 초)

(설치 및 설정한 후는 항상 아래 내용으로 검증할 것)
```powershell
# mcp-installer.ps1의 자동 검증 기능 사용 (권장)
pwsh -File .\mcp-installer.ps1 -Config .\mcp.windows.json -Scope user -Verify

# 또는 수동 검증
claude mcp list  # 설치 목록 확인
claude --debug   # 디버그 모드 실행 (최대 2분 관찰)
echo "/mcp" | claude --debug  # 실제 작동 확인
```

### 백업 및 복원 기능
mcp-installer.ps1은 설정 변경 시 자동으로 백업을 생성합니다:
```powershell
# 마지막 백업으로 롤백
pwsh -File .\mcp-installer.ps1 -Rollback

# 특정 백업 파일로 복원
pwsh -File .\mcp-installer.ps1 -RestoreFrom "backup_20250102_143022.json"

# 백업 목록 확인
ls ~\.claude\backups\*.json | Sort-Object LastWriteTime -Descending
```

### 충돌 감지 및 해결
기존 MCP 서버와 충돌이 발생할 경우:
- 자동으로 충돌을 감지하고 사용자에게 알림
- 덮어쓰기, 건너뛰기, 병합 옵션 제공
- 변경 전 자동 백업 생성

** MCP 서버 제거가 필요할 때 예시: **
claude mcp remove youtube-mcp
