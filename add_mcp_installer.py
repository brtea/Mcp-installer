#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Claude Code CLI .claude.json MCP 현황 파악 및 관리 스크립트
2025.09.04 PM11:10 생성
2025.09.04 PM11:25 MCP 현황 상세 파악 기능 추가
"""

import json
import shutil
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

def main():
    # 파일 경로
    claude_json_path = Path(r"C:\Users\brian_qs0\.claude.json")
    
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
                # mcp-installer 추가
                data['mcpServers']['mcp-installer'] = {
                    "type": "stdio",
                    "command": "cmd.exe",
                    "args": ["/c", "npx", "-y", "@anaisbetts/mcp-installer"]
                }
                
                # 백업 생성
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                backup_path = claude_json_path.parent / f".claude.json.backup_{timestamp}"
                shutil.copy2(claude_json_path, backup_path)
                
                # JSON 파일 저장
                with open(claude_json_path, 'w', encoding='utf-8') as f:
                    json.dump(data, f, indent=2, ensure_ascii=False)
                
                print("\n[SUCCESS] mcp-installer가 추가되었습니다!")
                print(f"[INFO] 백업 파일: {backup_path.name}")
                print("[INFO] Claude Code를 재시작하면 변경사항이 적용됩니다.")
        
    except Exception as e:
        print(f"[ERROR] 오류 발생: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())