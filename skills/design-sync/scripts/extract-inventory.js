/**
 * Phase 2: 전체 페이지 컴포넌트 인벤토리 추출
 *
 * 한 번의 Playwright 실행으로 모든 페이지를 순회하며 모든 가시 요소를 추출한다.
 * 8 카테고리 × 21 속성 포맷으로 영역(sidebar/header/content)과 컴포넌트 타입을 자동 분류.
 *
 * 사용법: URL, CORRECTION, PAGES를 수정한 뒤 `node extract-inventory.js` 실행
 * 출력: inventory.json
 */

import { chromium } from 'playwright';
import fs from 'fs';

const URL = '<<URL>>';
const VIEWPORT = { width: 1366, height: 900 };
const CORRECTION = 1.0; // Phase 1에서 산출한 보정 계수
const PAGES = [
  // { name: 'dashboard', nav: 'Dashboard' },
];

function shorten4(t, r, b, l) {
  if (t === r && r === b && b === l) return t;
  if (t === b && l === r) return `${t} ${r}`;
  return `${t} ${r} ${b} ${l}`;
}

const extractAll = (CORRECTION) => {
  // 랜드마크 감지
  const allDivs = [...document.querySelectorAll('div')];
  let sidebarRight = 0, headerBottom = 0;

  for (const d of allDivs) {
    const cs = getComputedStyle(d);
    const r = d.getBoundingClientRect();
    if (cs.position === 'fixed' && r.left < 5 && r.width > 150 && r.width < 300 && r.height > 400) {
      sidebarRight = r.right;
    }
  }
  for (const d of allDivs) {
    const r = d.getBoundingClientRect();
    if (r.left >= sidebarRight && r.top < 10 && r.height > 30 && r.height < 80 && r.width > 500) {
      headerBottom = r.bottom;
      break;
    }
  }

  function classifyArea(rect) {
    if (rect.left < sidebarRight) return 'sidebar';
    if (rect.top < headerBottom && rect.left >= sidebarRight) return 'header';
    return 'content';
  }

  function classifyType(tag, el, cs) {
    if (tag === 'svg' || (tag === 'img' && (el.src || '').includes('.svg'))) return 'icon';
    if (['table','thead','tbody','tr','th','td'].includes(tag)) return 'table';

    // 검색 컨테이너: input[type=search] 또는 relative wrapper + input + svg
    if (tag === 'input') {
      const type = el.getAttribute('type');
      const ph = (el.getAttribute('placeholder') || '').toLowerCase();
      if (type === 'search' || ph.includes('search') || ph.includes('검색') || ph.includes('찾기')) return 'search';
      const parent = el.parentElement;
      if (parent && getComputedStyle(parent).position === 'relative' && parent.querySelector('svg')) return 'search';
    }
    // 검색 컨테이너 wrapper
    if ((tag === 'div') && cs.position === 'relative') {
      const hasInput = el.querySelector('input');
      const hasSvg = el.querySelector('svg');
      if (hasInput && hasSvg) {
        const inputPh = (hasInput.getAttribute('placeholder') || '').toLowerCase();
        const inputType = hasInput.getAttribute('type');
        if (inputType === 'search' || inputPh.includes('search') || inputPh.includes('검색') || inputPh.includes('찾기')) return 'search';
      }
    }

    // 커스텀 드롭다운 패널: absolute + z-index≥10 + shadow/border + 내부 아이템
    if ((tag === 'div' || tag === 'ul') &&
        (cs.position === 'absolute' || cs.position === 'fixed') &&
        parseInt(cs.zIndex) >= 10 &&
        (cs.boxShadow !== 'none' || cs.borderWidth !== '0px')) {
      const children = el.querySelectorAll('li, a, div[role="option"], [class*="item"]');
      if (children.length >= 2) return 'dropdown';
    }

    // 필터 칩: inline-flex + rounded + bgColor + 작은 크기
    if ((tag === 'span' || tag === 'div' || tag === 'button') &&
        (cs.display === 'inline-flex' || cs.display === 'inline-block') &&
        cs.backgroundColor !== 'rgba(0, 0, 0, 0)') {
      const rect = el.getBoundingClientRect();
      if (rect.height < 40 && rect.width < 200 &&
          (cs.borderRadius.includes('9999') || parseInt(cs.borderRadius) >= 12)) return 'chip';
    }

    // 필터 바: flex + gap + 내부에 button/select 2개 이상
    if (tag === 'div' && (cs.display === 'flex' || cs.display === 'inline-flex') && cs.gap !== 'normal') {
      const controls = el.querySelectorAll('button, select, input[type="search"], input');
      if (controls.length >= 2) {
        const rect = el.getBoundingClientRect();
        if (rect.height < 80) return 'filter-bar';
      }
    }

    if (['input','select','textarea'].includes(tag)) return 'form';
    if (tag === 'button') return 'button';
    if (/^h[1-6]$/.test(tag)) return 'heading';
    if (tag === 'nav') return 'navigation';
    if ((tag === 'div' || tag === 'section') &&
        (cs.borderWidth !== '0px' || cs.boxShadow !== 'none') &&
        (cs.backgroundColor !== 'rgba(0, 0, 0, 0)' || cs.borderRadius !== '0px')) return 'card';
    if ((tag === 'span' || tag === 'div') &&
        cs.display.includes('inline') &&
        cs.backgroundColor !== 'rgba(0, 0, 0, 0)') return 'badge';
    return 'text';
  }

  // 접근성 헬퍼
  function parseRGB(c) {
    const m = c.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    return m ? { r: +m[1], g: +m[2], b: +m[3] } : null;
  }
  function luminance(rgb) {
    return [rgb.r, rgb.g, rgb.b].map(c => {
      c = c / 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    }).reduce((acc, v, i) => acc + [0.2126, 0.7152, 0.0722][i] * v, 0);
  }
  function contrastRatio(fg, bg) {
    const l1 = luminance(fg), l2 = luminance(bg);
    return ((Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)).toFixed(2);
  }
  function accessibleName(el) {
    return el.getAttribute('aria-label')
      || el.getAttribute('title')
      || (el.tagName === 'INPUT' ? el.placeholder : '')
      || (el.textContent || '').trim().substring(0, 30) || '';
  }
  function implicitRole(tag) {
    const roles = { th:'columnheader', td:'cell', button:'button', a:'link',
      nav:'navigation', main:'main', header:'banner', aside:'complementary',
      h1:'heading', h2:'heading', h3:'heading', h4:'heading', h5:'heading', h6:'heading',
      input:'textbox', select:'combobox', textarea:'textbox' };
    return roles[tag] || '';
  }

  const selectors = 'h1,h2,h3,h4,h5,h6,p,span,a,label,li,table,thead,tbody,tr,th,td,input,select,button,textarea,nav,aside,header,main,section,svg';
  const cardSelector = 'div[class*="border"],div[class*="bg-"],div[class*="rounded"]';
  const allEls = [...document.querySelectorAll(selectors), ...document.querySelectorAll(cardSelector)];

  const seen = new Set();
  const items = [];

  for (const el of allEls) {
    const tag = el.tagName.toLowerCase();
    const text = (el.innerText || '').trim().substring(0, 50);
    const rect = el.getBoundingClientRect();
    if (rect.width < 10 || rect.height < 5) continue;

    // 중복 필터
    const key = `${tag}:${text || (el.className?.toString() || '').substring(0, 40)}`;
    if (seen.has(key)) continue;
    seen.add(key);

    const s = getComputedStyle(el);
    const area = classifyArea(rect);
    const type = classifyType(tag, el, s);

    // 배경색 체인 탐색
    let bgColor = s.backgroundColor;
    let parent = el;
    while (bgColor === 'rgba(0, 0, 0, 0)' && parent.parentElement) {
      parent = parent.parentElement;
      bgColor = getComputedStyle(parent).backgroundColor;
    }
    const fgP = parseRGB(s.color), bgP = parseRGB(bgColor);
    const cr = fgP && bgP ? contrastRatio(fgP, bgP) : null;

    items.push({
      area, type, tag,
      text: text.substring(0, 40),
      selector: `${tag}.${(el.className || '').toString().split(/\s+/).filter(Boolean).join('.')}`.substring(0, 120),
      // 크기 (min/max/aspect 포함)
      dimensions: `${(rect.width * CORRECTION).toFixed(0)} × ${(rect.height * CORRECTION).toFixed(0)}`,
      minWidth: s.minWidth !== '0px' && s.minWidth !== 'auto' ? s.minWidth : '',
      maxWidth: s.maxWidth !== 'none' ? s.maxWidth : '',
      minHeight: s.minHeight !== '0px' && s.minHeight !== 'auto' ? s.minHeight : '',
      maxHeight: s.maxHeight !== 'none' ? s.maxHeight : '',
      aspectRatio: s.aspectRatio !== 'auto' ? s.aspectRatio : '',
      // 색상
      color: s.color,
      bgColor: s.backgroundColor,
      opacity: s.opacity !== '1' ? s.opacity : '',
      // 서체
      fontFamily: s.fontFamily.split(',')[0].trim().replace(/['"]/g, ''),
      fontSize: `${(parseFloat(s.fontSize) * CORRECTION).toFixed(0)}px`,
      fontWeight: s.fontWeight,
      fontStyle: s.fontStyle !== 'normal' ? s.fontStyle : '',
      lineHeight: `${(parseFloat(s.lineHeight) * CORRECTION).toFixed(0)}px`,
      letterSpacing: s.letterSpacing,
      // 텍스트
      textAlign: s.textAlign !== 'start' ? s.textAlign : '',
      textTransform: s.textTransform !== 'none' ? s.textTransform : '',
      whiteSpace: s.whiteSpace !== 'normal' ? s.whiteSpace : '',
      verticalAlign: s.verticalAlign !== 'baseline' ? s.verticalAlign : '',
      textDecoration: s.textDecorationLine !== 'none' ? s.textDecorationLine : '',
      textOverflow: s.textOverflow !== 'clip' ? s.textOverflow : '',
      wordBreak: s.wordBreak !== 'normal' ? s.wordBreak : '',
      overflowWrap: s.overflowWrap !== 'normal' ? s.overflowWrap : '',
      textShadow: s.textShadow !== 'none' ? s.textShadow : '',
      // 패딩/마진
      padding: shorten4(s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft),
      margin: shorten4(s.marginTop, s.marginRight, s.marginBottom, s.marginLeft),
      // 보더
      border: s.borderWidth !== '0px' ? `${s.borderWidth} ${s.borderStyle} ${s.borderColor}` : 'none',
      borderColor: s.borderColor,
      borderWidth: s.borderWidth !== '0px' ? s.borderWidth : '',
      borderRadius: s.borderRadius !== '0px' ? s.borderRadius : '',
      outline: s.outlineStyle !== 'none' ? `${s.outlineWidth} ${s.outlineStyle} ${s.outlineColor}` : '',
      outlineOffset: s.outlineOffset !== '0px' ? s.outlineOffset : '',
      // 시각효과
      boxShadow: s.boxShadow !== 'none' ? s.boxShadow.substring(0, 80) : '',
      backgroundImage: s.backgroundImage !== 'none' && s.backgroundImage.includes('gradient') ? s.backgroundImage.substring(0, 120) : '',
      filter: s.filter !== 'none' ? s.filter : '',
      backdropFilter: s.backdropFilter !== 'none' ? s.backdropFilter : '',
      mixBlendMode: s.mixBlendMode !== 'normal' ? s.mixBlendMode : '',
      clipPath: s.clipPath !== 'none' ? s.clipPath : '',
      // 레이아웃
      display: s.display,
      alignItems: s.alignItems !== 'normal' ? s.alignItems : '',
      justifyContent: s.justifyContent !== 'normal' ? s.justifyContent : '',
      flexDirection: s.flexDirection !== 'row' ? s.flexDirection : '',
      flexWrap: s.flexWrap !== 'nowrap' ? s.flexWrap : '',
      flexGrow: s.flexGrow !== '0' ? s.flexGrow : '',
      flexShrink: s.flexShrink !== '1' ? s.flexShrink : '',
      flexBasis: s.flexBasis !== 'auto' ? s.flexBasis : '',
      gridTemplateColumns: s.gridTemplateColumns !== 'none' ? s.gridTemplateColumns : '',
      gridTemplateRows: s.gridTemplateRows !== 'none' ? s.gridTemplateRows : '',
      gridColumn: s.gridColumn !== 'auto' ? s.gridColumn : '',
      gridRow: s.gridRow !== 'auto' ? s.gridRow : '',
      placeItems: s.placeItems !== 'normal' ? s.placeItems : '',
      order: s.order !== '0' ? s.order : '',
      gap: s.gap !== 'normal' ? s.gap : '',
      position: s.position !== 'static' ? s.position : '',
      overflow: s.overflow !== 'visible' ? s.overflow : '',
      zIndex: s.zIndex !== 'auto' ? s.zIndex : '',
      isolation: s.isolation !== 'auto' ? s.isolation : '',
      columns: s.columnCount !== 'auto' ? s.columnCount : '',
      // 포지셔닝
      top: s.position !== 'static' && s.top !== 'auto' ? s.top : '',
      right: s.position !== 'static' && s.right !== 'auto' ? s.right : '',
      bottom: s.position !== 'static' && s.bottom !== 'auto' ? s.bottom : '',
      left: s.position !== 'static' && s.left !== 'auto' ? s.left : '',
      // 트랜스폼
      transform: s.transform !== 'none' ? s.transform : '',
      transformOrigin: s.transformOrigin !== '50% 50%' && s.transformOrigin !== '50% 50% 0px' ? s.transformOrigin : '',
      // 인터랙션
      cursor: s.cursor !== 'auto' ? s.cursor : '',
      transition: s.transitionProperty !== 'all' && s.transitionProperty !== 'none'
        ? `${s.transitionProperty} ${s.transitionDuration} ${s.transitionTimingFunction}` : '',
      pointerEvents: s.pointerEvents !== 'auto' ? s.pointerEvents : '',
      userSelect: s.userSelect !== 'auto' ? s.userSelect : '',
      resize: s.resize !== 'none' ? s.resize : '',
      scrollBehavior: s.scrollBehavior !== 'auto' ? s.scrollBehavior : '',
      scrollSnapType: s.scrollSnapType !== 'none' ? s.scrollSnapType : '',
      scrollSnapAlign: s.scrollSnapAlign !== 'none' ? s.scrollSnapAlign : '',
      // 이미지/미디어
      objectFit: s.objectFit !== 'fill' ? s.objectFit : '',
      objectPosition: s.objectPosition !== '50% 50%' ? s.objectPosition : '',
      // 폼 스타일
      appearance: s.appearance !== 'none' && s.appearance !== 'auto' ? s.appearance : '',
      accentColor: s.accentColor !== 'auto' ? s.accentColor : '',
      caretColor: s.caretColor !== 'auto' && s.caretColor !== s.color ? s.caretColor : '',
      // 애니메이션
      animationName: s.animationName !== 'none' ? s.animationName : '',
      animationDuration: s.animationDuration !== '0s' ? s.animationDuration : '',
      // 기타
      visibility: s.visibility !== 'visible' ? s.visibility : '',
      listStyleType: s.listStyleType !== 'none' && s.listStyleType !== 'disc' ? s.listStyleType : '',
      // 아이콘 속성
      ...(tag === 'svg' ? {
        svgWidth: el.getAttribute('width') || s.width,
        svgHeight: el.getAttribute('height') || s.height,
        stroke: el.getAttribute('stroke') || s.stroke || '',
        strokeWidth: el.getAttribute('stroke-width') || '',
        fill: el.getAttribute('fill') || '',
      } : {}),
      // placeholder 스타일 (input/textarea)
      ...(['input','textarea'].includes(tag) ? (() => {
        const ph = el.getAttribute('placeholder');
        if (!ph) return {};
        return { placeholder: ph, placeholderColor: '' };
      })() : {}),
      // ::before/::after 의사 요소
      ...(() => {
        const pseudo = {};
        for (const p of ['::before', '::after']) {
          const ps = getComputedStyle(el, p === '::before' ? ':before' : ':after');
          if (ps.content && ps.content !== 'none' && ps.content !== '""' && ps.content !== "''") {
            pseudo[p] = {
              content: ps.content,
              width: ps.width, height: ps.height,
              bgColor: ps.backgroundColor,
              color: ps.color,
              position: ps.position !== 'static' ? ps.position : '',
              borderRadius: ps.borderRadius !== '0px' ? ps.borderRadius : '',
            };
          }
        }
        return Object.keys(pseudo).length > 0 ? { pseudoElements: pseudo } : {};
      })(),
      // 검색 컨테이너 전용 속성
      ...(() => {
        if (type !== 'search') return {};
        const searchProps = {};
        // 인풋 찾기
        const searchInput = tag === 'input' ? el : el.querySelector('input');
        if (searchInput) {
          const si = getComputedStyle(searchInput);
          searchProps.searchInputPadding = shorten4(si.paddingTop, si.paddingRight, si.paddingBottom, si.paddingLeft);
          searchProps.searchInputFontSize = `${(parseFloat(si.fontSize) * CORRECTION).toFixed(0)}px`;
          searchProps.searchInputBorder = si.borderWidth !== '0px' ? `${si.borderWidth} ${si.borderStyle} ${si.borderColor}` : 'none';
          searchProps.searchInputBorderRadius = si.borderRadius !== '0px' ? si.borderRadius : '';
          searchProps.searchInputBgColor = si.backgroundColor;
          searchProps.searchPlaceholder = searchInput.getAttribute('placeholder') || '';
        }
        // 아이콘 찾기
        const searchIcon = (tag === 'input' ? el.parentElement : el)?.querySelector('svg');
        if (searchIcon) {
          const ics = getComputedStyle(searchIcon);
          searchProps.searchIconPosition = ics.position;
          searchProps.searchIconSize = `${ics.width} × ${ics.height}`;
          searchProps.searchIconColor = ics.color;
          searchProps.searchIconTop = ics.top !== 'auto' ? ics.top : '';
          searchProps.searchIconLeft = ics.left !== 'auto' ? ics.left : '';
          searchProps.searchIconRight = ics.right !== 'auto' ? ics.right : '';
        }
        return searchProps;
      })(),
      // 드롭다운 패널 전용 속성
      ...(() => {
        if (type !== 'dropdown') return {};
        const ddProps = {};
        ddProps.dropdownMaxHeight = s.maxHeight !== 'none' ? s.maxHeight : '';
        ddProps.dropdownOverflowY = s.overflowY !== 'visible' ? s.overflowY : '';
        ddProps.dropdownMinWidth = s.minWidth !== '0px' && s.minWidth !== 'auto' ? s.minWidth : '';
        ddProps.dropdownPadding = shorten4(s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft);
        // 첫 번째 아이템 스타일 추출
        const firstItem = el.querySelector('li, a, div[role="option"], [class*="item"]');
        if (firstItem) {
          const fis = getComputedStyle(firstItem);
          ddProps.dropdownItemPadding = shorten4(fis.paddingTop, fis.paddingRight, fis.paddingBottom, fis.paddingLeft);
          ddProps.dropdownItemFontSize = `${(parseFloat(fis.fontSize) * CORRECTION).toFixed(0)}px`;
          ddProps.dropdownItemColor = fis.color;
          ddProps.dropdownItemBgColor = fis.backgroundColor;
          ddProps.dropdownItemCursor = fis.cursor;
        }
        // 구분선 확인
        const hasDivider = el.querySelector('hr, [class*="divider"], [class*="separator"]')
          || s.getPropertyValue('--tw-divide-y-reverse') !== '';
        ddProps.dropdownHasDivider = !!hasDivider;
        return ddProps;
      })(),
      // 필터 칩 전용 속성
      ...(() => {
        if (type !== 'chip') return {};
        const chipProps = {
          chipBgColor: s.backgroundColor,
          chipColor: s.color,
          chipBorder: s.borderWidth !== '0px' ? `${s.borderWidth} ${s.borderStyle} ${s.borderColor}` : 'none',
          chipBorderRadius: s.borderRadius,
          chipPadding: shorten4(s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft),
          chipFontSize: `${(parseFloat(s.fontSize) * CORRECTION).toFixed(0)}px`,
          chipFontWeight: s.fontWeight,
          chipGap: s.gap !== 'normal' ? s.gap : '',
        };
        // 활성 상태 칩 감지 (aria-selected, aria-pressed, data-active, 또는 진한 배경색)
        const isActive = el.getAttribute('aria-selected') === 'true'
          || el.getAttribute('aria-pressed') === 'true'
          || el.hasAttribute('data-active')
          || el.classList.contains('active');
        if (isActive) {
          chipProps.chipActiveBgColor = s.backgroundColor;
          chipProps.chipActiveColor = s.color;
        } else {
          // 비활성 칩의 형제 중 활성 칩 찾기
          const siblings = el.parentElement?.children || [];
          for (const sib of siblings) {
            if (sib === el) continue;
            const isAct = sib.getAttribute('aria-selected') === 'true'
              || sib.getAttribute('aria-pressed') === 'true'
              || sib.hasAttribute('data-active')
              || sib.classList.contains('active');
            if (isAct) {
              const sibS = getComputedStyle(sib);
              chipProps.chipActiveBgColor = sibS.backgroundColor;
              chipProps.chipActiveColor = sibS.color;
              break;
            }
          }
        }
        return chipProps;
      })(),
      // 필터 바 전용 속성
      ...(() => {
        if (type !== 'filter-bar') return {};
        return {
          filterBarDisplay: s.display,
          filterBarFlexWrap: s.flexWrap !== 'nowrap' ? s.flexWrap : '',
          filterBarGap: s.gap !== 'normal' ? s.gap : '',
          filterBarAlignItems: s.alignItems !== 'normal' ? s.alignItems : '',
          filterBarPadding: shorten4(s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft),
          filterBarChildCount: el.querySelectorAll('button, select, input').length,
        };
      })(),
      // ::selection 스타일
      ...(() => {
        try {
          const sel = getComputedStyle(el, '::selection');
          if (sel.backgroundColor !== 'rgba(0, 0, 0, 0)') {
            return { selectionBg: sel.backgroundColor, selectionColor: sel.color };
          }
        } catch {}
        return {};
      })(),
      // 접근성
      contrast: cr,
      contrastPass: cr ? parseFloat(cr) >= 4.5 : null,
      name: accessibleName(el),
      role: el.getAttribute('role') || implicitRole(tag),
      keyboardFocusable: el.tabIndex >= 0 || ['a','button','input','select','textarea'].includes(tag),
    });
  }
  return { items, landmarks: { sidebarRight, headerBottom } };
};

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: VIEWPORT });
  await page.goto(URL, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(3000);

  const inventory = { pages: {} };

  for (const pg of [{ name: 'home', nav: null }, ...PAGES]) {
    if (pg.nav) {
      try {
        await page.locator(`text=${pg.nav}`).first().click({ timeout: 5000 });
        await page.waitForTimeout(2000);
      } catch { console.error(`[SKIP] ${pg.name}`); continue; }
    }

    const { items, landmarks } = await page.evaluate(extractAll, CORRECTION);

    // 영역 > 타입별 분류
    const classified = {};
    for (const item of items) {
      if (!classified[item.area]) classified[item.area] = {};
      if (!classified[item.area][item.type]) classified[item.area][item.type] = [];
      classified[item.area][item.type].push(item);
    }

    inventory.pages[pg.name] = classified;

    // 콘솔 요약
    console.log(`\n=== ${pg.name.toUpperCase()} ===`);
    console.log(`  Landmarks: sidebar→${landmarks.sidebarRight}px, header→${landmarks.headerBottom}px`);
    for (const [area, types] of Object.entries(classified)) {
      const counts = Object.entries(types).map(([t, arr]) => `${t}:${arr.length}`).join(', ');
      console.log(`  ${area}: ${counts}`);
    }
  }

  fs.writeFileSync('inventory.json', JSON.stringify(inventory, null, 2));
  console.log('\nSaved: inventory.json');
  await browser.close();
})().catch(console.error);
