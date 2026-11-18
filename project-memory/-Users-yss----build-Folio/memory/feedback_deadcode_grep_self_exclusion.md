---
name: deadcode-grep-self-exclusion
description: dead 컴포넌트 삭제 검증 시 grep 제외 패턴이 sibling import를 가릴 수 있음 — typecheck가 최종 검증자
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 98c9586b-c501-4328-a0e9-9855aaf89fc6
---

dead 컴포넌트 "미사용 여부"를 grep으로 확인할 때, **검증 대상 파일 자신을 제외하는 패턴이 형제 파일의 import 라인까지 가려** false "dead" 판정을 낼 수 있다.

**Why**: PR #198(dead 정리)에서 `grep ... | grep -vE "live/(ActivityFeed|HeroCard|StatTile|LivePageHeader|ScopeToggle)\.tsx"`로 "ScopeToggle 사용처"를 확인. 그런데 제외 패턴에 `LivePageHeader.tsx`가 포함돼, **살아있는 LivePageHeader가 ScopeToggle을 import하는 라인**이 결과에서 사라짐 → ScopeToggle을 dead로 오판하고 삭제. typecheck가 `Cannot find module './ScopeToggle'`로 즉시 잡아냄 → 복원.

**How to apply**:
- dead-code 삭제 후 **반드시 typecheck를 먼저 돌려** dangling reference를 잡는다 (grep 판정만 믿지 말 것). 삭제 전후 typecheck가 안전망.
- grep 제외 패턴 작성 시, 제외하려는 파일이 **다른 삭제 후보의 import 소비자**일 수 있음을 의식. 차라리 제외 없이 전체 결과를 보고 "디렉터리 내부 vs 외부"를 눈으로 구분하는 편이 안전.
- 삭제는 git rm 후 typecheck→lint→test→build 순. 관련: [[plan-step-vs-pr-granularity]]