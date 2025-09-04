# 오류 수정 및 개선 기록

## Process Leak 방지 수정 (2025.01)

### 문제
- `mcp-installer.ps1`의 `Verify-Run` 함수에서 `claude --debug` 프로세스가 종료되지 않고 남아있는 리소스 누수 문제 발생

### 원인
- 예외 발생 시 프로세스 정리 코드 미실행
- 조건부 `Stop-Process` 호출로 인한 불완전한 정리

### 해결
- Try-Finally 블록으로 예외 발생 시에도 프로세스 정리 보장
- 프로세스 ID 추적 및 3분 이내 생성된 고아 프로세스 자동 정리
- 명시적 종료 확인 및 로깅 추가

## 주요 개선 사항

### 보안 강화
- **npx 패키지 화이트리스트 확장**: 검증된 MCP 서버 패키지만 설치 허용
- **위험 패턴 추가 차단**: `Remove-Item -Recurse`, `Invoke-Expression`, `IEX` 등 Windows 특화 위험 명령어 차단
- **환경 변수 검증**: PATH 조작 방지 및 특수문자 검사

### 프로세스 관리
- **세션별 프로세스 종료**: 현재 세션의 claude 프로세스만 선택적 종료
```powershell
$currentSessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
Get-Process -Name "claude" | Where-Object { $_.SessionId -eq $currentSessionId } | Stop-Process
```

### 성능 최적화
- **병렬 처리**: 여러 MCP 서버 동시 검증 (ThrottleLimit 5)
- **캐싱**: Node/Claude 버전 정보 5분 캐싱
- **지연 로딩**: 백업 디렉토리 필요 시점에만 생성

### 백업 관리
- 최대 10개 백업 파일 유지
- 30일 이상된 백업 자동 삭제
- 백업 압축 옵션 추가 계획

### 사용성 개선
- 대화형 설치 모드 (`-Interactive`)
- 설정 템플릿 제공 (`-Template "development"`)
- 상태 대시보드 (`-Status`)

## 권장사항
- 스크립트 실행 전 코드 서명 확인
- RemoteSigned 이상의 실행 정책 설정
- 모든 설치/변경 작업을 Windows Event Log에 기록