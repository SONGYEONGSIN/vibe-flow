---
name: PowerShell + Claude Code statusLine gotchas (Windows)
description: Windows에서 statusLine을 작성할 때 마주친 두 가지 비명시적 함정 — PowerShell 자동 변수 충돌과 .cmd 래퍼 stdin 전달 문제
type: feedback
originSessionId: 5f8cd0bc-83ea-4d61-91ab-1df683cff052
---
Windows에서 Claude Code `statusLine` 을 PowerShell 스크립트로 작성할 때 다음 두 함정을 회피한다.

## 함정 1: `$home` 은 PowerShell 자동 변수 (read-only)

```ps1
$home = $env:USERPROFILE.Replace('\', '/')  # ❌ throws SessionStateUnauthorizedAccessException
$userHome = $env:USERPROFILE.Replace('\', '/')  # ✅
```

**Why:** PowerShell 의 자동 변수 — `$home`, `$pid`, `$pshome`, `$true/$false/$null`, `$args`, `$input` 등 — 은 read-only. try/catch 블록 안에서 할당 시 *터미네이팅* 예외를 던져 catch 분기로 빠지므로 디버깅이 어렵다 (조용히 fallback 값으로 출력됨).

**How to apply:** PS 스크립트에서 `home`/`pid` 같은 이름은 절대 변수로 쓰지 않는다. 의심되면 `Get-Variable -Scope Global | Where-Object Options -Match 'ReadOnly|Constant'` 로 확인.

## 함정 2: Windows statusLine 은 `.cmd` 래퍼 대신 직접 pwsh 호출

```json
// ❌ stdin 전달이 일부 환경에서 안 됨
"command": "C:\\Users\\ys1114\\.claude\\statusline.cmd"

// ✅ 공식 문서 권장 방식
"command": "pwsh -NoProfile -NonInteractive -File C:/Users/ys1114/.claude/statusline.ps1"
```

**Why:** Claude Code 공식 문서 (code.claude.com/docs/en/statusline) Windows 예제는 직접 `powershell -File` 을 호출한다. `.cmd` 래퍼를 거치면 stdin JSON이 pwsh 까지 도달하지 않는 경우가 있어 statusLine 이 UI에 아예 안 나타난다.

**How to apply:**
- 인코딩(`chcp 65001`)이 필요하면 `.cmd` 가 아니라 ps1 시작부에 `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()` 로 처리.
- `settings.json` 의 `statusLine.command` 자체를 바꾸면 **세션 재시작이 필요**하다 (Claude Code 가 시작 시 1회만 읽음). 스크립트 *내용* 변경은 매 prompt 마다 즉시 반영.

## 디버깅 팁

- statusLine 이 안 나오면 우선 `cmd.exe //c "type input.json | <command>"` 로 직접 실행해 출력 확인.
- 빈 출력이면 PS 스크립트의 try/catch 가 예외를 삼키고 있을 가능성 — 임시로 catch 안에 `Write-Host "ERR: $($_.Exception.Message)" -ErrorAction Continue` 추가.
