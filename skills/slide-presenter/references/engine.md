# JavaScript 엔진 레퍼런스

prototype.html에서 검증된 전체 JS 엔진. 스킬 사용 시 이 코드를 기반으로 생성한다.

## 전체 JavaScript

```javascript
(function () {
  'use strict';

  const state = {
    currentSlide: 0,
    currentStep: -1,
    isAnimating: false,
    transitionMode: 'slide',
    notesVisible: false,
    helpVisible: false,
  };

  const TRANSITION_MODES = ['fade', 'slide', 'zoom'];
  const DURATION = 500;
  const EASING = 'cubic-bezier(0.4, 0.0, 0.2, 1)';

  const frame = document.querySelector('.slide-frame');
  const slides = Array.from(document.querySelectorAll('.slide'));
  const progressFill = document.querySelector('.progress-fill');
  const currentNum = document.querySelector('.current-num');
  const totalNum = document.querySelector('.total-num');
  const transitionLabel = document.getElementById('transition-label');
  const notesOverlay = document.getElementById('notes-overlay');
  const notesContent = document.getElementById('notes-content');
  const helpOverlay = document.querySelector('.help-overlay');

  totalNum.textContent = slides.length;

  // ===== FRAGMENTS =====
  function getSteps(slide) {
    const stepSet = new Set();
    slide.querySelectorAll('.fragment').forEach(f => {
      stepSet.add(parseInt(f.dataset.step || '0', 10));
    });
    const codeBlock = slide.querySelector('.code-block[data-highlight-steps]');
    if (codeBlock) {
      JSON.parse(codeBlock.dataset.highlightSteps).forEach((_, i) => stepSet.add(i));
    }
    return Array.from(stepSet).sort((a, b) => a - b);
  }

  function applyStep(slide, stepIndex) {
    slide.querySelectorAll('.fragment').forEach(f => {
      const s = parseInt(f.dataset.step || '0', 10);
      if (s <= stepIndex) {
        f.classList.add('visible');
        f.classList.toggle('past', s < stepIndex);
      } else {
        f.classList.remove('visible', 'past');
      }
    });
    const cb = slide.querySelector('.code-block[data-highlight-steps]');
    if (cb) {
      const steps = JSON.parse(cb.dataset.highlightSteps);
      highlightLines(cb, stepIndex >= 0 && stepIndex < steps.length ? steps[stepIndex] : null);
    }
  }

  function resetFragments(slide) {
    slide.querySelectorAll('.fragment').forEach(f => f.classList.remove('visible', 'past'));
    const cb = slide.querySelector('.code-block[data-highlight-steps]');
    if (cb) highlightLines(cb, null);
  }

  function showAllFragments(slide) {
    const steps = getSteps(slide);
    if (steps.length > 0) {
      state.currentStep = steps[steps.length - 1];
      applyStep(slide, state.currentStep);
    }
  }

  // ===== CODE HIGHLIGHT =====
  function parseRange(str) {
    const lines = [];
    str.split(',').forEach(p => {
      const t = p.trim();
      if (t.includes('-')) {
        const [a, b] = t.split('-').map(Number);
        for (let i = a; i <= b; i++) lines.push(i);
      } else lines.push(Number(t));
    });
    return lines;
  }

  function highlightLines(block, range) {
    const all = block.querySelectorAll('.line');
    if (!range) {
      block.classList.remove('hl-active');
      all.forEach(l => l.classList.remove('hl'));
      return;
    }
    block.classList.add('hl-active');
    const hl = parseRange(range);
    all.forEach(l => {
      l.classList.toggle('hl', hl.includes(parseInt(l.dataset.line, 10)));
    });
  }

  // ===== TRANSITIONS =====
  async function fadeTransition(cur, nxt) {
    nxt.style.opacity = '0';
    nxt.style.visibility = 'visible';
    nxt.style.zIndex = '2';
    nxt.style.pointerEvents = 'none';
    cur.style.zIndex = '1';
    cur.style.willChange = 'opacity';
    nxt.style.willChange = 'opacity';
    const a = nxt.animate(
      [{ opacity: 0 }, { opacity: 1 }],
      { duration: DURATION, easing: EASING, fill: 'forwards' }
    );
    await a.finished;
    a.cancel();
  }

  async function slideTransition(cur, nxt, dir) {
    nxt.style.opacity = '1';
    nxt.style.visibility = 'visible';
    nxt.style.zIndex = '2';
    nxt.style.pointerEvents = 'none';
    cur.style.willChange = 'transform';
    nxt.style.willChange = 'transform';
    const out = cur.animate(
      [{ transform: 'translate3d(0,0,0)' }, { transform: `translate3d(${-100 * dir}%,0,0)` }],
      { duration: DURATION, easing: EASING, fill: 'forwards' }
    );
    const into = nxt.animate(
      [{ transform: `translate3d(${100 * dir}%,0,0)` }, { transform: 'translate3d(0,0,0)' }],
      { duration: DURATION, easing: EASING, fill: 'forwards' }
    );
    await Promise.all([out.finished, into.finished]);
    out.cancel();
    into.cancel();
  }

  async function zoomTransition(cur, nxt) {
    nxt.style.opacity = '0';
    nxt.style.visibility = 'visible';
    nxt.style.zIndex = '2';
    nxt.style.pointerEvents = 'none';
    cur.style.zIndex = '1';
    cur.style.willChange = 'transform, opacity';
    nxt.style.willChange = 'transform, opacity';
    const out = cur.animate(
      [{ transform: 'scale3d(1,1,1)', opacity: 1 }, { transform: 'scale3d(0.85,0.85,1)', opacity: 0 }],
      { duration: DURATION, easing: EASING, fill: 'forwards' }
    );
    const into = nxt.animate(
      [{ transform: 'scale3d(1.15,1.15,1)', opacity: 0 }, { transform: 'scale3d(1,1,1)', opacity: 1 }],
      { duration: DURATION, easing: EASING, fill: 'forwards' }
    );
    await Promise.all([out.finished, into.finished]);
    out.cancel();
    into.cancel();
  }

  function getTransitionFn() {
    return state.transitionMode === 'fade' ? fadeTransition
         : state.transitionMode === 'zoom' ? zoomTransition
         : slideTransition;
  }

  // ===== NAVIGATION =====
  async function goTo(idx) {
    if (state.isAnimating || idx === state.currentSlide || idx < 0 || idx >= slides.length) return;
    state.isAnimating = true;
    const cur = slides[state.currentSlide];
    const nxt = slides[idx];
    const dir = idx > state.currentSlide ? 1 : -1;
    try {
      await getTransitionFn()(cur, nxt, dir);
    } finally {
      cur.classList.remove('active');
      cur.style.cssText = '';
      nxt.classList.add('active');
      nxt.style.cssText = '';
      state.currentSlide = idx;
      state.currentStep = -1;
      resetFragments(nxt);
      updateUI();
      updateHash();
      updateNotes();
      state.isAnimating = false;
    }
  }

  function next() {
    const slide = slides[state.currentSlide];
    const steps = getSteps(slide);
    const ni = steps.findIndex(s => s > state.currentStep);
    if (ni !== -1) {
      state.currentStep = steps[ni];
      applyStep(slide, state.currentStep);
    } else if (state.currentSlide < slides.length - 1) {
      goTo(state.currentSlide + 1);
    }
  }

  function prev() {
    const slide = slides[state.currentSlide];
    const steps = getSteps(slide);
    const ci = steps.indexOf(state.currentStep);
    if (ci > 0) {
      state.currentStep = steps[ci - 1];
      applyStep(slide, state.currentStep);
    } else if (ci === 0) {
      state.currentStep = -1;
      applyStep(slide, -1);
    } else if (state.currentSlide > 0) {
      goTo(state.currentSlide - 1).then(() => showAllFragments(slides[state.currentSlide]));
    }
  }

  // ===== UI =====
  function updateUI() {
    const pct = slides.length > 1 ? (state.currentSlide / (slides.length - 1)) * 100 : 100;
    progressFill.style.width = `${pct}%`;
    currentNum.textContent = String(state.currentSlide + 1).padStart(2, '0');
  }

  function updateHash() {
    history.replaceState({ slide: state.currentSlide }, '', `#slide-${state.currentSlide + 1}`);
  }

  function updateNotes() {
    const n = slides[state.currentSlide].querySelector('.speaker-notes');
    notesContent.textContent = n ? n.textContent.trim() : '(노트 없음)';
  }

  function toggleNotes() {
    state.notesVisible = !state.notesVisible;
    notesOverlay.classList.toggle('visible', state.notesVisible);
  }

  function toggleHelp() {
    state.helpVisible = !state.helpVisible;
    helpOverlay.classList.toggle('visible', state.helpVisible);
  }

  function cycleTransition() {
    const i = TRANSITION_MODES.indexOf(state.transitionMode);
    state.transitionMode = TRANSITION_MODES[(i + 1) % TRANSITION_MODES.length];
    if (transitionLabel) transitionLabel.textContent = state.transitionMode;
  }

  // ===== KEYBOARD =====
  document.addEventListener('keydown', (e) => {
    if (e.altKey || e.ctrlKey || e.metaKey) return;
    if (['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)) return;
    if (state.helpVisible && e.key !== '?') { e.preventDefault(); toggleHelp(); return; }

    switch (e.key) {
      case 'ArrowRight': case 'PageDown':
        e.preventDefault(); goTo(state.currentSlide + 1); break;
      case 'ArrowLeft': case 'PageUp':
        e.preventDefault(); goTo(state.currentSlide - 1); break;
      case 'ArrowDown': case ' ':
        e.preventDefault(); next(); break;
      case 'ArrowUp':
        e.preventDefault(); prev(); break;
      case 'Home':
        e.preventDefault(); goTo(0); break;
      case 'End':
        e.preventDefault(); goTo(slides.length - 1); break;
      case 'f': case 'F':
        if (!document.fullscreenElement) {
          document.documentElement.requestFullscreen();
        } else {
          document.exitFullscreen();
        }
        break;
      case 'n': case 'N': toggleNotes(); break;
      case 't': case 'T': cycleTransition(); break;
      case '?': toggleHelp(); break;
      case 'Escape':
        if (document.fullscreenElement) { document.exitFullscreen(); }
        else if (state.helpVisible) { toggleHelp(); }
        else if (state.notesVisible) { toggleNotes(); }
        break;
    }
  });

  // ===== TOUCH =====
  let tx = 0, ty = 0, tt = 0;
  frame.addEventListener('touchstart', (e) => {
    const t = e.changedTouches[0];
    tx = t.clientX; ty = t.clientY; tt = Date.now();
  }, { passive: true });

  frame.addEventListener('touchend', (e) => {
    const t = e.changedTouches[0];
    const dx = t.clientX - tx;
    const ax = Math.abs(dx);
    const ay = Math.abs(t.clientY - ty);
    if (ax < 50 || Date.now() - tt > 500 || ax < ay * 1.5) return;
    if (dx < 0) goTo(state.currentSlide + 1);
    else goTo(state.currentSlide - 1);
  }, { passive: true });

  // ===== CLICK =====
  document.querySelector('.prev-btn').addEventListener('click', () => goTo(state.currentSlide - 1));
  document.querySelector('.next-btn').addEventListener('click', () => goTo(state.currentSlide + 1));

  // ===== HASH =====
  function slideFromHash() {
    const m = window.location.hash.match(/^#slide-(\d+)$/);
    if (m) {
      const i = parseInt(m[1], 10) - 1;
      if (i >= 0 && i < slides.length) return i;
    }
    return 0;
  }

  window.addEventListener('popstate', (e) => {
    goTo(e.state?.slide ?? slideFromHash());
  });

  window.addEventListener('hashchange', () => {
    const t = slideFromHash();
    if (t !== state.currentSlide) goTo(t);
  });

  // ===== INIT =====
  const init = slideFromHash();
  if (init > 0) {
    slides[0].classList.remove('active');
    slides[init].classList.add('active');
    state.currentSlide = init;
  }
  history.replaceState({ slide: state.currentSlide }, '', `#slide-${state.currentSlide + 1}`);
  updateUI();
  updateNotes();
})();
```
