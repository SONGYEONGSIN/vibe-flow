#!/bin/bash
# firing-log.sh smoke test (audit F-Y16)
# 실행: bash scripts/tests/firing-log-smoke.sh
#
# 무산출 firing 이 저장소에 아무 흔적도 남기지 않는다 — 08-12/08-15/08-17 실측
# (브랜치 0 / PR 0 / 커밋 0). 프롬프트는 "abort 시 stderr 에 사유"를 지시하지만
# stderr 는 클라우드 세션에만 있어 사후 관측이 불가능하다. heartbeat 는 firing
# 시작 시점에 **저장소에 남는** 기록을 만들어 "발화했고 여기까지 왔다"를 보존한다.
#
# 제약(둘 다 실측): 루프는 main 에 push 할 수 없고(브랜치 보호), `git push --force`
# 는 auto-build-safety 가 차단한다. 따라서 전용 브랜치에 **fast-forward** 로만 쌓는다.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/core/skills/auto-build/scripts/firing-log.sh"

PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# git-bash(MSYS)는 인자에 `:` 와 `/` 가 섞이면 Windows 경로로 오인해 변환한다 —
# `<rev>:<path>` 가 `<rev>\<path>` + `;` 로 바뀌어 `git show` 가 통째로 실패한다
# (Windows CI 실측: "fatal: Not a valid object name auto-build\firing-…;.claude\memory\…").
# F-K13/K14/N01/N03 "POSIX 가정 vs Windows 실환경" 계보의 **인자 변환 축**.
gshow() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' git -C "$BARE" "$@"; }

echo "Test H1: 스크립트 존재"
if [ -f "$SCRIPT" ]; then ok "H1.1 firing-log.sh 존재"; else ng "H1.1 부재"; echo "PASS:$PASS FAIL:$FAIL"; exit 1; fi

# 격리 fixture: 로컬 bare origin + 작업 repo (실 push 경로를 진짜로 태운다)
setup() {
  BARE="$TMP/origin.git"; WORK="$TMP/work"
  rm -rf "$BARE" "$WORK"
  git init -q --bare "$BARE"
  git init -q "$WORK"
  (cd "$WORK"
   git config user.email t@t; git config user.name t
   mkdir -p .claude/memory && echo seed > .claude/memory/.keep
   git add -A && git commit -q -m seed
   git branch -M main && git remote add origin "$BARE" && git push -q origin main)
}

echo "Test H2: DRYRUN — git 조작 없이 레코드만"
setup
out=$(cd "$WORK" && FIRING_LOG_DRYRUN=1 bash "$SCRIPT" phase0 "health ok" 2>&1); rc=$?
[ "$rc" = "0" ] && ok "H2.1 exit 0" || ng "H2.1 exit=$rc"
echo "$out" | grep -q '"phase":"phase0"' && ok "H2.2 레코드 stdout 출력" || ng "H2.2 레코드 없음: $out"
remote_branches=$(git -C "$BARE" for-each-ref --format='%(refname:short)' refs/heads | grep -c firing || true)
[ "$remote_branches" = "0" ] && ok "H2.3 DRYRUN 은 origin 에 브랜치 미생성" || ng "H2.3 DRYRUN 인데 push 됨"

echo "Test H3: 실 경로 — 전용 브랜치에 heartbeat 착지"
setup
# 스크립트 출력을 버리지 않는다 — 실패 시 진단 근거가 없으면 추측만 남는다(F-Y16 의 교훈).
h3out=$(cd "$WORK" && bash "$SCRIPT" phase0 "health ok" 2>&1)
hb=$(git -C "$BARE" for-each-ref --format='%(refname:short)' refs/heads | grep firing | head -1)
diag() {  # 실패 시에만 호출 — 무엇이 어디에 있는지 그대로 드러낸다
  echo "  --- 진단 ---"
  echo "  script stdout/stderr: ${h3out:-<없음>}"
  echo "  origin 브랜치: $(git -C "$BARE" for-each-ref --format='%(refname:short)' refs/heads | tr '\n' ' ')"
  [ -n "$hb" ] && echo "  $hb 트리: $(git -C "$BARE" ls-tree -r --name-only "$hb" | tr '\n' ' ')"
  # 파일이 트리에 있는데 읽히지 않는다면 blob 이 비었는지 / show 가 실패하는지를 가른다
  [ -n "$hb" ] && echo "  blob 크기: $(gshow cat-file -s "$hb:.claude/memory/firing-log.jsonl" 2>&1 | head -1) bytes"
  [ -n "$hb" ] && echo "  blob 내용: [$(gshow cat-file -p "$hb:.claude/memory/firing-log.jsonl" 2>&1 | head -c 120)]"
  [ -n "$hb" ] && echo "  커밋수: $(git -C "$BARE" rev-list --count "$hb" 2>&1)"
  echo "  work 파일: $(cd "$WORK" && ls -1 .claude/memory 2>/dev/null | tr '\n' ' ')"
  echo "  work 브랜치: $(git -C "$WORK" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  echo "  -------------"
}
if [ -n "$hb" ]; then
  ok "H3.1 origin 에 heartbeat 브랜치 생성 ($hb)"
  n=$(gshow show "$hb:.claude/memory/firing-log.jsonl" 2>/dev/null | grep -c . || true)
  if [ "$n" = "1" ]; then ok "H3.2 레코드 1건 착지"; else ng "H3.2 레코드 $n 건 (want 1)"; diag; fi
  gshow show "$hb:.claude/memory/firing-log.jsonl" 2>/dev/null | jq -e '.ts and .phase' >/dev/null 2>&1 \
    && ok "H3.3 레코드에 ts/phase 필수 키" || ng "H3.3 필수 키 누락"
else
  ng "H3.1 heartbeat 브랜치 없음 — 무산출 firing 이 여전히 무흔적"
  ng "H3.2 (전제 실패)"; ng "H3.3 (전제 실패)"
fi

echo "Test H4: 동일 firing 2회 호출 — fast-forward 누적 (force 불필요)"
setup
(cd "$WORK" && bash "$SCRIPT" phase0 "start" >/dev/null 2>&1)
(cd "$WORK" && bash "$SCRIPT" phase4 "queue empty" >/dev/null 2>&1)
hb=$(git -C "$BARE" for-each-ref --format='%(refname:short)' refs/heads | grep firing | head -1)
n=$(gshow show "$hb:.claude/memory/firing-log.jsonl" 2>/dev/null | grep -c . || true)
[ "$n" = "2" ] && ok "H4.1 2건 누적 (앞 기록 보존)" || ng "H4.1 레코드 $n 건 (want 2 — 덮어썼거나 실패)"
phases=$(gshow show "$hb:.claude/memory/firing-log.jsonl" 2>/dev/null | jq -r '.phase' | tr '\n' ',')
[ "$phases" = "phase0,phase4," ] && ok "H4.2 phase 순서 보존 (phase0→phase4)" || ng "H4.2 phases=$phases"

echo "Test H5: main 을 건드리지 않는다 (보호 브랜치 회피)"
main_sha_before=$(git -C "$BARE" rev-parse main)
setup
(cd "$WORK" && bash "$SCRIPT" phase0 "x" >/dev/null 2>&1)
main_sha_after=$(git -C "$BARE" rev-parse main)
new_main=$(git -C "$BARE" rev-parse main)
seed_only=$(git -C "$BARE" log main --oneline | wc -l | tr -d ' ')
[ "$seed_only" = "1" ] && ok "H5.1 origin/main 커밋 수 불변 (heartbeat 가 main 오염 X)" || ng "H5.1 main 커밋 $seed_only 개"

echo "Test H6: --force 를 쓰지 않는다 (auto-build-safety 차단 회피)"
# 주석에 쓴 설명 문구(`git push --force` 는 …가 차단한다)를 명령으로 오인하지 않도록
# **주석·빈줄을 제거한 실행 라인**만 검사한다. 같은 클래스의 오탐이 command-guard 에도 있다.
if grep -vE '^\s*#' "$SCRIPT" | grep -qE 'git push[^|;]*(--force|[[:space:]]-f[[:space:]])'; then
  ng "H6.1 force push 사용 — 자율 세션에서 차단됨"
else
  ok "H6.1 force push 미사용 (실행 라인 기준)"
fi

echo
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
