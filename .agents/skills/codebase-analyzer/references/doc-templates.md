# Documentation Templates Guide

문서 생성을 위한 상세 지침. Docs-as-Code 워크플로우, README/API 문서 템플릿, 작성 원칙을 제공합니다.

---

## Docs-as-Code 워크플로우

### 1단계: 계획 및 구조 설계 (Planning)
- **독자 정의**: 문서의 타겟 독자와 목표 명확히 정의
- **구조 설계**: 목차와 구조를 먼저 작성
- **일관성 확보**: 문서가 집중되고 일관성 있게 유지

### 2단계: 초안 작성 (Drafting)
- **동시 작성**: 개발과 동시에 문서 작성
- **스타일 가이드 준수**: 명확하고 간결한 콘텐츠 작성
- **독자 수준 맞춤**: 타겟 독자의 기술 수준에 맞춤

### 3단계: 검토 및 피드백 (Review)
- **피어 리뷰**: 문서도 코드처럼 리뷰 받기
- **정확성 검증**: 기술적 정확성, 명확성, 일관성 확인
- **지식 공유**: 팀 전체의 품질 표준 유지

### 4단계: 배포 및 유지보수 (Deployment)
- **CI/CD 통합**: 코드 변경과 함께 문서 자동 배포
- **지속적 업데이트**: 문서가 현재 상태를 항상 반영
- **버전 관리**: 문서도 버전 관리 시스템으로 추적

---

## README.md 템플릿

```markdown
# [프로젝트 이름]

> *프로젝트의 핵심 목적과 가치를 한 문장으로 요약합니다.*

## 주요 기능 (Features)
- **핵심 기능 1:** 이 기능이 어떤 문제를 해결하는지 설명
- **핵심 기능 2:** 사용자가 얻을 수 있는 가치 설명

## 기술 스택 (Tech Stack)
- **Frontend:** React, TypeScript, TailwindCSS
- **Backend:** Node.js, Express
- **Database:** PostgreSQL

## 시작하기 (Getting Started)

### 사전 요구사항
- Node.js (v18 이상)
- npm 또는 yarn

### 설치
```bash
git clone https://github.com/username/repo.git
cd repo
npm install
cp .env.example .env
npm run dev
```

## 사용법 (Usage)
```typescript
import { feature } from 'package';
const result = feature({ param: 'value' });
```

## 기여 방법 (Contributing)
1. Fork → 2. Branch → 3. Commit → 4. Push → 5. PR

## 라이선스 (License)
MIT License
```

---

## API 문서 템플릿

```markdown
# API 문서

## 개요
**Base URL:** `https://api.example.com/v1`

## 인증
모든 요청에 `Authorization: Bearer YOUR_API_KEY` 헤더 필요

## 엔드포인트

### POST /users
새로운 사용자를 생성합니다.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `email` | string | Yes | 유효한 이메일 주소 |
| `name` | string | Yes | 사용자 이름 |

**Example Request:**
```bash
curl -X POST https://api.example.com/v1/users \
  -H "Authorization: Bearer YOUR_KEY" \
  -d '{"email": "test@example.com", "name": "Test"}'
```

**Responses:**
| Status | Description |
|--------|-------------|
| 201 | 생성 성공 |
| 400 | 잘못된 요청 |

## 에러 처리
```json
{
  "type": "https://api.example.com/errors/validation",
  "title": "Validation Error",
  "status": 400,
  "detail": "email field is required"
}
```

## 요청 제한
- Free: 60 요청/분
- Pro: 600 요청/분
```

---

## CHANGELOG 템플릿

[Keep a Changelog](https://keepachangelog.com) + [SemVer](https://semver.org) 준수

```markdown
# Changelog

## [Unreleased]

### Added
- 새로 추가된 기능

### Changed
- 기존 기능의 변경 사항

### Fixed
- 버그 수정

### Deprecated
- 더 이상 사용되지 않을 기능

### Removed
- 제거된 기능

### Security
- 보안 관련 수정
```

### SemVer 버전 규칙
| 버전 | 변경 시점 |
|------|----------|
| **MAJOR** | 호환되지 않는 API 변경 |
| **MINOR** | 하위 호환되는 기능 추가 |
| **PATCH** | 하위 호환되는 버그 수정 |

---

## DO / DON'T

### DO (권장)
| 패턴 | 설명 |
|------|------|
| 독자 명확히 정의 | 타겟 독자의 기술 수준에 맞춰 작성 |
| 코드와 동시 작성 | Docs-as-Code: 개발과 함께 문서 업데이트 |
| 능동태/긍정문 사용 | 명확하게 지시하는 문장 작성 |
| 간결한 문장 | 복잡한 내용은 목록이나 표로 분리 |
| 시각 자료 활용 | 코드 예제, 다이어그램, 스크린샷 적극 활용 |
| '왜(Why)' 문서화 | 코드의 의도와 이유를 명확히 설명 |

### DON'T (지양)
| 패턴 | 대신 할 일 |
|------|-----------|
| 전문 용어 남발 | 독자 수준에 맞는 용어 사용 |
| 개발 후 문서화 | 개발과 동시에 작성 |
| 수동태/부정문 | 능동태와 긍정문으로 명확하게 |
| 긴 복잡한 문장 | 짧고 간결한 문장으로 분리 |
| 텍스트로만 설명 | 시각 자료와 예제 코드 활용 |
| 'What' 반복 | 코드로 명백한 내용 대신 'Why' 설명 |

---

## 문서화 우선순위

### High Priority
- 공개 API와 export된 함수
- 복잡한 알고리즘
- 설정 옵션
- 설치 지침

### Medium Priority
- 내부 유틸리티 함수
- 타입 정의
- 컴포넌트 props

### Low Priority
- 간단한 getter/setter 메소드
- 자명한 코드

---

## 출력 형식

```markdown
# Documentation Report

## Summary
- **분석된 파일**: X
- **문서화된 항목**: X
- **문서화 커버리지**: X%

## Generated Documentation
[생성된 JSDoc/TSDoc]

## README Improvements
[README 업데이트 제안]

## Missing Documentation
- [문서화가 필요한 항목 목록]

## API Reference
[생성된 API 문서]
```

---

## 체크리스트

### README 작성 후 점검
- [ ] 한 문장 소개가 프로젝트를 명확히 설명하는가?
- [ ] 설치 가이드가 복사-붙여넣기로 작동하는가?
- [ ] 코드 예제가 실제로 동작하는가?
- [ ] 링크가 모두 유효한가?

### API 문서 작성 후 점검
- [ ] 모든 파라미터에 타입과 필수 여부가 명시되어 있는가?
- [ ] 요청 예제가 복사-붙여넣기로 실행 가능한가?
- [ ] 모든 응답 상태 코드가 문서화되어 있는가?
- [ ] 에러 응답 형식이 일관되게 정의되어 있는가?

---

## 실행 지침

1. 코드베이스 구조 분석
2. 문서화되지 않았거나 부실하게 문서화된 코드 식별
3. Docs-as-Code 워크플로우에 따라 포괄적인 문서 생성
4. 실용적인 예시 포함
5. 문서를 명확하고 간결하게 유지
6. 프로젝트의 문서화 스타일 따름
