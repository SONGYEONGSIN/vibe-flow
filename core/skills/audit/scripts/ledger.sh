#!/bin/bash
# ledger.sh — AHE decision-observability 원장 (audit finding 추적)
# rules/harness-evolution.md §4. finding 의 predicted_delta 기록 + 다음 라운드 actual_delta 반증.
#
# 저장: .claude/memory/audit-ledger.jsonl (1 finding = 1 JSON 라인)
# entry: {ts,round,id,component,dimension,evidence,root_cause,fix,predicted_delta,actual_delta,status}
#   status ∈ open|fixed|verified|refuted|deferred
#
# 사용법:
#   echo '{"round":"H","component":"skills","dimension":"D2","evidence":"x:1",
#          "root_cause":"y","fix":"z","predicted_delta":"+0.2"}' | ledger.sh append
#     → 전역 단일 시퀀스 id(F-<round><NN>) 자동 부여 + append, id 를 stdout 출력
#   ledger.sh resolve <id> <actual_delta> <status>   # actual_delta 채움 + 상태 전이
#   ledger.sh open                                    # status=open finding 목록
#   ledger.sh round <round>                           # 해당 라운드 finding 목록
#   ledger.sh next-num <round>                        # 다음 finding 번호(zero-pad)
#
# 환경: LEDGER 로 경로 override 가능(테스트용). 기본 = <git root>/.claude/memory/audit-ledger.jsonl

set -u

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LEDGER="${LEDGER:-$PROJECT_ROOT/.claude/memory/audit-ledger.jsonl}"
mkdir -p "$(dirname "$LEDGER")" 2>/dev/null || true
touch "$LEDGER" 2>/dev/null || true

# F-K11 (audit R11): 손상된 라인 1개가 next_num(:32) 과 id 충돌검사 둘 다를 fail-open 시킨다.
# 둘 다 `jq ... 2>/dev/null` 이라 파스 에러를 "비어있음/존재하지 않음"으로 해석하고,
# 두 fail-open read 가 합성돼 이미 존재하는 id 를 재발급한다 (중복 primary key).
# 감사 이력은 append-only 신뢰가 전제이므로 손상 시 조용히 진행하지 않고 즉시 중단한다.
if [ -s "$LEDGER" ] && ! jq empty "$LEDGER" >/dev/null 2>&1; then
  echo "error: ledger corrupt — 수동 복구 필요: $LEDGER" >&2
  exit 3
fi

cmd="${1:-}"; shift 2>/dev/null || true

# 라운드 내 다음 번호 (기존 F-<round><NN> 최대값+1, 없으면 1) — 전역 단일 시퀀스
next_num() {
  local round="$1" max
  max=$(jq -r --arg r "$round" 'select(.round==$r) | .id | ltrimstr("F-") | ltrimstr($r)' "$LEDGER" 2>/dev/null \
        | grep -E '^[0-9]+$' | sort -n | tail -1)
  # 10# 강제 base-10 — leading-zero(08/09)를 8진수로 오해석하는 버그 방지
  printf '%02d' "$(( 10#${max:-0} + 1 ))"
}

# F-I04/F-I07 (audit R9): 모든 mutating 커맨드(append/resolve/mark-fixed/enqueue)의
# read-modify-write 를 mkdir 원자 락으로 직렬화. F-H02(R8)는 append 만 보호해 병렬 resolve
# 시 lost-update 발생. trap 으로 crash/SIGINT 시 stale lock 자동 해제(F-I07).
LOCK="$LEDGER.lock"
acquire_lock() {
  local tries=0
  until mkdir "$LOCK" 2>/dev/null; do
    tries=$((tries + 1)); [ "$tries" -gt 100 ] && { echo "error: ledger lock timeout" >&2; exit 1; }
    sleep 0.05
  done
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
}
release_lock() { rmdir "$LOCK" 2>/dev/null; trap - EXIT INT TERM; }

case "$cmd" in
  append)
    IN=$(cat)
    round=$(echo "$IN" | jq -r '.round // empty')
    [ -z "$round" ] && { echo "error: .round required" >&2; exit 1; }
    # F-K01 (audit R11): rules/harness-evolution.md §3 의 4-필드 계약을 기계 강제.
    # 종전엔 .round 만 검사해 4 필드가 전부 null 인 finding 이 유효 id 로 기록됐고,
    # predicted_delta 가 null 이면 다음 라운드 pending-verify 가 반증할 대상을 잃는다.
    # 빈 문자열도 누락과 동치로 본다 (resolve 의 F-H03 가드와 동형).
    for field in evidence root_cause fix predicted_delta; do
      if [ -z "$(echo "$IN" | jq -r --arg f "$field" '.[$f] // empty')" ]; then
        echo "error: .$field required (4-필드 계약: evidence/root_cause/fix/predicted_delta)" >&2
        exit 1
      fi
    done
    # F-O01 (audit round P): component/dimension 귀속도 강제. SKILL.md Phase2 는 finding
    # 을 7-component 중 하나 + dimension 에 귀속시키라 요구하나 F-K01 은 4-field 만 굳혔다.
    # enqueue(:하단)가 큐 task 를 "[audit \(.id)/\(.dimension)/\(.component)]" 로 만들므로
    # 미제공 시 "[audit F-X/null/null]" 이 자율 fix 큐에 그대로 적재된다.
    for field in component dimension; do
      if [ -z "$(echo "$IN" | jq -r --arg f "$field" '.[$f] // empty')" ]; then
        echo "error: .$field required (귀속: 7-component 중 하나 + dimension)" >&2
        exit 1
      fi
    done
    # F-H02(R8)+F-I04(R9): append 를 원자 락으로 직렬화 (병렬 append 동일 id race 차단).
    acquire_lock
    num=$(next_num "$round")
    id="F-${round}${num}"
    # id 충돌 방지(전역 단일): 이미 존재하면 거부
    if jq -e --arg i "$id" 'select(.id==$i)' "$LEDGER" >/dev/null 2>&1; then
      release_lock
      echo "error: id $id already exists" >&2; exit 1
    fi
    echo "$IN" | jq -c --arg id "$id" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{ts:$ts, round:.round, id:$id, component:.component, dimension:.dimension,
        evidence:.evidence, root_cause:.root_cause, fix:.fix,
        predicted_delta:.predicted_delta, actual_delta:null, status:"open", enqueued_task:null}' >> "$LEDGER"
    release_lock
    echo "$id"
    ;;
  resolve)
    id="${1:-}"; actual="${2:-}"; status="${3:-}"
    # F-H03 (audit R8): actual_delta 는 decision-observability 핵심 측정값 — 빈값 거부
    # (빈 문자열이 저장되면 pending-verify 의 ==null 필터를 통과해 미측정 fix 가 verified 로 샘)
    [ -z "$id" ] || [ -z "$actual" ] || [ -z "$status" ] && { echo "usage: resolve <id> <actual_delta> <status>" >&2; exit 1; }
    case "$status" in fixed|verified|refuted|deferred) ;; *) echo "error: status ∈ fixed|verified|refuted|deferred" >&2; exit 1 ;; esac
    acquire_lock
    jq -e --arg i "$id" 'select(.id==$i)' "$LEDGER" >/dev/null 2>&1 || { release_lock; echo "error: id $id not found" >&2; exit 1; }
    # F-K02 (audit R11): mark-fixed 는 F-H08 로 단방향 가드를 얻었으나 resolve 는 현재 상태를
    # 읽지 않아 같은 역전을 다른 진입점으로 수행할 수 있었다 (측정된 actual_delta 가 조용히 소실).
    cur=$(jq -r --arg i "$id" 'select(.id==$i) | .status' "$LEDGER")
    case "$cur" in
      verified|refuted) release_lock
        echo "error: $cur 는 종결 상태 — 재기록 불가 (현재: $cur)" >&2; exit 1 ;;
    esac
    # resolve 로 fixed 를 쓰면 actual_delta 가 채워진 채 fixed 가 되어 open(status=="open") 과
    # pending-verify(actual_delta=="") 양쪽 워크리스트에서 사라진다 → 다음 라운드 Phase 0 이
    # 빈 pending-verify 를 "전부 검증됨"으로 오독. fixed 전이는 mark-fixed 가 유일 경로.
    [ "$status" = "fixed" ] && { release_lock
      echo "error: fixed 전이는 mark-fixed 전용 (resolve 는 측정 결과만 기록)" >&2; exit 1; }
    tmp=$(mktemp)
    jq -c --arg i "$id" --arg a "$actual" --arg s "$status" \
      'if .id==$i then .actual_delta=$a | .status=$s else . end' "$LEDGER" > "$tmp" && mv "$tmp" "$LEDGER"
    release_lock
    # F-R06 (audit R17): enqueue 는 ledger→queue 단방향이라, 사람 PR 트랙으로 fix 가
    # 흘러 ledger 가 닫혀도 큐 entry 는 queued 로 남았다(R17 실측 8건 좀비). Phase 4 는
    # created_ts 최선두를 pop 하므로 첫 firing 이 이미 verified 된 finding 을 집는다.
    # 종결 시 역참조 키(enqueued_task)로 큐도 함께 닫아 이중장부 분기를 막는다.
    qtask=$(jq -r --arg i "$id" 'select(.id==$i) | .enqueued_task // ""' "$LEDGER" 2>/dev/null)
    if [ -n "$qtask" ]; then
      QUEUE_SH="${QUEUE_SH:-$PROJECT_ROOT/core/skills/auto-build/scripts/queue.sh}"
      if [ -f "$QUEUE_SH" ]; then
        bash "$QUEUE_SH" status-update "$qtask" aborted >/dev/null 2>&1 \
          || echo "warn: 큐 entry $qtask 전이 실패 — queue.sh status-update 수동 확인 필요" >&2
      fi
    fi
    echo "resolved $id → $status"
    ;;
  open)
    jq -r 'select(.status=="open") | "\(.id)\t\(.dimension)\t\(.fix)"' "$LEDGER" 2>/dev/null
    ;;
  round)
    r="${1:-}"; [ -z "$r" ] && { echo "usage: round <round>" >&2; exit 1; }
    jq -r --arg r "$r" 'select(.round==$r) | "\(.id)\t\(.status)\t\(.predicted_delta // "-")\t\(.actual_delta // "-")"' "$LEDGER" 2>/dev/null
    ;;
  next-num)
    r="${1:-}"; [ -z "$r" ] && { echo "usage: next-num <round>" >&2; exit 1; }
    next_num "$r"
    ;;
  enqueue)
    # improve 자동화: open finding(선택 round 필터)을 auto-build 큐에 적재 → cloud cycle 이 fix.
    # idempotent — .enqueued_task 있으면 skip(중복 큐잉 방지). harness-evolution.md §1 improve.
    r="${1:-}"
    QUEUE_SH="${QUEUE_SH:-$PROJECT_ROOT/core/skills/auto-build/scripts/queue.sh}"
    [ -f "$QUEUE_SH" ] || { echo "error: queue.sh not found: $QUEUE_SH" >&2; exit 1; }
    acquire_lock
    count=0
    # F-K14 (audit R11): Windows jq.exe 는 매 라인에 \r\n 을 붙이고 $(...) 는 *마지막* 줄의
    # \r\n 만 뗀다 → 다중 라인 캡처는 마지막을 뺀 전 줄에 \r 이 남아 --arg 매칭이 빗나갔다.
    # 그 결과 첫 finding 의 enqueued_task 가 기록되지 않아 재실행마다 큐가 중복 적재됐다.
    ids=$(jq -r --arg r "$r" \
      'select(.status=="open") | select($r=="" or .round==$r) | select((.enqueued_task // "")=="") | .id' \
      "$LEDGER" 2>/dev/null | tr -d '\r')
    # F-W09 (audit R22/W): #198 로 evolution-guard 가 실제 활성화된 뒤, 자율 세션은
    # denylist(안전코어) 파일을 편집할 수 없다(exit 2). 그런데 enqueue 는 fix 대상을
    # 보지 않고 적재해, 큐 head 가 안전코어 task 면 매 firing 이 pop→차단→abort 로
    # **산출 0** 이 된다. 2026-08-12 firing 실측: PR/브랜치/커밋/큐op 전부 0, 그 시점
    # 큐 63건 중 24건이 이 유형이었다. 가드가 inert 일 땐 "작동"했으나(그 자체가 위험),
    # 켜자마자 보장된 실패로 바뀌었다 — 라우팅이 가드 상태를 따라가지 못한 것.
    DENYLIST_F="${EVOLUTION_DENYLIST:-$PROJECT_ROOT/.claude/evolution-protected}"
    DENY_NAMES=""
    if [ -f "$DENYLIST_F" ]; then
      DENY_NAMES=$(grep -v '^#' "$DENYLIST_F" | grep -v '^[[:space:]]*$' | sed 's#.*/##' | tr -d '\r')
    fi
    for id in $ids; do
      task=$(jq -r --arg i "$id" \
        'select(.id==$i) | "[audit \(.id)/\(.dimension)/\(.component)] \(.fix). 근거: \(.evidence). 원인: \(.root_cause). 예상효과: \(.predicted_delta)."' \
        "$LEDGER")
      # fix 문구가 안전코어 파일을 가리키면 큐에 넣지 않는다 — 자율이 할 수 없는 일이다.
      # open 으로 남겨 사람이 집도록 하고, 사유를 stderr 로 표면화한다(silent skip 금지).
      skip=""
      for n in $DENY_NAMES; do
        case "$task" in *"$n"*) skip="$n"; break ;; esac
      done
      if [ -n "$skip" ]; then
        echo "skip: $id — fix 대상이 안전코어($skip). 자율 세션은 evolution-guard 로 차단됨 → 사람 review 필요" >&2
        continue
      fi
      qid=$(bash "$QUEUE_SH" add "$task" 2>/dev/null | sed -n 's/^queued: //p')
      [ -z "$qid" ] && { echo "warn: enqueue failed for $id" >&2; continue; }
      tmp=$(mktemp)
      jq -c --arg i "$id" --arg q "$qid" 'if .id==$i then .enqueued_task=$q else . end' "$LEDGER" > "$tmp" && mv "$tmp" "$LEDGER"
      echo "$id → queued $qid"
      count=$((count+1))
    done
    release_lock
    echo "enqueued $count finding(s)" >&2
    ;;
  correct)
    # F-V08 (audit R21/V): F-K02 의 종결-상태 가드는 '악의적 재기록'과 '오검증 정정'을
    # 구분하지 못한다. 실제 사고 — R21/V 가 무효 계기(push --dry-run, F-T09)로 F-S10 을
    # 거짓 refuted 처리했고, 실 push 거부 로그를 확보하고도 resolve 가 거부해 되돌릴 수
    # 없었다. append-only 원장에서 정정은 '덮어쓰기'가 아니라 **원 값을 correction
    # 레코드로 보존한 채** 엔트리를 갱신하는 것이다. 사유(reason)는 필수 — 근거 없는
    # 정정은 F-K02 가 막으려던 그 재기록과 구분되지 않는다.
    id="${1:-}"; new="${2:-}"; actual="${3:-}"; reason="${4:-}"
    { [ -z "$id" ] || [ -z "$new" ] || [ -z "$actual" ] || [ -z "$reason" ]; } && {
      echo "usage: correct <id> <verified|refuted> <actual_delta> <사유>" >&2; exit 1; }
    case "$new" in verified|refuted) ;; *) echo "error: correct 의 status ∈ verified|refuted" >&2; exit 1 ;; esac
    acquire_lock
    jq -e --arg i "$id" 'select(.id==$i)' "$LEDGER" >/dev/null 2>&1 || { release_lock; echo "error: id $id not found" >&2; exit 1; }
    cur=$(jq -r --arg i "$id" 'select(.id==$i) | .status' "$LEDGER")
    case "$cur" in
      verified|refuted) ;;
      *) release_lock
         echo "error: correct 는 종결 상태(verified|refuted) 전용 — 현재 $cur 는 resolve 를 쓸 것" >&2; exit 1 ;;
    esac
    prev_actual=$(jq -r --arg i "$id" 'select(.id==$i) | .actual_delta // ""' "$LEDGER")
    tmp=$(mktemp)
    jq -c --arg i "$id" --arg a "$actual" --arg s "$new" \
      'if .id==$i then .actual_delta=$a | .status=$s else . end' "$LEDGER" > "$tmp" && mv "$tmp" "$LEDGER"
    # 원 값 보존 레코드. 키를 target_id 로 두는 이유: .id 를 쓰면 select(.id==$i) 를 쓰는
    # 모든 read(resolve/mark-fixed/correct 의 현재상태 가드, append 의 id 충돌검사)가
    # 엔트리+correction 두 줄을 받아 문자열 비교가 전부 깨진다(구현 중 실측).
    jq -nc --arg i "$id" --arg ps "$cur" --arg pa "$prev_actual" --arg ns "$new" \
           --arg na "$actual" --arg r "$reason" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{op:"correction", ts:$ts, target_id:$i, prev_status:$ps, prev_actual_delta:$pa,
        new_status:$ns, new_actual_delta:$na, reason:$r}' >> "$LEDGER"
    release_lock
    echo "corrected $id: $cur → $new"
    ;;
  mark-fixed)
    # fix PR 머지 시점 전이: open → fixed (actual_delta 는 null 유지 — 아직 미검증).
    # 다음 라운드가 pending-verify 로 집어 측정 후 resolve(verify/refute).
    id="${1:-}"; [ -z "$id" ] && { echo "usage: mark-fixed <id>" >&2; exit 1; }
    acquire_lock
    jq -e --arg i "$id" 'select(.id==$i)' "$LEDGER" >/dev/null 2>&1 || { release_lock; echo "error: id $id not found" >&2; exit 1; }
    # F-H08 (audit R8): 단방향 상태머신 가드 — open 에서만 fixed 전이 (verified/refuted→fixed 역전 차단)
    cur=$(jq -r --arg i "$id" 'select(.id==$i) | .status' "$LEDGER")
    [ "$cur" != "open" ] && { release_lock; echo "error: mark-fixed 는 open 에서만 (현재: $cur)" >&2; exit 1; }
    tmp=$(mktemp)
    jq -c --arg i "$id" 'if .id==$i then .status="fixed" else . end' "$LEDGER" > "$tmp" && mv "$tmp" "$LEDGER"
    release_lock
    echo "$id → fixed"
    ;;
  pending-verify)
    # decision-observability reconcile 워크리스트: fix 가 머지(status=fixed)됐으나
    # actual_delta 미기록인 finding. /audit Phase 0 가 측정 후 resolve 로 verify/refute.
    r="${1:-}"
    jq -r --arg r "$r" \
      'select(.status=="fixed") | select((.actual_delta // "")=="") | select($r=="" or .round==$r) | "\(.id)\t\(.dimension)\t\(.predicted_delta // "-")\t\(.fix)"' \
      "$LEDGER" 2>/dev/null
    ;;
  reconcile)
    # F-AA03: fix PR 머지와 mark-fixed 가 분리돼 있어 사람이 빠뜨리면 finding 이 open 으로
    # 남고, 다음 firing 의 Phase 3 가 **이미 끝난 일을 다시 큐에 넣는다**. 실사고(08-24):
    # F-AA10/F-AA11 이 #226/#227 머지 후에도 open 이라 재-enqueue 됐고, F-AA10 은 #227 이
    # 뒤집은 억제형이라 재적용되면 안 되는 건이었다.
    #
    # 세 가지 안전장치가 있다.
    # (1) **머지 기준** — F-AA03 원 처방(run-cloud 의 status-update done 직전)은 PR *생성*
    #     시점이라, 머지 안 된 PR 의 finding 이 fixed 로 굳어 재큐잉이 영원히 막힌다.
    #     lifecycle(F-H07)은 mark-fixed 를 머지 시점으로 규정한다.
    # (2) **제목만** — 본문은 다른 finding 을 참조로 인용한다. 실측(08-26): 본문까지 훑으면
    #     현재 open 36건이 거짓 전이 대상이 된다(전날 등록된 F-AB01~03 포함). 고친 것과
    #     언급한 것을 구분할 유일한 신호가 제목이다.
    # (3) **기본 report-only** — 제목만 봐도 잔여 오탐이 있다(예: "…오검증 사고 등록
    #     (F-T09/V07/V08)" 처럼 *등록*한 id 가 제목에 실린 경우). 증거 없는 상태 전이를
    #     막기 위해 전이는 --apply 로만 한다.
    #
    # 조회 실패(gh 부재·비인증·오프라인)는 빈 목록이 아니라 **no-op** 이다 — 조회가 죽었는데
    # 성공으로 치면 계기가 거짓 신호를 준다(F-AA14 교훈).
    APPLY=0; [ "${1:-}" = "--apply" ] && APPLY=1
    MERGED_CMD="${LEDGER_MERGED_PR_CMD:-__gh_merged_prs}"
    if [ "$MERGED_CMD" = "__gh_merged_prs" ]; then
      TITLES=$(gh pr list --state merged --limit 50 --json title --jq '.[].title' 2>/dev/null) || TITLES=""
    else
      [ -x "$MERGED_CMD" ] || { echo "reconcile: 머지 PR 조회 불가 — no-op" >&2; exit 0; }
      TITLES=$(bash "$MERGED_CMD" 2>/dev/null) || TITLES=""
    fi
    [ -z "$TITLES" ] && { echo "reconcile: 머지 PR 조회 결과 없음 — no-op" >&2; exit 0; }

    n=0
    while IFS= read -r title; do
      [ -z "$title" ] && continue
      # fix/feat 제목만 — `chore(audit): round X … AUDIT(F-X01~F-X10)` 류는 finding 을
      # **등록**한 PR 이지 고친 PR 이 아니다. 실측(08-26): 필터 없이 28건 중 16건이 이
      # 등록 PR 발 오탐이었고, 필터 후 12건은 전부 fix/feat 제목이다.
      case "$title" in fix*|feat*) ;; *) continue ;; esac
      for fid in $(printf '%s' "$title" | grep -oE 'F-[A-Z]+[0-9]+' | sort -u); do
        cur=$(jq -r --arg i "$fid" 'select(.id==$i) | .status' "$LEDGER" 2>/dev/null | head -1)
        # open 에서만 전이 — mark-fixed 와 동일한 단방향 가드(F-H08)
        [ "$cur" = "open" ] || continue
        if [ "$APPLY" = "1" ]; then
          bash "$0" mark-fixed "$fid" >/dev/null 2>&1 && {
            echo "reconcile: $fid open → fixed — \"$title\""; n=$((n + 1)); }
        else
          echo "reconcile[report]: $fid open — 머지된 PR 제목에 등장: \"$title\""; n=$((n + 1))
        fi
      done
    done <<EOF_TITLES
$TITLES
EOF_TITLES
    if [ "$APPLY" = "1" ]; then
      echo "reconcile: ${n}건 전이" >&2
    else
      echo "reconcile: 후보 ${n}건 (전이하려면 --apply — 각 PR 이 실제로 그 finding 을 고쳤는지 확인 후)" >&2
    fi
    ;;
  *)
    echo "usage: ledger.sh {append|resolve|correct|open|round|next-num|enqueue|mark-fixed|pending-verify|reconcile}" >&2
    exit 2
    ;;
esac
