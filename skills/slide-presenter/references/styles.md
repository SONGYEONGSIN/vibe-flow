# CSS 디자인 시스템 레퍼런스

prototype.html에서 검증된 전체 CSS. 스킬 사용 시 이 코드를 기반으로 생성한다.

## 전체 CSS

```css
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --bg:       #050507;
  --bg-card:  rgba(255,255,255,0.03);
  --border:   rgba(255,255,255,0.07);
  --accent:   #C6A55C;
  --accent-dim: rgba(198,165,92,0.15);
  --text:     #F2EDE4;
  --text-sub: #9E9688;
  --text-mute: #5C574E;
  --code-bg:  #0A0A0E;
  --font-body: 'Noto Sans KR', 'Inter', sans-serif;
  --font-code: 'JetBrains Mono', 'Consolas', monospace;
}

body {
  font-family: var(--font-body);
  background: var(--bg);
  color: var(--text);
  overflow: hidden;
}

/* === FULLSCREEN VIEWPORT === */
.slide-frame {
  position: fixed;
  inset: 0;
  width: 100vw;
  height: 100dvh;
  height: 100vh;
  overflow: hidden;
  background: var(--bg);
}

/* === SLIDES === */
.slide {
  position: absolute;
  inset: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 0 10vw;
  opacity: 0;
  visibility: hidden;
  pointer-events: none;
  z-index: 0;
}

.slide.active {
  opacity: 1;
  visibility: visible;
  pointer-events: auto;
  z-index: 1;
}

.slide-inner {
  width: 100%;
  max-width: 680px;
}

/* === TYPOGRAPHY === */
.slide h1 {
  font-size: clamp(2.2rem, 5.5vmin, 3.8rem);
  font-weight: 700;
  color: var(--text);
  line-height: 1.15;
  margin-bottom: 0.5em;
  letter-spacing: -0.02em;
}

.slide h2 {
  font-size: clamp(1.5rem, 3.8vmin, 2.4rem);
  font-weight: 700;
  color: var(--text);
  line-height: 1.2;
  margin-bottom: 0.8em;
  letter-spacing: -0.01em;
}

.slide h2.gold { color: var(--accent); }

.slide p {
  font-size: clamp(0.85rem, 1.8vmin, 1.1rem);
  line-height: 1.7;
  color: var(--text-sub);
}

.slide .hint {
  font-size: clamp(0.75rem, 1.3vmin, 0.85rem);
  color: var(--text-mute);
}

.slide strong { color: var(--accent); font-weight: 700; }

.speaker-notes { display: none; }

/* === LABEL === */
.slide-label {
  font-family: var(--font-code);
  font-size: clamp(0.65rem, 1.2vmin, 0.8rem);
  color: var(--accent);
  text-transform: uppercase;
  letter-spacing: 0.12em;
  margin-bottom: 0.6em;
}

/* === ACCENT BAR === */
.accent-bar {
  width: 40px;
  height: 2px;
  background: var(--accent);
  margin: 1.2em 0;
}

/* === FEATURE LIST === */
.feature-list {
  list-style: none;
  margin-top: 0.8em;
}

.feature-list li {
  font-size: clamp(0.85rem, 1.8vmin, 1.1rem);
  color: var(--text-sub);
  padding: 0.9em 0;
  border-bottom: 1px solid var(--border);
  line-height: 1.5;
}

.feature-list li:last-child { border-bottom: none; }
.feature-list li::before { content: '\2192\00a0\00a0'; color: var(--accent); }

/* === DEF GRID === */
.def-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0;
  margin-top: 1em;
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
}

.def-item { padding: 1.2em 1.5em; }
.def-item:nth-child(1) { border-bottom: 1px solid var(--border); border-right: 1px solid var(--border); }
.def-item:nth-child(2) { border-bottom: 1px solid var(--border); }
.def-item:nth-child(3) { border-right: 1px solid var(--border); }

.def-item dt {
  font-size: clamp(0.8rem, 1.5vmin, 0.95rem);
  font-weight: 700;
  color: var(--accent);
  margin-bottom: 0.3em;
}

.def-item dd {
  font-size: clamp(0.75rem, 1.3vmin, 0.85rem);
  color: var(--text-sub);
  line-height: 1.5;
}

/* === INFO CARD === */
.info-card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 1.3em 1.5em;
  margin-top: 1em;
}

.info-card .card-comment {
  font-family: var(--font-code);
  font-size: clamp(0.65rem, 1.1vmin, 0.75rem);
  color: var(--text-mute);
  margin-bottom: 0.8em;
}

.info-card p {
  font-size: clamp(0.8rem, 1.5vmin, 0.95rem);
  color: var(--text-sub);
  line-height: 1.7;
}

/* === CODE BLOCK === */
.code-block {
  background: var(--code-bg);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 0;
  font-family: var(--font-code);
  font-size: clamp(0.65rem, 1.3vmin, 0.85rem);
  line-height: 1.8;
  overflow-x: auto;
  margin-top: 1em;
}

.code-lang {
  display: block;
  padding: 0.6em 1.2em 0;
  font-size: clamp(0.55rem, 0.9vmin, 0.65rem);
  color: var(--text-mute);
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.code-lines { padding: 0.4em 0 0.8em; }

.code-block .line {
  display: block;
  padding: 0.15em 1.2em 0.15em 0;
  transition: opacity 0.3s ease, background-color 0.3s ease;
}

.code-block .line .line-num {
  display: inline-block;
  width: 2.5em;
  text-align: right;
  margin-right: 1em;
  color: transparent;
  user-select: none;
}

.code-block.hl-active .line { opacity: 0.25; }
.code-block.hl-active .line.hl {
  opacity: 1;
  background: rgba(198,165,92,0.06);
  border-left: 3px solid var(--accent);
}
.code-block.hl-active .line.hl .line-num { color: var(--text-mute); }

.kw { color: #B0B0B0; }
.fn { color: var(--text-sub); }
.str { color: #A8C98A; }
.tag { color: var(--text-sub); }
.val { color: #A8C98A; }

/* === CARD GRID === */
.card-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
  margin-top: 1em;
}

.card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 1.3em 1.4em;
}

.card h3 {
  font-size: clamp(0.8rem, 1.5vmin, 0.95rem);
  font-weight: 700;
  color: var(--accent);
  margin-bottom: 0.6em;
}

.card ul {
  list-style: none;
  font-size: clamp(0.75rem, 1.3vmin, 0.85rem);
  color: var(--text-sub);
  line-height: 1.8;
}

/* === FRAGMENTS === */
.fragment {
  opacity: 0;
  visibility: hidden;
  transform: translateY(14px);
  transition: opacity 0.4s ease, transform 0.4s ease, visibility 0.4s;
}

.fragment.visible {
  opacity: 1;
  visibility: visible;
  transform: translateY(0);
}

.fragment.stagger { transition-delay: calc(var(--i, 0) * 80ms); }

.fragment.highlight {
  opacity: 1; visibility: visible; transform: none;
  transition: color 0.3s ease, background-color 0.3s ease;
}

.fragment.highlight.visible {
  color: var(--bg);
  background: var(--accent);
  padding: 0.1em 0.4em;
  border-radius: 4px;
}

.fragment.visible.past { opacity: 0.4; }

/* === UI OVERLAYS === */
.progress-container {
  position: absolute;
  bottom: 0; left: 0;
  width: 100%; height: 2px;
  background: rgba(255,255,255,0.03);
  z-index: 100;
}

.progress-fill {
  height: 100%; width: 0%;
  background: var(--accent);
  transition: width 0.3s ease;
}

.slide-counter {
  position: absolute;
  bottom: 16px; right: 20px;
  font-family: var(--font-code);
  font-size: clamp(0.6rem, 1vmin, 0.75rem);
  color: var(--text-mute);
  font-variant-numeric: tabular-nums;
  z-index: 100;
  user-select: none;
}

.slide-controls {
  position: absolute;
  bottom: 12px; left: 16px;
  display: flex; gap: 4px;
  z-index: 100;
}

.slide-controls button {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-mute);
  width: 28px; height: 28px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 12px;
  transition: color 0.2s, border-color 0.2s;
}

.slide-controls button:hover {
  color: var(--accent);
  border-color: rgba(198,165,92,0.3);
}

#notes-overlay {
  position: absolute;
  bottom: 0; left: 0; right: 0;
  background: rgba(5,5,7,0.95);
  border-top: 1px solid var(--border);
  color: var(--text-sub);
  padding: 1em 10vw;
  font-size: clamp(0.7rem, 1.2vmin, 0.85rem);
  line-height: 1.6;
  max-height: 25%;
  overflow-y: auto;
  transform: translateY(100%);
  transition: transform 0.3s ease;
  z-index: 200;
}

#notes-overlay.visible { transform: translateY(0); }

.help-overlay {
  position: absolute; inset: 0;
  background: rgba(5,5,7,0.95);
  display: none;
  justify-content: center; align-items: center;
  z-index: 300;
  color: var(--text-sub);
  font-size: clamp(0.7rem, 1.3vmin, 0.85rem);
}

.help-overlay.visible { display: flex; }
.help-content { text-align: left; line-height: 2.2; }

.help-content kbd {
  background: rgba(198,165,92,0.08);
  border: 1px solid rgba(198,165,92,0.15);
  color: var(--accent);
  padding: 0.1em 0.5em;
  border-radius: 4px;
  font-family: var(--font-code);
  font-size: 0.85em;
}

@media (max-width: 700px) {
  .slide { padding: 0 6vw; }
  .def-grid, .card-grid { grid-template-columns: 1fr; }
}
```
