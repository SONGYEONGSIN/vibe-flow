#!/bin/bash
# Output Secret Filter - PostToolUse Hook
# 도구 실행 결과에서 시크릿을 감지하여 마스킹
#
# Hook trigger: PostToolUse (모든 도구)
# Exit codes: 0 = 항상 허용 (출력만 수정)
#
# 동작 방식:
#   - stdin으로 도구 실행 결과 JSON 수신
#   - tool_result에서 시크릿 패턴 감지
#   - 감지 시 마스킹된 결과를 stdout으로 출력 (Claude가 마스킹된 값만 봄)
#   - 마스킹 발생 시 security.log에 기록 (값 자체는 기록하지 않음)

# 원격 세션이 아니면 검사 건너뜀
if [[ -z "${OPENCLAW_SESSION_ID:-}" ]]; then
    exit 0
fi

# stdin에서 JSON 읽기
INPUT=$(cat)

# 환경변수로 전달하여 Python에서 처리
export _FILTER_INPUT="$INPUT"
export _SECURITY_LOG="$HOME/.claude/security.log"

python3 << 'FILTER_SCRIPT'
import os
import sys
import json
import re
from datetime import datetime

input_json = os.environ.get("_FILTER_INPUT", "")
security_log = os.environ.get("_SECURITY_LOG", "")

if not input_json:
    sys.exit(0)

try:
    data = json.loads(input_json)
except (json.JSONDecodeError, ValueError):
    sys.exit(0)

# tool_result에서 출력 텍스트 추출
tool_result = data.get("tool_result", "")
if isinstance(tool_result, dict):
    # 딕셔너리인 경우 문자열로 변환
    tool_result = json.dumps(tool_result, ensure_ascii=False)
elif not isinstance(tool_result, str):
    tool_result = str(tool_result)

if not tool_result:
    sys.exit(0)

# 마스킹 패턴 정의 (패턴, 설명)
SECRET_PATTERNS = [
    # API 키 패턴
    (r'\bsk-[a-zA-Z0-9_-]{20,}\b', "OpenAI API Key"),
    (r'\bsk-proj-[a-zA-Z0-9_-]{20,}\b', "OpenAI Project Key"),
    (r'\bAKIA[A-Z0-9]{16,}\b', "AWS Access Key"),
    (r'\bxoxb-[a-zA-Z0-9-]{20,}\b', "Slack Bot Token"),
    (r'\bxoxp-[a-zA-Z0-9-]{20,}\b', "Slack User Token"),
    (r'\bghp_[a-zA-Z0-9]{36,}\b', "GitHub PAT"),
    (r'\bghs_[a-zA-Z0-9]{36,}\b', "GitHub App Token"),
    (r'\bgho_[a-zA-Z0-9]{36,}\b', "GitHub OAuth Token"),
    (r'\bghu_[a-zA-Z0-9]{36,}\b', "GitHub User Token"),
    (r'\bglpat-[a-zA-Z0-9_-]{20,}\b', "GitLab PAT"),
    (r'\bnpm_[a-zA-Z0-9]{36,}\b', "NPM Token"),

    # Bearer/Auth 토큰
    (r'(?i)\bBearer\s+[a-zA-Z0-9_.-]{20,}\b', "Bearer Token"),
    (r'(?i)\btoken=[a-zA-Z0-9_.-]{20,}\b', "Token Parameter"),
    (r'(?i)\bauth=[a-zA-Z0-9_.-]{20,}\b', "Auth Parameter"),
    (r'(?i)\bapi[_-]?key=[a-zA-Z0-9_.-]{20,}\b', "API Key Parameter"),

    # 비밀번호/시크릿 패턴
    (r'(?i)\bpassword=[^\s&]{8,}\b', "Password Parameter"),
    (r'(?i)\bpasswd=[^\s&]{8,}\b', "Password Parameter"),
    (r'(?i)\bsecret=[^\s&]{20,}\b', "Secret Parameter"),

    # 환경변수 값 (KEY=VALUE 형식에서 값 부분)
    (r'(?i)\bAWS_SECRET_ACCESS_KEY=[^\s]{20,}\b', "AWS Secret Key"),
    (r'(?i)\bOPENAI_API_KEY=[^\s]{20,}\b', "OpenAI Key Value"),
    (r'(?i)\bANTHROPIC_API_KEY=[^\s]{20,}\b', "Anthropic Key Value"),
    (r'(?i)\bTELEGRAM_BOT_TOKEN=[^\s]{20,}\b', "Telegram Token Value"),
    (r'(?i)\bGITHUB_TOKEN=[^\s]{20,}\b', "GitHub Token Value"),
    (r'(?i)\bSUPABASE_SERVICE_ROLE_KEY=[^\s]{20,}\b', "Supabase Key Value"),
    (r'(?i)\bDATABASE_URL=[^\s]{20,}\b', "Database URL Value"),

    # Private Key 블록
    (r'-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----', "Private Key"),

    # 긴 Base64 같은 문자열 (40자 이상 연속 영숫자, 컨텍스트 의존)
    (r'(?i)(?:key|secret|token|password|credential|auth)[\s=:]+["\']?[a-zA-Z0-9+/]{40,}={0,2}["\']?', "Potential Base64 Secret"),
]

import base64
import urllib.parse

def decode_layers(text):
    """base64, URL 인코딩을 디코딩하여 숨겨진 시크릿을 탐지"""
    decoded_variants = []
    # base64 디코딩 시도
    # base64로 보이는 청크를 찾아서 디코딩
    b64_pattern = re.compile(r'[A-Za-z0-9+/]{20,}={0,2}')
    for m in b64_pattern.finditer(text):
        try:
            decoded = base64.b64decode(m.group(0), validate=True).decode("utf-8", errors="ignore")
            if decoded and len(decoded) >= 10:
                decoded_variants.append(decoded)
        except Exception:
            pass
    # URL 디코딩 시도
    try:
        url_decoded = urllib.parse.unquote(text)
        if url_decoded != text:
            decoded_variants.append(url_decoded)
    except Exception:
        pass
    return decoded_variants

def mask_match(original):
    """매칭된 문자열을 마스킹"""
    if len(original) > 16:
        return original[:8] + "***MASKED***" + original[-4:]
    return original[:4] + "***MASKED***"

masked_output = tool_result
masked_count = 0
masked_types = []

# 1단계: 원본 텍스트에서 직접 매칭
for pattern, desc in SECRET_PATTERNS:
    matches = list(re.finditer(pattern, masked_output))
    if matches:
        for match in reversed(matches):
            original = match.group(0)
            masked_output = masked_output[:match.start()] + mask_match(original) + masked_output[match.end():]
            masked_count += 1
        if desc not in masked_types:
            masked_types.append(desc)

# 2단계: 인코딩 우회 탐지 (디코딩된 텍스트에서 시크릿 발견 시 인코딩된 원본 청크를 마스킹)
decoded_variants = decode_layers(tool_result)
for decoded_text in decoded_variants:
    for pattern, desc in SECRET_PATTERNS:
        if re.search(pattern, decoded_text):
            # 디코딩된 텍스트에서 시크릿 발견 → 원본의 base64/URL 인코딩 청크를 마스킹
            b64_pattern = re.compile(r'[A-Za-z0-9+/]{20,}={0,2}')
            for m in b64_pattern.finditer(masked_output):
                try:
                    d = base64.b64decode(m.group(0), validate=True).decode("utf-8", errors="ignore")
                    if re.search(pattern, d):
                        chunk = m.group(0)
                        masked_output = masked_output[:m.start()] + mask_match(chunk) + masked_output[m.end():]
                        masked_count += 1
                        if desc not in masked_types:
                            masked_types.append(desc)
                        break
                except Exception:
                    pass
            # URL 인코딩 우회 탐지
            try:
                url_decoded = urllib.parse.unquote(masked_output)
                if url_decoded != masked_output and re.search(pattern, url_decoded):
                    # URL 인코딩된 시크릿 → %XX 시퀀스를 포함한 구간 마스킹
                    pct_pattern = re.compile(r'(?:%[0-9A-Fa-f]{2}[A-Za-z0-9_.~-]*){5,}')
                    for pm in reversed(list(pct_pattern.finditer(masked_output))):
                        decoded_chunk = urllib.parse.unquote(pm.group(0))
                        if re.search(pattern, decoded_chunk):
                            masked_output = masked_output[:pm.start()] + mask_match(pm.group(0)) + masked_output[pm.end():]
                            masked_count += 1
                            if desc not in masked_types:
                                masked_types.append(desc)
            except Exception:
                pass

if masked_count > 0:
    # 마스킹된 출력을 stdout으로 전달 (Claude가 이 값을 봄)
    print(masked_output)

    # 보안 로그 기록 (마스킹된 값 자체는 기록하지 않음)
    if security_log:
        try:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            tool_name = data.get("tool_name", "unknown")
            session_id = os.environ.get("OPENCLAW_SESSION_ID", "unknown")
            log_entry = (
                f"{timestamp} | SECRET_MASKED | tool={tool_name} | "
                f"count={masked_count} | types={','.join(masked_types)} | "
                f"session={session_id}\n"
            )
            with open(security_log, "a") as f:
                f.write(log_entry)
        except (IOError, OSError):
            pass

# 항상 허용 (exit 0)
sys.exit(0)
FILTER_SCRIPT
