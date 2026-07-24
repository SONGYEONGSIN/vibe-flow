---
name: pending-macmini-mailbox-cron-stop
description: 미완료 후속작업 — 집 Mac mini의 mailbox-ingest launchd 크론 중지 (사용자가 집에서 처리 예정)
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d49f8cc-9d93-47c1-bba1-5961f11b999a
  modified: 2026-07-22T02:34:31.219Z
---

**미완료 후속작업**: 집 Mac mini의 `mailbox-ingest` launchd 크론을 중지해야 함. (2026-07-22 기준 미완료 — 사용자가 집에서 직접 처리하기로 함)

**Why**: 2026-07-22에 mailbox-ingest 크론을 이 Windows 작업 PC(작업스케줄러 `OPS-Console-Mailbox-Ingest`)로 이전함 — Mac mini launchd 서비스 컨텍스트엔 `claude -p` OAuth 인증 세션이 없어 초안이 안 생겼기 때문. 그런데 Mac mini launchd 크론이 아직 살아있으면 **두 호스트가 `last_synced_at`를 두고 레이스**해서 서로 새 메일을 놓쳐 초안이 다시 누락된다. Windows PC는 초안 생성이 되고 Mac mini는 안 되므로, Mac mini가 먼저 돌아 last_synced를 밀면 그 사이 메일은 영영 초안 없이 남는다.

**How to apply**: Mac mini에서
```bash
launchctl list | grep -i mailbox            # 잡 라벨 확인
launchctl unload ~/Library/LaunchAgents/<해당-plist>
# 재부팅 후 재등록 방지: plist 파일도 이동/삭제
```
중지 확인되면 이 메모 삭제하고 [[mailbox-menu-todo]]의 "⚠️ Mac mini launchd 크론 중지" 경고도 해소 표기.

관련: [[mailbox-menu-todo]]
