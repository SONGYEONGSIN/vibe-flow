#!/bin/bash
# Rate Limiter - PreToolUse Hook
# 원격 세션에서 도구 호출 속도를 제한하는 보안 훅
#
# Hook trigger: PreToolUse (모든 도구)
# Exit codes: 0 = 허용, 2 = 차단 (속도 제한 초과)
#
# 제한:
#   - 분당 30회 (슬라이딩 윈도우)
#   - 시간당 500회
#   - 일일 5000회
#
# 카운터 저장: ~/.openclaw/sessions/rate-limits.json
# 로깅: ~/.claude/security.log

# 원격 세션이 아니면 검사 건너뜀
if [[ -z "${OPENCLAW_SESSION_ID:-}" ]]; then
    exit 0
fi

# 카운터 파일 경로
RATE_FILE="$HOME/.openclaw/sessions/rate-limits.json"
SECURITY_LOG="$HOME/.claude/security.log"

# 디렉토리 보장
mkdir -p "$(dirname "$RATE_FILE")"

# Python 스크립트에 파일 경로/세션 ID 전달
export _RATE_FILE="$RATE_FILE"
export _SECURITY_LOG="$SECURITY_LOG"
export _SESSION_ID="${OPENCLAW_SESSION_ID}"

python3 << 'RATE_SCRIPT'
import os
import sys
import json
import time
import fcntl
from datetime import datetime

rate_file = os.environ.get("_RATE_FILE", "")
security_log = os.environ.get("_SECURITY_LOG", "")
session_id = os.environ.get("_SESSION_ID", "unknown")
# 제한값 하드코딩 (환경변수 오버라이드 불가 — 보안 정책)
limit_per_min = 30
limit_per_hour = 500
limit_per_day = 5000

now = time.time()

# 카운터 파일 읽기 (파일 잠금으로 경쟁 조건 방지)
def load_rate_data():
    if not os.path.exists(rate_file):
        return {}
    try:
        with open(rate_file, "r") as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_SH)
            data = json.load(f)
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)
            return data
    except (json.JSONDecodeError, IOError):
        return {}

def save_rate_data(data):
    try:
        with open(rate_file, "a+") as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            f.seek(0)
            f.truncate()
            json.dump(data, f, indent=2)
            f.flush()
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)
    except IOError:
        pass

def log_rate_limit(limit_type, count, limit):
    if not security_log:
        return
    try:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        entry = (
            f"{timestamp} | RATE_LIMITED | type={limit_type} | "
            f"count={count}/{limit} | session={session_id}\n"
        )
        with open(security_log, "a") as f:
            f.write(entry)
    except IOError:
        pass

# 세션별 타임스탬프 배열 로드
data = load_rate_data()
session_data = data.get(session_id, {"timestamps": []})
timestamps = session_data.get("timestamps", [])

# 오래된 타임스탬프 정리 (24시간 이전 제거)
day_ago = now - 86400
timestamps = [t for t in timestamps if t > day_ago]

# 슬라이딩 윈도우 카운팅
minute_ago = now - 60
hour_ago = now - 3600

count_min = sum(1 for t in timestamps if t > minute_ago)
count_hour = sum(1 for t in timestamps if t > hour_ago)
count_day = len(timestamps)

# 제한 검사
blocked = False
if count_min >= limit_per_min:
    print(f"BLOCKED: 분당 속도 제한 초과 ({count_min}/{limit_per_min})", file=sys.stderr)
    log_rate_limit("per_minute", count_min, limit_per_min)
    blocked = True
elif count_hour >= limit_per_hour:
    print(f"BLOCKED: 시간당 속도 제한 초과 ({count_hour}/{limit_per_hour})", file=sys.stderr)
    log_rate_limit("per_hour", count_hour, limit_per_hour)
    blocked = True
elif count_day >= limit_per_day:
    print(f"BLOCKED: 일일 속도 제한 초과 ({count_day}/{limit_per_day})", file=sys.stderr)
    log_rate_limit("per_day", count_day, limit_per_day)
    blocked = True

if blocked:
    # 타임스탬프는 추가하지 않음 (차단된 요청은 카운트하지 않음)
    session_data["timestamps"] = timestamps
    data[session_id] = session_data
    save_rate_data(data)
    sys.exit(2)

# 현재 요청 타임스탬프 추가
timestamps.append(now)
session_data["timestamps"] = timestamps
data[session_id] = session_data
save_rate_data(data)

sys.exit(0)
RATE_SCRIPT
