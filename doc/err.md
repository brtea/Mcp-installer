# 오류 수정 및 개선 기록

## 종료 코드 처리 개선 (2025.09.04 PM04:19)

### 문제
- 오류 발생 시에도 성공(0)으로 종료되어 CI/CD 파이프라인에서 실패 감지 불가
- 특히 `--remove`로 존재하지 않는 서버 제거 시 에러 메시지만 출력하고 0 반환

### 원인
- 각 작업의 성공/실패를 추적하지 않고 항상 `return 0`
- `remove_server`가 False 반환해도 종료 코드에 반영 안됨

### 해결
- **has_error 플래그 도입**: 각 작업의 실패 추적
- **조건별 처리**:
  - `--remove` 실패: `has_error = True`
  - `--config` 일부 실패: `has_error = True`
  - `--verify` 실패: `has_error = True`
  - 설정 저장 실패: `has_error = True`
- **최종 반환**: `return 1 if has_error else 0`
- **테스트 결과**: 5개 시나리오 모두 올바른 종료 코드 반환

## 데이터 무결성 및 백업 관리 개선 (2025.09.04 PM04:12)

### 문제
1. **불필요한 백업 생성**: --list 등 조회 명령에서도 백업 생성
2. **무제한 백업 누적**: 백업 파일이 무한정 쌓여 디스크 공간 낭비
3. **원자적 쓰기 검증 필요**: 이미 구현되었으나 재검증 필요

### 원인
- 백업 로직이 명령 종류와 관계없이 실행
- 백업 파일 관리 정책 부재
- 원자적 쓰기는 이미 구현됨 (tempfile.mkstemp 사용)

### 해결
- **조건부 백업 생성**:
  - 실제 변경 명령만 백업 생성 (--add-installer, --config, --remove)
  - --list, --verify 등 조회 명령은 백업 제외
- **백업 관리 정책 (_cleanup_old_backups)**:
  - 최대 10개 백업 파일 유지
  - 30일 이상된 백업 자동 삭제
  - 백업 생성 시마다 자동 정리
- **원자적 쓰기 확인**:
  - tempfile.mkstemp()로 임시 파일 생성
  - JSON 검증 후 원본 교체
  - Windows: unlink() → rename()
  - Unix: replace() 사용

## 크로스 플랫폼 호환성 수정 (2025.09.04 PM03:45)

### 문제
1. **플랫폼 종속적 명령**: `cmd.exe`를 하드코딩하여 Mac/Linux에서 작동 불가
2. **하드코딩된 경로**: `C:\Users\brian_qs0\.claude.json` 특정 사용자 환경 종속

### 원인
- OS별 분기 처리 누락
- 개발 환경 경로를 그대로 커밋

### 해결
- **mcp-installer.py 개선**:
  - `sys.platform` 기반 OS 감지
  - Windows: `cmd.exe /c npx`
  - Mac/Linux: 직접 `npx` 실행
  - 플랫폼 정보를 성공 메시지에 표시
- **mcp-status.py 개선**:
  - `Path(r"C:\Users\brian_qs0\.claude.json")` → `Path.home() / ".claude.json"`
  - OS별 mcp-installer 설정 분기 추가

## 백업 예외 처리 및 원자적 쓰기 구현 (2025.09.04 PM03:30)

### 문제
- `create_backup()`에서 예외 처리 없이 `shutil.copy2` 호출로 디스크 부족/권한 오류 시 스크립트 중단
- `save_config()`에서 파일 쓰기 중 실패 시 데이터 손실 위험
- 백업 실패 시 복구 로직 부재

### 원인
- 파일 I/O 작업에 대한 예외 처리 누락
- 비원자적 쓰기로 중간 실패 시 파일 손상 가능
- 백업 실패 시 대응 방안 없음

### 해결
- **create_backup() 개선**:
  - try-except로 모든 예외 처리
  - 디스크 공간 체크 (최소 10MB)
  - 백업 파일 크기 검증
  - 권한/OS 오류별 세분화된 예외 처리
- **save_config() 원자적 쓰기**:
  - tempfile.mkstemp()로 임시 파일 생성
  - JSON 유효성 검증 후 원본 교체
  - os.fsync()로 디스크 강제 쓰기
  - 실패 시 백업에서 자동 복구 시도
- **추가 안전장치**:
  - --force 옵션: 백업 실패 시에도 진행
  - _attempt_recovery(): 최신 백업에서 자동 복구
  - 임시 파일 자동 정리 (finally 블록)

## 외부 설정 검증 보안 취약점 수정 (2025.09.04 PM03:20)

### 문제
- `mcp-installer.py`에서 외부 JSON 설정을 검증 없이 그대로 병합하여 악성 명령어가 실행될 위험 존재
- PowerShell 버전의 `Test-SafeCommand` 등 보안 검증이 Python 재작성 시 누락됨

### 원인  
- Python 재작성 과정에서 명령어 화이트리스트 및 위험 패턴 차단 로직이 구현되지 않음
- JSON 스키마 검증 부재로 잘못된 형식의 설정도 그대로 수용

### 해결
- **SecurityValidator 클래스 추가**: 모든 MCP 서버 설정에 대한 보안 검증
  - 명령어 화이트리스트: npx, node, python, uvx 등 안전한 명령어만 허용
  - npx 패키지 화이트리스트: 검증된 MCP 패키지만 설치 가능
  - 위험 패턴 차단: `rm -rf`, `&&`, `eval`, `exec` 등 위험한 패턴 탐지
  - 환경 변수 검증: PATH 조작 방지 및 특수문자 검사
- **--trust 옵션 추가**: 신뢰할 수 있는 소스에 한해 검증 건너뛰기 (경고 메시지 표시)
- **JSON 타입 검증**: mcpServers가 dict 타입인지 확인

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

## --trust 옵션 제거 및 화이트리스트 확장 메커니즘 추가 (2025.09.04 PM05:45)

### 문제
- `--trust` 옵션 사용 시 모든 보안 검증을 우회하여 악성 명령 실행 가능
- 외부 JSON 설정을 무검증 병합해 시스템 공격 위험 존재

### 원인
- 사용 편의를 위해 보안 검증 우회 기능 제공
- add_server()에서 trust_source=True일 때 SecurityValidator 완전 무시

### 해결
- **--trust 옵션 완전 제거**: 모든 서버 설정에 대해 예외 없이 보안 검증 강제
- **화이트리스트 확장 메커니즘 추가**:
  - `--extend-package`: 특정 패키지를 임시로 화이트리스트에 추가
  - `--extend-command`: 특정 명령어를 임시로 화이트리스트에 추가  
  - `--whitelist-file`: 외부 JSON 파일에서 커스텀 화이트리스트 로드
- **whitelist-example.json 제공**: 커스텀 화이트리스트 파일 템플릿

## mcp-status.py 원자적 파일 저장 구현 (2025.09.04 PM06:00)

### 문제
- 백업과 저장을 순차적으로 수행하여 중간 실패 시 파일 손상 위험
- shutil.copy2()와 json.dump()에 대한 예외 처리 부재
- JSON 검증 없이 직접 덮어쓰기로 데이터 무결성 보장 불가

### 원인
- 간단한 파일 교체 구현 시 원자적 쓰기 패턴 미적용
- 예외 처리 및 임시 파일 사용 누락

### 해결
- **create_backup() 함수 추가**: 예외 처리 포함한 안전한 백업 생성
  - 디스크 공간 체크 (최소 1MB)
  - 백업 파일 크기 검증
  - 실패 시 None 반환으로 계속 진행 가능
- **atomic_save() 함수 추가**: 원자적 파일 저장
  - tempfile.mkstemp()로 임시 파일 생성
  - JSON 유효성 검증 후 원자적 교체
  - 실패 시 백업에서 자동 복구
- **예외 처리 강화**: FileNotFoundError, JSONDecodeError 등 세분화

## 권장사항
- 스크립트 실행 전 코드 서명 확인
- RemoteSigned 이상의 실행 정책 설정
- 모든 설치/변경 작업을 Windows Event Log에 기록
- 필요시 --extend-package 또는 --whitelist-file로 안전하게 확장