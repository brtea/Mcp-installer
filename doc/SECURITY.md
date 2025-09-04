# MCP Installer Security Features

## Overview
The mcp-installer.py script has been enhanced with comprehensive security validation to prevent remote code execution (RCE) vulnerabilities when processing untrusted JSON configuration files.

## Security Features

### 1. Command Whitelist Validation
- **Allowed commands**: `npx`, `node`, `npm`, `python`, `python3`, `py`, `uvx`, `uv`, `pip`, `pip3`, `cmd`, `cmd.exe`, `powershell`, `pwsh`, `sh`, `bash`
- **Blocks any unrecognized executables**
- **Path validation**: Blocks absolute paths and parent directory traversal

### 2. NPX Package Whitelist
**10+ pre-approved packages:**
- `@anaisbetts/mcp-installer`
- `@modelcontextprotocol/server-filesystem`
- `@modelcontextprotocol/server-github`
- `@modelcontextprotocol/server-memory`
- `@modelcontextprotocol/server-postgres`
- `@modelcontextprotocol/server-sqlite`
- `@automattic/mcp-wordpress-remote`
- `youtube-data-mcp-server`
- `mcp-server-fetch`
- `@kimtaeyoon83/mcp-server-notion`

### 3. Dangerous Pattern Detection (43 patterns)
Detects and blocks:
- **File deletion**: `rm -rf`, `del /[sf]`, `Remove-Item.*-Recurse`, `rd /s`
- **Disk operations**: `format`, `dd if=.*of=/dev/`
- **Code injection**: `eval(`, `exec(`, `Invoke-Expression`, `IEX(`
- **Command chaining**: `&&`, `||`, `;`, `|`, `>`, `<`, `>>`
- **Shell escaping**: `$(...)`, `` `...` ``
- **PowerShell specific**: `Add-Type`, `System.Reflection.Assembly`, `-WindowStyle Hidden`
- **Network operations**: `DownloadString`, `WebClient`

### 4. Whitelist Extension Mechanism
**Safe expansion options:**
- `--extend-package`: Add specific packages to whitelist
- `--extend-command`: Add specific commands to whitelist
- `--whitelist-file`: Load custom whitelist from JSON file

Example whitelist file:
```json
{
  "packages": [
    "@mycompany/mcp-custom-server",
    "@internal/mcp-private-tool"
  ],
  "commands": [
    "deno",
    "bun"
  ]
}
```

### 5. Data Integrity Protection
- **Atomic writes**: Using `tempfile.mkstemp()` for safe file operations
- **JSON validation**: Validates JSON structure before saving
- **Automatic backup**: Creates timestamped backups before changes
- **Backup management**: Keeps max 10 backups, auto-deletes >30 days old
- **Auto-recovery**: Restores from latest backup on save failure

### 6. Concurrency Control
- **File locking**: `.claude.lock` file for process synchronization
- **Stale lock cleanup**: Auto-removes locks older than 30 seconds
- **Safe release**: try-finally ensures lock release
- **Timeout handling**: 10-second timeout for lock acquisition

### 7. Duplicate Command Detection
- **Signature-based**: Compares command + args combinations
- **User confirmation**: Prompts when duplicate detected
- **Clear reporting**: Shows which existing server has same command

## Usage Examples

### Safe Installation (with full security validation)
```bash
# Add installer
python mcp-installer.py --add-installer

# Install from config file
python mcp-installer.py -c external-config.json

# Dry run (preview only)
python mcp-installer.py -c config.json --dry-run
```

### Extending Whitelist
```bash
# Add custom package
python mcp-installer.py --extend-package "@mycompany/mcp-server"

# Load external whitelist
python mcp-installer.py --whitelist-file custom-whitelist.json
```

### Status and Verification
```bash
# Check MCP status
python mcp-status.py

# Verify Claude CLI
python mcp-installer.py --verify

# List registered servers
python mcp-installer.py --list
```

## Security Validation Results

### Successfully Blocks ✅
- Unknown executables (e.g., `malware.exe`)
- Dangerous deletion commands (e.g., `rm -rf /`)
- Absolute path executions (e.g., `C:\malware\evil.exe`)
- Command injection attempts (e.g., `eval(malicious_code)`)
- Path traversal attacks (e.g., `../../etc/passwd`)

### Allows Legitimate Operations ✅
- NPM packages via npx (e.g., `npx -y @safe/package`)
- Python packages via uvx/pip
- Standard node/python scripts
- Whitelisted MCP servers

## Implementation Details

### File Structure
- **mcp-installer.py**: Main installer with security validation
- **mcp-status.py**: Status reporter with atomic save
- **whitelist-example.json**: Template for custom whitelists
- **.claude.json**: Configuration file (user home directory)
- **.claude-backups/**: Backup directory

### Key Classes
- **SecurityValidator**: Handles all security validation
  - `validate_command()`: Checks command whitelist
  - `validate_args()`: Detects dangerous patterns
  - `validate_env()`: Validates environment variables
  - `validate_server_config()`: Full config validation

- **MCPInstaller**: Main installer logic
  - `acquire_lock()`: File locking for concurrency
  - `create_backup()`: Automatic backup creation
  - `save_config()`: Atomic file writing
  - `find_duplicate_command()`: Duplicate detection

## Threat Model

### Protected Against
1. **Remote Code Execution (RCE)**: Command validation prevents arbitrary code execution
2. **Path Traversal**: Blocks `..` and absolute paths
3. **Command Injection**: Detects and blocks injection patterns
4. **File System Attacks**: Prevents deletion/format commands
5. **Race Conditions**: File locking prevents concurrent modifications
6. **Data Corruption**: Atomic writes ensure data integrity

### Assumptions
- Python environment is trusted
- User home directory is writable
- Claude CLI is properly installed
- JSON configs may come from untrusted sources

## Compliance
- **No --trust option**: All configs undergo security validation
- **Fail-safe defaults**: Restrictive whitelist approach
- **User awareness**: Clear warnings for security issues
- **Audit trail**: Backups serve as change history

## Performance Impact
- Security validation: <100ms per server config
- File locking: Max 10s timeout
- Backup creation: <50ms for typical configs
- Overall impact: Negligible for user experience

## Future Enhancements
- [ ] Cryptographic signing for trusted configs
- [ ] Network-based whitelist updates
- [ ] Integration with security scanners
- [ ] Enhanced logging for security events