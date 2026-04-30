# README 배지 + 자동 갱신 설계 (Phase 4 3번째)

vibe-flow repo README에 메트릭 배지 추가 + 자동 갱신 스크립트.

## 의도

**문제**: vibe-flow 진행 상황 (스킬 카운트, CI 상태, 마지막 머지)이 README에 한눈에 안 보인다. 메이커는 ROADMAP을 봐야 알고, 외부 사용자는 활성 상태를 식별 어렵다.

**해결**: README 상단에 배지 섹션 추가. 일부는 shields.io 정적/동적 (CI 상태), 일부는 자체 갱신 (스킬/Hook 카운트).

## 제약

- **외부 의존 0**: shields.io는 외부 서비스지만 표준. 우리 repo는 변경 없음.
- **자동 갱신**: 메이커가 PR 만들기 전 `bash scripts/sync-readme-badges.sh` 1회 실행.
- **CI 통합 미포함**: 자동 commit back to main은 별도 스킴 (YAGNI). 수동 sync.
- **README 영향 최소**: 상단 5~6 배지만, 본문 변경 없음.

## 설계

### 배지 항목

```markdown
[![CI](https://github.com/SONGYEONGSIN/vibe-flow/actions/workflows/eval-regression.yml/badge.svg)](https://github.com/SONGYEONGSIN/vibe-flow/actions)
[![Core](https://img.shields.io/badge/Core-19_skills-blue)](docs/REFERENCE.md)
[![Extensions](https://img.shields.io/badge/Extensions-9_skills-purple)](extensions/)
[![Hooks](https://img.shields.io/badge/Hooks-23-orange)](docs/REFERENCE.md#hooks-22--모두-core)
[![Agents](https://img.shields.io/badge/Agents-12-green)](docs/REFERENCE.md#agents-12--core-10--extensions-2)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)
```

### `scripts/sync-readme-badges.sh`

자동으로 배지 수치 갱신 (Core/Ext/Hooks/Agents 카운트):

```bash
#!/bin/bash
set -u

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

CORE=$(find core/skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
EXT=$(find extensions -mindepth 3 -maxdepth 3 -type d -path '*/skills/*' | wc -l | tr -d ' ')
HOOKS=$(find core/hooks -name "*.sh" -type f | wc -l | tr -d ' ')
AGENTS_CORE=$(find core/agents -name "*.md" -type f | wc -l | tr -d ' ')
AGENTS_EXT=$(find extensions -path '*/agents/*.md' -type f | wc -l | tr -d ' ')
AGENTS_TOTAL=$((AGENTS_CORE + AGENTS_EXT))

# README의 배지 수치 sed 갱신
sed -i.tmp \
  -e "s|Core-[0-9]*_skills-|Core-${CORE}_skills-|" \
  -e "s|Extensions-[0-9]*_skills-|Extensions-${EXT}_skills-|" \
  -e "s|Hooks-[0-9]*-|Hooks-${HOOKS}-|" \
  -e "s|Agents-[0-9]*-|Agents-${AGENTS_TOTAL}-|" \
  README.md
rm -f README.md.tmp

echo "✓ Badges synced: Core=${CORE} Ext=${EXT} Hooks=${HOOKS} Agents=${AGENTS_TOTAL}"
```

### 호출 시점

1. **메이커 PR 생성 전**: `bash scripts/sync-readme-badges.sh` 수동
2. **eval-regression-check.sh 확장 (옵션)**: PR에서 README 배지 수치가 실제 카운트와 일치하는지 검증 → 불일치 시 fail

→ 후자는 YAGNI. 메이커 책임으로 충분.

### CHANGELOG / ROADMAP 갱신

Phase 4 메이커 도구화 마지막 항목 [x]:
```markdown
#### 메이커 도구화
- [x] telemetry 통합 (...)
- [x] eval 자동 회귀 알림 (...)
- [x] 빌드 자체 메트릭 dashboard — README 배지 + scripts/sync-readme-badges.sh
```

## YAGNI

- GitHub Actions 자동 commit back — 복잡 + main protection 이슈
- 별도 dashboard HTML — Phase 3 영역
- shields.io custom endpoint — 외부 인프라 필요
- 다국어 — README 자체가 한국어 위주
