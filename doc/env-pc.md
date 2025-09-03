═══ 🚀 개발 환경 체크 시작 ═══

  📅 실행 시간: 2025-09-02 16:29:18
  📂 현재 위치: C:\Users\brian_qs0
  📝 스크립트: dev-env-chk-in-powershell.ps1 (구조화 버전)

═══ 🐍 Python 개발 환경 ═══

🌐 전역 환경 (시스템 공통)
──────────────────
  💡 시스템 전체에서 사용되는 Python 도구들
Python (Global):
  경로   : D:\DevTools\Python313\python.exe
  버전   : Python 3.13.5
  설치일 : 2025-06-11 18:10
  수정일 : 2025-06-11 18:10

pip (Global):
  경로   : D:\DevTools\Python313\Scripts\pip.exe
  버전   : pip 25.1.1 from D:\DevTools\Python313\Lib\site-packages\pip (python 3.13)
  설치일 : 2025-08-21 17:10
  수정일 : 2025-08-21 17:10

📦 가상환경 (프로젝트별 격리)
───────────────────
  💡 프로젝트별 독립된 패키지 환경 (.venv, venv 폴더)
🔍 가상환경 검색 중...
Split-Path:
Line |
 184 |  … e $currentPath -and $currentPath -ne (Split-Path $currentPath -Parent …
     |                                                     ~~~~~~~~~~~~
     | Cannot bind argument to parameter 'Path' because it is an empty string.
📦 발견된 가상환경 (3개):

가상환경 감지됨 [Coding Project (IntelliFiller)]:
  경로   : D:\Coding\IntelliFiller\.venv
  버전   : Python 3.13.5
  실행파일: D:\Coding\IntelliFiller\.venv\Scripts\python.exe
  설정   : pyvenv.cfg 존재
  기반   : D:\DevTools\Python313


═══ 🜢 Node.js 개발 환경 ═══

🌐 전역 환경 (시스템 유틸리티용)
─────────────────────
  💡 CLI 도구처럼 여러 프로젝트에서 공유할 명령에만 사용 권장
Node.js (Global):
  경로   : D:\DevTools\Node\node.exe
  버전   : v22.18.0
  설치일 : 2025-07-31 09:02
  수정일 : 2025-07-31 09:02

npm (Global):
  경로   : D:\DevTools\Node\npm.cmd
  버전   : 10.9.3
  설치일 : 2024-11-07 15:34
  수정일 : 2024-11-07 15:34

npx (Global):
  경로   : D:\DevTools\Node\npx.cmd
  버전   : 10.9.3
  설치일 : 2024-11-07 15:34
  수정일 : 2024-11-07 15:34


🌐 전역 설치 패키지 (참고용):
  총 개수: 3 개
  - D:\DevTools\Node\npm-global
  - +-- @anthropic-ai/claude-code@1.0.93
  - `-- typescript@5.6.3
📦 프로젝트 로컬 환경 (권장)
───────────────────
  💡 대부분의 패키지는 프로젝트별 node_modules에 설치 권장
❌ Node.js 프로젝트를 찾을 수 없습니다.
  💡 다음 명령어로 새 프로젝트를 시작하세요:
     npm init -y              # package.json 생성
     npm install <package>    # 로컬 패키지 설치 (권장)
     npm install -g <tool>    # 전역 CLI 도구만 (최소한으로)


═══ 🌐 LocalWP WordPress 개발 환경 ═══

  💡 LocalWP (by Flywheel)에서 제공하는 WordPress 개발 도구들
✅ LocalWP 설치 감지됨: D:\DevTools\Local [실행 중]

📁 LocalWP 사이트 경로: C:\Users\brian_qs0\Local Sites
📋 설치된 WordPress 사이트 (1개):
  - brte
    PHP: php-fpm.d
    MySQL: 설정됨
    웹서버: Apache (레거시)

⚙️ LocalWP 런타임 환경
──────────────────
📦 PHP 런타임 버전:
  - PHP 8.2.27: 사용 가능

📦 MySQL/MariaDB 런타임 버전:
  - MariaDB 10.4.32: 설치됨 (비활성)
  - MySQL 8.0.35: ✅ 실행 중 (활성)

📦 웹서버:
  - nginx 1.26.1: ⚠️ 설치됨 (비활성)
  - Apache 2.4.43: ✅ 실행 중 (활성)
📦 메일 서버 (Mailpit):
  - Mailpit 1.24.1: 사용 가능 (로컬 메일 테스트용)

✅ LocalWP 환경 검사 완료!

═══ 🛠️ 기타 개발 도구 ═══

  💡 시스템 전역에 설치된 개발 도구들

WSL (Windows Subsystem for Linux):
  상태: WSL 설치됨 (배포판 없음)
  팁: wsl --install -d Ubuntu 실행

PowerShell:
  현재 세션:
    버전: 7.5.2
    에디션: Core
    경로: C:\Program Files\PowerShell\7
  Windows PowerShell:
    버전: 5.1.19041.6216
    경로: C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe
  PowerShell Core:
    버전: 7.5.2
    경로: C:\Program Files\PowerShell\7\pwsh.exe
    설치일: 2025-06-18 21:54
Git:
  경로   : D:\DevTools\Git\cmd\git.exe
  버전   : git version 2.51.0.windows.1
  설치일 : 2025-08-26 11:50
  수정일 : 2025-08-19 08:53

VSCode:
  경로   : D:\DevTools\Microsoft VS Code\bin\code.cmd
  버전   : 1.103.2 6f17636121051a53c88d3e605c491d22af2ba755 x64
  설치일 : 2025-08-30 17:30
  수정일 : 2025-08-20 17:04

Cursor IDE:
  경로   : D:\DevTools\Cursor\cursor\resources\app\bin\cursor.cmd
  버전   : 1.5.9 de327274300c6f38ec9f4240d11e82c3b0660b20 x64
  설치일 : 2025-09-01 11:12
  수정일 : 2025-08-30 21:14

TypeScript:
  경로   : D:\DevTools\Node\npm-global\tsc.cmd
  버전   : Version 5.6.3
  설치일 : 2025-08-26 16:38
  수정일 : 2025-08-26 16:38

GitHub CLI:
  경로   : D:\DevTools\GitHub CLI\gh.exe
  버전   : gh version 2.78.0 (2025-08-21) https://github.com/cli/cli/releases/tag/v2.78.0
  설치일 : 2025-08-21 19:01
  수정일 : 2025-08-21 19:01