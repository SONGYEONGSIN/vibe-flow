# Site Audit Checklist

전체 점검 시 확인해야 할 상세 체크리스트

---

## Performance Checklist

### 빌드
- [ ] `npm run build` 성공
- [ ] TypeScript 오류 없음
- [ ] ESLint 에러 없음
- [ ] 정적 페이지 생성 성공

### 번들 크기
- [ ] .next 폴더 < 20MB
- [ ] chunks 폴더 < 10MB
- [ ] 대용량 의존성 tree-shaking 확인

### 파일 무결성
- [ ] 모든 이미지 파일 유효
- [ ] 누락된 import 없음
- [ ] 404 링크 없음
- [ ] 미사용 파일 정리

### 성능 지표
- [ ] unoptimized 이미지 없음
- [ ] 미사용 의존성 제거
- [ ] console.log 제거 (production)

---

## Design Checklist

### AI Slop 방지
- [ ] 보라색 그라데이션 없음
- [ ] Space Grotesk 남발 없음
- [ ] 그라데이션 블롭 없음
- [ ] 3D 아이소메트릭 없음
- [ ] 이모지 없음 (특수 요청 제외)

### 타이포그래피
- [ ] 한글: Pretendard 사용
- [ ] 영문: Inter/Roboto/Arial 없음
- [ ] 본문 최소 16px
- [ ] 명확한 시각적 계층

### 색상
- [ ] 화이트/블랙 제외 최대 3색
- [ ] CSS 변수 사용
- [ ] 텍스트 대비 4.5:1 이상

### 접근성
- [ ] 모든 이미지 alt 속성
- [ ] outline: none 없음
- [ ] 키보드 네비게이션 지원
- [ ] 시맨틱 HTML 사용
- [ ] 폼 필드 label 연결

### UX
- [ ] 라이트/다크 모드 지원
- [ ] CTA 버튼 44x44px 이상
- [ ] 로딩 상태 피드백
- [ ] 반응형 레이아웃

---

## SEO Checklist

### 메타데이터
- [ ] metadataBase 설정
- [ ] title 템플릿 설정
- [ ] 각 페이지 고유 title/description
- [ ] keywords 설정

### Open Graph
- [ ] og.png 존재 (1200x630)
- [ ] openGraph 설정
- [ ] twitter card 설정

### 크롤링
- [ ] sitemap.ts 존재
- [ ] robots.ts 존재
- [ ] /sitemap.xml 접근 가능
- [ ] /robots.txt 접근 가능

### 구조화 데이터
- [ ] Organization schema
- [ ] Product schema (상품 페이지)
- [ ] Article schema (블로그)
- [ ] FAQ schema (FAQ 페이지)

### 기타
- [ ] favicon 설정
- [ ] apple-icon 설정
- [ ] canonical URL 설정
- [ ] Google Search Console 연동

---

## 점수 기준

| 점수 | 등급 | 의미 |
|------|------|------|
| 25-30 | 🟢 우수 | 배포 준비 완료 |
| 18-24 | 🟡 양호 | 마이너 이슈 존재, 배포 가능 |
| 10-17 | 🟠 개선 필요 | 주요 이슈 해결 후 배포 권장 |
| 0-9 | 🔴 긴급 | 배포 불가, 즉시 조치 필요 |
