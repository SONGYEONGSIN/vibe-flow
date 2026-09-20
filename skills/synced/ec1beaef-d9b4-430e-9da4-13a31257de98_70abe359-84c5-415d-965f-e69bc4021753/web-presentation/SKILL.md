---
name: web-presentation
description: |
  **Web Presentation Builder**: Create beautiful, interactive HTML slide presentations that run in any browser. Use this skill whenever the user asks for a web presentation, HTML slides, browser-based slides, web slide deck, or any presentation that should open in a browser rather than PowerPoint. Also trigger when the user says "웹 프레젠테이션", "HTML 프레젠테이션", "웹 슬라이드", "브라우저 프레젠테이션", or asks to convert existing content into a web-viewable slide format. This skill is the right choice when: the user wants slides that don't require PowerPoint/Keynote, needs interactive elements (animations, hover effects, live data), wants a self-contained single HTML file, or prefers a modern web-based presentation over traditional formats.
---

# Web Presentation Builder

Create self-contained, single-file HTML slide presentations with modern design, smooth animations, keyboard/touch navigation, and responsive layout.

## When to Use This Skill

Use this skill when the user wants any kind of browser-based presentation. This includes:
- Explicit requests: "웹 프레젠테이션", "HTML slides", "web slide deck"
- Implicit needs: "브라우저에서 볼 수 있는 발표자료", "파워포인트 없이 프레젠테이션"
- Conversion requests: "이 내용을 웹 슬라이드로 만들어줘", "보고서를 프레젠테이션으로"

## Architecture: Single-File HTML

Everything goes in one `.html` file — HTML structure, CSS styles, and JavaScript logic. This makes the presentation portable: the user can open it in any browser, email it, or host it on any server. Never split into separate CSS/JS files.

## Slide Deck Structure

A typical presentation has 6-12 slides. Here's the recommended structure depending on the use case:

**Business/Report presentations:**
1. Cover slide (title, subtitle, date)
2. Overview/key metrics (stats boxes or summary)
3-7. Content slides (data, charts, details)
8. Outlook/next steps
9. End slide

**Educational/Explainer presentations:**
1. Cover slide
2. Agenda/overview
3-7. Topic slides with visuals
8. Summary/takeaways
9. Q&A / End slide

**Pitch/Proposal presentations:**
1. Cover slide
2. Problem statement
3. Solution overview
4-6. Key features/benefits
7. Timeline or pricing
8. Call to action / End slide

## Design System

### Typography
Use Google Fonts for professional Korean+English typography:
```html
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;600;700;900&display=swap" rel="stylesheet">
```
- Primary font: `'Noto Sans KR', sans-serif`
- Cover title: 48-56px, font-weight 900
- Slide title: 32-40px, font-weight 700
- Body text: 17-20px, font-weight 400
- Captions/labels: 13-16px

### Color Palette
Define a cohesive palette using CSS variables. Choose one that matches the topic's tone:

**Professional/Corporate (default):**
```css
:root {
  --primary: #1a365d;
  --primary-light: #2b6cb0;
  --accent: #e53e3e;
  --bg: #f7fafc;
  --card: #ffffff;
  --text: #2d3748;
  --text-light: #718096;
  --border: #e2e8f0;
}
```

**Warm/Creative:**
```css
:root {
  --primary: #744210;
  --primary-light: #d69e2e;
  --accent: #dd6b20;
  --bg: #fffaf0;
  --card: #ffffff;
  --text: #2d3748;
  --text-light: #718096;
  --border: #e2e8f0;
}
```

**Tech/Modern:**
```css
:root {
  --primary: #1a202c;
  --primary-light: #805ad5;
  --accent: #38b2ac;
  --bg: #f7fafc;
  --card: #ffffff;
  --text: #2d3748;
  --text-light: #718096;
  --border: #e2e8f0;
}
```

Feel free to create custom palettes that fit the content — the above are starting points, not constraints.

### Slide Themes

Each slide should have a visual theme class. Varying themes across slides creates rhythm and prevents monotony:

```css
.slide-cover   /* gradient background, white text, centered — for title slides */
.slide-white   /* light background — for content with cards, tables, timelines */
.slide-dark    /* dark background — for stats, emphasis, key messages */
.slide-accent  /* primary color background — for important points, calls to action */
.slide-end     /* gradient background — for closing slide */
```

A good rhythm example: cover → dark(stats) → white(content) → white(content) → accent(key point) → white(content) → dark(outlook) → end

### Component Library

Build slides from these reusable components:

**Stats Grid** — For key numbers and metrics:
```html
<div class="stats"> <!-- grid: repeat(3-4, 1fr) -->
  <div class="stat">
    <div class="stat-value">42%</div>
    <div class="stat-label">Growth Rate</div>
    <div class="stat-sub">Year over year</div>
  </div>
</div>
```

**Cards Grid** — For features, categories, comparisons:
```html
<div class="cards"> <!-- grid: repeat(2-3, 1fr) -->
  <div class="card">
    <div class="card-icon">🎯</div>
    <div class="card-name">Title</div>
    <div class="card-detail">Description text</div>
    <div class="card-badge badge-success">Status</div>
  </div>
</div>
```

**Timeline** — For chronological information:
```html
<div class="timeline">
  <div class="tl-item done"> <!-- done/progress/upcoming -->
    <div class="tl-date">2026년 3월</div>
    <div class="tl-title">Milestone title</div>
    <div class="tl-desc">Description</div>
  </div>
</div>
```

**Tables** — For structured data:
```html
<table>
  <thead><tr><th>Column</th></tr></thead>
  <tbody><tr><td>Data</td></tr></tbody>
</table>
```

**Bullet Lists** — For key points (use custom styled lists, not default `<ul>`):
```html
<ul class="bullet-list">
  <li>Point with <strong>emphasis</strong> on key terms</li>
</ul>
```

**Two-Column Layout** — For side-by-side content:
```html
<div class="two-col"> <!-- grid: 1fr 1fr -->
  <div>Left content</div>
  <div>Right content</div>
</div>
```

**Badge/Tag** — For status indicators:
```html
<span class="card-badge badge-success">Complete</span>
<span class="card-badge badge-warning">In Progress</span>
<span class="card-badge badge-danger">Critical</span>
<span class="card-badge badge-info">Info</span>
```

### Navigation System

Every presentation needs these navigation features:

1. **Keyboard**: Left/Right arrows, Space (forward), Home/End
2. **Click buttons**: Previous/Next with slide counter
3. **Touch**: Swipe left/right for mobile
4. **Progress bar**: Thin bar at top showing progress

```javascript
// Core navigation pattern
let current = 0;
const slides = document.querySelectorAll('.slide');
const total = slides.length;

function showSlide(index) {
  slides.forEach(s => s.classList.remove('active'));
  slides[index].classList.add('active');
  // Update progress bar and counter
}

function changeSlide(dir) {
  current = Math.max(0, Math.min(total - 1, current + dir));
  showSlide(current);
}

// Keyboard
document.addEventListener('keydown', e => {
  if (e.key === 'ArrowRight' || e.key === ' ') { e.preventDefault(); changeSlide(1); }
  if (e.key === 'ArrowLeft') { e.preventDefault(); changeSlide(-1); }
});

// Touch
let touchStartX = 0;
document.addEventListener('touchstart', e => { touchStartX = e.touches[0].clientX; });
document.addEventListener('touchend', e => {
  const diff = touchStartX - e.changedTouches[0].clientX;
  if (Math.abs(diff) > 50) changeSlide(diff > 0 ? 1 : -1);
});
```

### Animations

Use subtle entrance animations that trigger when a slide becomes active. Cards, stats, and timeline items should stagger their entrances:

```css
.slide.active .card,
.slide.active .stat,
.slide.active .tl-item {
  animation: fadeUp 0.5s ease forwards;
  opacity: 0;
}

.slide.active .card:nth-child(1) { animation-delay: 0.1s; }
.slide.active .card:nth-child(2) { animation-delay: 0.2s; }
/* etc. */

@keyframes fadeUp {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}
```

Slide transitions should be smooth but fast:
```css
.slide {
  transition: opacity 0.5s ease, transform 0.5s ease;
  transform: translateX(40px);
}
.slide.active {
  transform: translateX(0);
}
```

### Responsive Design

The presentation should work on screens from phones to large monitors:

```css
@media (max-width: 900px) {
  .slide { padding: 40px; }
  .cover-title { font-size: 36px; }
  .cards { grid-template-columns: 1fr; }
  .stats { grid-template-columns: repeat(2, 1fr); }
  .two-col { grid-template-columns: 1fr; }
}
```

## Content Guidelines

- **One idea per slide**: Don't overcrowd. If content overflows, split into multiple slides.
- **Visual hierarchy**: Use size and weight to guide the eye. Titles → subtitles → body → captions.
- **Data over text**: Prefer stats boxes, cards, and tables over long paragraphs.
- **Contrast themes**: Alternate between light and dark slides to maintain visual interest.
- **Emoji as icons**: Use emoji for card icons — they're universally supported and add personality without external dependencies.
- **Highlight key terms**: Use `<strong>` and accent colors to draw attention to important words.
- **Korean/English**: Support both languages naturally. The font stack handles both.

## Output

Save the HTML file to the user's workspace folder. The filename should be descriptive and match the presentation topic.

## Checklist Before Delivery

1. All slides render correctly (no overflow, no broken layout)
2. Keyboard navigation works (arrows, space, home/end)
3. Touch swipe works
4. Progress bar updates correctly
5. Animations play on slide entry
6. Text is readable on all slide themes (contrast check)
7. Responsive layout works at smaller widths
