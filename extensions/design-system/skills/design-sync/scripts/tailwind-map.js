/**
 * CSS 속성값 → Tailwind 클래스 변환 맵
 * SKILL.md 4.2절 기반
 */

export const TAILWIND_MAP = {
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
  fontStyle: { 'italic': 'italic', 'normal': 'not-italic' },
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
  wordBreak: { 'break-all': 'break-all', 'keep-all': 'break-keep' },
  overflowWrap: { 'break-word': 'break-words' },
  textDecoration: {
    'underline': 'underline', 'overline': 'overline',
    'line-through': 'line-through', 'none': 'no-underline',
  },
  textOverflow: { 'ellipsis': 'truncate' },
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
    'wrap': 'flex-wrap', 'wrap-reverse': 'flex-wrap-reverse', 'nowrap': 'flex-nowrap',
  },
  alignItems: {
    'flex-start': 'items-start', 'flex-end': 'items-end',
    'center': 'items-center', 'baseline': 'items-baseline', 'stretch': 'items-stretch',
  },
  justifyContent: {
    'flex-start': 'justify-start', 'flex-end': 'justify-end',
    'center': 'justify-center', 'space-between': 'justify-between',
    'space-around': 'justify-around', 'space-evenly': 'justify-evenly',
  },
  gridTemplateColumns: (value) => {
    const repeatMatch = value.match(/repeat\((\d+),/);
    if (repeatMatch) return `grid-cols-${repeatMatch[1]}`;
    return `grid-cols-${value.split(/\s+/).length}`;
  },
  gridTemplateRows: (value) => {
    const repeatMatch = value.match(/repeat\((\d+),/);
    if (repeatMatch) return `grid-rows-${repeatMatch[1]}`;
    return `grid-rows-${value.split(/\s+/).length}`;
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
    '8px': 'rounded-lg', '12px': 'rounded-xl', '16px': 'rounded-2xl', '9999px': 'rounded-full',
  },
  borderWidth: {
    '0px': 'border-0', '1px': 'border', '2px': 'border-2', '4px': 'border-4', '8px': 'border-8',
  },
  iconSize: {
    '12px': 'w-3 h-3', '16px': 'w-4 h-4', '20px': 'w-5 h-5',
    '24px': 'w-6 h-6', '32px': 'w-8 h-8', '40px': 'w-10 h-10', '48px': 'w-12 h-12',
  },
  zIndex: { '0': 'z-0', '10': 'z-10', '20': 'z-20', '30': 'z-30', '40': 'z-40', '50': 'z-50' },
  spacing: (px) => {
    const rem = parseFloat(px) / 4;
    const map = { 0:'0', 1:'1', 2:'2', 3:'3', 4:'4', 5:'5', 6:'6', 8:'8',
      10:'10', 12:'12', 16:'16', 20:'20', 24:'24' };
    return map[rem] || `[${px}]`;
  },
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
  scrollSnapAlign: { 'start': 'snap-start', 'end': 'snap-end', 'center': 'snap-center' },
  appearance: { 'none': 'appearance-none', 'auto': 'appearance-auto' },
  listStyleType: { 'disc': 'list-disc', 'decimal': 'list-decimal', 'none': 'list-none' },
  columns: { '1': 'columns-1', '2': 'columns-2', '3': 'columns-3', '4': 'columns-4' },
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
    if (brightM) parts.push(`brightness-${Math.round(parseFloat(brightM[1]) * 100)}`);
    const contrastM = value.match(/contrast\(([\d.]+)\)/);
    if (contrastM) parts.push(`contrast-${Math.round(parseFloat(contrastM[1]) * 100)}`);
    const saturateM = value.match(/saturate\(([\d.]+)\)/);
    if (saturateM) parts.push(`saturate-${Math.round(parseFloat(saturateM[1]) * 100)}`);
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

// 색상 맵 (비교 로직에서 공유)
export const COLOR_MAPS = {
  bgColor: {
    'rgb(249, 250, 251)': 'bg-gray-50', 'rgb(243, 244, 246)': 'bg-gray-100',
    'rgb(229, 231, 235)': 'bg-gray-200', 'rgb(209, 213, 219)': 'bg-gray-300',
    'rgb(255, 255, 255)': 'bg-white',
  },
  textColor: {
    'rgb(17, 24, 39)': 'text-gray-900', 'rgb(31, 41, 55)': 'text-gray-800',
    'rgb(55, 65, 81)': 'text-gray-700', 'rgb(75, 85, 99)': 'text-gray-600',
    'rgb(107, 114, 128)': 'text-gray-500', 'rgb(156, 163, 175)': 'text-gray-400',
    'rgb(209, 213, 219)': 'text-gray-300',
  },
  borderColor: {
    'rgb(229, 231, 235)': 'border-gray-200',
    'rgb(209, 213, 219)': 'border-gray-300',
    'rgb(156, 163, 175)': 'border-gray-400',
  },
  iconColor: {
    'rgb(107, 114, 128)': 'text-gray-500', 'rgb(156, 163, 175)': 'text-gray-400',
    'rgb(75, 85, 99)': 'text-gray-600',
  },
  chipBgColor: {
    'rgb(243, 244, 246)': 'bg-gray-100', 'rgb(229, 231, 235)': 'bg-gray-200',
    'rgb(219, 234, 254)': 'bg-blue-100', 'rgb(239, 246, 255)': 'bg-blue-50',
    'rgb(255, 255, 255)': 'bg-white',
  },
  chipActiveBgColor: {
    'rgb(37, 99, 235)': 'bg-blue-600', 'rgb(59, 130, 246)': 'bg-blue-500',
    'rgb(219, 234, 254)': 'bg-blue-100', 'rgb(243, 244, 246)': 'bg-gray-100',
  },
};

// spacing 값 → Tailwind 단위 변환
export const SPACING_MAP = { 0:'0', 1:'1', 2:'2', 3:'3', 4:'4', 5:'5', 6:'6', 8:'8', 10:'10', 12:'12', 16:'16', 20:'20', 24:'24' };
export const SPACING_MAP_SMALL = { 0:'0', 0.5:'0.5', 1:'1', 1.5:'1.5', 2:'2', 3:'3', 4:'4', 5:'5', 6:'6', 8:'8' };
