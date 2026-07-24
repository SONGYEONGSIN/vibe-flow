#!/bin/bash
# forge-update-check.sh - SessionStart Hook
# 원격에 claude-forge 새 버전이 있는지 체크하고 /forge-update 제안
# 4시간 쿨다운, 4초 네트워크 타임아웃
# exit 0 필수

INPUT=$(cat)

MSG=$(echo "$INPUT" | python3 -c "
import sys, json, os, subprocess, time

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

sid = d.get('session_id', '')
if not sid:
    sys.exit(0)

# 메타파일 로드
meta_path = os.path.expanduser('~/.claude/.forge-meta.json')
if not os.path.exists(meta_path):
    sys.exit(0)

try:
    with open(meta_path) as f:
        meta = json.load(f)
except Exception:
    sys.exit(0)

repo_path = meta.get('repo_path', '')
if not repo_path:
    sys.exit(0)

# 경로 정규화 (심링크 해제) + 저장소 검증
repo_path = os.path.realpath(repo_path)
if not os.path.isdir(os.path.join(repo_path, '.git')):
    sys.exit(0)

# claude-forge 저장소인지 특징 파일로 검증
plugin_json = os.path.join(repo_path, '.claude-plugin', 'plugin.json')
if not os.path.isfile(plugin_json):
    sys.exit(0)

# 4시간 쿨다운: ~/.claude/ 하위에 마커 파일 (보안상 /tmp 사용 안 함)
check_marker = os.path.expanduser('~/.claude/.forge-update-last-check')
if os.path.exists(check_marker):
    try:
        with open(check_marker) as f:
            last_check = float(f.read().strip())
        if time.time() - last_check < 14400:  # 4시간
            sys.exit(0)
    except (ValueError, IOError):
        pass  # 파싱 실패 시 체크 실행

# git fetch (4초 타임아웃, settings.json의 훅 timeout 5초와 맞춤)
try:
    result = subprocess.run(
        ['git', '-C', repo_path, 'fetch', 'origin', '--quiet'],
        capture_output=True, text=True, timeout=4
    )
    if result.returncode != 0:
        sys.exit(0)
except subprocess.TimeoutExpired:
    sys.exit(0)
except Exception:
    sys.exit(0)

# 기본 브랜치 동적 감지
try:
    default_branch_ref = subprocess.run(
        ['git', '-C', repo_path, 'symbolic-ref', 'refs/remotes/origin/HEAD'],
        capture_output=True, text=True, timeout=2
    ).stdout.strip()
    default_branch = default_branch_ref.replace('refs/remotes/origin/', '') if default_branch_ref else 'main'
except Exception:
    default_branch = 'main'

# HEAD vs origin/{default_branch} 비교
try:
    local_head = subprocess.run(
        ['git', '-C', repo_path, 'rev-parse', 'HEAD'],
        capture_output=True, text=True, timeout=2
    ).stdout.strip()

    remote_head = subprocess.run(
        ['git', '-C', repo_path, 'rev-parse', f'origin/{default_branch}'],
        capture_output=True, text=True, timeout=2
    ).stdout.strip()

    # 마커 업데이트: 비교 로직이 성공적으로 완료된 후에만 기록
    try:
        with open(check_marker, 'w') as f:
            f.write(str(time.time()))
    except Exception:
        pass

    if local_head == remote_head:
        sys.exit(0)

    current_ver = meta.get('version', '?')
    print(f'[Claude Forge] 새 업데이트가 있습니다 (현재 v{current_ver}). /forge-update 로 업데이트하세요.')

except Exception:
    sys.exit(0)
" 2>/dev/null)

if [[ -n "$MSG" ]]; then
    echo "$MSG" >&2
fi

exit 0
