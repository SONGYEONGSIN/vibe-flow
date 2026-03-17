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
 * 비교 대상 속성:
 *   - 타이포그래피: fontSize, fontWeight, lineHeight, letterSpacing, fontFamily,
 *     fontStyle, textAlign, textTransform, textDecoration, textOverflow,
 *     whiteSpace, wordBreak, overflowWrap
 *   - 레이아웃: display, flexDirection, flexWrap, alignItems, justifyContent,
 *     gridTemplateColumns, gridTemplateRows, gridColumn, gridRow,
 *     flexGrow, flexShrink, flexBasis, placeItems, order, gap
 *   - 스페이싱: padding, margin
 *   - 비주얼: borderRadius, borderColor, backgroundColor, color, boxShadow,
 *     overflow, aspectRatio, objectFit, objectPosition, mixBlendMode,
 *     visibility, pointerEvents, userSelect, resize
 *   - 스크롤: scrollBehavior, scrollSnapType, scrollSnapAlign
 *   - 기타: appearance, listStyleType, isolation, columns, filter,
 *     backdropFilter, maxWidth, transformOrigin, outline, textShadow,
 *     backgroundImage, accentColor, caretColor
 *   - 검색/필터/드롭다운: searchInput*, dropdownItem*, chipBgColor, filterBar* 등
 *
 * 사용법:
 *   node scripts/component-map.js
 *
 * 필요 파일:
 *   - inventory.json (Phase 2 extract-inventory.js 출력물)
 *   - src/components/ 디렉토리 (로컬 코드베이스)
 *   - tokens.json (선택 — Phase 1 extract-tokens.js 출력물)
 *
 * @see SKILL.md Phase 4 (섹션 4.2 TAILWIND_MAP, 섹션 4.4 스크립트 템플릿 D)
 */

import fs from 'fs';
import path from 'path';

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
    heading: [], // 페이지 파일에서 직접 사용
    button: [],
    search: ['ui/search-input.tsx', 'ui/search-bar.tsx'],
    dropdown: ['ui/dropdown.tsx', 'ui/dropdown-menu.tsx', 'ui/select.tsx'],
    chip: ['ui/chip.tsx', 'ui/tag.tsx', 'ui/filter-chip.tsx'],
    'filter-bar': ['ui/filter-bar.tsx', 'ui/toolbar.tsx'],
  },
};

// CSS 속성값 → Tailwind 클래스 변환 맵 (SKILL.md 4.2절)
const TAILWIND_MAP = {
  fontSize: {
    '12px': 'text-xs', '14px': 'text-sm', '16px': 'text-base',
    '18px': 'text-lg', '20px': 'text-xl', '24px': 'text-2xl',
    '30px': 'text-3xl', '36px': 'text-4xl',
  },
  fontWeight: {
    '100': 'font-thin', '200': 'font-extralight', '300': 'font-light', '400': 'font-normal',
    '500': 'font-medium', '600': 'font-semibold', '700': 'font-bold',
    '800': 'font-extrabold', '900': 'font-black',
  },
  lineHeight: {
    '16px': 'leading-4', '20px': 'leading-5', '24px': 'leading-6',
    '28px': 'leading-7', '32px': 'leading-8', '36px': 'leading-9',
    '40px': 'leading-10', '1': 'leading-none', '1.25': 'leading-tight',
    '1.375': 'leading-snug', '1.5': 'leading-normal', '1.625': 'leading-relaxed',
    '2': 'leading-loose',
  },
  letterSpacing: {
    '-0.05em': 'tracking-tighter', '-0.025em': 'tracking-tight',
    '0em': 'tracking-normal', 'normal': 'tracking-normal',
    '0.025em': 'tracking-wide', '0.05em': 'tracking-wider',
    '0.1em': 'tracking-widest',
  },
  fontStyle: {
    'italic': 'italic', 'normal': 'not-italic',
  },
  textAlign: {
    'left': 'text-left', 'center': 'text-center', 'right': 'text-right',
    'justify': 'text-justify', 'start': 'text-start', 'end': 'text-end',
  },
  textTransform: {
    'uppercase': 'uppercase', 'lowercase': 'lowercase',
    'capitalize': 'capitalize', 'none': 'normal-case',
  },
  whiteSpace: {
    'nowrap': 'whitespace-nowrap', 'pre': 'whitespace-pre',
    'pre-line': 'whitespace-pre-line', 'pre-wrap': 'whitespace-pre-wrap',
    'break-spaces': 'whitespace-break-spaces', 'normal': 'whitespace-normal',
  },
  wordBreak: {
    'break-all': 'break-all', 'keep-all': 'break-keep',
  },
  overflowWrap: {
    'break-word': 'break-words',
  },
  textDecoration: {
    'underline': 'underline', 'overline': 'overline',
    'line-through': 'line-through', 'none': 'no-underline',
  },
  textOverflow: {
    'ellipsis': 'truncate',
  },
  overflow: {
    'hidden': 'overflow-hidden', 'auto': 'overflow-auto',
    'scroll': 'overflow-scroll', 'visible': 'overflow-visible',
  },
  display: {
    'flex': 'flex', 'inline-flex': 'inline-flex',
    'grid': 'grid', 'inline-grid': 'inline-grid',
    'block': 'block', 'inline-block': 'inline-block',
    'inline': 'inline', 'none': 'hidden',
  },
  flexDirection: {
    'row': 'flex-row', 'row-reverse': 'flex-row-reverse',
    'column': 'flex-col', 'column-reverse': 'flex-col-reverse',
  },
  flexWrap: {
    'wrap': 'flex-wrap', 'wrap-reverse': 'flex-wrap-reverse',
    'nowrap': 'flex-nowrap',
  },
  alignItems: {
    'flex-start': 'items-start', 'flex-end': 'items-end',
    'center': 'items-center', 'baseline': 'items-baseline',
    'stretch': 'items-stretch',
  },
  justifyContent: {
    'flex-start': 'justify-start', 'flex-end': 'justify-end',
    'center': 'justify-center', 'space-between': 'justify-between',
    'space-around': 'justify-around', 'space-evenly': 'justify-evenly',
  },
  gridTemplateColumns: (value) => {
    const repeatMatch = value.match(/repeat\((\d+),/);
    if (repeatMatch) return `grid-cols-${repeatMatch[1]}`;
    const colCount = value.split(/\s+/).length;
    return `grid-cols-${colCount}`;
  },
  gridTemplateRows: (value) => {
    const repeatMatch = value.match(/repeat\((\d+),/);
    if (repeatMatch) return `grid-rows-${repeatMatch[1]}`;
    const rowCount = value.split(/\s+/).length;
    return `grid-rows-${rowCount}`;
  },
  flexGrow: { '0': 'grow-0', '1': 'grow' },
  flexShrink: { '0': 'shrink-0', '1': 'shrink' },
  placeItems: {
    'center': 'place-items-center', 'start': 'place-items-start',
    'end': 'place-items-end', 'stretch': 'place-items-stretch',
  },
  order: {
    '-1': 'order-first', '0': 'order-none', '1': 'order-1',
    '2': 'order-2', '3': 'order-3', '9999': 'order-last',
  },
  borderRadius: {
    '0px': 'rounded-none', '2px': 'rounded-sm', '4px': 'rounded', '6px': 'rounded-md',
    '8px': 'rounded-lg', '12px': 'rounded-xl', '16px': 'rounded-2xl',
    '9999px': 'rounded-full',
  },
  borderWidth: {
    '0px': 'border-0', '1px': 'border', '2px': 'border-2',
    '4px': 'border-4', '8px': 'border-8',
  },
  iconSize: {
    '12px': 'w-3 h-3', '16px': 'w-4 h-4', '20px': 'w-5 h-5',
    '24px': 'w-6 h-6', '32px': 'w-8 h-8', '40px': 'w-10 h-10',
    '48px': 'w-12 h-12',
  },
  zIndex: {
    '0': 'z-0', '10': 'z-10', '20': 'z-20', '30': 'z-30',
    '40': 'z-40', '50': 'z-50',
  },
  spacing: (px) => {
    const rem = parseFloat(px) / 4;
    const map = { 0:'0', 1:'1', 2:'2', 3:'3', 4:'4', 5:'5', 6:'6', 8:'8',
      10:'10', 12:'12', 16:'16', 20:'20', 24:'24' };
    return map[rem] || `[${px}]`;
  },
  // --- 새 속성 매핑 ---
  aspectRatio: {
    'auto': 'aspect-auto', '1 / 1': 'aspect-square',
    '16 / 9': 'aspect-video', '4 / 3': 'aspect-[4/3]',
  },
  objectFit: {
    'contain': 'object-contain', 'cover': 'object-cover',
    'fill': 'object-fill', 'none': 'object-none', 'scale-down': 'object-scale-down',
  },
  objectPosition: {
    '50% 50%': 'object-center', '50% 0%': 'object-top', '50% 100%': 'object-bottom',
    '0% 50%': 'object-left', '100% 50%': 'object-right',
  },
  mixBlendMode: {
    'multiply': 'mix-blend-multiply', 'screen': 'mix-blend-screen',
    'overlay': 'mix-blend-overlay', 'darken': 'mix-blend-darken',
    'lighten': 'mix-blend-lighten', 'color-dodge': 'mix-blend-color-dodge',
    'difference': 'mix-blend-difference', 'exclusion': 'mix-blend-exclusion',
  },
  isolation: { 'isolate': 'isolate', 'auto': 'isolation-auto' },
  visibility: { 'visible': 'visible', 'hidden': 'invisible', 'collapse': 'collapse' },
  pointerEvents: { 'none': 'pointer-events-none', 'auto': 'pointer-events-auto' },
  userSelect: {
    'none': 'select-none', 'text': 'select-text', 'all': 'select-all', 'auto': 'select-auto',
  },
  resize: {
    'both': 'resize', 'horizontal': 'resize-x', 'vertical': 'resize-y', 'none': 'resize-none',
  },
  scrollBehavior: { 'smooth': 'scroll-smooth', 'auto': 'scroll-auto' },
  scrollSnapType: {
    'x mandatory': 'snap-x snap-mandatory', 'y mandatory': 'snap-y snap-mandatory',
    'x proximity': 'snap-x', 'y proximity': 'snap-y',
    'both mandatory': 'snap-both snap-mandatory',
  },
  scrollSnapAlign: {
    'start': 'snap-start', 'end': 'snap-end', 'center': 'snap-center',
  },
  appearance: { 'none': 'appearance-none', 'auto': 'appearance-auto' },
  listStyleType: {
    'disc': 'list-disc', 'decimal': 'list-decimal', 'none': 'list-none',
  },
  columns: {
    '1': 'columns-1', '2': 'columns-2', '3': 'columns-3', '4': 'columns-4',
  },
  backdropFilter: (value) => {
    if (value.includes('blur')) {
      const m = value.match(/blur\((\d+)px\)/);
      if (m) {
        const blurMap = { 4:'backdrop-blur-sm', 8:'backdrop-blur', 12:'backdrop-blur-md',
          16:'backdrop-blur-lg', 24:'backdrop-blur-xl', 40:'backdrop-blur-2xl', 64:'backdrop-blur-3xl' };
        return blurMap[m[1]] || `backdrop-blur-[${m[1]}px]`;
      }
    }
    return null;
  },
  filter: (value) => {
    const parts = [];
    const blurM = value.match(/blur\((\d+)px\)/);
    if (blurM) {
      const bMap = { 0:'blur-none', 4:'blur-sm', 8:'blur', 12:'blur-md', 16:'blur-lg', 24:'blur-xl', 40:'blur-2xl', 64:'blur-3xl' };
      parts.push(bMap[blurM[1]] || `blur-[${blurM[1]}px]`);
    }
    if (value.includes('grayscale(1)')) parts.push('grayscale');
    if (value.includes('invert(1)')) parts.push('invert');
    if (value.includes('sepia(1)')) parts.push('sepia');
    const brightM = value.match(/brightness\(([\d.]+)\)/);
    if (brightM) {
      const v = Math.round(parseFloat(brightM[1]) * 100);
      parts.push(`brightness-${v}`);
    }
    const contrastM = value.match(/contrast\(([\d.]+)\)/);
    if (contrastM) {
      const v = Math.round(parseFloat(contrastM[1]) * 100);
      parts.push(`contrast-${v}`);
    }
    const saturateM = value.match(/saturate\(([\d.]+)\)/);
    if (saturateM) {
      const v = Math.round(parseFloat(saturateM[1]) * 100);
      parts.push(`saturate-${v}`);
    }
    return parts.length > 0 ? parts.join(' ') : null;
  },
  transformOrigin: {
    'center': 'origin-center', 'top': 'origin-top', 'top right': 'origin-top-right',
    'right': 'origin-right', 'bottom right': 'origin-bottom-right', 'bottom': 'origin-bottom',
    'bottom left': 'origin-bottom-left', 'left': 'origin-left', 'top left': 'origin-top-left',
  },
  maxWidth: (value) => {
    const map = { '0px':'max-w-0', '320px':'max-w-xs', '384px':'max-w-sm', '448px':'max-w-md',
      '512px':'max-w-lg', '576px':'max-w-xl', '672px':'max-w-2xl', '768px':'max-w-3xl',
      '896px':'max-w-4xl', '1024px':'max-w-5xl', '1152px':'max-w-6xl', '1280px':'max-w-7xl',
      'none':'max-w-none', '100%':'max-w-full' };
    return map[value] || `max-w-[${value}]`;
  },
  minHeight: (value) => {
    const map = { '0px':'min-h-0', '100%':'min-h-full', '100vh':'min-h-screen',
      '100dvh':'min-h-dvh', '100svh':'min-h-svh' };
    return map[value] || `min-h-[${value}]`;
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
    // Template literal className
    const tmplMatches = [...line.matchAll(/className=\{`([^`]+)`\}/g)];
    for (const m of tmplMatches) {
      results.push({ line: idx + 1, classes: m[1], raw: line.trim() });
    }
  });

  return results;
}

function suggestChange(refValue, property) {
  const map = TAILWIND_MAP[property];
  if (!map) return null;
  return map[refValue] || null;
}

(async () => {
  const inventory = JSON.parse(fs.readFileSync(INVENTORY_PATH, 'utf-8'));
  const mapping = { mappings: [] };

  // 각 페이지의 각 영역 처리
  for (const [pageName, areas] of Object.entries(inventory.pages)) {
    for (const [area, types] of Object.entries(areas)) {
      for (const [type, elements] of Object.entries(types)) {
        // 대상 파일 찾기
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

          // 각 참고 요소의 CSS vs 파일의 클래스 비교
          for (const refEl of elements.slice(0, 5)) {
            for (const fc of fileClasses) {
              // fontSize 비교
              const refFS = refEl.fontSize;
              const twFS = TAILWIND_MAP.fontSize[refFS];
              if (twFS && !fc.classes.includes(twFS)) {
                const currentTW = Object.values(TAILWIND_MAP.fontSize).find(v => fc.classes.includes(v));
                if (currentTW && currentTW !== twFS) {
                  diffs.push({
                    line: fc.line,
                    property: 'fontSize',
                    reference: `${refFS} (${twFS})`,
                    current: currentTW,
                    suggestion: `${currentTW} → ${twFS}`,
                  });
                }
              }

              // fontWeight 비교
              const refFW = refEl.fontWeight;
              const twFW = TAILWIND_MAP.fontWeight[refFW];
              if (twFW && !fc.classes.includes(twFW)) {
                const currentTW = Object.values(TAILWIND_MAP.fontWeight).find(v => fc.classes.includes(v));
                if (currentTW && currentTW !== twFW) {
                  diffs.push({
                    line: fc.line,
                    property: 'fontWeight',
                    reference: `w:${refFW} (${twFW})`,
                    current: currentTW,
                    suggestion: `${currentTW} → ${twFW}`,
                  });
                }
              }

              // lineHeight 비교
              const refLH = refEl.lineHeight;
              const twLH = TAILWIND_MAP.lineHeight[refLH];
              if (twLH && !fc.classes.includes(twLH)) {
                const currentTW = Object.values(TAILWIND_MAP.lineHeight).find(v => fc.classes.includes(v));
                if (currentTW && currentTW !== twLH) {
                  diffs.push({
                    line: fc.line,
                    property: 'lineHeight',
                    reference: `${refLH} (${twLH})`,
                    current: currentTW,
                    suggestion: `${currentTW} → ${twLH}`,
                  });
                }
              }

              // letterSpacing 비교
              const refLS = refEl.letterSpacing;
              const twLS = TAILWIND_MAP.letterSpacing[refLS];
              if (twLS && !fc.classes.includes(twLS)) {
                const currentTW = Object.values(TAILWIND_MAP.letterSpacing).find(v => fc.classes.includes(v));
                if (currentTW && currentTW !== twLS) {
                  diffs.push({
                    line: fc.line,
                    property: 'letterSpacing',
                    reference: `${refLS} (${twLS})`,
                    current: currentTW,
                    suggestion: `${currentTW} → ${twLS}`,
                  });
                }
              }

              // padding 비교
              if (refEl.padding && refEl.padding !== '0px') {
                const padValues = refEl.padding.split(' ').map(v => parseFloat(v));
                for (const [idx, dir] of ['t','r','b','l'].entries()) {
                  const pv = padValues[idx] || padValues[0];
                  const pvRem = pv / 4;
                  const spMap = { 0:'0',1:'1',2:'2',3:'3',4:'4',5:'5',6:'6',8:'8',10:'10',12:'12',16:'16',20:'20',24:'24' };
                  const twP = spMap[pvRem] ? `p${dir}-${spMap[pvRem]}` : null;
                  // 축약형도 체크 (px-, py-, p-)
                  if (twP && !fc.classes.includes(twP)) {
                    const pxClass = `px-${spMap[pvRem]}`;
                    const pyClass = `py-${spMap[pvRem]}`;
                    const pClass = `p-${spMap[pvRem]}`;
                    if (!fc.classes.includes(pxClass) && !fc.classes.includes(pyClass) && !fc.classes.includes(pClass)) {
                      diffs.push({
                        line: fc.line, property: `padding-${dir}`,
                        reference: `${pv}px (${twP})`,
                        current: '', suggestion: `→ ${twP}`,
                      });
                    }
                  }
                }
              }

              // margin 비교 (padding과 동일 패턴)
              if (refEl.margin && refEl.margin !== '0px') {
                const mValues = refEl.margin.split(' ').map(v => parseFloat(v));
                for (const [idx, dir] of ['t','r','b','l'].entries()) {
                  const mv = mValues[idx] || mValues[0];
                  const mvRem = mv / 4;
                  const spMap = { 0:'0',1:'1',2:'2',3:'3',4:'4',5:'5',6:'6',8:'8',10:'10',12:'12',16:'16',20:'20',24:'24' };
                  const twM = spMap[mvRem] ? `m${dir}-${spMap[mvRem]}` : null;
                  if (twM && !fc.classes.includes(twM)) {
                    const mxClass = `mx-${spMap[mvRem]}`;
                    const myClass = `my-${spMap[mvRem]}`;
                    const mClass = `m-${spMap[mvRem]}`;
                    if (!fc.classes.includes(mxClass) && !fc.classes.includes(myClass) && !fc.classes.includes(mClass)) {
                      diffs.push({
                        line: fc.line, property: `margin-${dir}`,
                        reference: `${mv}px (${twM})`,
                        current: '', suggestion: `→ ${twM}`,
                      });
                    }
                  }
                }
              }

              // borderRadius 비교
              if (refEl.borderRadius) {
                const brMap = { '0px':'rounded-none','2px':'rounded-sm','4px':'rounded','6px':'rounded-md','8px':'rounded-lg','12px':'rounded-xl','16px':'rounded-2xl','9999px':'rounded-full' };
                const twBR = brMap[refEl.borderRadius];
                if (twBR && !fc.classes.includes(twBR)) {
                  const currentBR = Object.values(brMap).find(v => fc.classes.includes(v));
                  if (currentBR && currentBR !== twBR) {
                    diffs.push({
                      line: fc.line, property: 'borderRadius',
                      reference: `${refEl.borderRadius} (${twBR})`,
                      current: currentBR, suggestion: `${currentBR} → ${twBR}`,
                    });
                  }
                }
              }

              // backgroundColor 비교 (gray 스케일)
              if (refEl.bgColor && refEl.bgColor !== 'rgba(0, 0, 0, 0)') {
                const bgMap = {
                  'rgb(249, 250, 251)': 'bg-gray-50', 'rgb(243, 244, 246)': 'bg-gray-100',
                  'rgb(229, 231, 235)': 'bg-gray-200', 'rgb(209, 213, 219)': 'bg-gray-300',
                  'rgb(255, 255, 255)': 'bg-white',
                };
                const twBG = bgMap[refEl.bgColor];
                if (twBG) {
                  const currentBG = Object.values(bgMap).find(v => fc.classes.includes(v.replace('bg-', '')));
                  if (currentBG && currentBG !== twBG) {
                    diffs.push({
                      line: fc.line, property: 'backgroundColor',
                      reference: twBG, current: currentBG,
                      suggestion: `${currentBG} → ${twBG}`,
                    });
                  }
                }
              }

              // color (텍스트) 비교
              if (refEl.color) {
                const colorMap = {
                  'rgb(17, 24, 39)': 'text-gray-900', 'rgb(31, 41, 55)': 'text-gray-800',
                  'rgb(55, 65, 81)': 'text-gray-700', 'rgb(75, 85, 99)': 'text-gray-600',
                  'rgb(107, 114, 128)': 'text-gray-500', 'rgb(156, 163, 175)': 'text-gray-400',
                  'rgb(209, 213, 219)': 'text-gray-300',
                };
                const twColor = colorMap[refEl.color];
                if (twColor) {
                  const currentColor = Object.values(colorMap).find(v => fc.classes.includes(v.replace('text-', '')));
                  if (currentColor && currentColor !== twColor) {
                    diffs.push({
                      line: fc.line, property: 'color',
                      reference: twColor, current: currentColor,
                      suggestion: `${currentColor} → ${twColor}`,
                    });
                  }
                }
              }

              // boxShadow 비교
              if (refEl.boxShadow) {
                const shadowMap = {
                  'none': 'shadow-none',
                  '0 1px 2px 0 rgba(0,0,0,0.05)': 'shadow-sm',
                  '0 1px 3px 0 rgba(0,0,0,0.1)': 'shadow',
                  '0 4px 6px -1px rgba(0,0,0,0.1)': 'shadow-md',
                  '0 10px 15px -3px rgba(0,0,0,0.1)': 'shadow-lg',
                };
                // 근사 매칭 (shadow 값은 정확히 안 맞을 수 있어서 패턴 매칭)
                let twShadow = null;
                if (refEl.boxShadow.includes('10px') || refEl.boxShadow.includes('15px')) twShadow = 'shadow-lg';
                else if (refEl.boxShadow.includes('4px') || refEl.boxShadow.includes('6px')) twShadow = 'shadow-md';
                else if (refEl.boxShadow.includes('1px 3px')) twShadow = 'shadow';
                else if (refEl.boxShadow.includes('1px 2px')) twShadow = 'shadow-sm';
                if (twShadow && !fc.classes.includes(twShadow)) {
                  const currentShadow = ['shadow-none','shadow-sm','shadow','shadow-md','shadow-lg','shadow-xl','shadow-2xl'].find(v => fc.classes.includes(v));
                  if (currentShadow && currentShadow !== twShadow) {
                    diffs.push({
                      line: fc.line, property: 'boxShadow',
                      reference: `(${twShadow})`, current: currentShadow,
                      suggestion: `${currentShadow} → ${twShadow}`,
                    });
                  }
                }
              }

              // fontStyle 비교
              if (refEl.fontStyle) {
                const twFSt = { 'italic':'italic' }[refEl.fontStyle];
                if (twFSt && !fc.classes.includes(twFSt)) {
                  diffs.push({
                    line: fc.line, property: 'fontStyle',
                    reference: `${refEl.fontStyle} (${twFSt})`,
                    current: 'normal', suggestion: `→ ${twFSt}`,
                  });
                }
              }

              // textAlign 비교
              if (refEl.textAlign && refEl.textAlign !== 'start') {
                const twTA = { 'left':'text-left', 'center':'text-center', 'right':'text-right', 'justify':'text-justify' }[refEl.textAlign];
                if (twTA && !fc.classes.includes(twTA)) {
                  const currentTA = ['text-left','text-center','text-right','text-justify'].find(v => fc.classes.includes(v));
                  if (currentTA && currentTA !== twTA) {
                    diffs.push({
                      line: fc.line, property: 'textAlign',
                      reference: `${refEl.textAlign} (${twTA})`,
                      current: currentTA, suggestion: `${currentTA} → ${twTA}`,
                    });
                  }
                }
              }

              // textTransform 비교
              if (refEl.textTransform && refEl.textTransform !== 'none') {
                const twTT = { 'uppercase':'uppercase', 'lowercase':'lowercase', 'capitalize':'capitalize' }[refEl.textTransform];
                if (twTT && !fc.classes.includes(twTT)) {
                  diffs.push({
                    line: fc.line, property: 'textTransform',
                    reference: `${refEl.textTransform} (${twTT})`,
                    current: 'none', suggestion: `→ ${twTT}`,
                  });
                }
              }

              // whiteSpace 비교
              if (refEl.whiteSpace) {
                const twWS = { 'nowrap':'whitespace-nowrap', 'pre':'whitespace-pre', 'pre-line':'whitespace-pre-line', 'pre-wrap':'whitespace-pre-wrap' }[refEl.whiteSpace];
                if (twWS && !fc.classes.includes(twWS)) {
                  diffs.push({
                    line: fc.line, property: 'whiteSpace',
                    reference: `${refEl.whiteSpace} (${twWS})`,
                    current: 'normal', suggestion: `→ ${twWS}`,
                  });
                }
              }

              // wordBreak 비교
              if (refEl.wordBreak) {
                const twWB = { 'break-all':'break-all', 'keep-all':'break-keep' }[refEl.wordBreak];
                if (twWB && !fc.classes.includes(twWB)) {
                  diffs.push({
                    line: fc.line, property: 'wordBreak',
                    reference: `${refEl.wordBreak} (${twWB})`,
                    current: 'normal', suggestion: `→ ${twWB}`,
                  });
                }
              }

              // overflowWrap 비교
              if (refEl.overflowWrap) {
                const twOW = { 'break-word':'break-words' }[refEl.overflowWrap];
                if (twOW && !fc.classes.includes(twOW)) {
                  diffs.push({
                    line: fc.line, property: 'overflowWrap',
                    reference: `${refEl.overflowWrap} (${twOW})`,
                    current: 'normal', suggestion: `→ ${twOW}`,
                  });
                }
              }

              // textDecoration 비교
              if (refEl.textDecoration) {
                const twTD = { 'underline':'underline', 'line-through':'line-through', 'overline':'overline' }[refEl.textDecoration];
                if (twTD && !fc.classes.includes(twTD)) {
                  diffs.push({
                    line: fc.line, property: 'textDecoration',
                    reference: `${refEl.textDecoration} (${twTD})`,
                    current: 'none', suggestion: `→ ${twTD}`,
                  });
                }
              }

              // textOverflow/overflow 비교
              if (refEl.textOverflow === 'ellipsis' && !fc.classes.includes('truncate')) {
                diffs.push({
                  line: fc.line, property: 'textOverflow',
                  reference: 'ellipsis (truncate)', current: 'clip',
                  suggestion: '→ truncate',
                });
              }
              if (refEl.overflow && refEl.overflow !== 'visible') {
                const twOF = { 'hidden':'overflow-hidden', 'auto':'overflow-auto', 'scroll':'overflow-scroll' }[refEl.overflow];
                if (twOF && !fc.classes.includes(twOF)) {
                  diffs.push({
                    line: fc.line, property: 'overflow',
                    reference: `${refEl.overflow} (${twOF})`,
                    current: '', suggestion: `→ ${twOF}`,
                  });
                }
              }

              // borderColor 비교 (gray 스케일)
              if (refEl.borderWidth && refEl.borderColor) {
                const borderColorMap = {
                  'rgb(229, 231, 235)': 'border-gray-200',
                  'rgb(209, 213, 219)': 'border-gray-300',
                  'rgb(156, 163, 175)': 'border-gray-400',
                };
                const twBC = borderColorMap[refEl.borderColor];
                if (twBC && !fc.classes.includes(twBC.replace('border-', ''))) {
                  const currentBC = Object.values(borderColorMap).find(v => fc.classes.includes(v.replace('border-', '')));
                  if (currentBC && currentBC !== twBC) {
                    diffs.push({
                      line: fc.line, property: 'borderColor',
                      reference: twBC, current: currentBC,
                      suggestion: `${currentBC} → ${twBC}`,
                    });
                  }
                }
              }

              // 아이콘 크기 비교
              if (refEl.svgWidth) {
                const iconSizeMap = { '12':'w-3 h-3', '16':'w-4 h-4', '20':'w-5 h-5', '24':'w-6 h-6', '32':'w-8 h-8' };
                const refSize = parseInt(refEl.svgWidth);
                const twIcon = iconSizeMap[String(refSize)];
                if (twIcon) {
                  const twW = twIcon.split(' ')[0]; // e.g., 'w-4'
                  if (!fc.classes.includes(twW)) {
                    const currentIcon = Object.values(iconSizeMap).map(v => v.split(' ')[0]).find(v => fc.classes.includes(v));
                    if (currentIcon) {
                      diffs.push({
                        line: fc.line, property: 'iconSize',
                        reference: `${refSize}px (${twIcon})`,
                        current: currentIcon, suggestion: `${currentIcon} → ${twW}`,
                      });
                    }
                  }
                }
              }

              // fontFamily 비교
              if (refEl.fontFamily) {
                const refFF = refEl.fontFamily;
                const fontClassPattern = /font-\[([^\]]+)\]|font-(sans|serif|mono)/;
                const currentFontMatch = fc.classes.match(fontClassPattern);
                const currentFont = currentFontMatch ? currentFontMatch[0] : null;
                const expectedFont = refFF.toLowerCase().includes('mono') ? 'font-mono'
                  : refFF.toLowerCase().includes('serif') ? 'font-serif' : 'font-sans';
                if (currentFont && currentFont !== expectedFont) {
                  diffs.push({
                    line: fc.line,
                    property: 'fontFamily',
                    reference: `${refFF} (${expectedFont})`,
                    current: currentFont,
                    suggestion: `${currentFont} → ${expectedFont}`,
                  });
                }
              }

              // flexDirection 비교
              if (refEl.flexDirection) {
                const twFD = { 'column':'flex-col', 'column-reverse':'flex-col-reverse', 'row-reverse':'flex-row-reverse' }[refEl.flexDirection];
                if (twFD && !fc.classes.includes(twFD)) {
                  const currentFD = ['flex-col','flex-col-reverse','flex-row-reverse','flex-row'].find(v => fc.classes.includes(v));
                  diffs.push({
                    line: fc.line, property: 'flexDirection',
                    reference: `${refEl.flexDirection} (${twFD})`,
                    current: currentFD || 'flex-row',
                    suggestion: `→ ${twFD}`,
                  });
                }
              }

              // flexWrap 비교
              if (refEl.flexWrap) {
                const twFW = { 'wrap':'flex-wrap', 'wrap-reverse':'flex-wrap-reverse' }[refEl.flexWrap];
                if (twFW && !fc.classes.includes(twFW)) {
                  diffs.push({
                    line: fc.line, property: 'flexWrap',
                    reference: `${refEl.flexWrap} (${twFW})`,
                    current: 'flex-nowrap', suggestion: `→ ${twFW}`,
                  });
                }
              }

              // alignItems 비교
              if (refEl.alignItems) {
                const twAI = { 'flex-start':'items-start', 'flex-end':'items-end', 'center':'items-center', 'baseline':'items-baseline', 'stretch':'items-stretch' }[refEl.alignItems];
                if (twAI && !fc.classes.includes(twAI)) {
                  const currentAI = ['items-start','items-end','items-center','items-baseline','items-stretch'].find(v => fc.classes.includes(v));
                  if (currentAI && currentAI !== twAI) {
                    diffs.push({
                      line: fc.line, property: 'alignItems',
                      reference: `${refEl.alignItems} (${twAI})`,
                      current: currentAI, suggestion: `${currentAI} → ${twAI}`,
                    });
                  }
                }
              }

              // justifyContent 비교
              if (refEl.justifyContent) {
                const twJC = { 'flex-start':'justify-start', 'flex-end':'justify-end', 'center':'justify-center', 'space-between':'justify-between', 'space-around':'justify-around', 'space-evenly':'justify-evenly' }[refEl.justifyContent];
                if (twJC && !fc.classes.includes(twJC)) {
                  const currentJC = ['justify-start','justify-end','justify-center','justify-between','justify-around','justify-evenly'].find(v => fc.classes.includes(v));
                  if (currentJC && currentJC !== twJC) {
                    diffs.push({
                      line: fc.line, property: 'justifyContent',
                      reference: `${refEl.justifyContent} (${twJC})`,
                      current: currentJC, suggestion: `${currentJC} → ${twJC}`,
                    });
                  }
                }
              }

              // gridTemplateColumns 비교
              if (refEl.gridTemplateColumns) {
                const repeatMatch = refEl.gridTemplateColumns.match(/repeat\((\d+),/);
                const colCount = repeatMatch ? repeatMatch[1] : refEl.gridTemplateColumns.split(/\s+/).length;
                const twGC = `grid-cols-${colCount}`;
                if (!fc.classes.includes(twGC)) {
                  const currentGC = fc.classes.match(/grid-cols-(\d+)/)?.[0];
                  if (currentGC) {
                    diffs.push({
                      line: fc.line, property: 'gridTemplateColumns',
                      reference: `${refEl.gridTemplateColumns} (${twGC})`,
                      current: currentGC, suggestion: `${currentGC} → ${twGC}`,
                    });
                  }
                }
              }

              // gridTemplateRows 비교
              if (refEl.gridTemplateRows) {
                const repeatMatch = refEl.gridTemplateRows.match(/repeat\((\d+),/);
                const rowCount = repeatMatch ? repeatMatch[1] : refEl.gridTemplateRows.split(/\s+/).length;
                const twGR = `grid-rows-${rowCount}`;
                if (!fc.classes.includes(twGR)) {
                  const currentGR = fc.classes.match(/grid-rows-(\d+)/)?.[0];
                  if (currentGR) {
                    diffs.push({
                      line: fc.line, property: 'gridTemplateRows',
                      reference: `${refEl.gridTemplateRows} (${twGR})`,
                      current: currentGR, suggestion: `${currentGR} → ${twGR}`,
                    });
                  }
                }
              }

              // gridColumn span 비교
              if (refEl.gridColumn) {
                const spanMatch = refEl.gridColumn.match(/span\s+(\d+)/);
                if (spanMatch) {
                  const twSpan = `col-span-${spanMatch[1]}`;
                  if (!fc.classes.includes(twSpan)) {
                    const currentSpan = fc.classes.match(/col-span-(\d+|full)/)?.[0];
                    if (currentSpan && currentSpan !== twSpan) {
                      diffs.push({
                        line: fc.line, property: 'gridColumn',
                        reference: `${refEl.gridColumn} (${twSpan})`,
                        current: currentSpan, suggestion: `${currentSpan} → ${twSpan}`,
                      });
                    }
                  }
                }
              }

              // gridRow span 비교
              if (refEl.gridRow) {
                const spanMatch = refEl.gridRow.match(/span\s+(\d+)/);
                if (spanMatch) {
                  const twSpan = `row-span-${spanMatch[1]}`;
                  if (!fc.classes.includes(twSpan)) {
                    const currentSpan = fc.classes.match(/row-span-(\d+|full)/)?.[0];
                    if (currentSpan && currentSpan !== twSpan) {
                      diffs.push({
                        line: fc.line, property: 'gridRow',
                        reference: `${refEl.gridRow} (${twSpan})`,
                        current: currentSpan, suggestion: `${currentSpan} → ${twSpan}`,
                      });
                    }
                  }
                }
              }

              // flexGrow/Shrink/Basis 비교
              if (refEl.flexGrow) {
                const twFG = { '0':'grow-0', '1':'grow' }[refEl.flexGrow];
                if (twFG && !fc.classes.includes(twFG)) {
                  diffs.push({
                    line: fc.line, property: 'flexGrow',
                    reference: `${refEl.flexGrow} (${twFG})`,
                    current: '', suggestion: `→ ${twFG}`,
                  });
                }
              }
              if (refEl.flexShrink) {
                const twFS = { '0':'shrink-0', '1':'shrink' }[refEl.flexShrink];
                if (twFS && !fc.classes.includes(twFS)) {
                  diffs.push({
                    line: fc.line, property: 'flexShrink',
                    reference: `${refEl.flexShrink} (${twFS})`,
                    current: '', suggestion: `→ ${twFS}`,
                  });
                }
              }
              if (refEl.flexBasis) {
                const basisPx = parseFloat(refEl.flexBasis);
                const basisMap = { 0:'basis-0', 64:'basis-16', 128:'basis-32', 256:'basis-64' };
                const twBasis = basisMap[basisPx] || `basis-[${refEl.flexBasis}]`;
                if (!fc.classes.includes(twBasis)) {
                  const currentBasis = fc.classes.match(/basis-(\d+|\[[\w%]+\])/)?.[0];
                  if (currentBasis && currentBasis !== twBasis) {
                    diffs.push({
                      line: fc.line, property: 'flexBasis',
                      reference: `${refEl.flexBasis} (${twBasis})`,
                      current: currentBasis, suggestion: `${currentBasis} → ${twBasis}`,
                    });
                  }
                }
              }

              // placeItems 비교
              if (refEl.placeItems) {
                const twPI = { 'center':'place-items-center', 'start':'place-items-start', 'end':'place-items-end', 'stretch':'place-items-stretch' }[refEl.placeItems];
                if (twPI && !fc.classes.includes(twPI)) {
                  diffs.push({
                    line: fc.line, property: 'placeItems',
                    reference: `${refEl.placeItems} (${twPI})`,
                    current: '', suggestion: `→ ${twPI}`,
                  });
                }
              }

              // order 비교
              if (refEl.order) {
                const twOrd = { '1':'order-1', '2':'order-2', '3':'order-3', '-1':'order-first', '9999':'order-last', '0':'order-none' }[refEl.order];
                if (twOrd && !fc.classes.includes(twOrd)) {
                  diffs.push({
                    line: fc.line, property: 'order',
                    reference: `${refEl.order} (${twOrd})`,
                    current: '', suggestion: `→ ${twOrd}`,
                  });
                }
              }

              // gap 비교
              if (refEl.gap) {
                const gapPx = parseFloat(refEl.gap);
                const gapRem = gapPx / 4;
                const gapMap = { 0:'0', 1:'1', 2:'2', 3:'3', 4:'4', 5:'5', 6:'6', 8:'8', 10:'10', 12:'12' };
                const twGap = gapMap[gapRem] ? `gap-${gapMap[gapRem]}` : `gap-[${gapPx}px]`;
                if (!fc.classes.includes(twGap)) {
                  const currentGap = fc.classes.match(/gap-(\d+|\[[\dpx]+\])/)?.[0];
                  if (currentGap && currentGap !== twGap) {
                    diffs.push({
                      line: fc.line, property: 'gap',
                      reference: `${refEl.gap} (${twGap})`,
                      current: currentGap, suggestion: `${currentGap} → ${twGap}`,
                    });
                  }
                }
              }

              // === 새 속성 비교 ===

              // aspectRatio 비교
              if (refEl.aspectRatio) {
                const twAR = TAILWIND_MAP.aspectRatio[refEl.aspectRatio];
                if (twAR && !fc.classes.includes(twAR)) {
                  diffs.push({ line: fc.line, property: 'aspectRatio', reference: `${refEl.aspectRatio} (${twAR})`, current: '', suggestion: `→ ${twAR}` });
                }
              }

              // objectFit 비교
              if (refEl.objectFit) {
                const twOF = TAILWIND_MAP.objectFit[refEl.objectFit];
                if (twOF && !fc.classes.includes(twOF)) {
                  diffs.push({ line: fc.line, property: 'objectFit', reference: `${refEl.objectFit} (${twOF})`, current: '', suggestion: `→ ${twOF}` });
                }
              }

              // objectPosition 비교
              if (refEl.objectPosition) {
                const twOP = TAILWIND_MAP.objectPosition[refEl.objectPosition];
                if (twOP && !fc.classes.includes(twOP)) {
                  diffs.push({ line: fc.line, property: 'objectPosition', reference: `${refEl.objectPosition} (${twOP})`, current: '', suggestion: `→ ${twOP}` });
                }
              }

              // mixBlendMode 비교
              if (refEl.mixBlendMode) {
                const twMBM = TAILWIND_MAP.mixBlendMode[refEl.mixBlendMode];
                if (twMBM && !fc.classes.includes(twMBM)) {
                  diffs.push({ line: fc.line, property: 'mixBlendMode', reference: `${refEl.mixBlendMode} (${twMBM})`, current: '', suggestion: `→ ${twMBM}` });
                }
              }

              // visibility 비교
              if (refEl.visibility) {
                const twVis = TAILWIND_MAP.visibility[refEl.visibility];
                if (twVis && !fc.classes.includes(twVis)) {
                  diffs.push({ line: fc.line, property: 'visibility', reference: `${refEl.visibility} (${twVis})`, current: '', suggestion: `→ ${twVis}` });
                }
              }

              // pointerEvents 비교
              if (refEl.pointerEvents) {
                const twPE = TAILWIND_MAP.pointerEvents[refEl.pointerEvents];
                if (twPE && !fc.classes.includes(twPE)) {
                  diffs.push({ line: fc.line, property: 'pointerEvents', reference: `${refEl.pointerEvents} (${twPE})`, current: '', suggestion: `→ ${twPE}` });
                }
              }

              // userSelect 비교
              if (refEl.userSelect) {
                const twUS = TAILWIND_MAP.userSelect[refEl.userSelect];
                if (twUS && !fc.classes.includes(twUS)) {
                  diffs.push({ line: fc.line, property: 'userSelect', reference: `${refEl.userSelect} (${twUS})`, current: '', suggestion: `→ ${twUS}` });
                }
              }

              // resize 비교
              if (refEl.resize) {
                const twRS = TAILWIND_MAP.resize[refEl.resize];
                if (twRS && !fc.classes.includes(twRS)) {
                  diffs.push({ line: fc.line, property: 'resize', reference: `${refEl.resize} (${twRS})`, current: '', suggestion: `→ ${twRS}` });
                }
              }

              // scrollBehavior 비교
              if (refEl.scrollBehavior) {
                const twSB = TAILWIND_MAP.scrollBehavior[refEl.scrollBehavior];
                if (twSB && !fc.classes.includes(twSB)) {
                  diffs.push({ line: fc.line, property: 'scrollBehavior', reference: `${refEl.scrollBehavior} (${twSB})`, current: '', suggestion: `→ ${twSB}` });
                }
              }

              // scrollSnapType 비교
              if (refEl.scrollSnapType) {
                const twSST = TAILWIND_MAP.scrollSnapType[refEl.scrollSnapType];
                if (twSST && !fc.classes.includes(twSST.split(' ')[0])) {
                  diffs.push({ line: fc.line, property: 'scrollSnapType', reference: `${refEl.scrollSnapType} (${twSST})`, current: '', suggestion: `→ ${twSST}` });
                }
              }

              // scrollSnapAlign 비교
              if (refEl.scrollSnapAlign) {
                const twSSA = TAILWIND_MAP.scrollSnapAlign[refEl.scrollSnapAlign];
                if (twSSA && !fc.classes.includes(twSSA)) {
                  diffs.push({ line: fc.line, property: 'scrollSnapAlign', reference: `${refEl.scrollSnapAlign} (${twSSA})`, current: '', suggestion: `→ ${twSSA}` });
                }
              }

              // appearance 비교
              if (refEl.appearance) {
                const twApp = TAILWIND_MAP.appearance[refEl.appearance];
                if (twApp && !fc.classes.includes(twApp)) {
                  diffs.push({ line: fc.line, property: 'appearance', reference: `${refEl.appearance} (${twApp})`, current: '', suggestion: `→ ${twApp}` });
                }
              }

              // listStyleType 비교
              if (refEl.listStyleType) {
                const twLS = TAILWIND_MAP.listStyleType[refEl.listStyleType];
                if (twLS && !fc.classes.includes(twLS)) {
                  diffs.push({ line: fc.line, property: 'listStyleType', reference: `${refEl.listStyleType} (${twLS})`, current: '', suggestion: `→ ${twLS}` });
                }
              }

              // isolation 비교
              if (refEl.isolation) {
                const twIso = TAILWIND_MAP.isolation[refEl.isolation];
                if (twIso && !fc.classes.includes(twIso)) {
                  diffs.push({ line: fc.line, property: 'isolation', reference: `${refEl.isolation} (${twIso})`, current: '', suggestion: `→ ${twIso}` });
                }
              }

              // columns 비교
              if (refEl.columns) {
                const twCol = TAILWIND_MAP.columns[refEl.columns];
                if (twCol && !fc.classes.includes(twCol)) {
                  diffs.push({ line: fc.line, property: 'columns', reference: `${refEl.columns} (${twCol})`, current: '', suggestion: `→ ${twCol}` });
                }
              }

              // filter 비교
              if (refEl.filter) {
                const twFilter = typeof TAILWIND_MAP.filter === 'function' ? TAILWIND_MAP.filter(refEl.filter) : null;
                if (twFilter) {
                  diffs.push({ line: fc.line, property: 'filter', reference: `${refEl.filter} (${twFilter})`, current: '', suggestion: `→ ${twFilter}` });
                }
              }

              // backdropFilter 비교
              if (refEl.backdropFilter) {
                const twBDF = typeof TAILWIND_MAP.backdropFilter === 'function' ? TAILWIND_MAP.backdropFilter(refEl.backdropFilter) : null;
                if (twBDF) {
                  diffs.push({ line: fc.line, property: 'backdropFilter', reference: `${refEl.backdropFilter} (${twBDF})`, current: '', suggestion: `→ ${twBDF}` });
                }
              }

              // maxWidth 비교
              if (refEl.maxWidth && refEl.maxWidth !== 'none') {
                const twMW = typeof TAILWIND_MAP.maxWidth === 'function' ? TAILWIND_MAP.maxWidth(refEl.maxWidth) : null;
                if (twMW && !fc.classes.includes(twMW)) {
                  const currentMW = fc.classes.match(/max-w-(\w+|\[[\w%]+\])/)?.[0];
                  if (currentMW && currentMW !== twMW) {
                    diffs.push({ line: fc.line, property: 'maxWidth', reference: `${refEl.maxWidth} (${twMW})`, current: currentMW, suggestion: `${currentMW} → ${twMW}` });
                  }
                }
              }

              // transformOrigin 비교
              if (refEl.transformOrigin) {
                const twTO = TAILWIND_MAP.transformOrigin[refEl.transformOrigin];
                if (twTO && !fc.classes.includes(twTO)) {
                  diffs.push({ line: fc.line, property: 'transformOrigin', reference: `${refEl.transformOrigin} (${twTO})`, current: '', suggestion: `→ ${twTO}` });
                }
              }

              // outline 비교
              if (refEl.outline) {
                // outline ring 패턴 검출
                if (refEl.outline.includes('2px') && !fc.classes.includes('ring-2') && !fc.classes.includes('outline')) {
                  diffs.push({ line: fc.line, property: 'outline', reference: refEl.outline, current: '', suggestion: '→ ring-2 또는 outline' });
                }
              }

              // textShadow 비교
              if (refEl.textShadow) {
                if (!fc.classes.includes('drop-shadow')) {
                  diffs.push({ line: fc.line, property: 'textShadow', reference: refEl.textShadow, current: '', suggestion: '→ drop-shadow-* (커스텀)' });
                }
              }

              // backgroundImage (gradient) 비교
              if (refEl.backgroundImage) {
                const hasGradient = fc.classes.match(/bg-gradient/);
                if (!hasGradient) {
                  diffs.push({ line: fc.line, property: 'backgroundImage', reference: refEl.backgroundImage.substring(0, 60), current: '', suggestion: '→ bg-gradient-to-* (커스텀)' });
                }
              }

              // accentColor 비교
              if (refEl.accentColor) {
                if (!fc.classes.match(/accent-/)) {
                  diffs.push({ line: fc.line, property: 'accentColor', reference: refEl.accentColor, current: '', suggestion: '→ accent-* (커스텀)' });
                }
              }

              // caretColor 비교
              if (refEl.caretColor) {
                if (!fc.classes.match(/caret-/)) {
                  diffs.push({ line: fc.line, property: 'caretColor', reference: refEl.caretColor, current: '', suggestion: '→ caret-* (커스텀)' });
                }
              }

              // === 검색/필터/드롭다운 전용 속성 비교 ===

              // 검색 인풋 속성
              if (refEl.searchInputPadding) {
                const padValues = refEl.searchInputPadding.split(' ').map(v => parseFloat(v));
                const spMap = { 0:'0',1:'1',2:'2',3:'3',4:'4',5:'5',6:'6',8:'8',10:'10',12:'12' };
                const pyVal = spMap[padValues[0] / 4];
                const pxVal = spMap[(padValues[1] || padValues[0]) / 4];
                if (pyVal && pxVal) {
                  const twPy = `py-${pyVal}`;
                  const twPx = `px-${pxVal}`;
                  if (!fc.classes.includes(twPy) || !fc.classes.includes(twPx)) {
                    diffs.push({ line: fc.line, property: 'searchInputPadding', reference: `${refEl.searchInputPadding} (${twPy} ${twPx})`, current: '', suggestion: `→ ${twPy} ${twPx}` });
                  }
                }
              }
              if (refEl.searchInputFontSize) {
                const twFS = TAILWIND_MAP.fontSize[refEl.searchInputFontSize];
                if (twFS && !fc.classes.includes(twFS)) {
                  diffs.push({ line: fc.line, property: 'searchInputFontSize', reference: `${refEl.searchInputFontSize} (${twFS})`, current: '', suggestion: `→ ${twFS}` });
                }
              }
              if (refEl.searchInputBorderRadius) {
                const brMap = { '2px':'rounded-sm','4px':'rounded','6px':'rounded-md','8px':'rounded-lg','12px':'rounded-xl','9999px':'rounded-full' };
                const twBR = brMap[refEl.searchInputBorderRadius];
                if (twBR && !fc.classes.includes(twBR)) {
                  diffs.push({ line: fc.line, property: 'searchInputBorderRadius', reference: `${refEl.searchInputBorderRadius} (${twBR})`, current: '', suggestion: `→ ${twBR}` });
                }
              }
              if (refEl.searchInputBgColor && refEl.searchInputBgColor !== 'rgba(0, 0, 0, 0)') {
                const bgMap = {
                  'rgb(249, 250, 251)': 'bg-gray-50', 'rgb(243, 244, 246)': 'bg-gray-100',
                  'rgb(255, 255, 255)': 'bg-white',
                };
                const twBG = bgMap[refEl.searchInputBgColor];
                if (twBG && !fc.classes.includes(twBG.replace('bg-', ''))) {
                  diffs.push({ line: fc.line, property: 'searchInputBgColor', reference: twBG, current: '', suggestion: `→ ${twBG}` });
                }
              }
              // 검색 아이콘
              if (refEl.searchIconSize) {
                const [w, h] = refEl.searchIconSize.split('\u00d7').map(s => parseInt(s.trim()));
                const iconMap = { 12:'w-3 h-3', 16:'w-4 h-4', 20:'w-5 h-5', 24:'w-6 h-6' };
                const twIcon = iconMap[w];
                if (twIcon) {
                  const twW = twIcon.split(' ')[0];
                  if (!fc.classes.includes(twW)) {
                    diffs.push({ line: fc.line, property: 'searchIconSize', reference: `${refEl.searchIconSize} (${twIcon})`, current: '', suggestion: `→ ${twIcon}` });
                  }
                }
              }
              if (refEl.searchIconColor) {
                const colorMap = {
                  'rgb(107, 114, 128)': 'text-gray-500', 'rgb(156, 163, 175)': 'text-gray-400',
                  'rgb(75, 85, 99)': 'text-gray-600',
                };
                const twColor = colorMap[refEl.searchIconColor];
                if (twColor && !fc.classes.includes(twColor.replace('text-', ''))) {
                  diffs.push({ line: fc.line, property: 'searchIconColor', reference: twColor, current: '', suggestion: `→ ${twColor}` });
                }
              }

              // 드롭다운 패널 속성
              if (refEl.dropdownMaxHeight) {
                const mhPx = parseFloat(refEl.dropdownMaxHeight);
                const twMH = mhPx <= 256 ? `max-h-64` : mhPx <= 384 ? 'max-h-96' : `max-h-[${mhPx}px]`;
                if (!fc.classes.includes(twMH) && !fc.classes.match(/max-h-/)) {
                  diffs.push({ line: fc.line, property: 'dropdownMaxHeight', reference: `${refEl.dropdownMaxHeight} (${twMH})`, current: '', suggestion: `→ ${twMH}` });
                }
              }
              if (refEl.dropdownOverflowY && refEl.dropdownOverflowY !== 'visible') {
                const twOF = { 'auto':'overflow-y-auto', 'scroll':'overflow-y-scroll', 'hidden':'overflow-y-hidden' }[refEl.dropdownOverflowY];
                if (twOF && !fc.classes.includes(twOF)) {
                  diffs.push({ line: fc.line, property: 'dropdownOverflowY', reference: `${refEl.dropdownOverflowY} (${twOF})`, current: '', suggestion: `→ ${twOF}` });
                }
              }
              if (refEl.dropdownPadding) {
                const padValues = refEl.dropdownPadding.split(' ').map(v => parseFloat(v));
                const spMap = { 0:'0',0.5:'0.5',1:'1',1.5:'1.5',2:'2',3:'3',4:'4' };
                const pyVal = spMap[padValues[0] / 4];
                if (pyVal) {
                  const twPy = `py-${pyVal}`;
                  if (!fc.classes.includes(twPy)) {
                    diffs.push({ line: fc.line, property: 'dropdownPadding', reference: `${refEl.dropdownPadding} (${twPy})`, current: '', suggestion: `→ ${twPy}` });
                  }
                }
              }
              // 드롭다운 아이템 속성
              if (refEl.dropdownItemPadding) {
                const padValues = refEl.dropdownItemPadding.split(' ').map(v => parseFloat(v));
                const spMap = { 0:'0',1:'1',2:'2',3:'3',4:'4',5:'5',6:'6',8:'8' };
                const pyVal = spMap[padValues[0] / 4];
                const pxVal = spMap[(padValues[1] || padValues[0]) / 4];
                if (pyVal && pxVal) {
                  const twPy = `py-${pyVal}`;
                  const twPx = `px-${pxVal}`;
                  if (!fc.classes.includes(twPy) || !fc.classes.includes(twPx)) {
                    diffs.push({ line: fc.line, property: 'dropdownItemPadding', reference: `${refEl.dropdownItemPadding} (${twPy} ${twPx})`, current: '', suggestion: `→ ${twPy} ${twPx}` });
                  }
                }
              }
              if (refEl.dropdownItemFontSize) {
                const twFS = TAILWIND_MAP.fontSize[refEl.dropdownItemFontSize];
                if (twFS && !fc.classes.includes(twFS)) {
                  diffs.push({ line: fc.line, property: 'dropdownItemFontSize', reference: `${refEl.dropdownItemFontSize} (${twFS})`, current: '', suggestion: `→ ${twFS}` });
                }
              }
              if (refEl.dropdownItemColor) {
                const colorMap = {
                  'rgb(17, 24, 39)': 'text-gray-900', 'rgb(55, 65, 81)': 'text-gray-700',
                  'rgb(75, 85, 99)': 'text-gray-600', 'rgb(107, 114, 128)': 'text-gray-500',
                };
                const twColor = colorMap[refEl.dropdownItemColor];
                if (twColor && !fc.classes.includes(twColor.replace('text-', ''))) {
                  diffs.push({ line: fc.line, property: 'dropdownItemColor', reference: twColor, current: '', suggestion: `→ ${twColor}` });
                }
              }

              // 필터 칩 속성
              if (refEl.chipBgColor && refEl.chipBgColor !== 'rgba(0, 0, 0, 0)') {
                const bgMap = {
                  'rgb(243, 244, 246)': 'bg-gray-100', 'rgb(229, 231, 235)': 'bg-gray-200',
                  'rgb(219, 234, 254)': 'bg-blue-100', 'rgb(239, 246, 255)': 'bg-blue-50',
                  'rgb(255, 255, 255)': 'bg-white',
                };
                const twBG = bgMap[refEl.chipBgColor];
                if (twBG && !fc.classes.includes(twBG.replace('bg-', ''))) {
                  diffs.push({ line: fc.line, property: 'chipBgColor', reference: twBG, current: '', suggestion: `→ ${twBG}` });
                }
              }
              if (refEl.chipActiveBgColor && refEl.chipActiveBgColor !== refEl.chipBgColor) {
                const bgMap = {
                  'rgb(37, 99, 235)': 'bg-blue-600', 'rgb(59, 130, 246)': 'bg-blue-500',
                  'rgb(219, 234, 254)': 'bg-blue-100', 'rgb(243, 244, 246)': 'bg-gray-100',
                };
                const twBG = bgMap[refEl.chipActiveBgColor];
                if (twBG) {
                  diffs.push({ line: fc.line, property: 'chipActiveBgColor', reference: twBG, current: '', suggestion: `활성 상태: → ${twBG}` });
                }
              }
              if (refEl.chipFontSize) {
                const twFS = TAILWIND_MAP.fontSize[refEl.chipFontSize];
                if (twFS && !fc.classes.includes(twFS)) {
                  diffs.push({ line: fc.line, property: 'chipFontSize', reference: `${refEl.chipFontSize} (${twFS})`, current: '', suggestion: `→ ${twFS}` });
                }
              }
              if (refEl.chipBorderRadius) {
                const brMap = { '2px':'rounded-sm','4px':'rounded','6px':'rounded-md','9999px':'rounded-full','16px':'rounded-2xl' };
                const twBR = brMap[refEl.chipBorderRadius];
                if (twBR && !fc.classes.includes(twBR)) {
                  diffs.push({ line: fc.line, property: 'chipBorderRadius', reference: `${refEl.chipBorderRadius} (${twBR})`, current: '', suggestion: `→ ${twBR}` });
                }
              }
              if (refEl.chipPadding) {
                const padValues = refEl.chipPadding.split(' ').map(v => parseFloat(v));
                const spMap = { 0:'0',0.5:'0.5',1:'1',1.5:'1.5',2:'2',3:'3',4:'4' };
                const pyVal = spMap[padValues[0] / 4];
                const pxVal = spMap[(padValues[1] || padValues[0]) / 4];
                if (pyVal && pxVal) {
                  diffs.push({ line: fc.line, property: 'chipPadding', reference: `${refEl.chipPadding} (py-${pyVal} px-${pxVal})`, current: '', suggestion: `→ py-${pyVal} px-${pxVal}` });
                }
              }

              // 필터 바 속성
              if (refEl.filterBarGap) {
                const gapPx = parseFloat(refEl.filterBarGap);
                const gapRem = gapPx / 4;
                const gapMap = { 1:'1', 2:'2', 3:'3', 4:'4', 6:'6', 8:'8' };
                const twGap = gapMap[gapRem] ? `gap-${gapMap[gapRem]}` : `gap-[${gapPx}px]`;
                if (!fc.classes.includes(twGap)) {
                  diffs.push({ line: fc.line, property: 'filterBarGap', reference: `${refEl.filterBarGap} (${twGap})`, current: '', suggestion: `→ ${twGap}` });
                }
              }
              if (refEl.filterBarFlexWrap && refEl.filterBarFlexWrap !== 'nowrap') {
                const twFW = { 'wrap':'flex-wrap', 'wrap-reverse':'flex-wrap-reverse' }[refEl.filterBarFlexWrap];
                if (twFW && !fc.classes.includes(twFW)) {
                  diffs.push({ line: fc.line, property: 'filterBarFlexWrap', reference: `${refEl.filterBarFlexWrap} (${twFW})`, current: '', suggestion: `→ ${twFW}` });
                }
              }
              if (refEl.filterBarAlignItems) {
                const twAI = { 'center':'items-center', 'flex-start':'items-start', 'flex-end':'items-end' }[refEl.filterBarAlignItems];
                if (twAI && !fc.classes.includes(twAI)) {
                  diffs.push({ line: fc.line, property: 'filterBarAlignItems', reference: `${refEl.filterBarAlignItems} (${twAI})`, current: '', suggestion: `→ ${twAI}` });
                }
              }
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

  // 출력
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
    // globals.css에서 로컬 CSS 변수 추출
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
})().catch(console.error);
