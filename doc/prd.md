## VSCode/Cursor IDE에서 Claude Code CLI를 위한 MCP (Model Context Protocol) 설치 및 설정 가이드

### 🔒 보안 기능 (Python 버전 - mcp-installer.py)
- **명령어 화이트리스트**: npx, node, python, cmd, powershell 등 안전한 명령어만 허용
- **패키지 화이트리스트**: 10개 이상의 검증된 MCP 패키지 사전 등록
- **위험 패턴 차단**: 43개의 위험한 패턴 감지 및 차단 (rm -rf, eval, 파이프라인 인젝션 등)
- **경로 보호**: 절대 경로 실행 차단, 상위 디렉토리 접근 차단
- **화이트리스트 확장**: --extend-package, --whitelist-file로 안전하게 확장 가능
- **원자적 파일 쓰기**: tempfile.mkstemp로 데이터 무결성 보장
- **자동 백업/복원**: 타임스탬프 백업 생성, 최대 10개 유지, 30일 이상 자동 삭제
- **파일 잠금**: .claude.lock으로 프로세스 간 동기화
- **중복 검증**: 명령어 시그니처 기반 중복 감지

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
mcp-installer.py는 다음 환경을 자동으로 감지하고 지원합니다:
- **Windows**: Python 3.7+ (네이티브 Windows)
- **macOS**: Python 3.7+ 
- **Linux**: Python 3.7+
- **WSL**: Windows Subsystem for Linux 환경 지원

### MCP 서버 설치 순서

1.  기본 설치 - mcp-installer.py 사용
    ```bash
    # mcp-installer 추가
    python mcp-installer.py --add-installer
    
    # 설정 파일을 통한 설치 (권장)
    python mcp-installer.py -c sample-mcp.json
    
    # 검증 모드 (Claude CLI 테스트)
    python mcp-installer.py --verify
    
    # 드라이런 (미리보기)
    python mcp-installer.py -c sample-mcp.json --dry-run
    
    # 커스텀 패키지 추가
    python mcp-installer.py --extend-package "@mycompany/mcp-server"
    
    # 외부 화이트리스트 로드
    python mcp-installer.py --whitelist-file whitelist-example.json
    ```

2.  설치 후 정상 설치 여부 확인하기
    ```bash
    # 설치 목록 확인
    python mcp-installer.py --list
    
    # MCP 현황 상세 보고서
    python mcp-status.py
    
    # Claude CLI 검증
    python mcp-installer.py --verify
    
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
    (설정 파일 위치 - Claude Code CLI 표준 경로)
    **_모든 OS 공통_**
    - **User 설정**: 홈 디렉토리의 `.claude.json` 파일 (단일 파일)
        - Windows: `C:\Users\{사용자명}\.claude.json`
        - Linux/macOS: `~/.claude.json`
    - **백업 디렉토리**: `~/.claude-backups/`

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
```bash
# Python 도구를 사용한 검증
python mcp-installer.py --verify  # Claude CLI 작동 확인
python mcp-installer.py --list    # 등록된 서버 목록
python mcp-status.py               # 상세한 MCP 현황 보고서

# 또는 수동 검증
claude mcp list  # 설치 목록 확인
claude --debug   # 디버그 모드 실행 (최대 2분 관찰)
echo "/mcp" | claude --debug  # 실제 작동 확인
```

### 백업 및 복원 기능
mcp-installer.py는 설정 변경 시 자동으로 백업을 생성합니다:
- **자동 백업**: 모든 변경 전 `~/.claude-backups/`에 타임스탬프 백업 생성
- **백업 관리**: 최대 10개 유지, 30일 이상 자동 삭제
- **원자적 쓰기**: tempfile로 임시 파일 생성 → JSON 검증 → 원자적 교체
- **실패 시 자동 복구**: 저장 실패 시 최신 백업에서 자동 복원

```bash
# 백업 목록 확인 (Windows)
dir %USERPROFILE%\.claude-backups\*.json

# 백업 목록 확인 (Linux/macOS)
ls -la ~/.claude-backups/*.json
```

### 충돌 감지 및 해결
- **중복 명령어 검증**: 명령어 시그니처 기반 중복 감지
- **사용자 확인**: 중복 발견 시 사용자에게 확인 요청
- **파일 잠금**: `.claude.lock`으로 동시 실행 보호
- **변경 전 자동 백업 생성**

### 동시성 제어
- **파일 잠금 메커니즘**: `.claude.lock` 파일로 프로세스 간 동기화
- **오래된 잠금 자동 정리**: 30초 이상된 잠금 자동 제거
- **안전한 해제**: try-finally로 잠금 해제 보장

** MCP 서버 제거가 필요할 때 예시: **
```bash
# Python 도구 사용
python mcp-installer.py --remove youtube-mcp

# 또는 Claude CLI 직접 사용
claude mcp remove youtube-mcp
```
