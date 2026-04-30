# k8s Extension 설계

Kubernetes manifest YAML 정적 audit (Phase 4 새 Extension).

## 의도

**문제**: k8s manifest 작성 시 흔한 안티패턴(resource limits 누락, `image: :latest`, securityContext 미설정, label/selector mismatch, Secret 평문 노출)이 PR 머지 후 production에서 발견된다. kubeval/kubeconform 같은 도구가 있지만 별도 설치 + CI 통합 부담.

**해결**: `/k8s-audit` 스킬 — manifest 디렉토리 자동 탐색 + 5 안티패턴 정적 검증. 외부 의존 0 (grep+awk fallback, yq 가용 시 정확도↑).

**대상**: k8s manifest 사용 프로젝트 (kustomize / helm / 단순 YAML 모두).

## 제약

- **외부 의존 0 (선택 yq)**: grep + awk + sed로 fallback. yq 있으면 정확도↑.
- **단일 스킬**: `/k8s-audit`만. lint / apply는 LLM 위임.
- **정량 anti-pattern**: 정형화된 5 항목만. 디자인 검증 안 함.
- **YAML 한정**: kustomize/helm 자체는 무관 (rendered YAML만 검사).
- **명령 표면**: `/k8s-audit` 또는 `/k8s-audit <manifest-dir>` 또는 `--json`.

## 설계

### 입력

```bash
/k8s-audit                   # 자동 탐색
/k8s-audit <manifest-dir>    # 디렉토리 명시
/k8s-audit --json            # JSON 출력
```

### Manifest 자동 탐색

```bash
DIRS=()
for d in k8s manifests deploy kustomize helm/templates .k8s deployment; do
  [ -d "$d" ] && DIRS+=("$d")
done
```

명시 인자 시 그것만 사용. 디렉토리 없으면 "k8s 미적용" 메시지 + exit 0.

### 검증 항목 (5)

#### 1. resource limits/requests 누락

대상: `kind: Deployment | StatefulSet | DaemonSet | Job | CronJob`

검출: `containers[]` 안에 `resources.limits` 또는 `resources.requests` 둘 다 없음 → warn.

```bash
# yq 가용 시
yq -o json '.spec.template.spec.containers[]' manifest.yaml \
  | jq -e 'has("resources") and (.resources | has("limits") or has("requests"))'

# Fallback (grep): 'containers:' 블록 내 'resources:' 키 검색
```

#### 2. `image: ...:latest` 또는 tag 없음

```bash
grep -rEn "image:\s*['\"]?[^'\"\s]+:latest" "$DIR"
grep -rEn "image:\s*['\"]?[^'\"\s:]+(?:\s|$)" "$DIR"  # tag 자체 없음
```

검출 시 warn ("reproducibility 위험").

#### 3. securityContext 미설정

대상: 위와 동일 workload kinds.

검출: `securityContext.runAsNonRoot: true` 없음 → warn.

```bash
yq -o json '.spec.template.spec' manifest.yaml \
  | jq -e '.securityContext.runAsNonRoot == true' || warn
```

#### 4. label/selector mismatch

`Deployment.spec.selector.matchLabels` ↔ `Deployment.spec.template.metadata.labels` 일치 검증.

```bash
SEL=$(yq -o json '.spec.selector.matchLabels' deployment.yaml)
TPL=$(yq -o json '.spec.template.metadata.labels' deployment.yaml)
# selector ⊆ template labels 여야
```

#### 5. Secret 평문 (env 직접 값)

`env[]` 안에 `value:` 가 있는데 키 이름에 `password|secret|token|key|api_key` 포함 → warn ("secretKeyRef 권장").

```bash
yq -o json '.spec.template.spec.containers[].env[]' manifest.yaml \
  | jq -e 'select((.name | test("(?i)password|secret|token|key|api_key")) and has("value"))'
```

### YAML 파싱 전략

```bash
HAS_YQ=$(command -v yq >/dev/null && echo 1 || echo 0)

if [ "$HAS_YQ" = "1" ]; then
  # 정확한 yq 기반 검증
  parse_yq()
else
  # grep + awk fallback
  parse_grep()
fi
```

fallback 정확도 ~70% (regex 한계). 사용자에게 명시:
> ⚠ yq 미설치 — 정확도 낮음. 권장: `brew install yq` 또는 `go install github.com/mikefarah/yq/v4@latest`

### 출력 포맷

```
☸️  vibe-flow k8s Audit

📂 Manifest 디렉토리: k8s/ (자동 탐색)
   - 12 YAML 파일 (kind 분포: Deployment 3, Service 4, ConfigMap 2, ...)

━━━ Resource limits/requests 누락 (3) ━━━
  ⚠ k8s/web-deployment.yaml:24 — container 'web': resources 미정의
  ⚠ k8s/api-deployment.yaml:18 — container 'api': limits만 있고 requests 없음
  ⚠ k8s/worker-deployment.yaml:30 — container 'worker': resources 미정의

━━━ Image tag 위험 (2) ━━━
  ⚠ k8s/web-deployment.yaml:22 — image: nginx:latest
  ⚠ k8s/api-deployment.yaml:16 — image: api (tag 없음)

━━━ securityContext 미설정 (3) ━━━
  ⚠ k8s/web-deployment.yaml — runAsNonRoot 미설정
  ⚠ k8s/api-deployment.yaml — runAsNonRoot 미설정
  ⚠ k8s/worker-deployment.yaml — runAsNonRoot 미설정

━━━ Label/selector mismatch (1) ━━━
  ✗ k8s/api-deployment.yaml — selector {app:api} vs template {app:api,env:prod} 불일치

━━━ Secret 평문 (2) ━━━
  ⚠ k8s/api-deployment.yaml:35 — env DB_PASSWORD: 직접 값 (secretKeyRef 권장)
  ⚠ k8s/api-deployment.yaml:38 — env JWT_SECRET: 직접 값 (secretKeyRef 권장)

━━━ 결과 ━━━
  검사: 12 파일 / 25 워크로드
  warn: 10 / fail: 1

권장:
  1. label/selector mismatch (1) 즉시 수정
  2. resource limits 추가 (3 deployment)
  3. securityContext.runAsNonRoot: true (3 deployment)
  4. Secret을 secretKeyRef로 분리 (2 항목)
```

### Events 발생

```json
{
  "type": "k8s_audit",
  "ts": "...",
  "files_count": 12,
  "workloads_count": 25,
  "warn": 10,
  "fail": 1,
  "categories": {
    "resources_missing": 3,
    "image_tag_risk": 2,
    "security_context_missing": 3,
    "label_mismatch": 1,
    "secret_plaintext": 2
  }
}
```

## 데이터 흐름

```
사용자: /k8s-audit
   │
   ▼
1. Manifest 디렉토리 탐색 (k8s/, manifests/, ...)
2. yq 가용성 확인 → 정확/fallback 모드 결정
3. 각 *.yaml 파일:
   - kind 추출
   - 5 항목 검증 per workload
4. 결과 분류 (warn vs fail) + 카테고리별 카운트
5. 출력
6. events.jsonl에 k8s_audit append
```

## 구성 요소

```
extensions/k8s/
├── README.md
├── skills/
│   └── k8s-audit/
│       ├── SKILL.md
│       └── evals/
│           └── evals.json
└── agents/
    └── .gitkeep
```

setup.sh `get_extensions_list` + `get_extension_summary`에 k8s 추가 (7번째).

### Evals (5 케이스)

1. 빈 프로젝트 — manifest 없음 → "k8s 미적용" 메시지
2. 모든 워크로드 정상 → 0 warn / 0 fail
3. resources 누락 검출
4. `image: :latest` 검출
5. label/selector mismatch (fail) 검출

## 의존

- **외부 (선택)**: `yq` (mikefarah/yq v4) — 정확도↑. 없으면 grep+awk fallback (정확도 ~70%).
- **POSIX**: grep, awk, sed, find

## YAGNI 제외

- **kubectl apply --dry-run** — cluster 접근 필요
- **kubeval/kubeconform** — 외부 도구 의존
- **policy engine (OPA, Kyverno)** — 다른 영역
- **자동 fix** — audit만 (사용자 결정)

## 다른 Audit 스킬과의 패턴 일관성

| Extension | Audit 스킬 | 검출 영역 |
|-----------|------------|----------|
| design-system | /design-audit | 디자인 토큰/하드코딩 색상 |
| code-feedback | /feedback | git diff 품질 |
| i18n | /i18n-audit | 번역 키 누락/미사용 |
| **k8s** (신규) | **/k8s-audit** | **manifest 안티패턴 5** |

같은 패턴: 단일 audit 스킬 + 정량 anti-pattern 검출 + 외부 의존 최소.
