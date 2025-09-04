#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=====================================================================
파일명: mcp-status.py
기능 요약: Claude Code CLI MCP 서버 현황 파악 및 상태 보고서 도구
          상세한 MCP 서버 현황을 테이블 형식으로 표시

File History:
  2025.09.04 PM11:10 초기 버전 생성 - add_mcp_installer.py로 시작
  2025.09.04 PM11:25 MCP 현황 상세 파악 기능 추가
  2025.09.04 PM11:45 파일명을 mcp-status.py로 변경 (목적 명확화)
  2025.09.04 PM03:45 크로스 플랫폼 지원 - 하드코딩된 경로 제거
  2025.09.04 PM06:00 원자적 파일 쓰기 및 예외 처리 강화
  2025.09.04 PM06:30 백업 관리 및 JSON 검증 로직 추가
  2025.09.04 PM11:50 온라인 MCP 정보 검색 및 상세 정보 표시 기능 추가
=====================================================================
"""

import json
import sys
import shutil
import os
import tempfile
import urllib.request
import urllib.parse
import ssl
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Any

# MCP 정보 캐시 (성능 최적화)
MCP_INFO_CACHE = {}
CACHE_EXPIRY = 3600  # 1시간 캐시

def get_mcp_online_info(mcp_name: str, package_name: Optional[str] = None) -> Dict[str, Any]:
    """MCP 온라인 정보 검색 (GitHub, NPM 등에서)"""
    global MCP_INFO_CACHE
    
    # package_name이 리스트인 경우 처리
    if isinstance(package_name, list):
        package_name = package_name[0] if package_name else None
    
    # 캐시 확인
    cache_key = f"{mcp_name}:{package_name or ''}"
    if cache_key in MCP_INFO_CACHE:
        cached_time, cached_info = MCP_INFO_CACHE[cache_key]
        if time.time() - cached_time < CACHE_EXPIRY:
            return cached_info
    
    info = {
        'description': None,
        'repository': None,
        'version': None,
        'features': [],
        'scope': None,
        'health_check': None,
        'runtime': None
    }
    
    try:
        # NPM 패키지 검색 시도
        if package_name and isinstance(package_name, str) and package_name.startswith('@'):
            # SSL 컨텍스트 생성 (Windows 환경 지원)
            ssl_context = ssl.create_default_context()
            ssl_context.check_hostname = False
            ssl_context.verify_mode = ssl.CERT_NONE
            
            # NPM API 호출
            try:
                npm_url = f"https://registry.npmjs.org/{urllib.parse.quote(package_name, safe='@/')}"
            except Exception:
                npm_url = None
            
            if npm_url:
                try:
                    req = urllib.request.Request(
                        npm_url,
                        headers={'User-Agent': 'mcp-status/1.0'}
                    )
                    with urllib.request.urlopen(req, context=ssl_context, timeout=3) as response:
                        npm_data = json.loads(response.read().decode('utf-8'))
                        
                        # 정보 추출
                        if 'description' in npm_data:
                            info['description'] = npm_data['description']
                        
                        if 'repository' in npm_data and isinstance(npm_data['repository'], dict):
                            info['repository'] = npm_data['repository'].get('url', '')
                            # git+ 제거 및 .git 제거
                            if info['repository']:
                                info['repository'] = info['repository'].replace('git+', '').replace('.git', '')
                        
                        if 'dist-tags' in npm_data:
                            info['version'] = npm_data['dist-tags'].get('latest')
                        
                        # keywords에서 MCP 관련 정보 추출
                        if 'keywords' in npm_data:
                            keywords = npm_data.get('keywords', [])
                            if 'mcp' in keywords:
                                info['features'] = [k for k in keywords if k != 'mcp' and not k.startswith('mcp-')]
                except Exception:
                    pass  # 온라인 정보 실패는 무시
        
        # 알려진 MCP 정보 (하드코딩된 정보)
        known_mcps = {
            'shrimp': {
                'description': '자연어 요청을 구조화된 개발 작업으로 변환, 작업 분해·추적 지원',
                'features': ['체인 오브 소트(chain-of-thought) 기반 계획', '수행 및 반영(reflection) 흐름 제공'],
                'runtime': 'Node.js 18+ (npm 기반)',
                'scope': 'user',
                'health_check': 'GET /health'
            },
            'filesystem': {
                'description': '파일 시스템 접근 및 조작 기능 제공',
                'features': ['파일 읽기/쓰기', '디렉토리 탐색', '파일 검색'],
                'runtime': 'Node.js',
                'scope': 'user'
            },
            'mcp-installer': {
                'description': 'MCP 서버 관리 도구 (설치/제거/업데이트)',
                'features': ['MCP 서버 자동 설치', '의존성 관리', '설정 자동화'],
                'runtime': 'Node.js (npx)',
                'scope': 'user'
            }
        }
        
        # 알려진 정보로 보완
        if mcp_name in known_mcps:
            for key, value in known_mcps[mcp_name].items():
                if not info[key]:
                    info[key] = value
        
    except Exception:
        pass  # 온라인 검색 실패는 무시
    
    # 캐시 저장
    MCP_INFO_CACHE[cache_key] = (time.time(), info)
    return info

def generate_markdown_report(data):
    """MCP 현황을 Markdown 형식으로 생성"""
    lines = []
    lines.append("# Claude Code CLI MCP 서버 현황 보고서")
    lines.append(f"\n> 생성 시각: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"> 시스템: {sys.platform}")
    lines.append("")
    
    # 전역 mcpServers
    global_servers = data.get('mcpServers', {})
    
    if global_servers:
        lines.append("## 전역 MCP 서버 목록")
        lines.append("\n모든 프로젝트에서 사용 가능한 MCP 서버들입니다.\n")
        
        # 요약 테이블
        active_count = sum(1 for config in global_servers.values() if config.get('command'))
        lines.append("### 📊 요약")
        lines.append(f"- **총 MCP 서버**: {len(global_servers)}개")
        lines.append(f"- **활성화**: {active_count}개")
        lines.append(f"- **비활성화**: {len(global_servers) - active_count}개")
        lines.append("")
        
        # 각 MCP 상세 정보
        lines.append("### 상세 정보\n")
        
        for idx, (name, config) in enumerate(global_servers.items(), 1):
            # 상태 확인
            status = "✅ 활성화" if config.get('command') else "❌ 비활성화"
            command = config.get('command', 'N/A')
            
            # args에서 패키지명 추출
            package = None
            if config.get('args'):
                args_list = config['args']
                for i, arg in enumerate(args_list):
                    if arg.startswith('@') or (i > 0 and args_list[i-1] in ['-y', 'npx']):
                        if arg not in ['-y', 'npx', '/c']:
                            package = arg
                            break
            
            # 온라인 정보 가져오기
            online_info = get_mcp_online_info(name, package)
            
            lines.append(f"#### {idx}. {name.upper()}")
            lines.append("")
            lines.append(f"**상태**: {status}\n")
            lines.append(f"**ID**: `{name}`\n")
            
            if online_info['description']:
                lines.append(f"**설명**: {online_info['description']}\n")
            
            if command:
                runtime_info = online_info['runtime'] or f"{command}"
                if package:
                    runtime_info += f" ({package})"
                lines.append(f"**실행방식**: `{runtime_info}`\n")
            
            if online_info['features']:
                lines.append("**주요 기능**:")
                for feature in online_info['features'][:5]:  # 최대 5개
                    lines.append(f"- {feature}")
                lines.append("")
            
            if online_info['repository']:
                lines.append(f"**저장소**: [{online_info['repository']}]({online_info['repository']})\n")
            
            if online_info['version']:
                lines.append(f"**버전**: `{online_info['version']}`\n")
            
            if online_info['scope']:
                lines.append(f"**스코프**: `{online_info['scope']}`\n")
            
            if online_info['health_check']:
                lines.append(f"**상태체크**: `{online_info['health_check']}`\n")
            
            if config.get('env'):
                lines.append(f"**환경변수**: {len(config['env'])}개 설정됨\n")
                lines.append("<details>")
                lines.append("<summary>환경변수 목록</summary>")
                lines.append("")
                for key in sorted(config['env'].keys()):
                    value = config['env'][key]
                    # API 키 마스킹
                    if 'KEY' in key.upper() or 'TOKEN' in key.upper() or 'SECRET' in key.upper() or 'PASSWORD' in key.upper():
                        if value and len(str(value)) > 4:
                            value = str(value)[:4] + '*' * (len(str(value)) - 4)
                    lines.append(f"- `{key}`: {value}")
                lines.append("</details>")
            
            lines.append("\n---\n")
    else:
        lines.append("## 전역 MCP 서버")
        lines.append("\n설치된 전역 MCP 서버가 없습니다.\n")
    
    # 프로젝트별 MCP
    projects = data.get('projects', {})
    project_with_mcp = []
    
    for proj_path, proj_config in projects.items():
        if proj_config.get('mcpServers') and proj_config['mcpServers']:
            project_with_mcp.append((proj_path, proj_config['mcpServers']))
    
    if project_with_mcp:
        lines.append("## 프로젝트별 MCP 서버\n")
        for proj_path, servers in project_with_mcp:
            lines.append(f"### 프로젝트: `{proj_path}`\n")
            for name, config in servers.items():
                lines.append(f"- **{name}**: {config.get('command', 'N/A')}")
            lines.append("")
    
    # 시스템 상태
    lines.append("## 시스템 상태 및 권장사항\n")
    
    essential_mcps = {
        'mcp-installer': 'MCP 서버 관리 도구',
        'filesystem': '파일 시스템 접근',
        'shrimp': 'Task 관리 도구'
    }
    
    lines.append("### 필수 MCP 체크리스트\n")
    for mcp_name, description in essential_mcps.items():
        if mcp_name in global_servers:
            config = global_servers[mcp_name]
            if config.get('command'):
                lines.append(f"- [x] **{mcp_name}** - {description} (활성화)")
            else:
                lines.append(f"- [ ] **{mcp_name}** - {description} (비활성화 - 설정 확인 필요)")
        else:
            lines.append(f"- [ ] **{mcp_name}** - {description} (미설치)")
    
    lines.append("")
    lines.append("### 통계 정보\n")
    lines.append(f"- 전역 MCP 서버 수: {len(global_servers)}개")
    lines.append(f"- 프로젝트별 MCP 설정 수: {len(project_with_mcp)}개")
    lines.append(f"- 총 프로젝트 수: {len(projects)}개")
    
    lines.append("\n---")
    lines.append(f"\n*Generated by mcp-status.py at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*")
    
    return "\n".join(lines)

def print_mcp_status(data):
    """MCP 서버 현황 상세 출력"""
    # Windows 콘솔 인코딩 설정
    if sys.platform == 'win32':
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32
            kernel32.SetConsoleCP(65001)
            kernel32.SetConsoleOutputCP(65001)
        except:
            pass
    
    print("\n" + "="*70)
    print(" " * 15 + "Claude Code CLI MCP 서버 현황 보고서")
    print("="*70)
    
    # 전역 mcpServers
    global_servers = data.get('mcpServers', {})
    
    if global_servers:
        print("\n[전역 MCP 서버 목록] - 모든 프로젝트에서 사용 가능")
        print("=" * 80)
        
        for idx, (name, config) in enumerate(global_servers.items(), 1):
            # 상태 확인 (이모지 대신 텍스트 사용)
            status = "[활성화]" if config.get('command') else "[비활성화]"
            command = config.get('command', 'N/A')
            
            # args에서 패키지명 추출
            package = None
            if config.get('args'):
                args_list = config['args']
                # npx 패키지명 찾기
                for i, arg in enumerate(args_list):
                    if isinstance(arg, str) and (arg.startswith('@') or (i > 0 and args_list[i-1] in ['-y', 'npx'])):
                        if arg not in ['-y', 'npx', '/c']:
                            package = arg
                            break
            
            # 온라인 정보 가져오기
            online_info = get_mcp_online_info(name, package)
            
            # MCP 정보 출력 (개선된 포맷)
            print(f"\n{idx}. {name.upper()}")
            print("-" * 80)
            print(f"  상태: {status}")
            print(f"  ID: {name}")
            
            if online_info['description']:
                print(f"  설명: {online_info['description']}")
            
            if command:
                runtime_info = online_info['runtime'] or f"{command}"
                if package:
                    runtime_info += f" ({package})"
                print(f"  실행방식: {runtime_info}")
            
            if online_info['features']:
                print(f"  주요 기능:")
                for feature in online_info['features'][:3]:  # 최대 3개만 표시
                    print(f"    - {feature}")
            
            if online_info['repository']:
                print(f"  저장소: {online_info['repository']}")
            
            if online_info['version']:
                print(f"  버전: {online_info['version']}")
            
            if online_info['scope']:
                print(f"  스코프: {online_info['scope']}")
            
            if online_info['health_check']:
                print(f"  상태체크: {online_info['health_check']}")
            
            # 설정 정보
            if config.get('env'):
                print(f"  환경변수: {len(config['env'])}개 설정됨")
        
        print("\n" + "=" * 80)
        
        # 요약 정보
        active_count = sum(1 for config in global_servers.values() if config.get('command'))
        print(f"\n요약: 총 {len(global_servers)}개 MCP 서버 (활성화: {active_count}개, 비활성화: {len(global_servers) - active_count}개)")
    else:
        print("\n[전역 MCP 서버] 없음")
    
    # 프로젝트별 mcpServers 확인
    projects = data.get('projects', {})
    project_with_mcp = []
    
    for proj_path, proj_config in projects.items():
        if proj_config.get('mcpServers') and proj_config['mcpServers']:
            project_with_mcp.append((proj_path, proj_config['mcpServers']))
    
    if project_with_mcp:
        print("\n[프로젝트별 MCP 서버]")
        print("-" * 40)
        for proj_path, servers in project_with_mcp:
            print(f"\n  [프로젝트: {proj_path}]")
            for name, config in servers.items():
                print(f"     - {name}: {config.get('command', 'N/A')}")
    
    # 통계 정보
    print("\n[통계 정보]")
    print("-" * 70)
    print(f"  전역 MCP 서버 수: {len(global_servers)}개")
    print(f"  프로젝트별 MCP 설정 수: {len(project_with_mcp)}개")
    print(f"  총 프로젝트 수: {len(projects)}개")
    
    # 권장사항 및 상태 체크
    print("\n[시스템 상태 및 권장사항]")
    print("-" * 70)
    
    # 필수 MCP 체크
    essential_mcps = {
        'mcp-installer': 'MCP 서버 관리 도구',
        'filesystem': '파일 시스템 접근',
        'shrimp': 'Task 관리 도구'
    }
    
    print("\n필수 MCP 상태:")
    for mcp_name, description in essential_mcps.items():
        if mcp_name in global_servers:
            config = global_servers[mcp_name]
            if config.get('command'):
                print(f"  [O] {mcp_name:<15} - {description} (활성화)")
            else:
                print(f"  [!] {mcp_name:<15} - {description} (비활성화 - 설정 확인 필요)")
        else:
            print(f"  [X] {mcp_name:<15} - {description} (미설치)")
    
    # 온라인 정보 수집 상태
    print("\n온라인 정보 수집:")
    if MCP_INFO_CACHE:
        print(f"  - 캐시된 정보: {len(MCP_INFO_CACHE)}개")
        print(f"  - 캐시 유효시간: {CACHE_EXPIRY//60}분")
    else:
        print("  - 온라인 정보 수집 대기 중")
    
    print("\n" + "="*70)

def create_backup(file_path):
    """안전한 백업 파일 생성 (예외 처리 포함)"""
    if not file_path.exists():
        return None
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = file_path.parent / ".claude-backups"
    backup_path = backup_dir / f"claude_{timestamp}.json"
    
    try:
        # 백업 디렉토리 생성
        if not backup_dir.exists():
            backup_dir.mkdir(parents=True, exist_ok=True)
        
        # 디스크 공간 체크 (최소 1MB)
        stat = shutil.disk_usage(backup_dir)
        if stat.free < 1024 * 1024:
            print("[WARN] 디스크 공간 부족 - 백업을 건너뜁니다")
            return None
        
        # 백업 파일 생성
        shutil.copy2(file_path, backup_path)
        
        # 백업 파일 검증
        if backup_path.exists() and backup_path.stat().st_size > 0:
            print(f"[INFO] 백업 생성 완료: {backup_path.name}")
            return backup_path
        else:
            print("[WARN] 백업 파일 생성 실패")
            if backup_path.exists():
                backup_path.unlink()
            return None
            
    except PermissionError as e:
        print(f"[WARN] 백업 생성 권한 부족: {e}")
        return None
    except Exception as e:
        print(f"[WARN] 백업 생성 실패: {e}")
        return None

def atomic_save(file_path, data):
    """원자적 파일 저장 (임시 파일 사용)"""
    temp_fd = None
    temp_path = None
    
    try:
        # 1단계: 임시 파일에 쓰기
        temp_fd, temp_path = tempfile.mkstemp(
            dir=file_path.parent,
            prefix='.claude_tmp_',
            suffix='.json',
            text=True
        )
        
        # JSON 데이터를 문자열로 변환
        json_str = json.dumps(data, indent=2, ensure_ascii=False)
        
        # 임시 파일에 쓰기
        with os.fdopen(temp_fd, 'w', encoding='utf-8') as f:
            f.write(json_str)
            f.flush()
            os.fsync(f.fileno())  # 디스크에 강제 쓰기
        temp_fd = None  # fdopen이 닫았으므로 None으로 설정
        
        # 2단계: 임시 파일 검증
        temp_path_obj = Path(temp_path)
        if not temp_path_obj.exists() or temp_path_obj.stat().st_size == 0:
            raise IOError("임시 파일 생성 실패 또는 크기가 0")
        
        # JSON 유효성 검증
        with open(temp_path, 'r', encoding='utf-8') as f:
            test_data = json.load(f)
            if 'mcpServers' not in test_data:
                raise ValueError("mcpServers 필드가 없습니다")
        
        # 3단계: 원자적 교체
        if sys.platform == 'win32':
            # Windows: 기존 파일 제거 후 이동
            if file_path.exists():
                file_path.unlink()
            temp_path_obj.rename(file_path)
        else:
            # Unix: 원자적 이동
            temp_path_obj.replace(file_path)
        
        print(f"[SUCCESS] 설정 저장 완료: {file_path}")
        return True
        
    except PermissionError as e:
        print(f"[ERROR] 파일 쓰기 권한 부족: {e}")
        return False
    except json.JSONDecodeError as e:
        print(f"[ERROR] JSON 검증 실패: {e}")
        return False
    except Exception as e:
        print(f"[ERROR] 파일 저장 오류: {e}")
        return False
    finally:
        # 임시 파일 정리
        if temp_fd is not None:
            try:
                os.close(temp_fd)
            except OSError:
                pass
        if temp_path and Path(temp_path).exists():
            try:
                Path(temp_path).unlink()
            except (OSError, PermissionError):
                pass

def main():
    # Windows 콘솔 인코딩 설정 (메인 함수 시작 시)
    if sys.platform == 'win32':
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32
            kernel32.SetConsoleCP(65001)
            kernel32.SetConsoleOutputCP(65001)
        except:
            pass
    
    # 파일 경로 (크로스 플럏폼 지원)
    claude_json_path = Path.home() / ".claude.json"
    
    print("[INFO] Claude Code CLI 설정 파일 분석 중...")
    print("[INFO] 온라인 MCP 정보 검색 중...")
    
    try:
        # JSON 파일 읽기
        with open(claude_json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # MCP 현황 상세 출력
        print_mcp_status(data)
        
        # --report 옵션 처리
        if '--report' in sys.argv:
            try:
                # Markdown 보고서 생성
                report_content = generate_markdown_report(data)
                
                # doc 폴더 생성 (없으면)
                doc_dir = Path.cwd() / 'doc'
                doc_dir.mkdir(exist_ok=True, parents=True)
                
                # 보고서 파일 저장
                report_path = doc_dir / 'mcp-report.md'
                with open(report_path, 'w', encoding='utf-8') as f:
                    f.write(report_content)
                
                print(f"\n[SUCCESS] 보고서 생성 완료: {report_path}")
                print("[INFO] doc/mcp-report.md 파일이 업데이트되었습니다.")
            except Exception as e:
                print(f"[ERROR] 보고서 생성 실패: {e}")
                return 1
        
        # 사용자 입력 처리
        if len(sys.argv) > 1 and sys.argv[1] == '--add':
            # mcpServers가 없으면 생성
            if 'mcpServers' not in data:
                data['mcpServers'] = {}
            
            # mcp-installer가 이미 있는지 확인
            if 'mcp-installer' in data['mcpServers']:
                print("\n[INFO] mcp-installer가 이미 존재합니다.")
            else:
                # mcp-installer 추가 (OS별 분기)
                if sys.platform == 'win32':
                    data['mcpServers']['mcp-installer'] = {
                        "type": "stdio",
                        "command": "cmd.exe",
                        "args": ["/c", "npx", "-y", "@anaisbetts/mcp-installer"]
                    }
                elif sys.platform == 'darwin':
                    # macOS
                    data['mcpServers']['mcp-installer'] = {
                        "type": "stdio",
                        "command": "npx",
                        "args": ["-y", "@anaisbetts/mcp-installer"]
                    }
                else:
                    # Linux 및 기타 Unix
                    data['mcpServers']['mcp-installer'] = {
                        "type": "stdio",
                        "command": "npx",
                        "args": ["-y", "@anaisbetts/mcp-installer"]
                    }
                
                # 백업 생성 (실패해도 계속 진행 가능)
                backup_path = create_backup(claude_json_path)
                if not backup_path:
                    print("[WARN] 백업 생성 실패 - 계속 진행합니다")
                
                # 원자적 저장
                if atomic_save(claude_json_path, data):
                    print("\n[SUCCESS] mcp-installer가 추가되었습니다!")
                    if backup_path:
                        print(f"[INFO] 백업 파일: {backup_path.name}")
                    print("[INFO] Claude Code를 재시작하면 변경사항이 적용됩니다.")
                    print("\n[TIP] 더 많은 MCP 서버를 추가하려면: python mcp-installer.py -c config.json")
                    print("[TIP] 보고서 생성: python mcp-status.py --report")
                else:
                    print("\n[ERROR] 설정 저장 실패")
                    # 백업에서 복구 시도
                    if backup_path and backup_path.exists():
                        try:
                            shutil.copy2(backup_path, claude_json_path)
                            print("[INFO] 백업에서 복구 완료")
                        except Exception as e:
                            print(f"[ERROR] 백업 복구 실패: {e}")
                    return 1
        
    except FileNotFoundError:
        print(f"[ERROR] Claude 설정 파일을 찾을 수 없습니다: {claude_json_path}")
        print("[INFO] Claude Code CLI가 설치되어 있는지 확인하세요")
        return 1
    except json.JSONDecodeError as e:
        print(f"[ERROR] JSON 파싱 오류: {e}")
        print("[INFO] 설정 파일이 손상되었을 수 있습니다")
        return 1
    except Exception as e:
        print(f"[ERROR] 오류 발생: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())