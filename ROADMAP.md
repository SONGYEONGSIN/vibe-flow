# ROADMAP

claude-builds 개선 로드맵. 커뮤니티 리서치(GitHub 오픈소스 Claude Code 레포)와 내부 감사 결과를 기반으로 한 작업 큐.

**머신 간 동기화**: Claude Code 메모리는 로컬 저장이라 회사↔집 공유가 안 됨. 이 파일이 진행 상황의 **단일 진실의 원천(single source of truth)**. 작업 완료 시 체크박스 갱신 + 커밋.

---

## 완료

### 디자인 시스템
- [x] **DESIGN.md 9섹션 포맷 지원** ([`0871d9b`](https://github.com/SONGYEONGSIN/claude-builds/commit/0871d9b)) — VoltAgent/Google Stitch 표준 통합
- [x] **README 정합성** ([`cb29c77`](https://github.com/SONGYEONGSIN/claude-builds/commit/cb29c77)) — 훅 수 15→18, Design System 4중 레이어 확장

### 인프라
- [x] **P1 정비** ([`ab2b130`](https://github.com/SONGYEONGSIN/claude-builds/commit/ab2b130)) — `_common.sh::truncate_log_file()` DRY화, `agents.json` 단일 소스, `validate.sh` 5단계 검증
- [x] **settings 매처 통합** ([`e85dffc`](https://github.com/SONGYEONGSIN/claude-builds/commit/e85dffc)) — PostToolUse 9→5블록, Stop 3→1블록

### 커뮤니티 1순위: SQLite Instinct Store ✅
- [x] **초벌 도입** ([`fb54ece`](https://github.com/SONGYEONGSIN/claude-builds/commit/fb54ece)) — `scripts/store.js` + better-sqlite3, dual-write 패턴
- [x] **성숙화 P1~P3** ([`309ca09`](https://github.com/SONGYEONGSIN/claude-builds/commit/309ca09)) — 마이그레이션 시스템, daily_summary 집계, cleanup/aggregate/export/migrate, pragma 최적화, 신규 쿼리(weekly-trend/failure-trend/health)
- **출처**: [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code)

### 커뮤니티 3순위: 에이전트 실시간 관측 스트림 ✅
- [x] **JSONL 스트림 + 포맷터** — `scripts/watch-events.sh` + `scripts/events-tail.js`, 훅 2개 JSONL append 추가, session-review.sh에 10MB 회전 로직
- **출처**: [disler/claude-code-hooks-multi-agent-observability](https://github.com/disler/claude-code-hooks-multi-agent-observability)
- **사용**: `bash .claude/scripts/watch-events.sh [--errors-only] [--file <pattern>] [--raw]`

### 커뮤니티 4순위: TDD 강제화 훅 ✅
- [x] **경고 모드 도입** — `hooks/tdd-enforce.sh` (PreToolUse Write|Edit), settings.template.json 등록, validate.sh REQUIRED_HOOKS 업데이트
- **출처**: [obra/superpowers](https://github.com/obra/superpowers) (Anthropic 마켓플레이스)
- **동작**: 소스 파일 수정 시 대응 `*.test.*` / `__tests__/` 미존재 → `additionalContext`로 Claude에게 경고 전달
- **모드 전환**: `export CLAUDE_TDD_ENFORCE=strict` (차단) / `off` (비활성화) / 기본값 `warn`

### 커뮤니티 2순위: Builder/Validator Pair Mode ✅
- [x] **Validator 에이전트 + Pair 스킬** — `agents/validator.md` (Edit/Write 차단, Bash 허용), `skills/pair/SKILL.md` (Builder+Validator 워크플로우), `agents/developer.md`에 pair 완료 프로토콜 추가
- **출처**: [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery)
- **역할 구분**: comparator(A/B 비교), feedback(품질 리뷰), validator(머지 준비 binary 판정) — 중복 없음
- **사용**: Builder 완료 시 `pair-review-request` 메시지 → Validator 7단계 검증 → approved/needs-revision (최대 3 iteration, 교착 시 moderator 자동 소환)

---

## 미완 (우선순위 순)

### 🔵 P2 전략 공백: 토큰/비용 예산 프레임워크
- **배경**: `/orchestrate`로 11개 에이전트 병렬 실행 시 무제한 과금 가능
- **통합 지점**: 신규 `hooks/budget-guard.sh` + `.claude/budget.json` + `/metrics`에 비용 차트
- **예상 공수**: 반나절
- **우선순위**: 실제 과금 사례 발생 시 착수

---

## 작업 재개 절차 (머신 간)

```bash
# 1) 최신 상태 확보
cd claude-builds && git pull origin main

# 2) ROADMAP.md 확인 → 다음 미완 항목 선택
cat ROADMAP.md

# 3) 작업 시작 — Claude Code 세션에서 "ROADMAP N순위 진행" 같이 지시
```

## 갱신 규칙
- 작업 **시작** 시: 해당 항목 앞에 "🚧 진행중" 표시 + 커밋
- 작업 **완료** 시: `[ ]` → `[x]`, "미완 → 완료" 섹션 이동, 커밋 해시 추가
- 새 아이디어 발생 시: "미완" 섹션에 우선순위와 함께 추가
- **ROADMAP 갱신도 해당 작업 커밋과 함께 묶음** (별도 커밋 X)

## 참고 자료
- 내부 감사 원본: 세션 대화 (2026-04-14)
- 커뮤니티 리서치 원본: 세션 대화 (2026-04-14)
- 커뮤니티 1순위 확장 근거: openclaw-obs, claude-code-analytics, Capstan, agentic-qe (커밋 `309ca09` 메시지 참조)
