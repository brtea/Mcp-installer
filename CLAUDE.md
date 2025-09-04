# Project Context

## Development Policies & Guidelines

### 코딩 정책 및 가이드라인

1. **Encoding Policy (인코딩 정책)**

나는 **한글 Windows 10(64비트)** 환경에서 한국어로 개발한다. 운영체제·도구 간 인코딩 충돌과 한글 깨짐을 방지하고, 코드·데이터의 **일관성과 호환성**을 유지하기 위해 규칙을 정의한다.

-   모든 파일/로그/콘솔은 UTF-8(no BOM) + LF를 기본으로 한다.

-   Windows/PowerShell은 콘솔 출력 인코딩을 UTF-8로 고정한다(65001/OutputEncoding).

-   Git은 core.autocrlf=false, eol=lf로 설정한다. LF가 아닌 개행이 있으면 **경고만 출력**하며, 최종 리뷰/배포 단계에서만 차단한다.

-   파일명은 유니코드 NFC로 통일한다(WSL/macOS와 동기화 충돌 방지).

-   AI가 생성한 코드/로그/아티팩트도 UTF-8+LF 수렴을 보장한다.

-   EUC-KR/CP949/ANSI 등 레거시 데이터는 반드시 UTF-8로 변환 후 반영한다.

-   HTTP/CSV/DB 입출력은 charset=UTF-8을 명시한다.

-   pre-commit 훅은 BOM/CRLF/NFD 파일명을 검사하고 **경고만 출력**, 리뷰/배포 단계에서 차단한다.

-   한글 깨짐 발견 시: 원본 보존 → UTF-8 재저장 → 'encoding fix only'로 커밋한다.

2. **Language Policy (언어 정책)**

나는 **한국어 환경에서 개발**하지만, 코드와 협업은 영어 중심 생태계와 연결된다. 따라서 **주석·출력은 한국어**, **식별자·공식 용어는 영어**로 구분하여 가독성과 국제적 호환성을 함께 보장한다.

-   주석·콘솔 출력은 한국어, 오류 메시지·식별자·공식 용어는 영어로 유지한다.

-   사용자에게 보이는 텍스트는 코드에 직접 쓰지 말고 i18n 키(영문)로 두고 리소스 파일에서 관리한다.

-   예외/로그는 “한국어 설명 + 원문 에러(영문)”을 함께 기록한다.

-   용어 혼란을 막기 위해 glossary.md에 한/영 용어를 정리해둔다.

2. **Code Presence Policy (코드 작성 정책)**

> 바이브 코딩에서 **질문과 실제 구현 요청을 명확히 구분**하여, 질문일 경우 불필요한 코드를 생성하지 않는다.

-   **필요시에만 코드 작성**: 코드는 반드시 필요한 경우에만 작성하고, 그 외에는 간결한 요약으로 답변한다.
-   **구현 우선순위**: 기능 설명 → 핵심 로직 코드 → 전체 구현 (요청 시에만).
-   **질문 인식 규칙**
    -   문장의 끝이 **물음표(?)**로 끝나면 질문으로 인식하여 설명만 제공한다.
    -   문장의 시작이 **“질문”**으로 시작하면 질문으로 인식하여 설명만 제공한다.

3. **Complexity Guidelines (복잡성 가이드라인)**

> 나는 개념만 익힌 **초급 개발자**로서, AI 기반 **바이브 코딩(자동 코딩)**을 활용한다. 복잡한 코드는 유지보수가 어렵기 때문에, AI가 방대한 데이터 속에서 제공할 수 있는 **보편적·단순·표준적 접근법**을 우선한다.

-   **단순한 표준 접근법 선호**: 가능한 한 간단하고 표준적인 방법 사용
-   **최소한의 라이브러리**: 정확성/안전성이 요구되는 경우, 최소한의 라이브러리/패턴 허용 (한 줄 정당화 포함)
-   **예시**: `# requests 사용: HTTP 요청의 안정성과 표준 호환성 보장`

4. **Comments & Identifiers (주석 및 식별자)**

> 모든 개발은 **AI 기반 바이브 코딩**으로 진행되므로, 코드 생성·수정 과정에서 혼란을 줄이고 오류 대응을 쉽게 하기 위해 **통일성 있는 규칙**을 유지한다.

-   **주석**: 한국어로 작성
-   **콘솔 출력/로그**: 한국어 맥락 + **원문 에러(영문) 병기**
    -   예: `인증 실패(세션 만료 추정): original_error="Invalid token signature"`
-   **식별자 규칙**
    -   **Python**: `snake_case` (예: `process_notes`, `api_client`)
    -   **JavaScript/TypeScript**: `camelCase` (예: `processNotes`, `apiClient`)
    -   **클래스/컴포넌트**: `PascalCase` (예: `UserProfile`, `AuthManager`)
    -   **상수**: `UPPER_SNAKE_CASE` (예: `MAX_RETRY_COUNT`)
    -   **변수명**: 목적이 명확한 의미 있는 이름 사용 (`note_count`, `userToken`)
    -   **관례적 예외**: 루프 인덱스에 한해 `i`, `j` 허용
-   **파일명**: 영어 규칙, 소문자-하이픈 권장 (예: `user-service.ts`, `data-model.py`)

6. **Ambiguity Handling (모호성 처리)**

나는 **초급 개발자**로서 프로그램 개발에 정확한 용어 개념 사용이 서툴러 **모호한 질문을 하기 쉽다**. 이를 보완하기 위해 AI는 먼저 **간단한 확인 질문**으로 요구사항을 명확히 한다.

- **명확화 우선**: 모호한 요구사항 시 간단한 질문 1개 먼저 제시

- **답변 후 진행**: 답변 받은 후 즉시 작업 진행

- **예시**: "API 호출 실패 시 재시도 횟수는 몇 번으로 설정할까요?" → 답변 후 구현

7. **Safe Execution Policy (안전 실행 정책)**

- **기본값**: 실제 명령어 실행 (Default to real commands)

- **파괴적 작업**: 요청 시에만 dry-run 예시 제공

- **예시**: `git reset --hard` → 기본적으로 실제 명령, 요청 시 `--dry-run` 옵션 설명

### Code File Header & File History Policy

모든 코드 파일(.py, .ts, .js, .tsx, .jsx, .php, .java 등)에는 상단에 "File History" 주석 박스를 유지해야 한다.

단, .md / .mdc 파일은 제외한다.

주석 박스 규칙:

-   첫 줄부터 마지막 줄까지 **삭제 금지**
-   `"파일명"`은 실제 파일명 기재
-   `"기능 요약"`은 주요 역할을 2~3줄로 기록
-   `"File History"`는 수정 시마다 **KST 날짜·시간 + 변경 요약**을 1~2줄 추가
    -   형식: `YYYY.MM.DD AM/PMhh:mm 변경 요약`
    -   예: `2025.09.02 AM11:12 기본 기능 구현`
-   기존 `"File History"`는 수정하지 않는 것을 원칙으로 한다.
-   코드 변경 시, 반드시 이 주석 박스를 최신 상태로 업데이트 후 코드 작성

### Error Log Policy (에러 로그 정책)

모든 **에러·버그 수정 기록**은 `doc/err_log.md` 파일에 보관한다.  
이는 **프롬프트에서 “버그를 잡아라 / 에러를 수정하라”**와 같이 명시적으로 요청된 경우에만 기록한다.

-   **파일 위치**: `doc/err_log.md`
-   **기록 범위**: 주요 버그 수정 및 오류 해결 사항만 기록 (단순 리팩토링·주석 변경 제외)
-   **기록 형식**
    -   날짜·시간: **KST 기준**
    -   **에러 요약**: 3~5줄로 발생 원인, 증상, 영향 등 핵심 설명
    -   **해결 기록**: 3줄로 해결 방법과 적용 사항 정리
    -   예시:
        `2025.09.03 PM02:45   API 인증 오류 수정    [에러 요약]   - 문제: 401 Unauthorized 오류가 빈번히 발생  - 원인: 토큰 갱신 로직이 누락되어 만료 시 인증 실패  - 영향: 모든 API 호출 실패로 서비스 중단 위험 발생  [해결 기록]   - refreshToken 로직을 추가하여 토큰 자동 갱신 처리  - 인증 모듈 내 예외 처리 보강으로 안정성 확보  - 재현 테스트 완료 후 정상 동작 검증 완료`  

-   **원칙**
    -   `doc/err_log.md`는 절대 삭제하지 않는다.
    -   기존 기록은 수정하지 않고, 새로운 에러 수정 내역만 하단에 추가한다.
    -   코드 변경 전에 반드시 `doc/err_log.md`를 최신 상태로 업데이트한다.

## Git Commit & Push Rules (커밋 및 푸시 규칙)

### 커밋 메시지

-   **언어**: 제목/본문은 한국어, 코드·에러 문구는 영어 그대로

-   **타입**: `feat` / `fix` / `docs` / `refactor` / `test` / `build` / `ci` / `chore`

-   **제목**: ≤50자, 마침표 금지, `타입: 설명` 형식

### 본문

-   **3줄 구조**: What / Why / Impact

-   **버그 수정**: Root-cause / Repro 간단 추가

-   **호환성 깨짐**: `BREAKING CHANGE: ...`

### 푸시

-   **확인 후 푸시**: `git diff`, `git status` 확인 → `git push origin main`

-   **강제 푸시**: 승인 시 `git push --force-with-lease`

## Overview

MCP (Model Context Protocol) installer and configuration project - **VSCode 또는 Cursor IDE에서 Claude Code CLI를 사용할 때** MCP 서버를 쉽게 등록하고 관리할 수 있도록 돕는 프로젝트

## Project Structure

-   **메인 도구**
    -   `mcp-installer.py` - MCP 서버 설치 및 관리 도구 (보안 검증, 백업, 잠금 기능)
    -   `mcp-status.py` - MCP 서버 현황 파악 도구 (상세 보고서, 빠른 추가)
    -   `whitelist-example.json` - 커스텀 화이트리스트 파일 템플릿
-   `/doc` - MCP 설정 및 구성에 대한 문서 파일
    -   `prd.md` - MCP 설치 및 설정 가이드 (프로젝트 요구사항 정의서)
    -   `err.md` - 오류 수정 및 개선 기록
    -   `env-pc.md` - 현재 사용 환경 정보
    -   `ide-addon.md` - IDE 애드온 설정 정보
    -   `mcp-setting.md` - MCP 서버 설정 정보
    -   `manual.md` - 간단한 사용 설명서

## Key Information

### 🎯 중대한 목표 (Critical Goal)
-   **VSCode/Cursor IDE에서 Claude Code CLI MCP 관리 자동화**
-   **Claude Code CLI MCP 설정 파일 경로 표준화**:
    -   Windows: `C:\Users\{사용자명}\.claude.json` (단일 파일)
    -   macOS/Linux: `~/.claude.json` (단일 파일)
-   **user 스코프로 한 번 등록하면 모든 프로젝트에 적용**

### 프로젝트 목적
-   VSCode/Cursor IDE에서 Claude Code CLI 사용 시 MCP 서버 등록 및 관리 자동화
-   Windows, Linux, macOS 환경 지원
-   mcp-installer를 통한 자동화된 설치 프로세스 제공

### 주요 기능
-   MCP 서버 자동 설치 및 관리
-   환경별 맞춤 설정 지원 (Windows/macOS/Linux 자동 감지)
-   설치 후 작동 검증 자동화
-   **보안 기능**:
    -   명령어 화이트리스트 검증
    -   npx 패키지 화이트리스트
    -   위험한 인자 패턴 차단 (43개 패턴)
    -   JSON 스키마 검증
    -   화이트리스트 확장 메커니즘 (--extend-package, --whitelist-file)
-   **데이터 무결성**:
    -   원자적 파일 쓰기 (tempfile.mkstemp)
    -   자동 백업 생성 (타임스탬프 포함)
    -   백업 자동 정리 (최대 10개, 30일 이상 삭제)
    -   실패 시 자동 복구
-   **동시성 제어**:
    -   파일 잠금 메커니즘 (.claude.lock)
    -   프로세스 간 동기화
    -   오래된 잠금 자동 정리 (30초)
-   **중복 검증**:
    -   명령어 시그니처 기반 중복 감지
    -   사용자 확인 프롬프트

## Development Guidelines

### MCP 설치 프로세스
1. **환경 확인**: OS 및 실행 환경 파악 (Windows/Linux/macOS, WSL/PowerShell/명령 프롬프트)
2. **사전 검증**: WebSearch로 공식 사이트 확인, context7 MCP로 추가 검증
3. **설치 실행**: mcp-installer 사용하여 user 스코프로 설치
4. **설정 적용**: 올바른 위치의 JSON 파일에 MCP 설정
5. **작동 검증**: 디버그 모드로 실제 작동 확인

### 설정 파일 위치 (Claude Code CLI 표준 경로)
-   **Windows**: `C:\Users\{사용자명}\.claude.json` ⭐ **중요**
-   **Linux/macOS**: `~/.claude.json`
-   **백업 디렉토리**: `~/.claude-backups/`

### Windows 경로 처리
-   JSON 내 백슬래시는 이스케이프 처리 필수 (`\\`)
-   Node.js v18 이상 필수
-   npx 사용 시 `-y` 옵션 권장

## Important Commands

### 🐍 Python 도구 사용법

#### mcp-installer.py - MCP 서버 관리 도구
```bash
# mcp-installer 추가
python mcp-installer.py --add-installer

# 설정 파일에서 MCP 서버 추가
python mcp-installer.py -c sample-mcp.json

# 등록된 서버 목록 보기
python mcp-installer.py --list

# 특정 서버 제거
python mcp-installer.py --remove shrimp

# Claude CLI 작동 확인
python mcp-installer.py --verify

# DryRun 모드 (실제 변경 없이 미리보기)
python mcp-installer.py -c sample-mcp.json --dry-run

# 커스텀 패키지 화이트리스트에 추가
python mcp-installer.py --extend-package "@mycompany/mcp-server"

# 외부 화이트리스트 파일 로드
python mcp-installer.py --whitelist-file whitelist-example.json
```

#### mcp-status.py - MCP 현황 파악 도구
```bash
# 상세한 MCP 현황 보고서 보기
python mcp-status.py

# mcp-installer만 빠르게 추가
python mcp-status.py --add
```

### 📋 Python 버전 주요 파라미터

#### mcp-installer.py
- `-c, --config`: 병합할 MCP 서버 설정 JSON 파일
- `--add-installer`: mcp-installer 추가
- `--list`: 등록된 MCP 서버 목록 보기
- `--remove`: 특정 MCP 서버 제거
- `--verify`: Claude CLI 작동 확인
- `--dry-run`: 실제 변경 없이 미리보기
- `--force`: 백업 실패 시에도 계속 진행
- `--extend-package`: 특정 패키지를 화이트리스트에 추가
- `--extend-command`: 특정 명령어를 화이트리스트에 추가
- `--whitelist-file`: 외부 화이트리스트 JSON 파일 로드

#### mcp-status.py
- `--add`: mcp-installer만 빠르게 추가 (기본은 현황 표시)

### MCP 관리 명령어
```bash
# MCP 설치
claude mcp add --scope user [mcp-name] [options]

# 설치 목록 확인
claude mcp list

# MCP 제거
claude mcp remove [mcp-name]

# 디버그 모드 실행
claude --debug

# MCP 작동 확인
echo "/mcp" | claude --debug
```

### 설치 검증 프로세스
1. `claude mcp list`로 설치 확인
2. `claude --debug`로 디버그 모드 실행 (최대 2분 관찰)
3. `/mcp` 명령으로 실제 작동 확인

## Notes

### 주의사항
-   API KEY가 필요한 MCP는 가상 키로 먼저 설치 후 실제 키 입력 안내
-   특정 서버 의존 MCP (예: MySQL)는 서버 구동 조건 안내
-   이미 설치된 MCP의 에러는 무시하고 요청받은 것만 처리
-   설치 실패 시 공식 사이트의 권장 방법으로 재시도

### 문제 해결
-   npm/npx 패키지 못 찾을 때: `npm config get prefix` 확인
-   uvx 명령어 없을 때: uv 설치 필요
-   터미널 작동 성공 시: 해당 인자와 환경변수로 JSON 직접 설정
-   백업 복원: `.claude/backups/` 디렉토리에서 이전 설정 확인 가능
-   충돌 해결: 개별 선택(i), 모두 덮어쓰기(a), 모두 건너뛰기(s) 옵션 제공

## Security Features

### 보안 검증 체계
1. **명령어 화이트리스트**: npx, node, python, cmd, powershell 등 안전한 명령어만 허용
2. **패키지 화이트리스트**: 10개 이상의 검증된 MCP 패키지 사전 등록
3. **위험 패턴 차단**: 43개의 위험한 패턴 감지 및 차단
4. **경로 보호**: 절대 경로 실행 차단, 상위 디렉토리 접근 차단
5. **화이트리스트 확장**: --extend-package, --whitelist-file로 안전하게 확장 가능

### 백업 및 복원
- **자동 백업**: 모든 변경 전 `~/.claude-backups/` 에 타임스탬프 백업 생성
- **백업 관리**: 최대 10개 유지, 30일 이상 자동 삭제
- **원자적 쓰기**: 임시 파일 → JSON 검증 → 원자적 교체로 데이터 무결성 보장
- **실패 시 자동 복구**: 저장 실패 시 최신 백업에서 자동 복원

### 동시성 제어
- **파일 잠금**: `.claude.lock` 파일로 프로세스 간 동기화
- **오래된 잠금 정리**: 30초 이상된 잠금 자동 제거
- **안전한 해제**: try-finally로 잠금 해제 보장
