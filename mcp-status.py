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
=====================================================================
"""

import json
import sys
import shutil
import os
import tempfile
from datetime import datetime
from pathlib import Path

def print_mcp_status(data):
    """MCP 서버 현황 상세 출력"""
    print("\n" + "="*70)
    print(" " * 15 + "Claude Code CLI MCP 서버 현황 보고서")
    print("="*70)
    
    # 전역 mcpServers
    global_servers = data.get('mcpServers', {})
    
    if global_servers:
        print("\n[전역 MCP 서버 목록] - 모든 프로젝트에서 사용 가능")
        print("-" * 70)
        
        # 테이블 헤더
        print(f"{'번호':<5} {'MCP 이름':<20} {'상태':<10} {'명령어':<15} {'패키지/경로':<25}")
        print("-" * 70)
        
        # 활성화 상태 체크 (command가 있으면 활성화로 간주)
        for idx, (name, config) in enumerate(global_servers.items(), 1):
            # 상태 확인
            status = "활성화" if config.get('command') else "비활성화"
            command = config.get('command', 'N/A')
            
            # args에서 패키지명 추출
            package = 'N/A'
            if config.get('args'):
                args_list = config['args']
                # npx 패키지명 찾기
                for i, arg in enumerate(args_list):
                    if arg.startswith('@') or (i > 0 and args_list[i-1] in ['-y', 'npx']):
                        if not arg in ['-y', 'npx', '/c']:
                            package = arg
                            break
            
            print(f"{idx:<5} {name:<20} {status:<10} {command:<15} {package:<25}")
        
        print("-" * 70)
        
        # 요약 정보
        active_count = sum(1 for config in global_servers.values() if config.get('command'))
        print(f"\n총 {len(global_servers)}개 MCP 서버 (활성화: {active_count}개, 비활성화: {len(global_servers) - active_count}개)")
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
    
    for mcp_name, description in essential_mcps.items():
        if mcp_name in global_servers:
            config = global_servers[mcp_name]
            if config.get('command'):
                print(f"  [O] {mcp_name:<15} - {description} (활성화)")
            else:
                print(f"  [!] {mcp_name:<15} - {description} (비활성화 - 설정 확인 필요)")
        else:
            print(f"  [X] {mcp_name:<15} - {description} (미설치)")
    
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
    # 파일 경로 (크로스 플랫폼 지원)
    claude_json_path = Path.home() / ".claude.json"
    
    print("[INFO] Claude Code CLI 설정 파일 분석 중...")
    
    try:
        # JSON 파일 읽기
        with open(claude_json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # MCP 현황 상세 출력
        print_mcp_status(data)
        
        # 사용자 입력 처리
        import sys
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