---
name: k8s-audit
description: Kubernetes manifest YAML 5 anti-pattern 정적 audit (resources/image:latest/securityContext/label-selector/Secret 평문). yq 가용 시 정확, fallback grep+awk.
model: claude-sonnet-4-6
---

# /k8s-audit

k8s manifest 디렉토리를 자동 탐색하고 5 anti-pattern을 검출한다.

## 트리거

- `/k8s-audit` — 자동 탐색
- `/k8s-audit <manifest-dir>` — 디렉토리 명시
- `/k8s-audit --json` — JSON 출력

## 절차

### 1. 인자 파싱

```bash
ARG="${1:-auto}"
case "$ARG" in
  --json) MODE="json"; MANIFEST_DIR="" ;;
  ""|auto) MODE="auto"; MANIFEST_DIR="" ;;
  *) MODE="auto"; MANIFEST_DIR="$ARG" ;;
esac
```

### 2. Manifest 탐색

```bash
DIRS=()
if [ -n "$MANIFEST_DIR" ]; then
  [ -d "$MANIFEST_DIR" ] && DIRS+=("$MANIFEST_DIR")
else
  for d in k8s manifests deploy kustomize helm/templates .k8s deployment; do
    [ -d "$d" ] && DIRS+=("$d")
  done
fi

if [ ${#DIRS[@]} -eq 0 ]; then
  echo "☸️  k8s 미적용 감지 — manifest 디렉토리 (k8s/, manifests/, deploy/, ...) 없음"
  exit 0
fi

# YAML 파일 수집
YAML_FILES=()
for d in "${DIRS[@]}"; do
  while IFS= read -r f; do
    YAML_FILES+=("$f")
  done < <(find "$d" -type f \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null)
done

if [ ${#YAML_FILES[@]} -eq 0 ]; then
  echo "☸️  YAML 파일 없음: ${DIRS[*]}"
  exit 0
fi
```

### 3. yq 가용성

```bash
HAS_YQ=0
command -v yq >/dev/null 2>&1 && HAS_YQ=1

if [ "$HAS_YQ" = "0" ]; then
  echo "⚠ yq 미설치 — grep+awk fallback (정확도 ~70%)" >&2
  echo "  권장: brew install yq" >&2
  echo "" >&2
fi
```

### 4. 검증 함수

```bash
WARN_RESOURCES=()
WARN_IMAGE=()
WARN_SECCTX=()
FAIL_LABEL=()
WARN_SECRET=()

# Workload kinds
WORKLOAD_KINDS="Deployment StatefulSet DaemonSet Job CronJob ReplicaSet"

# 1) resources 검증
check_resources() {
  local f="$1"
  if [ "$HAS_YQ" = "1" ]; then
    local kind
    kind=$(yq -r '.kind // ""' "$f" 2>/dev/null)
    echo "$WORKLOAD_KINDS" | grep -qw "$kind" || return

    local containers_path
    case "$kind" in
      CronJob) containers_path='.spec.jobTemplate.spec.template.spec.containers' ;;
      *) containers_path='.spec.template.spec.containers' ;;
    esac

    local count
    count=$(yq -r "${containers_path} | length" "$f" 2>/dev/null)
    [ -z "$count" ] || [ "$count" = "null" ] || [ "$count" = "0" ] && return

    for i in $(seq 0 $((count - 1))); do
      local has_limits has_requests cname
      has_limits=$(yq -r "${containers_path}[${i}].resources.limits // null" "$f" 2>/dev/null)
      has_requests=$(yq -r "${containers_path}[${i}].resources.requests // null" "$f" 2>/dev/null)
      cname=$(yq -r "${containers_path}[${i}].name // \"?\"" "$f" 2>/dev/null)
      if [ "$has_limits" = "null" ] && [ "$has_requests" = "null" ]; then
        WARN_RESOURCES+=("$f — container '$cname': resources 미정의")
      fi
    done
  else
    # Fallback: grep으로 'resources:' 키가 'containers:' 블록 안에 있는지 단순 체크
    if grep -q "^kind:\s*\(Deployment\|StatefulSet\|DaemonSet\|Job\|CronJob\)" "$f"; then
      if ! grep -q "^\s*resources:" "$f"; then
        WARN_RESOURCES+=("$f — workload에 resources 키 없음 (fallback grep)")
      fi
    fi
  fi
}

# 2) image:latest 검증
check_image_tag() {
  local f="$1"
  while IFS=: read -r line_num content; do
    [ -z "$content" ] && continue
    # image: foo:latest
    if echo "$content" | grep -qE "image:\s*['\"]?[^'\"\s]+:latest"; then
      WARN_IMAGE+=("$f:$line_num — image: ...:latest")
      continue
    fi
    # image: foo (tag 없음)
    if echo "$content" | grep -qE "image:\s*['\"]?[a-zA-Z0-9_./-]+['\"]?\s*$"; then
      # 단, 로컬 변수 또는 helm template은 제외
      if ! echo "$content" | grep -qE "(\\\$|\{\{|\.Values)"; then
        WARN_IMAGE+=("$f:$line_num — image: tag 없음")
      fi
    fi
  done < <(grep -nE "image:\s*" "$f" 2>/dev/null)
}

# 3) securityContext 검증
check_security_context() {
  local f="$1"
  if [ "$HAS_YQ" = "1" ]; then
    local kind
    kind=$(yq -r '.kind // ""' "$f" 2>/dev/null)
    echo "$WORKLOAD_KINDS" | grep -qw "$kind" || return

    local secctx_path
    case "$kind" in
      CronJob) secctx_path='.spec.jobTemplate.spec.template.spec.securityContext.runAsNonRoot' ;;
      *) secctx_path='.spec.template.spec.securityContext.runAsNonRoot' ;;
    esac
    local val
    val=$(yq -r "${secctx_path} // null" "$f" 2>/dev/null)
    if [ "$val" != "true" ]; then
      WARN_SECCTX+=("$f — runAsNonRoot 미설정")
    fi
  else
    if grep -q "^kind:\s*\(Deployment\|StatefulSet\|DaemonSet\)" "$f"; then
      if ! grep -q "runAsNonRoot:\s*true" "$f"; then
        WARN_SECCTX+=("$f — runAsNonRoot 미설정 (fallback)")
      fi
    fi
  fi
}

# 4) label/selector mismatch
check_label_selector() {
  local f="$1"
  [ "$HAS_YQ" = "0" ] && return  # fallback 어려움
  local kind
  kind=$(yq -r '.kind // ""' "$f" 2>/dev/null)
  [ "$kind" != "Deployment" ] && return

  local sel_keys tpl_keys
  sel_keys=$(yq -r '.spec.selector.matchLabels // {} | keys | .[]' "$f" 2>/dev/null | sort -u)
  [ -z "$sel_keys" ] && return

  for key in $sel_keys; do
    local sel_val tpl_val
    sel_val=$(yq -r ".spec.selector.matchLabels.${key} // null" "$f" 2>/dev/null)
    tpl_val=$(yq -r ".spec.template.metadata.labels.${key} // null" "$f" 2>/dev/null)
    if [ "$sel_val" != "$tpl_val" ]; then
      FAIL_LABEL+=("$f — selector.${key}=${sel_val} vs template.${key}=${tpl_val} 불일치")
    fi
  done
}

# 5) Secret 평문
check_secret_plaintext() {
  local f="$1"
  if [ "$HAS_YQ" = "1" ]; then
    local kind
    kind=$(yq -r '.kind // ""' "$f" 2>/dev/null)
    echo "$WORKLOAD_KINDS" | grep -qw "$kind" || return

    local env_path
    case "$kind" in
      CronJob) env_path='.spec.jobTemplate.spec.template.spec.containers[].env[]' ;;
      *) env_path='.spec.template.spec.containers[].env[]' ;;
    esac

    yq -r "${env_path} | select((.name | test(\"(?i)password|secret|token|key|api_key\")) and has(\"value\")) | .name" "$f" 2>/dev/null | while read -r ename; do
      [ -n "$ename" ] && echo "WARN_SECRET:$f — env $ename: 직접 값 (secretKeyRef 권장)"
    done >> /tmp/k8s-audit-secrets-$$.txt
  else
    grep -nE "^\s*-\s*name:.*(password|secret|token|key|api_key)" "$f" 2>/dev/null \
      | head -10 | while read -r line; do
        echo "WARN_SECRET:$f — $line (fallback)"
      done >> /tmp/k8s-audit-secrets-$$.txt
  fi
}
```

### 5. 모든 파일 검증

```bash
> /tmp/k8s-audit-secrets-$$.txt

for f in "${YAML_FILES[@]}"; do
  check_resources "$f"
  check_image_tag "$f"
  check_security_context "$f"
  check_label_selector "$f"
  check_secret_plaintext "$f"
done

# Secret 결과 집계
while IFS=: read -r prefix line; do
  WARN_SECRET+=("$line")
done < <(grep "^WARN_SECRET:" /tmp/k8s-audit-secrets-$$.txt 2>/dev/null | sed 's/^WARN_SECRET://')
rm -f /tmp/k8s-audit-secrets-$$.txt

# 워크로드 카운트
WORKLOAD_COUNT=0
if [ "$HAS_YQ" = "1" ]; then
  for f in "${YAML_FILES[@]}"; do
    kind=$(yq -r '.kind // ""' "$f" 2>/dev/null)
    if echo "$WORKLOAD_KINDS" | grep -qw "$kind"; then
      WORKLOAD_COUNT=$((WORKLOAD_COUNT + 1))
    fi
  done
else
  WORKLOAD_COUNT=$(grep -lE "^kind:\s*(Deployment|StatefulSet|DaemonSet|Job|CronJob)" "${YAML_FILES[@]}" 2>/dev/null | wc -l | tr -d ' ')
fi

WARN_TOTAL=$((${#WARN_RESOURCES[@]} + ${#WARN_IMAGE[@]} + ${#WARN_SECCTX[@]} + ${#WARN_SECRET[@]}))
FAIL_TOTAL=${#FAIL_LABEL[@]}
```

### 6. 출력 (auto 모드)

```bash
print_section() {
  local title="$1"; shift
  local items=("$@")
  echo "━━━ $title (${#items[@]}) ━━━"
  if [ ${#items[@]} -eq 0 ]; then
    echo "  ✓ 없음"
  else
    for it in "${items[@]:0:10}"; do
      echo "  ⚠ $it"
    done
    [ ${#items[@]} -gt 10 ] && echo "  ... (총 ${#items[@]})"
  fi
  echo ""
}

if [ "$MODE" = "auto" ]; then
  echo "☸️  vibe-flow k8s Audit"
  echo ""
  echo "📂 Manifest 디렉토리: ${DIRS[*]}"
  echo "   ${#YAML_FILES[@]} YAML 파일 / ${WORKLOAD_COUNT} 워크로드"
  echo ""
  print_section "Resource limits/requests 누락" "${WARN_RESOURCES[@]}"
  print_section "Image tag 위험" "${WARN_IMAGE[@]}"
  print_section "securityContext 미설정" "${WARN_SECCTX[@]}"
  print_section "Label/selector mismatch" "${FAIL_LABEL[@]}"
  print_section "Secret 평문" "${WARN_SECRET[@]}"
  echo "━━━ 결과 ━━━"
  echo "  검사: ${#YAML_FILES[@]} 파일 / ${WORKLOAD_COUNT} 워크로드"
  echo "  warn: ${WARN_TOTAL} / fail: ${FAIL_TOTAL}"
fi

if [ "$MODE" = "json" ]; then
  jq -n \
    --argjson files "${#YAML_FILES[@]}" \
    --argjson workloads "$WORKLOAD_COUNT" \
    --argjson warn "$WARN_TOTAL" \
    --argjson fail "$FAIL_TOTAL" \
    --argjson r "${#WARN_RESOURCES[@]}" \
    --argjson i "${#WARN_IMAGE[@]}" \
    --argjson s "${#WARN_SECCTX[@]}" \
    --argjson l "${#FAIL_LABEL[@]}" \
    --argjson sec "${#WARN_SECRET[@]}" \
    '{
      files_count: $files,
      workloads_count: $workloads,
      warn: $warn,
      fail: $fail,
      categories: {
        resources_missing: $r,
        image_tag_risk: $i,
        security_context_missing: $s,
        label_mismatch: $l,
        secret_plaintext: $sec
      }
    }'
fi
```

### 7. Events 발생

```bash
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p .claude
jq -nc \
  --arg ts "$NOW_ISO" \
  --argjson files "${#YAML_FILES[@]}" \
  --argjson workloads "$WORKLOAD_COUNT" \
  --argjson warn "$WARN_TOTAL" \
  --argjson fail "$FAIL_TOTAL" \
  '{type:"k8s_audit", ts:$ts, files_count:$files, workloads_count:$workloads, warn:$warn, fail:$fail}' \
  >> .claude/events.jsonl
```

## 출처

Phase 4 새 Extension. spec: `docs/superpowers/specs/2026-04-30-k8s-extension-design.md`.
