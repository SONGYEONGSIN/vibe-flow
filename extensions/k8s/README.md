# k8s Extension

Kubernetes manifest YAML 정적 audit. 5 anti-pattern 검출.

## 포함

| 종류 | 항목 | 설명 |
|------|------|------|
| Skill | `/k8s-audit [<dir>\|--json]` | manifest 자동 탐색 + 5 anti-pattern 검증 |

## 검출 항목

1. **resource limits/requests 누락** — workload (Deployment/StatefulSet/...) 의 container.resources
2. **image tag 위험** — `image: ...:latest` 또는 tag 없음
3. **securityContext 미설정** — `runAsNonRoot: true` 누락
4. **label/selector mismatch** — Deployment.spec.selector ↔ template labels 불일치
5. **Secret 평문** — env에서 `password|secret|token|key|api_key` 키가 직접 `value:` (secretKeyRef 권장)

## Manifest 자동 탐색

- `k8s/`, `manifests/`, `deploy/`, `kustomize/`, `helm/templates/`, `.k8s/`, `deployment/`

## 의존

- **외부 (선택)**: `yq` (mikefarah/yq v4) — 정확도↑
- 없으면 grep + awk fallback (정확도 ~70%, 핵심 anti-pattern은 잡음)

## 사용 시나리오

- PR 직전 manifest 안티패턴 검증
- production 배포 전 보안/안정성 사전 점검
- 신규 manifest 추가 후 정합성 검증

## 설치

```bash
bash setup.sh --extensions k8s

# 정확도 위해 yq 권장 설치
brew install yq    # macOS
# 또는 go install github.com/mikefarah/yq/v4@latest
```
