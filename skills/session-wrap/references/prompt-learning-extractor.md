# learning-extractor subagent 프롬프트

## 역할

이번 세션에서 **배운 점(learning points)**을 추출하고, instinct 후보로 정리한다.
continuous-learning-v2의 관찰/instinct 아키텍처를 따른다.

## 입력

- `/tmp/session-wrap/recent-observations.jsonl` — 세션 중 관찰 데이터
- `/tmp/session-wrap/recent-buffer.jsonl` — 버퍼 데이터 (있으면)
- `/tmp/session-wrap/recent-commits.txt` — 최근 커밋 메시지
- `/tmp/session-wrap/changed-files.txt` — 변경된 파일 목록

## 탐지 기준

1. **사용자 교정(correction)**: 사용자가 Claude의 제안을 거부/수정한 경우
2. **에러 해결(error resolution)**: 에러를 만나고 해결한 패턴
3. **새 라이브러리/API 사용**: 이번 세션에서 처음 사용한 도구/라이브러리
4. **워크플로우 선호**: 사용자가 특정 순서/방식을 선호한 경우
5. **프로젝트 특성**: 프로젝트 고유의 규칙이나 패턴 발견

## Instinct 형식 참조

continuous-learning-v2 아키텍처:

```yaml
---
id: prefer-functional-style
trigger: "when writing new functions"
confidence: 0.5
domain: "code-style"
source: "session-observation"
---

# Prefer Functional Style

## Action
함수형 패턴을 클래스 기반보다 우선 사용

## Evidence
- 2026-02-22 세션에서 클래스 기반 접근을 함수형으로 교정 관찰
```

## 출력 형식

반드시 `/tmp/session-wrap/results/learning-points.json`에 기록:

```json
{
  "items": [
    {
      "id": "learn-001",
      "source": "learning-extractor",
      "title": "Supabase RLS 패턴 학습",
      "description": "auth.uid() 기반 RLS 정책을 모든 테이블에 적용하는 패턴을 학습함.",
      "category": "user",
      "priority": "low",
      "action": "instinct 파일 생성: prefer-rls-auth-uid.md (confidence: 0.5)",
      "files": [],
      "metadata": {
        "instinct_id": "prefer-rls-auth-uid",
        "trigger": "Supabase 테이블 생성 시",
        "confidence": 0.5,
        "domain": "database",
        "evidence_type": "error_resolution"
      }
    }
  ]
}
```

## 신뢰도(confidence) 기준

| 근거 | 초기 신뢰도 |
|------|-----------|
| 사용자가 직접 교정 | 0.7 |
| 에러 해결 후 패턴 발견 | 0.5 |
| 반복 관찰 (3회 이상) | 0.6 |
| 새 라이브러리 첫 사용 | 0.3 |
| 워크플로우 선호 (1회 관찰) | 0.4 |

## 제약

- instinct 파일을 직접 생성하지 않는다. 후보만 제안한다.
- 이미 존재하는 instinct와 중복이면 "confidence 업데이트 제안"으로 기록한다.
- 관찰 데이터가 없으면 커밋 메시지와 변경 파일 기반으로 추론한다.
- 너무 일반적인 학습 (예: "코드를 잘 작성해야 한다")은 제외한다.
