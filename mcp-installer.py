#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=====================================================================
파일명: mcp-installer.py
기능 요약: Claude Code CLI MCP 서버 자동 설치 및 설정 스크립트
          VSCode/Cursor IDE에서 사용하는 Claude Code CLI를 위한 도구

File History:
  2025.09.04 PM11:15 초기 버전 생성 - Python으로 완전 재작성
=====================================================================
"""

import json
import sys
import os
import shutil
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, Optional, List
import subprocess

# 색상 코드 (Windows 콘솔 호환)
class Colors:
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    GRAY = '\033[90m'
    RESET = '\033[0m'

def info(msg: str) -> None:
    """정보 메시지 출력"""
    print(f"{Colors.CYAN}[INFO]{Colors.RESET} {msg}")

def success(msg: str) -> None:
    """성공 메시지 출력"""
    print(f"{Colors.GREEN}[SUCCESS]{Colors.RESET} {msg}")

def warn(msg: str) -> None:
    """경고 메시지 출력"""
    print(f"{Colors.YELLOW}[WARN]{Colors.RESET} {msg}")

def error(msg: str) -> None:
    """에러 메시지 출력"""
    print(f"{Colors.RED}[ERROR]{Colors.RESET} {msg}")

class MCPInstaller:
    """Claude Code CLI MCP 서버 설치 관리 클래스"""
    
    def __init__(self, dry_run: bool = False):
        """
        초기화
        
        Args:
            dry_run: True면 실제 파일 수정 없이 미리보기만
        """
        self.dry_run = dry_run
        self.home_dir = Path.home()
        self.claude_json_path = self.home_dir / ".claude.json"
        self.backup_dir = self.home_dir / ".claude-backups"
        self.data = None
        
    def load_config(self) -> bool:
        """Claude 설정 파일 로드"""
        if not self.claude_json_path.exists():
            info("Claude 설정 파일이 없습니다. 새로 생성합니다.")
            self.data = {"mcpServers": {}}
            return True
            
        try:
            with open(self.claude_json_path, 'r', encoding='utf-8') as f:
                self.data = json.load(f)
            info(f"설정 파일 로드 완료: {self.claude_json_path}")
            
            # mcpServers가 없으면 생성
            if 'mcpServers' not in self.data:
                self.data['mcpServers'] = {}
                
            return True
        except json.JSONDecodeError as e:
            error(f"JSON 파싱 오류: {e}")
            return False
        except Exception as e:
            error(f"파일 읽기 오류: {e}")
            return False
    
    def create_backup(self) -> Optional[Path]:
        """백업 파일 생성"""
        if not self.claude_json_path.exists():
            return None
            
        if not self.backup_dir.exists():
            self.backup_dir.mkdir(exist_ok=True)
            
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = self.backup_dir / f"claude_{timestamp}.json"
        
        if not self.dry_run:
            shutil.copy2(self.claude_json_path, backup_path)
            info(f"백업 생성: {backup_path.name}")
        else:
            info(f"(DryRun) 백업 생성 예정: {backup_path.name}")
            
        return backup_path
    
    def save_config(self) -> bool:
        """설정 파일 저장"""
        if self.dry_run:
            info("(DryRun) 저장할 내용:")
            print(json.dumps(self.data.get('mcpServers', {}), indent=2))
            return True
            
        try:
            with open(self.claude_json_path, 'w', encoding='utf-8') as f:
                json.dump(self.data, f, indent=2, ensure_ascii=False)
            success(f"설정 저장 완료: {self.claude_json_path}")
            return True
        except Exception as e:
            error(f"파일 저장 오류: {e}")
            return False
    
    def add_mcp_installer(self) -> bool:
        """mcp-installer 추가"""
        if 'mcp-installer' in self.data['mcpServers']:
            warn("mcp-installer가 이미 존재합니다.")
            return True
            
        # Windows 환경용 설정
        self.data['mcpServers']['mcp-installer'] = {
            "type": "stdio",
            "command": "cmd.exe",
            "args": ["/c", "npx", "-y", "@anaisbetts/mcp-installer"]
        }
        
        success("mcp-installer 추가 완료")
        return True
    
    def add_server(self, config_file: Path) -> bool:
        """외부 설정 파일에서 MCP 서버 추가"""
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                import_data = json.load(f)
                
            # mcpServers 필드가 있는지 확인
            servers = import_data.get('mcpServers', import_data)
            
            added = []
            skipped = []
            
            for name, config in servers.items():
                if name in self.data['mcpServers']:
                    skipped.append(name)
                else:
                    self.data['mcpServers'][name] = config
                    added.append(name)
            
            if added:
                success(f"추가된 서버: {', '.join(added)}")
            if skipped:
                warn(f"이미 존재하는 서버 (건너뜀): {', '.join(skipped)}")
                
            return True
            
        except Exception as e:
            error(f"설정 파일 처리 오류: {e}")
            return False
    
    def list_servers(self) -> None:
        """등록된 MCP 서버 목록 출력"""
        servers = self.data.get('mcpServers', {})
        
        if not servers:
            info("등록된 MCP 서버가 없습니다.")
            return
            
        print(f"\n{Colors.CYAN}=== 등록된 MCP 서버 목록 ==={Colors.RESET}")
        for name, config in servers.items():
            cmd = config.get('command', 'N/A')
            print(f"  - {Colors.GREEN}{name}{Colors.RESET}: {cmd}")
        print(f"{Colors.CYAN}========================={Colors.RESET}\n")
    
    def remove_server(self, name: str) -> bool:
        """MCP 서버 제거"""
        if name not in self.data['mcpServers']:
            error(f"'{name}' 서버를 찾을 수 없습니다.")
            return False
            
        del self.data['mcpServers'][name]
        success(f"'{name}' 서버 제거 완료")
        return True
    
    def verify(self) -> bool:
        """Claude CLI 작동 확인"""
        info("Claude CLI 확인 중...")
        
        try:
            result = subprocess.run(
                ["claude", "--version"], 
                capture_output=True, 
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                success(f"Claude CLI OK: {result.stdout.strip()}")
                return True
            else:
                error("Claude CLI가 설치되지 않았거나 PATH에 없습니다.")
                return False
                
        except subprocess.TimeoutExpired:
            error("Claude CLI 응답 시간 초과")
            return False
        except FileNotFoundError:
            error("Claude CLI를 찾을 수 없습니다. 설치를 확인하세요.")
            return False
        except Exception as e:
            error(f"Claude CLI 확인 실패: {e}")
            return False

def main():
    """메인 실행 함수"""
    parser = argparse.ArgumentParser(
        description='Claude Code CLI MCP 서버 설치 관리 도구',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
사용 예시:
  python mcp-installer.py --add-installer              # mcp-installer 추가
  python mcp-installer.py -c config.json               # 설정 파일에서 서버 추가
  python mcp-installer.py --list                       # 서버 목록 보기
  python mcp-installer.py --remove shrimp              # 특정 서버 제거
  python mcp-installer.py --verify                     # Claude CLI 확인
  python mcp-installer.py -c config.json --dry-run     # 미리보기 모드
        """
    )
    
    parser.add_argument('-c', '--config', type=str, 
                       help='병합할 MCP 서버 설정 JSON 파일')
    parser.add_argument('--add-installer', action='store_true',
                       help='mcp-installer 추가')
    parser.add_argument('--list', action='store_true',
                       help='등록된 MCP 서버 목록 보기')
    parser.add_argument('--remove', type=str,
                       help='특정 MCP 서버 제거')
    parser.add_argument('--verify', action='store_true',
                       help='Claude CLI 작동 확인')
    parser.add_argument('--dry-run', action='store_true',
                       help='실제 변경 없이 미리보기')
    
    args = parser.parse_args()
    
    # Windows 콘솔에서 ANSI 색상 지원 활성화
    if sys.platform == 'win32':
        os.system('color')
    
    # 인스턴스 생성
    installer = MCPInstaller(dry_run=args.dry_run)
    
    # 설정 파일 로드
    if not installer.load_config():
        return 1
    
    # 백업 생성 (dry-run이 아닐 때만)
    if not args.dry_run and installer.claude_json_path.exists():
        installer.create_backup()
    
    # 명령 처리
    modified = False
    
    if args.add_installer:
        if installer.add_mcp_installer():
            modified = True
    
    if args.config:
        config_path = Path(args.config)
        if not config_path.exists():
            error(f"설정 파일을 찾을 수 없습니다: {args.config}")
            return 1
        if installer.add_server(config_path):
            modified = True
    
    if args.remove:
        if installer.remove_server(args.remove):
            modified = True
    
    # 목록 출력
    if args.list or modified:
        installer.list_servers()
    
    # 변경사항 저장
    if modified:
        if installer.save_config():
            if not args.dry_run:
                info("Claude Code를 재시작하면 변경사항이 적용됩니다.")
    
    # Claude CLI 확인
    if args.verify:
        installer.verify()
    
    # 아무 옵션도 없으면 도움말 출력
    if not any(vars(args).values()):
        parser.print_help()
    
    return 0

if __name__ == "__main__":
    sys.exit(main())