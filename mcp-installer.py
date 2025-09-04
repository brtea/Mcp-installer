#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=====================================================================
파일명: mcp-installer.py
기능 요약: Claude Code CLI MCP 서버 자동 설치 및 설정 스크립트
          VSCode/Cursor IDE에서 사용하는 Claude Code CLI를 위한 도구

File History:
  2025.09.04 PM11:15 초기 버전 생성 - Python으로 완전 재작성
  2025.09.04 PM03:20 보안 검증 로직 추가 - 명령어 화이트리스트 및 위험 패턴 차단
  2025.09.04 PM03:45 크로스 플랫폼 지원 - OS별 명령어 분기 처리
=====================================================================
"""

import json
import sys
import os
import shutil
import argparse
import re
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

class SecurityValidator:
    """MCP 서버 설정 보안 검증 클래스"""
    
    # 안전한 명령어 화이트리스트
    SAFE_COMMANDS = {
        'npx', 'node', 'npm', 'python', 'python3', 'py', 
        'uvx', 'uv', 'pip', 'pip3',
        'cmd', 'cmd.exe', 'powershell', 'pwsh', 'sh', 'bash'
    }
    
    # 검증된 npx 패키지 화이트리스트
    SAFE_NPX_PACKAGES = {
        '@anaisbetts/mcp-installer',
        '@modelcontextprotocol/server-filesystem',
        '@modelcontextprotocol/server-github',
        '@modelcontextprotocol/server-memory',
        '@modelcontextprotocol/server-postgres',
        '@modelcontextprotocol/server-sqlite',
        '@automattic/mcp-wordpress-remote',
        'youtube-data-mcp-server',
        'mcp-server-fetch',
        '@kimtaeyoon83/mcp-server-notion'
    }
    
    # 추가 화이트리스트 (사용자 정의)
    _custom_packages = set()
    _custom_commands = set()
    
    # 위험한 패턴 목록
    DANGEROUS_PATTERNS = [
        r'rm\s+-rf',
        r'del\s+/[sf]',
        r'Remove-Item.*-Recurse',
        r'rd\s+/s',
        r'format\s+[cC]:',
        r'dd\s+if=.*of=/dev/',
        r'eval\s*\(',
        r'exec\s*\(',
        r'Invoke-Expression',
        r'IEX\s*\(',
        r'\$\(.*\)',
        r'`.*`',
        r'&&',
        r'\|\|',
        r';',
        r'\|',
        r'>',
        r'<',
        r'>>',
        r'2>',
        r'Add-Type',
        r'System\.Reflection\.Assembly',
        r'-WindowStyle\s+Hidden',
        r'DownloadString',
        r'WebClient'
    ]
    
    @classmethod
    def add_custom_packages(cls, packages: List[str]) -> None:
        """사용자 정의 패키지를 화이트리스트에 추가"""
        for pkg in packages:
            cls._custom_packages.add(pkg)
            info(f"커스텀 패키지 추가: {pkg}")
    
    @classmethod
    def add_custom_commands(cls, commands: List[str]) -> None:
        """사용자 정의 명령어를 화이트리스트에 추가"""
        for cmd in commands:
            cls._custom_commands.add(cmd.lower())
            info(f"커스텀 명령어 추가: {cmd}")
    
    @classmethod
    def load_whitelist_file(cls, file_path: Path) -> bool:
        """외부 화이트리스트 파일 로드"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                
            if 'packages' in data:
                cls.add_custom_packages(data['packages'])
            if 'commands' in data:
                cls.add_custom_commands(data['commands'])
                
            success(f"화이트리스트 파일 로드 완료: {file_path}")
            return True
        except Exception as e:
            error(f"화이트리스트 파일 로드 실패: {e}")
            return False
    
    @classmethod
    def validate_command(cls, command: str) -> bool:
        """명령어가 화이트리스트에 있는지 확인"""
        if not command:
            return False
        
        # null 바이트 체크
        if '\x00' in command:
            warn(f"명령어에 null 바이트 포함: {command}")
            return False
        
        # 경로 순회 공격 방지
        if '..' in command or command.startswith('/') or command.startswith('\\'):
            # 절대 경로나 상위 디렉토리 참조는 허용하지 않음
            if '..' in command:
                warn(f"경로 순회 시도 감지: {command}")
                return False
        
        # 경로가 포함된 경우 실행 파일명만 추출
        cmd_name = Path(command).name.lower()
        
        # 기본 명령어 확인
        base_cmd = cmd_name.replace('.exe', '').replace('.cmd', '').replace('.bat', '')
        
        # 기본 화이트리스트와 커스텀 화이트리스트 모두 확인
        if base_cmd not in cls.SAFE_COMMANDS and base_cmd not in cls._custom_commands:
            warn(f"안전하지 않은 명령어: {command}")
            return False
        
        return True
    
    @classmethod
    def validate_args(cls, args: List[str], command: str) -> bool:
        """명령어 인자에 위험한 패턴이 있는지 검사"""
        if not args:
            return True
        
        args_str = ' '.join(str(arg) for arg in args)
        
        # 위험한 패턴 검사
        for pattern in cls.DANGEROUS_PATTERNS:
            if re.search(pattern, args_str, re.IGNORECASE):
                warn(f"위험한 패턴 감지: {pattern}")
                return False
        
        # npx 명령인 경우 패키지 화이트리스트 확인
        if command and Path(command).name.lower() in ['npx', 'npx.cmd', 'npx.exe']:
            package_found = False
            for arg in args:
                if arg.startswith('@') or (not arg.startswith('-')):
                    if arg not in ['-y', '-c', '/c']:
                        # 기본 화이트리스트와 커스텀 화이트리스트 모두 확인
                        if arg not in cls.SAFE_NPX_PACKAGES and arg not in cls._custom_packages:
                            warn(f"검증되지 않은 npx 패키지: {arg}")
                            return False
                        package_found = True
                        break
            
            if not package_found:
                warn("npx 명령에 패키지가 지정되지 않았습니다")
                return False
        
        return True
    
    @classmethod
    def validate_env(cls, env: Dict[str, str]) -> bool:
        """환경 변수에 위험한 값이 있는지 검사"""
        if not env:
            return True
        
        for key, value in env.items():
            # PATH 변수 조작 방지
            if key.upper() in ['PATH', 'PYTHONPATH', 'NODE_PATH']:
                warn(f"PATH 변수 조작 시도: {key}")
                return False
            
            # 위험한 문자 검사
            if re.search(r'[$`";|&<>]', str(value)):
                warn(f"환경 변수에 위험한 문자 포함: {key}")
                return False
        
        return True
    
    @classmethod
    def validate_server_config(cls, name: str, config: Dict[str, Any]) -> bool:
        """MCP 서버 설정의 보안 검증"""
        # 필수 필드 확인
        if 'type' not in config:
            error(f"'{name}': type 필드가 없습니다")
            return False
        
        if config['type'] != 'stdio':
            warn(f"'{name}': stdio가 아닌 타입은 지원하지 않습니다")
            return False
        
        # 명령어 검증
        command = config.get('command', '')
        if not cls.validate_command(command):
            error(f"'{name}': 허용되지 않은 명령어")
            return False
        
        # 인자 검증
        args = config.get('args', [])
        if not cls.validate_args(args, command):
            error(f"'{name}': 위험한 인자 패턴")
            return False
        
        # 환경 변수 검증
        env = config.get('env', {})
        if not cls.validate_env(env):
            error(f"'{name}': 위험한 환경 변수")
            return False
        
        return True

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
        """백업 파일 생성 (예외 처리 포함)"""
        if not self.claude_json_path.exists():
            return None
            
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = self.backup_dir / f"claude_{timestamp}.json"
        
        if self.dry_run:
            info(f"(DryRun) 백업 생성 예정: {backup_path.name}")
            return backup_path
            
        try:
            # 백업 디렉토리 생성
            if not self.backup_dir.exists():
                self.backup_dir.mkdir(parents=True, exist_ok=True)
            
            # 오래된 백업 파일 정리 (최대 10개 유지)
            self._cleanup_old_backups(max_keep=10)
            
            # 디스크 공간 체크 (최소 10MB)
            stat = shutil.disk_usage(self.backup_dir)
            if stat.free < 10 * 1024 * 1024:
                warn("디스크 공간 부족 - 백업을 건너뜁니다")
                return None
            
            # 백업 파일 생성
            shutil.copy2(self.claude_json_path, backup_path)
            
            # 백업 파일 검증
            if backup_path.exists() and backup_path.stat().st_size > 0:
                info(f"백업 생성 완료: {backup_path.name}")
                return backup_path
            else:
                warn("백업 파일 생성 실패 - 크기가 0입니다")
                if backup_path.exists():
                    backup_path.unlink()
                return None
                
        except PermissionError as e:
            warn(f"백업 생성 권한 부족: {e}")
            return None
        except OSError as e:
            warn(f"백업 생성 중 OS 오류: {e}")
            return None
        except Exception as e:
            warn(f"백업 생성 실패: {e}")
            return None
    
    def _cleanup_old_backups(self, max_keep: int = 10, max_age_days: int = 30):
        """오래된 백업 파일 정리"""
        if not self.backup_dir.exists():
            return
        
        try:
            # 백업 파일 목록 가져오기
            backup_files = list(self.backup_dir.glob("claude_*.json"))
            
            # 날짜별 정렬 (최신 파일 먼저)
            backup_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
            
            # 1. 개수 제한 적용 (최대 max_keep개)
            if len(backup_files) > max_keep:
                for old_backup in backup_files[max_keep:]:
                    try:
                        old_backup.unlink()
                        info(f"오래된 백업 삭제: {old_backup.name}")
                    except Exception:
                        pass  # 삭제 실패 시 무시
            
            # 2. 날짜 제한 적용 (max_age_days일 이상)
            cutoff_time = datetime.now().timestamp() - (max_age_days * 24 * 60 * 60)
            for backup in backup_files[:max_keep]:  # 개수 제한 내에서만
                try:
                    if backup.stat().st_mtime < cutoff_time:
                        backup.unlink()
                        info(f"만료된 백업 삭제: {backup.name}")
                except Exception:
                    pass  # 삭제 실패 시 무시
                    
        except Exception as e:
            # 백업 정리 실패는 경고만 (치명적이지 않음)
            warn(f"백업 정리 중 오류 (무시됨): {e}")
    
    def save_config(self) -> bool:
        """설정 파일 저장 (원자적 쓰기)"""
        if self.dry_run:
            info("(DryRun) 저장할 내용:")
            print(json.dumps(self.data.get('mcpServers', {}), indent=2))
            return True
        
        import tempfile
        temp_fd = None
        temp_path = None
        
        try:
            # 1단계: 임시 파일에 쓰기
            temp_fd, temp_path = tempfile.mkstemp(
                dir=self.claude_json_path.parent,
                prefix='.claude_tmp_',
                suffix='.json',
                text=True
            )
            
            # JSON 데이터를 문자열로 변환
            json_str = json.dumps(self.data, indent=2, ensure_ascii=False)
            
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
            
            # 3단계: 원자적 교체 (Windows에서는 덮어쓰기)
            if sys.platform == 'win32':
                # Windows: 기존 파일 제거 후 이동
                if self.claude_json_path.exists():
                    self.claude_json_path.unlink()
                temp_path_obj.rename(self.claude_json_path)
            else:
                # Unix: 원자적 이동
                temp_path_obj.replace(self.claude_json_path)
            
            success(f"설정 저장 완료: {self.claude_json_path}")
            return True
            
        except PermissionError as e:
            error(f"파일 쓰기 권한 부족: {e}")
            # 백업에서 복구 시도
            self._attempt_recovery()
            return False
        except json.JSONDecodeError as e:
            error(f"JSON 검증 실패: {e}")
            return False
        except Exception as e:
            error(f"파일 저장 오류: {e}")
            return False
        finally:
            # 임시 파일 정리
            if temp_fd is not None:
                try:
                    os.close(temp_fd)
                except OSError:
                    pass  # 이미 닫혀있는 경우 무시
            if temp_path and Path(temp_path).exists():
                try:
                    Path(temp_path).unlink()
                except (OSError, PermissionError):
                    pass  # 삭제 실패 시 무시 (임시 파일이므로)
    
    def _attempt_recovery(self) -> bool:
        """백업에서 복구 시도"""
        if not self.backup_dir.exists():
            return False
        
        try:
            backups = sorted(self.backup_dir.glob("claude_*.json"), reverse=True)
            if backups:
                latest_backup = backups[0]
                warn(f"최신 백업에서 복구 시도: {latest_backup.name}")
                shutil.copy2(latest_backup, self.claude_json_path)
                info("백업에서 복구 성공")
                return True
        except Exception as e:
            error(f"백업 복구 실패: {e}")
        
        return False
    
    def add_mcp_installer(self) -> bool:
        """mcp-installer 추가 (크로스 플랫폼 지원)"""
        if 'mcp-installer' in self.data['mcpServers']:
            warn("mcp-installer가 이미 존재합니다.")
            return True
            
        # OS별 설정 분기
        if sys.platform == 'win32':
            # Windows
            config = {
                "type": "stdio",
                "command": "cmd.exe",
                "args": ["/c", "npx", "-y", "@anaisbetts/mcp-installer"]
            }
        elif sys.platform == 'darwin':
            # macOS
            config = {
                "type": "stdio",
                "command": "npx",
                "args": ["-y", "@anaisbetts/mcp-installer"]
            }
        else:
            # Linux 및 기타 Unix 계열
            config = {
                "type": "stdio",
                "command": "npx",
                "args": ["-y", "@anaisbetts/mcp-installer"]
            }
        
        # 보안 검증 (항상 수행)
        if not SecurityValidator.validate_server_config('mcp-installer', config):
            error("mcp-installer 설정이 보안 검증을 통과하지 못했습니다")
            return False
        
        self.data['mcpServers']['mcp-installer'] = config
        success(f"mcp-installer 추가 완료 (플랫폼: {sys.platform})")
        return True
    
    def add_server(self, config_file: Path) -> bool:
        """외부 설정 파일에서 MCP 서버 추가"""
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                import_data = json.load(f)
                
            # mcpServers 필드가 있는지 확인
            servers = import_data.get('mcpServers', import_data)
            
            if not isinstance(servers, dict):
                error("설정 파일의 mcpServers가 올바른 형식이 아닙니다")
                return False
            
            added = []
            skipped = []
            failed = []
            
            for name, config in servers.items():
                if name in self.data['mcpServers']:
                    skipped.append(name)
                    continue
                
                # 보안 검증 (항상 수행)
                if not SecurityValidator.validate_server_config(name, config):
                    failed.append(name)
                    error(f"'{name}' 서버가 보안 검증을 통과하지 못했습니다")
                    continue
                
                self.data['mcpServers'][name] = config
                added.append(name)
            
            if added:
                success(f"추가된 서버: {', '.join(added)}")
            if skipped:
                warn(f"이미 존재하는 서버 (건너뜀): {', '.join(skipped)}")
            if failed:
                error(f"보안 검증 실패 (추가 안됨): {', '.join(failed)}")
                
            return len(added) > 0 or len(skipped) > 0
            
        except json.JSONDecodeError as e:
            error(f"JSON 파싱 오류: {e}")
            return False
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
  python mcp-installer.py --extend-package "@mycompany/mcp-server"  # 패키지 화이트리스트 추가
  python mcp-installer.py --whitelist-file custom.json              # 외부 화이트리스트 파일 로드
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
    parser.add_argument('--force', action='store_true',
                       help='백업 실패 시에도 계속 진행')
    parser.add_argument('--extend-package', action='append', dest='custom_packages',
                       help='특정 패키지를 화이트리스트에 추가')
    parser.add_argument('--extend-command', action='append', dest='custom_commands',
                       help='특정 명령어를 화이트리스트에 추가')
    parser.add_argument('--whitelist-file', type=str,
                       help='외부 화이트리스트 JSON 파일 로드')
    
    args = parser.parse_args()
    
    # Windows 콘솔에서 ANSI 색상 지원 활성화
    if sys.platform == 'win32':
        os.system('color')
    
    # 화이트리스트 확장 처리
    if args.custom_packages:
        SecurityValidator.add_custom_packages(args.custom_packages)
        info(f"{len(args.custom_packages)}개의 커스텀 패키지 추가됨")
    
    if args.custom_commands:
        SecurityValidator.add_custom_commands(args.custom_commands)
        info(f"{len(args.custom_commands)}개의 커스텀 명령어 추가됨")
    
    if args.whitelist_file:
        whitelist_path = Path(args.whitelist_file)
        if not whitelist_path.exists():
            error(f"화이트리스트 파일을 찾을 수 없습니다: {args.whitelist_file}")
            return 1
        if not SecurityValidator.load_whitelist_file(whitelist_path):
            return 1
    
    # 인스턴스 생성
    installer = MCPInstaller(dry_run=args.dry_run)
    
    # 설정 파일 로드
    if not installer.load_config():
        return 1
    
    # 명령 처리
    modified = False
    
    # 백업이 필요한지 먼저 확인 (변경이 발생할 명령인지)
    needs_backup = (
        args.add_installer or 
        args.config or 
        args.remove
    ) and not args.dry_run and installer.claude_json_path.exists()
    
    # 백업 생성 (실제 변경이 필요한 경우에만)
    if needs_backup and modified is False:  # 변경 전에 백업
        backup_path = installer.create_backup()
        if not backup_path:
            warn("백업 생성 실패 - 계속 진행하시겠습니까?")
            if not args.force:
                try:
                    response = input("계속하려면 'y'를 입력하세요: ")
                    if response.lower() != 'y':
                        error("사용자가 작업을 취소했습니다")
                        return 1
                except (KeyboardInterrupt, EOFError):
                    error("\n사용자가 작업을 취소했습니다")
                    return 1
    
    # 각 작업의 성공/실패 추적
    has_error = False
    
    if args.add_installer:
        if installer.add_mcp_installer():
            modified = True
        else:
            # mcp-installer가 이미 있는 것은 오류가 아님
            pass
    
    if args.config:
        config_path = Path(args.config)
        if not config_path.exists():
            error(f"설정 파일을 찾을 수 없습니다: {args.config}")
            return 1
        if installer.add_server(config_path):
            modified = True
        else:
            # 일부 서버가 추가되지 않았을 수 있지만, 일부는 성공했을 수 있음
            # add_server의 반환값이 False면 모두 실패한 것
            if not args.dry_run:
                has_error = True
    
    if args.remove:
        if installer.remove_server(args.remove):
            modified = True
        else:
            has_error = True  # 제거 실패
    
    # 목록 출력
    if args.list or modified:
        installer.list_servers()
    
    # 변경사항 저장
    if modified:
        if installer.save_config():
            if not args.dry_run:
                info("Claude Code를 재시작하면 변경사항이 적용됩니다.")
        else:
            error("설정 저장 실패")
            has_error = True
    
    # Claude CLI 확인
    if args.verify:
        if not installer.verify():
            has_error = True
    
    # 아무 옵션도 없으면 도움말 출력
    if not any(vars(args).values()):
        parser.print_help()
    
    # 오류가 있었으면 비정상 종료
    if has_error:
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())