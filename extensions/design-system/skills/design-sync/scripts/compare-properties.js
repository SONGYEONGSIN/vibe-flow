/**
 * 참고 요소(refEl)와 로컬 클래스(fc)를 속성별로 비교하여 diff 목록을 반환한다.
 */

import { TAILWIND_MAP, COLOR_MAPS, SPACING_MAP, SPACING_MAP_SMALL } from './tailwind-map.js';

// 간단한 맵 기반 비교 (값 → Tailwind 클래스 조회 → 현재 클래스에 포함 여부)
function compareSimple(refEl, fc, prop, map, searchValues) {
  const refVal = refEl[prop];
  if (!refVal) return null;
  const twClass = map[refVal];
  if (!twClass || fc.classes.includes(twClass)) return null;
  if (searchValues) {
    const current = searchValues.find(v => fc.classes.includes(v));
    if (current && current !== twClass) {
      return { line: fc.line, property: prop, reference: `${refVal} (${twClass})`, current, suggestion: `${current} → ${twClass}` };
    }
  } else {
    return { line: fc.line, property: prop, reference: `${refVal} (${twClass})`, current: '', suggestion: `→ ${twClass}` };
  }
  return null;
}

// spacing (padding/margin) 비교
function compareSpacing(refEl, fc, prop, prefix) {
  const value = refEl[prop];
  if (!value || value === '0px') return [];
  const diffs = [];
  const values = value.split(' ').map(v => parseFloat(v));
  for (const [idx, dir] of ['t','r','b','l'].entries()) {
    const pv = values[idx] || values[0];
    const pvRem = pv / 4;
    const twVal = SPACING_MAP[pvRem];
    if (!twVal) continue;
    const twClass = `${prefix}${dir}-${twVal}`;
    if (fc.classes.includes(twClass)) continue;
    const axisX = `${prefix}x-${twVal}`;
    const axisY = `${prefix}y-${twVal}`;
    const all = `${prefix}-${twVal}`;
    if (!fc.classes.includes(axisX) && !fc.classes.includes(axisY) && !fc.classes.includes(all)) {
      diffs.push({ line: fc.line, property: `${prop}-${dir}`, reference: `${pv}px (${twClass})`, current: '', suggestion: `→ ${twClass}` });
    }
  }
  return diffs;
}

// 타이포그래피 비교
function compareTypography(refEl, fc) {
  const diffs = [];

  // fontSize
  const twFS = TAILWIND_MAP.fontSize[refEl.fontSize];
  if (twFS && !fc.classes.includes(twFS)) {
    const current = Object.values(TAILWIND_MAP.fontSize).find(v => fc.classes.includes(v));
    if (current && current !== twFS) {
      diffs.push({ line: fc.line, property: 'fontSize', reference: `${refEl.fontSize} (${twFS})`, current, suggestion: `${current} → ${twFS}` });
    }
  }

  // fontWeight
  const twFW = TAILWIND_MAP.fontWeight[refEl.fontWeight];
  if (twFW && !fc.classes.includes(twFW)) {
    const current = Object.values(TAILWIND_MAP.fontWeight).find(v => fc.classes.includes(v));
    if (current && current !== twFW) {
      diffs.push({ line: fc.line, property: 'fontWeight', reference: `w:${refEl.fontWeight} (${twFW})`, current, suggestion: `${current} → ${twFW}` });
    }
  }

  // lineHeight
  const twLH = TAILWIND_MAP.lineHeight[refEl.lineHeight];
  if (twLH && !fc.classes.includes(twLH)) {
    const current = Object.values(TAILWIND_MAP.lineHeight).find(v => fc.classes.includes(v));
    if (current && current !== twLH) {
      diffs.push({ line: fc.line, property: 'lineHeight', reference: `${refEl.lineHeight} (${twLH})`, current, suggestion: `${current} → ${twLH}` });
    }
  }

  // letterSpacing
  const twLS = TAILWIND_MAP.letterSpacing[refEl.letterSpacing];
  if (twLS && !fc.classes.includes(twLS)) {
    const current = Object.values(TAILWIND_MAP.letterSpacing).find(v => fc.classes.includes(v));
    if (current && current !== twLS) {
      diffs.push({ line: fc.line, property: 'letterSpacing', reference: `${refEl.letterSpacing} (${twLS})`, current, suggestion: `${current} → ${twLS}` });
    }
  }

  // fontStyle
  if (refEl.fontStyle) {
    const d = compareSimple(refEl, fc, 'fontStyle', { 'italic': 'italic' });
    if (d) diffs.push(d);
  }

  // fontFamily
  if (refEl.fontFamily) {
    const fontClassPattern = /font-\[([^\]]+)\]|font-(sans|serif|mono)/;
    const currentFontMatch = fc.classes.match(fontClassPattern);
    const currentFont = currentFontMatch ? currentFontMatch[0] : null;
    const expected = refEl.fontFamily.toLowerCase().includes('mono') ? 'font-mono'
      : refEl.fontFamily.toLowerCase().includes('serif') ? 'font-serif' : 'font-sans';
    if (currentFont && currentFont !== expected) {
      diffs.push({ line: fc.line, property: 'fontFamily', reference: `${refEl.fontFamily} (${expected})`, current: currentFont, suggestion: `${currentFont} → ${expected}` });
    }
  }

  // textAlign
  if (refEl.textAlign && refEl.textAlign !== 'start') {
    const map = { 'left':'text-left', 'center':'text-center', 'right':'text-right', 'justify':'text-justify' };
    const tw = map[refEl.textAlign];
    if (tw && !fc.classes.includes(tw)) {
      const current = Object.values(map).find(v => fc.classes.includes(v));
      if (current && current !== tw) diffs.push({ line: fc.line, property: 'textAlign', reference: `${refEl.textAlign} (${tw})`, current, suggestion: `${current} → ${tw}` });
    }
  }

  // textTransform
  if (refEl.textTransform && refEl.textTransform !== 'none') {
    const d = compareSimple(refEl, fc, 'textTransform', { 'uppercase':'uppercase', 'lowercase':'lowercase', 'capitalize':'capitalize' });
    if (d) diffs.push(d);
  }

  // whiteSpace, wordBreak, overflowWrap, textDecoration
  for (const prop of ['whiteSpace', 'wordBreak', 'overflowWrap', 'textDecoration']) {
    if (refEl[prop]) {
      const d = compareSimple(refEl, fc, prop, TAILWIND_MAP[prop]);
      if (d) diffs.push(d);
    }
  }

  // textOverflow
  if (refEl.textOverflow === 'ellipsis' && !fc.classes.includes('truncate')) {
    diffs.push({ line: fc.line, property: 'textOverflow', reference: 'ellipsis (truncate)', current: 'clip', suggestion: '→ truncate' });
  }

  return diffs;
}

// 레이아웃 비교
function compareLayout(refEl, fc) {
  const diffs = [];

  // flexDirection
  if (refEl.flexDirection) {
    const map = { 'column':'flex-col', 'column-reverse':'flex-col-reverse', 'row-reverse':'flex-row-reverse' };
    const tw = map[refEl.flexDirection];
    if (tw && !fc.classes.includes(tw)) {
      const current = ['flex-col','flex-col-reverse','flex-row-reverse','flex-row'].find(v => fc.classes.includes(v));
      diffs.push({ line: fc.line, property: 'flexDirection', reference: `${refEl.flexDirection} (${tw})`, current: current || 'flex-row', suggestion: `→ ${tw}` });
    }
  }

  // flexWrap
  if (refEl.flexWrap) {
    const d = compareSimple(refEl, fc, 'flexWrap', { 'wrap':'flex-wrap', 'wrap-reverse':'flex-wrap-reverse' });
    if (d) diffs.push(d);
  }

  // alignItems
  if (refEl.alignItems) {
    const map = { 'flex-start':'items-start', 'flex-end':'items-end', 'center':'items-center', 'baseline':'items-baseline', 'stretch':'items-stretch' };
    const tw = map[refEl.alignItems];
    if (tw && !fc.classes.includes(tw)) {
      const current = Object.values(map).find(v => fc.classes.includes(v));
      if (current && current !== tw) diffs.push({ line: fc.line, property: 'alignItems', reference: `${refEl.alignItems} (${tw})`, current, suggestion: `${current} → ${tw}` });
    }
  }

  // justifyContent
  if (refEl.justifyContent) {
    const map = { 'flex-start':'justify-start', 'flex-end':'justify-end', 'center':'justify-center', 'space-between':'justify-between', 'space-around':'justify-around', 'space-evenly':'justify-evenly' };
    const tw = map[refEl.justifyContent];
    if (tw && !fc.classes.includes(tw)) {
      const current = Object.values(map).find(v => fc.classes.includes(v));
      if (current && current !== tw) diffs.push({ line: fc.line, property: 'justifyContent', reference: `${refEl.justifyContent} (${tw})`, current, suggestion: `${current} → ${tw}` });
    }
  }

  // gridTemplateColumns / gridTemplateRows
  for (const [prop, prefix] of [['gridTemplateColumns', 'grid-cols-'], ['gridTemplateRows', 'grid-rows-']]) {
    if (refEl[prop]) {
      const repeatMatch = refEl[prop].match(/repeat\((\d+),/);
      const count = repeatMatch ? repeatMatch[1] : refEl[prop].split(/\s+/).length;
      const tw = `${prefix}${count}`;
      if (!fc.classes.includes(tw)) {
        const current = fc.classes.match(new RegExp(`${prefix}(\\d+)`))?.[0];
        if (current) diffs.push({ line: fc.line, property: prop, reference: `${refEl[prop]} (${tw})`, current, suggestion: `${current} → ${tw}` });
      }
    }
  }

  // gridColumn / gridRow spans
  for (const [prop, prefix] of [['gridColumn', 'col-span-'], ['gridRow', 'row-span-']]) {
    if (refEl[prop]) {
      const spanMatch = refEl[prop].match(/span\s+(\d+)/);
      if (spanMatch) {
        const tw = `${prefix}${spanMatch[1]}`;
        if (!fc.classes.includes(tw)) {
          const current = fc.classes.match(new RegExp(`${prefix}(\\d+|full)`))?.[0];
          if (current && current !== tw) diffs.push({ line: fc.line, property: prop, reference: `${refEl[prop]} (${tw})`, current, suggestion: `${current} → ${tw}` });
        }
      }
    }
  }

  // flexGrow / flexShrink
  if (refEl.flexGrow) { const d = compareSimple(refEl, fc, 'flexGrow', { '0':'grow-0', '1':'grow' }); if (d) diffs.push(d); }
  if (refEl.flexShrink) { const d = compareSimple(refEl, fc, 'flexShrink', { '0':'shrink-0', '1':'shrink' }); if (d) diffs.push(d); }

  // flexBasis
  if (refEl.flexBasis) {
    const basisPx = parseFloat(refEl.flexBasis);
    const basisMap = { 0:'basis-0', 64:'basis-16', 128:'basis-32', 256:'basis-64' };
    const tw = basisMap[basisPx] || `basis-[${refEl.flexBasis}]`;
    if (!fc.classes.includes(tw)) {
      const current = fc.classes.match(/basis-(\d+|\[[\w%]+\])/)?.[0];
      if (current && current !== tw) diffs.push({ line: fc.line, property: 'flexBasis', reference: `${refEl.flexBasis} (${tw})`, current, suggestion: `${current} → ${tw}` });
    }
  }

  // placeItems, order
  if (refEl.placeItems) { const d = compareSimple(refEl, fc, 'placeItems', TAILWIND_MAP.placeItems); if (d) diffs.push(d); }
  if (refEl.order) { const d = compareSimple(refEl, fc, 'order', { '1':'order-1', '2':'order-2', '3':'order-3', '-1':'order-first', '9999':'order-last', '0':'order-none' }); if (d) diffs.push(d); }

  // gap
  if (refEl.gap) {
    const gapPx = parseFloat(refEl.gap);
    const gapRem = gapPx / 4;
    const gapMap = { 0:'0', 1:'1', 2:'2', 3:'3', 4:'4', 5:'5', 6:'6', 8:'8', 10:'10', 12:'12' };
    const tw = gapMap[gapRem] ? `gap-${gapMap[gapRem]}` : `gap-[${gapPx}px]`;
    if (!fc.classes.includes(tw)) {
      const current = fc.classes.match(/gap-(\d+|\[[\dpx]+\])/)?.[0];
      if (current && current !== tw) diffs.push({ line: fc.line, property: 'gap', reference: `${refEl.gap} (${tw})`, current, suggestion: `${current} → ${tw}` });
    }
  }

  // overflow
  if (refEl.overflow && refEl.overflow !== 'visible') {
    const d = compareSimple(refEl, fc, 'overflow', { 'hidden':'overflow-hidden', 'auto':'overflow-auto', 'scroll':'overflow-scroll' });
    if (d) diffs.push(d);
  }

  return diffs;
}

// 비주얼 속성 비교
function compareVisual(refEl, fc) {
  const diffs = [];

  // borderRadius
  if (refEl.borderRadius) {
    const brMap = TAILWIND_MAP.borderRadius;
    const tw = brMap[refEl.borderRadius];
    if (tw && !fc.classes.includes(tw)) {
      const current = Object.values(brMap).find(v => fc.classes.includes(v));
      if (current && current !== tw) diffs.push({ line: fc.line, property: 'borderRadius', reference: `${refEl.borderRadius} (${tw})`, current, suggestion: `${current} → ${tw}` });
    }
  }

  // backgroundColor
  if (refEl.bgColor && refEl.bgColor !== 'rgba(0, 0, 0, 0)') {
    const tw = COLOR_MAPS.bgColor[refEl.bgColor];
    if (tw) {
      const current = Object.values(COLOR_MAPS.bgColor).find(v => fc.classes.includes(v.replace('bg-', '')));
      if (current && current !== tw) diffs.push({ line: fc.line, property: 'backgroundColor', reference: tw, current, suggestion: `${current} → ${tw}` });
    }
  }

  // color (text)
  if (refEl.color) {
    const tw = COLOR_MAPS.textColor[refEl.color];
    if (tw) {
      const current = Object.values(COLOR_MAPS.textColor).find(v => fc.classes.includes(v.replace('text-', '')));
      if (current && current !== tw) diffs.push({ line: fc.line, property: 'color', reference: tw, current, suggestion: `${current} → ${tw}` });
    }
  }

  // borderColor
  if (refEl.borderWidth && refEl.borderColor) {
    const tw = COLOR_MAPS.borderColor[refEl.borderColor];
    if (tw && !fc.classes.includes(tw.replace('border-', ''))) {
      const current = Object.values(COLOR_MAPS.borderColor).find(v => fc.classes.includes(v.replace('border-', '')));
      if (current && current !== tw) diffs.push({ line: fc.line, property: 'borderColor', reference: tw, current, suggestion: `${current} → ${tw}` });
    }
  }

  // boxShadow
  if (refEl.boxShadow) {
    let tw = null;
    if (refEl.boxShadow.includes('10px') || refEl.boxShadow.includes('15px')) tw = 'shadow-lg';
    else if (refEl.boxShadow.includes('4px') || refEl.boxShadow.includes('6px')) tw = 'shadow-md';
    else if (refEl.boxShadow.includes('1px 3px')) tw = 'shadow';
    else if (refEl.boxShadow.includes('1px 2px')) tw = 'shadow-sm';
    if (tw && !fc.classes.includes(tw)) {
      const current = ['shadow-none','shadow-sm','shadow','shadow-md','shadow-lg','shadow-xl','shadow-2xl'].find(v => fc.classes.includes(v));
      if (current && current !== tw) diffs.push({ line: fc.line, property: 'boxShadow', reference: `(${tw})`, current, suggestion: `${current} → ${tw}` });
    }
  }

  // iconSize
  if (refEl.svgWidth) {
    const iconSizeMap = { '12':'w-3 h-3', '16':'w-4 h-4', '20':'w-5 h-5', '24':'w-6 h-6', '32':'w-8 h-8' };
    const refSize = parseInt(refEl.svgWidth);
    const twIcon = iconSizeMap[String(refSize)];
    if (twIcon) {
      const twW = twIcon.split(' ')[0];
      if (!fc.classes.includes(twW)) {
        const current = Object.values(iconSizeMap).map(v => v.split(' ')[0]).find(v => fc.classes.includes(v));
        if (current) diffs.push({ line: fc.line, property: 'iconSize', reference: `${refSize}px (${twIcon})`, current, suggestion: `${current} → ${twW}` });
      }
    }
  }

  // 단순 맵 비교 속성들
  const simpleProps = ['aspectRatio','objectFit','objectPosition','mixBlendMode','visibility',
    'pointerEvents','userSelect','resize','scrollBehavior','scrollSnapAlign',
    'appearance','listStyleType','isolation','columns','transformOrigin'];
  for (const prop of simpleProps) {
    if (refEl[prop]) {
      const d = compareSimple(refEl, fc, prop, TAILWIND_MAP[prop]);
      if (d) diffs.push(d);
    }
  }

  // scrollSnapType
  if (refEl.scrollSnapType) {
    const tw = TAILWIND_MAP.scrollSnapType[refEl.scrollSnapType];
    if (tw && !fc.classes.includes(tw.split(' ')[0])) {
      diffs.push({ line: fc.line, property: 'scrollSnapType', reference: `${refEl.scrollSnapType} (${tw})`, current: '', suggestion: `→ ${tw}` });
    }
  }

  // function-based: filter, backdropFilter, maxWidth
  if (refEl.filter) {
    const tw = TAILWIND_MAP.filter(refEl.filter);
    if (tw) diffs.push({ line: fc.line, property: 'filter', reference: `${refEl.filter} (${tw})`, current: '', suggestion: `→ ${tw}` });
  }
  if (refEl.backdropFilter) {
    const tw = TAILWIND_MAP.backdropFilter(refEl.backdropFilter);
    if (tw) diffs.push({ line: fc.line, property: 'backdropFilter', reference: `${refEl.backdropFilter} (${tw})`, current: '', suggestion: `→ ${tw}` });
  }
  if (refEl.maxWidth && refEl.maxWidth !== 'none') {
    const tw = TAILWIND_MAP.maxWidth(refEl.maxWidth);
    if (tw && !fc.classes.includes(tw)) {
      const current = fc.classes.match(/max-w-(\w+|\[[\w%]+\])/)?.[0];
      if (current && current !== tw) diffs.push({ line: fc.line, property: 'maxWidth', reference: `${refEl.maxWidth} (${tw})`, current, suggestion: `${current} → ${tw}` });
    }
  }

  // outline, textShadow, backgroundImage, accentColor, caretColor
  if (refEl.outline && refEl.outline.includes('2px') && !fc.classes.includes('ring-2') && !fc.classes.includes('outline')) {
    diffs.push({ line: fc.line, property: 'outline', reference: refEl.outline, current: '', suggestion: '→ ring-2 또는 outline' });
  }
  if (refEl.textShadow && !fc.classes.includes('drop-shadow')) {
    diffs.push({ line: fc.line, property: 'textShadow', reference: refEl.textShadow, current: '', suggestion: '→ drop-shadow-* (커스텀)' });
  }
  if (refEl.backgroundImage && !fc.classes.match(/bg-gradient/)) {
    diffs.push({ line: fc.line, property: 'backgroundImage', reference: refEl.backgroundImage.substring(0, 60), current: '', suggestion: '→ bg-gradient-to-* (커스텀)' });
  }
  if (refEl.accentColor && !fc.classes.match(/accent-/)) {
    diffs.push({ line: fc.line, property: 'accentColor', reference: refEl.accentColor, current: '', suggestion: '→ accent-* (커스텀)' });
  }
  if (refEl.caretColor && !fc.classes.match(/caret-/)) {
    diffs.push({ line: fc.line, property: 'caretColor', reference: refEl.caretColor, current: '', suggestion: '→ caret-* (커스텀)' });
  }

  return diffs;
}

// 검색/필터/드롭다운 전용 속성 비교
function compareSpecialized(refEl, fc) {
  const diffs = [];

  // 검색 인풋
  if (refEl.searchInputPadding) {
    const padValues = refEl.searchInputPadding.split(' ').map(v => parseFloat(v));
    const pyVal = SPACING_MAP_SMALL[padValues[0] / 4];
    const pxVal = SPACING_MAP_SMALL[(padValues[1] || padValues[0]) / 4];
    if (pyVal && pxVal) {
      const twPy = `py-${pyVal}`, twPx = `px-${pxVal}`;
      if (!fc.classes.includes(twPy) || !fc.classes.includes(twPx)) {
        diffs.push({ line: fc.line, property: 'searchInputPadding', reference: `${refEl.searchInputPadding} (${twPy} ${twPx})`, current: '', suggestion: `→ ${twPy} ${twPx}` });
      }
    }
  }
  if (refEl.searchInputFontSize) {
    const d = compareSimple({ searchInputFontSize: refEl.searchInputFontSize }, fc, 'searchInputFontSize', TAILWIND_MAP.fontSize);
    if (d) { d.property = 'searchInputFontSize'; diffs.push(d); }
  }
  if (refEl.searchInputBorderRadius) {
    const brMap = { '2px':'rounded-sm','4px':'rounded','6px':'rounded-md','8px':'rounded-lg','12px':'rounded-xl','9999px':'rounded-full' };
    const tw = brMap[refEl.searchInputBorderRadius];
    if (tw && !fc.classes.includes(tw)) diffs.push({ line: fc.line, property: 'searchInputBorderRadius', reference: `${refEl.searchInputBorderRadius} (${tw})`, current: '', suggestion: `→ ${tw}` });
  }
  if (refEl.searchInputBgColor && refEl.searchInputBgColor !== 'rgba(0, 0, 0, 0)') {
    const bgMap = { 'rgb(249, 250, 251)':'bg-gray-50', 'rgb(243, 244, 246)':'bg-gray-100', 'rgb(255, 255, 255)':'bg-white' };
    const tw = bgMap[refEl.searchInputBgColor];
    if (tw && !fc.classes.includes(tw.replace('bg-', ''))) diffs.push({ line: fc.line, property: 'searchInputBgColor', reference: tw, current: '', suggestion: `→ ${tw}` });
  }
  if (refEl.searchIconSize) {
    const [w] = refEl.searchIconSize.split('\u00d7').map(s => parseInt(s.trim()));
    const iconMap = { 12:'w-3 h-3', 16:'w-4 h-4', 20:'w-5 h-5', 24:'w-6 h-6' };
    const tw = iconMap[w];
    if (tw && !fc.classes.includes(tw.split(' ')[0])) diffs.push({ line: fc.line, property: 'searchIconSize', reference: `${refEl.searchIconSize} (${tw})`, current: '', suggestion: `→ ${tw}` });
  }
  if (refEl.searchIconColor) {
    const tw = COLOR_MAPS.iconColor[refEl.searchIconColor];
    if (tw && !fc.classes.includes(tw.replace('text-', ''))) diffs.push({ line: fc.line, property: 'searchIconColor', reference: tw, current: '', suggestion: `→ ${tw}` });
  }

  // 드롭다운 패널
  if (refEl.dropdownMaxHeight) {
    const mhPx = parseFloat(refEl.dropdownMaxHeight);
    const tw = mhPx <= 256 ? 'max-h-64' : mhPx <= 384 ? 'max-h-96' : `max-h-[${mhPx}px]`;
    if (!fc.classes.includes(tw) && !fc.classes.match(/max-h-/)) diffs.push({ line: fc.line, property: 'dropdownMaxHeight', reference: `${refEl.dropdownMaxHeight} (${tw})`, current: '', suggestion: `→ ${tw}` });
  }
  if (refEl.dropdownOverflowY && refEl.dropdownOverflowY !== 'visible') {
    const d = compareSimple(refEl, fc, 'dropdownOverflowY', { 'auto':'overflow-y-auto', 'scroll':'overflow-y-scroll', 'hidden':'overflow-y-hidden' });
    if (d) diffs.push(d);
  }
  if (refEl.dropdownPadding) {
    const padValues = refEl.dropdownPadding.split(' ').map(v => parseFloat(v));
    const pyVal = SPACING_MAP_SMALL[padValues[0] / 4];
    if (pyVal && !fc.classes.includes(`py-${pyVal}`)) diffs.push({ line: fc.line, property: 'dropdownPadding', reference: `${refEl.dropdownPadding} (py-${pyVal})`, current: '', suggestion: `→ py-${pyVal}` });
  }
  if (refEl.dropdownItemPadding) {
    const padValues = refEl.dropdownItemPadding.split(' ').map(v => parseFloat(v));
    const pyVal = SPACING_MAP_SMALL[padValues[0] / 4], pxVal = SPACING_MAP_SMALL[(padValues[1] || padValues[0]) / 4];
    if (pyVal && pxVal && (!fc.classes.includes(`py-${pyVal}`) || !fc.classes.includes(`px-${pxVal}`))) {
      diffs.push({ line: fc.line, property: 'dropdownItemPadding', reference: `${refEl.dropdownItemPadding} (py-${pyVal} px-${pxVal})`, current: '', suggestion: `→ py-${pyVal} px-${pxVal}` });
    }
  }
  if (refEl.dropdownItemFontSize) {
    const tw = TAILWIND_MAP.fontSize[refEl.dropdownItemFontSize];
    if (tw && !fc.classes.includes(tw)) diffs.push({ line: fc.line, property: 'dropdownItemFontSize', reference: `${refEl.dropdownItemFontSize} (${tw})`, current: '', suggestion: `→ ${tw}` });
  }
  if (refEl.dropdownItemColor) {
    const tw = COLOR_MAPS.textColor[refEl.dropdownItemColor];
    if (tw && !fc.classes.includes(tw.replace('text-', ''))) diffs.push({ line: fc.line, property: 'dropdownItemColor', reference: tw, current: '', suggestion: `→ ${tw}` });
  }

  // 필터 칩
  if (refEl.chipBgColor && refEl.chipBgColor !== 'rgba(0, 0, 0, 0)') {
    const tw = COLOR_MAPS.chipBgColor[refEl.chipBgColor];
    if (tw && !fc.classes.includes(tw.replace('bg-', ''))) diffs.push({ line: fc.line, property: 'chipBgColor', reference: tw, current: '', suggestion: `→ ${tw}` });
  }
  if (refEl.chipActiveBgColor && refEl.chipActiveBgColor !== refEl.chipBgColor) {
    const tw = COLOR_MAPS.chipActiveBgColor[refEl.chipActiveBgColor];
    if (tw) diffs.push({ line: fc.line, property: 'chipActiveBgColor', reference: tw, current: '', suggestion: `활성 상태: → ${tw}` });
  }
  if (refEl.chipFontSize) {
    const tw = TAILWIND_MAP.fontSize[refEl.chipFontSize];
    if (tw && !fc.classes.includes(tw)) diffs.push({ line: fc.line, property: 'chipFontSize', reference: `${refEl.chipFontSize} (${tw})`, current: '', suggestion: `→ ${tw}` });
  }
  if (refEl.chipBorderRadius) {
    const brMap = { '2px':'rounded-sm','4px':'rounded','6px':'rounded-md','9999px':'rounded-full','16px':'rounded-2xl' };
    const tw = brMap[refEl.chipBorderRadius];
    if (tw && !fc.classes.includes(tw)) diffs.push({ line: fc.line, property: 'chipBorderRadius', reference: `${refEl.chipBorderRadius} (${tw})`, current: '', suggestion: `→ ${tw}` });
  }
  if (refEl.chipPadding) {
    const padValues = refEl.chipPadding.split(' ').map(v => parseFloat(v));
    const pyVal = SPACING_MAP_SMALL[padValues[0] / 4], pxVal = SPACING_MAP_SMALL[(padValues[1] || padValues[0]) / 4];
    if (pyVal && pxVal) diffs.push({ line: fc.line, property: 'chipPadding', reference: `${refEl.chipPadding} (py-${pyVal} px-${pxVal})`, current: '', suggestion: `→ py-${pyVal} px-${pxVal}` });
  }

  // 필터 바
  if (refEl.filterBarGap) {
    const gapPx = parseFloat(refEl.filterBarGap);
    const gapMap = { 1:'1', 2:'2', 3:'3', 4:'4', 6:'6', 8:'8' };
    const tw = gapMap[gapPx / 4] ? `gap-${gapMap[gapPx / 4]}` : `gap-[${gapPx}px]`;
    if (!fc.classes.includes(tw)) diffs.push({ line: fc.line, property: 'filterBarGap', reference: `${refEl.filterBarGap} (${tw})`, current: '', suggestion: `→ ${tw}` });
  }
  if (refEl.filterBarFlexWrap && refEl.filterBarFlexWrap !== 'nowrap') {
    const d = compareSimple(refEl, fc, 'filterBarFlexWrap', { 'wrap':'flex-wrap', 'wrap-reverse':'flex-wrap-reverse' });
    if (d) diffs.push(d);
  }
  if (refEl.filterBarAlignItems) {
    const d = compareSimple(refEl, fc, 'filterBarAlignItems', { 'center':'items-center', 'flex-start':'items-start', 'flex-end':'items-end' });
    if (d) diffs.push(d);
  }

  return diffs;
}

/**
 * 참고 요소와 로컬 파일 클래스를 비교하여 전체 diff 목록을 반환한다.
 */
export function compareAll(refEl, fc) {
  return [
    ...compareTypography(refEl, fc),
    ...compareSpacing(refEl, fc, 'padding', 'p'),
    ...compareSpacing(refEl, fc, 'margin', 'm'),
    ...compareLayout(refEl, fc),
    ...compareVisual(refEl, fc),
    ...compareSpecialized(refEl, fc),
  ];
}
