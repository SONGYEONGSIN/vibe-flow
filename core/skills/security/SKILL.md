---
name: security
effort: high
description: OWASP Top 10 기준으로 프로젝트 전체 코드를 보안 스캔한다
---

프로젝트 전체를 OWASP Top 10 기준으로 보안 점검한다.

## 절차

1. **security** 에이전트를 호출하여 `src/` 전체를 스캔
2. 다음 항목을 중점 점검:
   - A01: Broken Access Control — Server Action 인증 확인
   - A02: Cryptographic Failures — 시크릿 관리
   - A03: Injection — 입력 검증 (zod)
   - A07: XSS — `dangerouslySetInnerHTML`, 이스케이핑
   - A09: Security Logging — 에러 로깅 방식
3. 추가 점검:
   - `.env` 파일 git 추적 여부
   - `NEXT_PUBLIC_` 환경변수에 민감 정보 포함 여부
   - npm audit 결과 확인
4. 결과를 심각도별 테이블로 출력
5. events.jsonl 기록 (retrospective의 보안 추이 분석 입력):
   ```bash
   echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"type\":\"security_scan\",\"high\":$HIGH,\"medium\":$MEDIUM,\"low\":$LOW,\"overall\":\"$OVERALL\"}" >> .claude/events.jsonl
   ```

## 출력 형식

```markdown
## 보안 점검 결과

| 심각도 | 카테고리 | 파일 | 설명 | 권장 조치 |
| ------ | -------- | ---- | ---- | --------- |
| HIGH   | ...      | ...  | ...  | ...       |

### 요약

- HIGH: N개
- MEDIUM: N개
- LOW: N개
- 전체: PASS / WARN / FAIL
```
