/**
 * @file component-map.js
 * @description Design-sync Phase 4 — 컴포넌트 매핑 및 디자인 차이 분석 스크립트
 *
 * 이 스크립트는 다음 작업을 수행합니다:
 *   1. inventory.json에서 참고 사이트의 UI 요소 정보를 읽음
 *   2. AREA_FILE_MAP을 사용하여 참고 요소를 로컬 코드베이스 파일에 매핑
 *   3. 각 파일의 className을 파싱하여 현재 Tailwind 클래스를 추출
 *   4. TAILWIND_MAP(CSS값 → Tailwind 클래스)을 사용하여 참고 CSS 속성과 로컬 클래스를 비교
 *   5. 불일치 항목에 대한 diff 제안을 파일별/라인별로 출력
 *   6. tokens.json이 있으면 CSS 변수도 비교
 *   7. 결과를 mapping.json으로 저장
 *
 * 사용법:
 *   node scripts/component-map.js
 *
 * 필요 파일:
 *   - inventory.json (Phase 2 extract-inventory.js 출력물)
 *   - src/components/ 디렉토리 (로컬 코드베이스)
 *   - tokens.json (선택 — Phase 1 extract-tokens.js 출력물)
 *
 * @see SKILL.md Phase 4
 * @see tailwind-map.js — CSS→Tailwind 변환 매핑
 * @see compare-properties.js — 속성별 비교 로직
 */

import fs from 'fs';
import path from 'path';
import { compareAll } from './compare-properties.js';

const INVENTORY_PATH = 'inventory.json';
const SRC_DIR = 'src/components';

// 영역 → 파일 매핑 (프로젝트별 수정 필요)
const AREA_FILE_MAP = {
  sidebar: ['layout/sidebar.tsx', 'layout/nav-item.tsx'],
  header: ['layout/header.tsx', 'layout/user-menu.tsx'],
  content: {
    card: ['ui/stat-card.tsx', 'dashboard/recent-tasks.tsx', 'dashboard/recent-work.tsx'],
    table: ['ui/data-table.tsx', 'employees/employee-table.tsx', 'tasks/task-table.tsx'],
    form: ['ui/form-field.tsx', 'employees/employee-filters.tsx', 'tasks/task-filters.tsx'],
    badge: ['ui/status-badge.tsx'],
    heading: [],
    button: [],
    search: ['ui/search-input.tsx', 'ui/search-bar.tsx'],
    dropdown: ['ui/dropdown.tsx', 'ui/dropdown-menu.tsx', 'ui/select.tsx'],
    chip: ['ui/chip.tsx', 'ui/tag.tsx', 'ui/filter-chip.tsx'],
    'filter-bar': ['ui/filter-bar.tsx', 'ui/toolbar.tsx'],
  },
};

function extractClassesFromFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const results = [];

  lines.forEach((line, idx) => {
    const matches = [...line.matchAll(/className="([^"]+)"/g)];
    for (const m of matches) {
      results.push({ line: idx + 1, classes: m[1], raw: line.trim() });
    }
    const tmplMatches = [...line.matchAll(/className=\{`([^`]+)`\}/g)];
    for (const m of tmplMatches) {
      results.push({ line: idx + 1, classes: m[1], raw: line.trim() });
    }
  });

  return results;
}

(async () => {
  const inventory = JSON.parse(fs.readFileSync(INVENTORY_PATH, 'utf-8'));
  const mapping = { mappings: [] };

  for (const [pageName, areas] of Object.entries(inventory.pages)) {
    for (const [area, types] of Object.entries(areas)) {
      for (const [type, elements] of Object.entries(types)) {
        let targetFiles = [];
        if (area === 'sidebar' || area === 'header') {
          targetFiles = AREA_FILE_MAP[area] || [];
        } else {
          targetFiles = AREA_FILE_MAP.content?.[type] || [];
        }

        for (const relFile of targetFiles) {
          const filePath = path.join(SRC_DIR, relFile);
          if (!fs.existsSync(filePath)) continue;

          const fileClasses = extractClassesFromFile(filePath);
          const diffs = [];

          for (const refEl of elements.slice(0, 5)) {
            for (const fc of fileClasses) {
              diffs.push(...compareAll(refEl, fc));
            }
          }

          if (diffs.length > 0) {
            mapping.mappings.push({
              page: pageName,
              area,
              type,
              file: filePath,
              diffs: diffs.filter((d, i, a) =>
                a.findIndex(x => x.line === d.line && x.property === d.property) === i),
            });
          }
        }
      }
    }
  }

  // 콘솔 출력
  for (const m of mapping.mappings) {
    console.log(`\n┌─── ${m.file} (${m.page}/${m.area}/${m.type}) ${'─'.repeat(30)}`);
    for (const d of m.diffs) {
      console.log(`│ Line ${d.line}: ${d.property}`);
      console.log(`│   참고: ${d.reference}`);
      console.log(`│   현재: ${d.current}`);
      console.log(`│   제안: ${d.suggestion}`);
    }
    console.log('└' + '─'.repeat(60));
  }

  // CSS 변수 비교 (tokens.json이 있으면)
  const tokensPath = 'tokens.json';
  if (fs.existsSync(tokensPath)) {
    const tokens = JSON.parse(fs.readFileSync(tokensPath, 'utf-8'));
    const refVars = tokens.tokens?.cssVariables?.light || {};
    const globalsPath = path.join('src/app', 'globals.css');
    if (fs.existsSync(globalsPath)) {
      const globalsContent = fs.readFileSync(globalsPath, 'utf-8');
      const localVars = {};
      const varRegex = /--([\w-]+):\s*([^;]+);/g;
      let match;
      while ((match = varRegex.exec(globalsContent)) !== null) {
        localVars[`--${match[1]}`] = match[2].trim();
      }
      console.log('\n┌─── CSS Variables Comparison ─────────────────────────');
      for (const [varName, refValue] of Object.entries(refVars)) {
        const localValue = localVars[varName];
        if (!localValue) {
          console.log(`│ ${varName}: MISSING in local`);
        } else if (localValue !== refValue) {
          console.log(`│ ${varName}: ${localValue} → ${refValue}`);
        }
      }
      console.log('└' + '─'.repeat(55));
    }
  }

  fs.writeFileSync('mapping.json', JSON.stringify(mapping, null, 2));
  console.log('\nSaved: mapping.json');
})().catch(err => { console.error(err); process.exit(1); });
