const C = {
  bg: { r: 0.065, g: 0.098, b: 0.145 },
  surface: { r: 0.082, g: 0.13, b: 0.19 },
  glass: { r: 0.19, g: 0.28, b: 0.39 },
  line: { r: 0.62, g: 0.72, b: 0.86 },
  text: { r: 0.95, g: 0.97, b: 1 },
  softText: { r: 0.78, g: 0.84, b: 0.93 },
  muted: { r: 0.57, g: 0.66, b: 0.79 },
  lavender: { r: 0.61, g: 0.55, b: 1 },
  teal: { r: 0.28, g: 0.76, b: 0.7 },
  amber: { r: 1, g: 0.82, b: 0.28 },
  blue: { r: 0.075, g: 0.31, b: 0.83 },
  navActive: { r: 0.39, g: 0.62, b: 1 },
  blueDeep: { r: 0.06, g: 0.14, b: 0.31 },
  blueDark: { r: 0.035, g: 0.18, b: 0.57 }
};

const solid = (color, opacity = 1) => [{ type: 'SOLID', color, opacity }];
const shadow = (color, alpha, radius, y) => [{
  type: 'DROP_SHADOW', color: { ...color, a: alpha }, offset: { x: 0, y }, radius, spread: 0, visible: true, blendMode: 'NORMAL'
}];

async function load(style = 'Regular') {
  try {
    await figma.loadFontAsync({ family: 'Noto Sans SC', style });
    return { family: 'Noto Sans SC', style };
  } catch (_) {
    await figma.loadFontAsync({ family: 'Inter', style });
    return { family: 'Inter', style };
  }
}

async function text(parent, value, x, y, size, color, style = 'Regular', width) {
  const fontName = await load(style);
  const node = figma.createText();
  node.fontName = fontName;
  node.characters = value;
  node.fontSize = size;
  node.fills = solid(color);
  node.x = x;
  node.y = y;
  if (width) {
    node.resize(width, node.height);
    node.textAutoResize = 'HEIGHT';
  }
  parent.appendChild(node);
  return node;
}

function rect(parent, x, y, w, h, fill, radius = 16, opacity = 1) {
  const node = figma.createRectangle();
  node.resize(w, h);
  node.x = x; node.y = y;
  node.cornerRadius = radius;
  node.fills = solid(fill, opacity);
  parent.appendChild(node);
  return node;
}

function ellipse(parent, x, y, w, h, fill, opacity = 1, blur = 0) {
  const node = figma.createEllipse();
  node.resize(w, h); node.x = x; node.y = y;
  node.fills = solid(fill, opacity);
  if (blur) node.effects = [{ type: 'LAYER_BLUR', radius: blur, visible: true }];
  parent.appendChild(node);
  return node;
}

function hex(color) {
  return [color.r, color.g, color.b]
    .map(value => Math.round(value * 255).toString(16).padStart(2, '0'))
    .join('');
}

// Lucide icons: a consistent external icon set, imported as its original SVG paths.
function lucide(parent, paths, x, y, size, color, strokeWidth = 1.8) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#${hex(color)}" stroke-width="${strokeWidth}" stroke-linecap="round" stroke-linejoin="round">${paths}</svg>`;
  const node = figma.createNodeFromSvg(svg);
  node.resize(size, size);
  node.x = x; node.y = y;
  parent.appendChild(node);
  return node;
}

async function makeTaskCard(phone, x, y, w, h, title, meta, accent, count, isFocus = false, innerOnRight = false) {
  const card = rect(phone, x, y, w, h, isFocus ? C.blue : C.blueDeep, 20, isFocus ? 1 : 0.68);
  if (!isFocus) {
    // Side cards are the dim state of the same blue tile. Their inner edge stays visible,
    // while the outer edge melts into the dark background for a smooth swipe transition.
    const bright = { ...C.blueDark, a: 0.88 };
    const dark = { ...C.bg, a: 0.08 };
    card.fills = [{
      type: 'GRADIENT_LINEAR',
      gradientStops: innerOnRight
        ? [{ position: 0, color: dark }, { position: 1, color: bright }]
        : [{ position: 0, color: bright }, { position: 1, color: dark }],
      gradientTransform: [[1, 0, 0], [0, 1, 0]]
    }];
    card.strokes = solid(C.line, 0.12); card.strokeWeight = 1;
  }
  if (isFocus) {
    card.effects = shadow({ r: 0, g: 0.01, b: 0.05 }, 0.34, 8, 5);
    // The active card is a calm stage for the one task, not a collection of invented controls.
    await text(phone, title, x + 26, y + 48, 28, C.text, 'Semi Bold', w - 52);
    await text(phone, meta, x + 26, y + 93, 14, C.text, 'Regular', w - 52);
  } else {
    // The neighbours are intentionally smaller, darker, and quieter than the current task.
    const accentX = innerOnRight ? x + w - 54 : x + 20;
    const accentBlock = rect(phone, accentX, y + 24, 52, 52, accent, 18, 0.72);
    accentBlock.effects = [];
  }
  return card;
}

async function makeCalendarRow(phone, y, state, title, time) {
  const divider = rect(phone, 24, y, 382, 1, C.line, 1, 0.14);
  divider.effects = [];
  const statusIcons = {
    completed: '<circle cx="12" cy="12" r="9"/><path d="m8 12 2.5 2.5L16 9"/>',
    pending: '<circle cx="12" cy="12" r="9"/><path d="m9 9 6 6m0-6-6 6"/>',
    ignored: '<circle cx="12" cy="12" r="9"/><path d="m8.5 15.5 7-7"/>'
  };
  const statusColor = state === 'completed' ? C.teal : (state === 'pending' ? C.softText : C.muted);
  lucide(phone, statusIcons[state], 24, y + 15, 24, statusColor, 1.8);
  await text(phone, title, 63, y + 19, 16, C.softText, 'Semi Bold');
  if (time) {
    const timeNode = await text(phone, time, 0, y + 21, 13, C.muted, 'Regular');
    timeNode.x = 382 - timeNode.width;
  }
}

async function run() {
  // The calendar is its own source page. Re-running this generator never touches 首页.
  const page = figma.root.children.find(node => node.type === 'PAGE' && node.name === '02 · 日历（深色）') || figma.createPage();
  page.name = '02 · 日历（深色）';
  figma.currentPage = page;
  for (const child of [...page.children]) child.remove();

  const phone = figma.createFrame();
  phone.name = '日历 · 月视图与当天事项';
  phone.resize(430, 932);
  phone.x = 120; phone.y = 80;
  phone.cornerRadius = 34;
  phone.clipsContent = true;
  phone.fills = solid(C.bg);
  phone.effects = shadow({ r: 0, g: 0, b: 0 }, 0.26, 24, 12);
  page.appendChild(phone);

  // Ambient light, not decoration: the glass planes borrow depth from these quiet sources.
  ellipse(phone, 156, -62, 390, 340, C.lavender, 0.22, 92);
  ellipse(phone, -126, 355, 285, 350, C.teal, 0.11, 86);
  ellipse(phone, 286, 414, 220, 360, C.lavender, 0.09, 88);
  ellipse(phone, 92, 716, 330, 220, C.blue, 0.14, 84);
  const topShade = rect(phone, 0, 0, 430, 360, C.surface, 0, 0.06);
  topShade.effects = [{ type: 'LAYER_BLUR', radius: 34, visible: true }];

  // System status bar.
  await text(phone, '9:41', 25, 28, 14, C.text, 'Semi Bold');
  lucide(phone, '<path d="M2 22h20"/><path d="M5 18v-4M9 18V9M13 18V5M17 18V2"/>', 324, 27, 16, C.text, 1.8);
  lucide(phone, '<path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><path d="M12 20h.01"/>', 346, 27, 17, C.text, 1.7);
  lucide(phone, '<rect width="16" height="10" x="3" y="7" rx="2"/><path d="M21 11v2"/><path d="M7 10h8v4H7z" fill="#f2f7ff" stroke="none"/>', 373, 27, 18, C.text, 1.7);
  // The monthly context lives on one distinct Aqara-like glass plane.
  const todayButton = rect(phone, 24, 74, 68, 34, C.surface, 17, 0.42);
  todayButton.strokes = solid(C.line, 0.16); todayButton.strokeWeight = 1;
  todayButton.effects = [{ type: 'BACKGROUND_BLUR', radius: 16, visible: true }];
  lucide(phone, '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2"/>', 34, 83, 16, C.softText, 1.65);
  await text(phone, '今天', 56, 83, 12, C.softText, 'Regular');
  const recur = rect(phone, 296, 74, 102, 34, C.surface, 17, 0.42);
  recur.strokes = solid(C.line, 0.16); recur.strokeWeight = 1;
  recur.effects = [{ type: 'BACKGROUND_BLUR', radius: 16, visible: true }];
  lucide(phone, '<path d="M17 1l4 4-4 4"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><path d="m7 23-4-4 4-4"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/>', 307, 82, 16, C.softText, 1.65);
  await text(phone, '周期事项', 330, 83, 12, C.softText, 'Regular');
  const calendarPanel = rect(phone, 16, 116, 398, 348, C.glass, 22, 0.38);
  calendarPanel.strokes = solid(C.line, 0.21); calendarPanel.strokeWeight = 1;
  calendarPanel.effects = [{ type: 'BACKGROUND_BLUR', radius: 24, visible: true }];
  await text(phone, '2026年5月', 32, 135, 25, C.softText, 'Semi Bold');
  lucide(phone, '<path d="m6 9 6 6 6-6"/>', 160, 145, 14, C.muted, 1.8);

  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  for (let i = 0; i < weekdays.length; i++) {
    await text(phone, weekdays[i], 45 + i * 51, 191, 12, C.softText, 'Regular');
  }
  const weekdayDivider = rect(phone, 32, 209, 366, 1, C.line, 1, 0.14);
  weekdayDivider.effects = [];
  const days = [
    ['28', '29', '30', '1', '2', '3', '4'],
    ['5', '6', '7', '8', '9', '10', '11'],
    ['12', '13', '14', '15', '16', '17', '18'],
    ['19', '20', '21', '22', '23', '24', '25'],
    ['26', '27', '28', '29', '30', '31', '1']
  ];
  const lunar = {
    '1': '初一', '2': '初二', '3': '初三', '4': '初四', '5': '初五', '6': '初六', '7': '初七', '8': '初八', '9': '初九', '10': '初十',
    '11': '十一', '12': '十二', '13': '十三', '14': '十四', '15': '十五', '16': '十六', '17': '十七', '18': '十八', '19': '十九', '20': '廿',
    '21': '廿一', '22': '廿二', '23': '廿三', '24': '廿四', '25': '廿五', '26': '廿六', '27': '廿七', '28': '廿八', '29': '廿九', '30': '三十', '31': '初一'
  };
  const taskDots = {
    '1-0': [C.teal],
    '2-2': [C.lavender, C.amber],
    '3-1': [C.teal, C.lavender, C.amber],
    '3-5': [C.lavender]
  };
  for (let row = 1; row < days.length; row++) {
    const weekDivider = rect(phone, 32, 213 + row * 43, 366, 1, C.line, 1, 0.1);
    weekDivider.effects = [];
  }
  for (let row = 0; row < days.length; row++) {
    for (let column = 0; column < days[row].length; column++) {
      const day = days[row][column];
      const x = 36 + column * 51;
      const y = 219 + row * 43;
      const outside = (row === 0 && column < 3) || (row === 4 && column === 6);
      if (day === '20') {
        const selectedDay = ellipse(phone, x - 5, y - 7, 40, 40, C.blue, 0.95);
        selectedDay.effects = shadow(C.blue, 0.26, 8, 3);
      }
      const foreground = day === '20' ? C.text : (outside ? C.muted : C.softText);
      const dateNode = await text(phone, day, 0, y - 1, 14, foreground, day === '20' ? 'Semi Bold' : 'Regular');
      dateNode.x = x + 15 - dateNode.width / 2;
      const lunarNode = await text(phone, lunar[day], 0, y + 16, 10, foreground, 'Regular');
      lunarNode.x = x + 15 - lunarNode.width / 2;
      const marks = outside ? [] : (taskDots[`${row}-${column}`] || []);
      for (let mark = 0; mark < marks.length; mark++) {
        const dot = ellipse(phone, x + 15 - ((marks.length - 1) * 3) + mark * 6 - 2, y + 34, 4, 4, marks[mark], 0.92);
        dot.effects = [];
      }
    }
  }

  const calendarDivider = rect(phone, 24, 484, 382, 1, C.line, 1, 0.16);
  calendarDivider.effects = [];
  await text(phone, '5月20日 · 星期三', 24, 508, 17, C.softText, 'Semi Bold');
  await makeCalendarRow(phone, 544, 'pending', '给诊所打电话', '09:30');
  await makeCalendarRow(phone, 602, 'completed', '给植物浇水', '');
  await makeCalendarRow(phone, 660, 'ignored', '整理收据', '');
  const addDivider = rect(phone, 24, 718, 382, 1, C.line, 1, 0.14);
  addDivider.effects = [];
  const addLabel = await text(phone, '＋ 新增事项', 0, 740, 14, C.muted, 'Semi Bold');
  addLabel.x = (430 - addLabel.width) / 2;

  // A floating liquid-glass tab bar: translucent, blurred, and held by a fine highlight
  // rather than a thick dark toolbar.
  const nav = rect(phone, 54, 840, 322, 58, C.glass, 29, 0.54);
  nav.strokes = solid(C.line, 0.28); nav.strokeWeight = 1;
  nav.effects = [
    { type: 'BACKGROUND_BLUR', radius: 22, visible: true },
    { type: 'DROP_SHADOW', color: { r: 0, g: 0.015, b: 0.05, a: 0.22 }, offset: { x: 0, y: 8 }, radius: 18, spread: 0, visible: true, blendMode: 'NORMAL' }
  ];
  const navIcons = [
    '<path d="m3 10 9-7 9 7v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/><path d="M9 22V12h6v10"/>',
    '<rect width="18" height="18" x="3" y="4" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
    '<rect width="6" height="6" x="3" y="3" rx="1"/><rect width="6" height="6" x="15" y="3" rx="1"/><rect width="6" height="6" x="3" y="15" rx="1"/><rect width="6" height="6" x="15" y="15" rx="1"/>',
    '<circle cx="12" cy="8" r="4"/><path d="M4 22a8 8 0 0 1 16 0"/>'
  ];
  const centres = [94, 174, 256, 336];
  for (let i = 0; i < navIcons.length; i++) {
    const active = i === 1;
    if (active) {
      const glow = lucide(phone, navIcons[i], centres[i] - 10, 861, 20, C.navActive, 3.1);
      glow.opacity = 0.52;
      glow.effects = [{ type: 'LAYER_BLUR', radius: 6, visible: true }];
    }
    lucide(phone, navIcons[i], centres[i] - 10, 861, 20, active ? C.navActive : C.muted, active ? 2.65 : 1.55);
  }
  const homeBar = rect(phone, 150, 908, 130, 5, C.text, 3, 0.96);
  homeBar.effects = [];
  figma.currentPage.selection = [phone];
  figma.viewport.scrollAndZoomIntoView([phone]);
}

async function makeCategoryRow(phone, y, name, color) {
  const row = rect(phone, 24, y, 382, 54, C.glass, 18, 0.5);
  row.strokes = solid(C.line, 0.24); row.strokeWeight = 1;
  row.effects = [
    { type: 'BACKGROUND_BLUR', radius: 18, visible: true },
    { type: 'DROP_SHADOW', color: { r: 0, g: 0.015, b: 0.05, a: 0.2 }, offset: { x: 0, y: 4 }, radius: 7, spread: 0, visible: true, blendMode: 'NORMAL' }
  ];
  const highlight = rect(phone, 43, y + 1, 344, 1, C.text, 1, 0.1);
  highlight.effects = [];
  const dot = ellipse(phone, 43, y + 21, 12, 12, color, 0.96);
  dot.effects = [];
  await text(phone, name, 68, y + 16, 16, C.softText, 'Semi Bold');
}

// The bar stays visually light in its resting state. The coloured copies are only
// shown on the dedicated transition keyframe — they describe a 220 ms icon trail,
// never a permanent rainbow decoration in the dark theme.
function makeNavBar(phone, activeIndex, showTrail = false) {
  const nav = rect(phone, 72, 846, 286, 50, C.glass, 25, 0.46);
  nav.strokes = solid(C.line, 0.16); nav.strokeWeight = 1;
  nav.effects = [
    { type: 'BACKGROUND_BLUR', radius: 20, visible: true },
    { type: 'DROP_SHADOW', color: { r: 0, g: 0.015, b: 0.05, a: 0.19 }, offset: { x: 0, y: 5 }, radius: 7, spread: 0, visible: true, blendMode: 'NORMAL' }
  ];
  const highlight = rect(phone, 91, 847, 248, 1, C.text, 1, 0.1);
  highlight.effects = [];
  const navIcons = [
    '<path d="m3 10 9-7 9 7v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/><path d="M9 22V12h6v10"/>',
    '<rect width="18" height="18" x="3" y="4" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
    '<rect width="6" height="6" x="3" y="3" rx="1"/><rect width="6" height="6" x="15" y="3" rx="1"/><rect width="6" height="6" x="3" y="15" rx="1"/><rect width="6" height="6" x="15" y="15" rx="1"/>',
    '<circle cx="12" cy="8" r="4"/><path d="M4 22a8 8 0 0 1 16 0"/>'
  ];
  const centres = [108, 180, 252, 324];
  if (showTrail) {
    const trail = [
      { dx: -28, color: C.lavender, opacity: 0.12, width: 1.5 },
      { dx: -18, color: C.teal, opacity: 0.2, width: 1.8 },
      { dx: -9, color: C.navActive, opacity: 0.32, width: 2.05 }
    ];
    for (const ghost of trail) {
      const node = lucide(phone, navIcons[activeIndex], centres[activeIndex] - 10 + ghost.dx, 861, 20, ghost.color, ghost.width);
      node.opacity = ghost.opacity;
      node.effects = [{ type: 'LAYER_BLUR', radius: 1.2, visible: true }];
    }
  }
  for (let i = 0; i < navIcons.length; i++) {
    const active = i === activeIndex;
    if (active) {
      const glow = lucide(phone, navIcons[i], centres[i] - 10, 861, 20, C.navActive, 3.2);
      glow.opacity = 0.36;
      glow.effects = [{ type: 'LAYER_BLUR', radius: 4.5, visible: true }];
    }
    lucide(phone, navIcons[i], centres[i] - 10, 861, 20, active ? C.navActive : C.muted, active ? 2.35 : 1.5);
  }
  const homeBar = rect(phone, 150, 908, 130, 5, C.text, 3, 0.96);
  homeBar.effects = [];
}

async function makeMotionPhone(page, x, activeIndex, showTrail, caption) {
  const phone = figma.createFrame();
  phone.name = caption;
  phone.resize(430, 932);
  phone.x = x; phone.y = 104;
  phone.cornerRadius = 34;
  phone.clipsContent = true;
  phone.fills = solid(C.bg);
  phone.effects = shadow({ r: 0, g: 0, b: 0 }, 0.26, 24, 12);
  page.appendChild(phone);
  ellipse(phone, 176, -72, 392, 350, C.lavender, 0.18, 92);
  ellipse(phone, -124, 430, 280, 360, C.teal, 0.08, 86);
  ellipse(phone, 102, 704, 330, 230, C.blue, 0.12, 84);
  await text(phone, '9:41', 25, 28, 14, C.text, 'Semi Bold');
  await text(phone, caption, 24, 82, 28, C.softText, 'Semi Bold');
  const detail = activeIndex === 0 ? '\u4eca\u65e5\u4e8b\u9879' : '\u6708\u89c6\u56fe';
  await text(phone, detail, 24, 128, 15, C.muted, 'Regular');
  const plane = rect(phone, 24, 178, 382, 238, C.glass, 20, 0.26);
  plane.strokes = solid(C.line, 0.11); plane.strokeWeight = 1;
  plane.effects = [{ type: 'BACKGROUND_BLUR', radius: 20, visible: true }];
  await text(phone, showTrail ? '\u5207\u6362\u4e2d\u2026' : '\u5f53\u524d\u9875\u9762', 48, 210, 17, C.softText, 'Semi Bold');
  await text(phone, showTrail ? '\u5149\u8f68\u53ea\u5728\u5207\u6362\u77ac\u95f4\u51fa\u73b0' : '\u8fd9\u4e2a\u72b6\u6001\u4e0d\u4fdd\u7559\u6b8b\u5f71', 48, 246, 14, C.muted, 'Regular');
  makeNavBar(phone, activeIndex, showTrail);
  return phone;
}

async function runNavigationMotionStudy() {
  const pageName = '04 \u00b7 \u5bfc\u822a\u52a8\u6548\u65b9\u6848\uff08\u6df1\u8272\uff09';
  const page = figma.root.children.find(node => node.type === 'PAGE' && node.name === pageName) || figma.createPage();
  page.name = pageName;
  figma.currentPage = page;
  for (const child of [...page.children]) child.remove();
  await makeMotionPhone(page, 80, 0, false, '\u9759\u6b62\u72b6\u6001');
  await makeMotionPhone(page, 590, 1, true, '\u5207\u6362\u77ac\u95f4');
  await makeMotionPhone(page, 1100, 1, false, '\u65e5\u5386\u9009\u4e2d');
  figma.currentPage.selection = [...page.children];
  figma.viewport.scrollAndZoomIntoView([...page.children]);
}

async function runHomeReminderStudy() {
  const pageName = '01.1 · 首页下拉提醒（深色）';
  const page = figma.root.children.find(node => node.type === 'PAGE' && node.name === pageName) || figma.createPage();
  page.name = pageName;
  figma.currentPage = page;
  for (const child of [...page.children]) child.remove();

  const phone = figma.createFrame();
  phone.name = '首页 · 下拉后的文档提醒';
  phone.resize(430, 932);
  phone.x = 120; phone.y = 80;
  phone.cornerRadius = 34;
  phone.clipsContent = true;
  phone.fills = solid(C.bg);
  phone.effects = shadow({ r: 0, g: 0, b: 0 }, 0.26, 24, 12);
  page.appendChild(phone);

  ellipse(phone, 176, -72, 392, 350, C.lavender, 0.18, 92);
  ellipse(phone, -124, 428, 280, 360, C.teal, 0.08, 86);
  ellipse(phone, 102, 704, 330, 230, C.blue, 0.12, 84);
  await text(phone, '9:41', 25, 28, 14, C.text, 'Semi Bold');
  lucide(phone, '<path d="M2 22h20"/><path d="M5 18v-4M9 18V9M13 18V5M17 18V2"/>', 324, 27, 16, C.text, 1.8);
  lucide(phone, '<path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><path d="M12 20h.01"/>', 346, 27, 17, C.text, 1.7);
  lucide(phone, '<rect width="16" height="10" x="3" y="7" rx="2"/><path d="M21 11v2"/><path d="M7 10h8v4H7z" fill="#f2f7ff" stroke="none"/>', 373, 27, 18, C.text, 1.7);

  await text(phone, '5月20日', 24, 78, 27, C.softText, 'Semi Bold');
  await text(phone, '星期三', 141, 89, 13, C.muted, 'Regular');
  const headerLine = rect(phone, 24, 130, 382, 1, C.line, 1, 0.13);
  headerLine.effects = [];
  await text(phone, '今日事项', 24, 154, 15, C.softText, 'Semi Bold');
  const task = rect(phone, 24, 184, 382, 204, C.blue, 20, 0.92);
  task.effects = shadow({ r: 0, g: 0.01, b: 0.05 }, 0.25, 8, 5);
  await text(phone, '给诊所打电话', 48, 218, 23, C.text, 'Semi Bold', 280);
  await text(phone, '今天 · 未设置时间', 48, 259, 14, C.text, 'Regular');
  await text(phone, '完成后会从首页消失', 48, 338, 13, C.text, 'Regular');

  const reminderDivider = rect(phone, 24, 424, 382, 1, C.line, 1, 0.16);
  reminderDivider.effects = [];
  await text(phone, '文档提醒', 24, 448, 17, C.softText, 'Semi Bold');
  lucide(phone, '<path d="M21 12a9 9 0 0 1-15.5 6.2L3 16"/><path d="M3 21v-5h5"/><path d="M3 12A9 9 0 0 1 18.5 5.8L21 8"/><path d="M16 8h5V3"/>', 370, 449, 16, C.muted, 1.7);
  await text(phone, '从提醒池中随机抽取', 24, 474, 12, C.muted, 'Regular');

  const reminders = [
    ['旅行证件放在哪里', '证件 · 6月12日编辑', C.lavender],
    ['下次体检想问的问题', '健康 · 还在草稿', C.teal],
    ['日语学习清单', '学习 · 已置顶', C.amber]
  ];
  for (let i = 0; i < reminders.length; i++) {
    const y = 502 + i * 68;
    const divider = rect(phone, 24, y + 59, 382, 1, C.line, 1, 0.12);
    divider.effects = [];
    const dot = ellipse(phone, 25, y + 18, 10, 10, reminders[i][2], 0.96);
    dot.effects = [];
    await text(phone, reminders[i][0], 50, y + 9, 16, C.softText, 'Semi Bold', 260);
    await text(phone, reminders[i][1], 50, y + 33, 12, C.muted, 'Regular');
    lucide(phone, '<circle cx="12" cy="12" r="1" fill="#91a8c9" stroke="none"/><circle cx="19" cy="12" r="1" fill="#91a8c9" stroke="none"/><circle cx="5" cy="12" r="1" fill="#91a8c9" stroke="none"/>', 374, y + 21, 16, C.muted, 1);
  }

  await text(phone, '下拉继续查看冰箱与物品位置', 24, 728, 13, C.muted, 'Regular');
  makeNavBar(phone, 0, false);
  figma.currentPage.selection = [phone];
  figma.viewport.scrollAndZoomIntoView([phone]);
}

async function runCategories() {
  const page = figma.root.children.find(node => node.type === 'PAGE' && node.name === '03 · 分类（深色）') || figma.createPage();
  page.name = '03 · 分类（深色）';
  figma.currentPage = page;
  for (const child of [...page.children]) child.remove();

  const phone = figma.createFrame();
  phone.name = '分类 · 文档目录';
  phone.resize(430, 932);
  phone.x = 120; phone.y = 80;
  phone.cornerRadius = 34;
  phone.clipsContent = true;
  phone.fills = solid(C.bg);
  phone.effects = shadow({ r: 0, g: 0, b: 0 }, 0.26, 24, 12);
  page.appendChild(phone);

  ellipse(phone, 176, -72, 392, 350, C.lavender, 0.22, 92);
  ellipse(phone, -124, 360, 280, 360, C.teal, 0.1, 86);
  ellipse(phone, 102, 704, 330, 230, C.blue, 0.14, 84);

  await text(phone, '9:41', 25, 28, 14, C.text, 'Semi Bold');
  lucide(phone, '<path d="M2 22h20"/><path d="M5 18v-4M9 18V9M13 18V5M17 18V2"/>', 324, 27, 16, C.text, 1.8);
  lucide(phone, '<path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><path d="M12 20h.01"/>', 346, 27, 17, C.text, 1.7);
  lucide(phone, '<rect width="16" height="10" x="3" y="7" rx="2"/><path d="M21 11v2"/><path d="M7 10h8v4H7z" fill="#f2f7ff" stroke="none"/>', 373, 27, 18, C.text, 1.7);

  await text(phone, '分类', 24, 78, 30, C.softText, 'Semi Bold');
  const search = rect(phone, 24, 133, 382, 48, C.glass, 18, 0.48);
  search.strokes = solid(C.line, 0.2); search.strokeWeight = 1;
  search.effects = [{ type: 'BACKGROUND_BLUR', radius: 20, visible: true }];
  lucide(phone, '<circle cx="11" cy="11" r="6"/><path d="m20 20-4-4"/>', 41, 146, 18, C.muted, 1.8);
  await text(phone, '搜索文档和分类', 70, 147, 14, C.muted, 'Regular');

  const sectionDivider = rect(phone, 24, 210, 382, 1, C.line, 1, 0.15);
  sectionDivider.effects = [];
  await text(phone, '全部分类', 24, 233, 15, C.softText, 'Semi Bold');
  await text(phone, '编辑', 360, 234, 14, C.muted, 'Regular');

  await makeCategoryRow(phone, 267, '未分类', C.lavender);
  await makeCategoryRow(phone, 335, '证件', C.amber);
  await makeCategoryRow(phone, 403, '健康', C.teal);
  await makeCategoryRow(phone, 471, '学习', C.blue);
  await makeCategoryRow(phone, 539, '灵感', C.lavender);

  const nav = rect(phone, 54, 840, 322, 58, C.glass, 29, 0.54);
  nav.strokes = solid(C.line, 0.28); nav.strokeWeight = 1;
  nav.effects = [
    { type: 'BACKGROUND_BLUR', radius: 22, visible: true },
    { type: 'DROP_SHADOW', color: { r: 0, g: 0.015, b: 0.05, a: 0.22 }, offset: { x: 0, y: 8 }, radius: 18, spread: 0, visible: true, blendMode: 'NORMAL' }
  ];
  const navIcons = [
    '<path d="m3 10 9-7 9 7v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/><path d="M9 22V12h6v10"/>',
    '<rect width="18" height="18" x="3" y="4" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
    '<rect width="6" height="6" x="3" y="3" rx="1"/><rect width="6" height="6" x="15" y="3" rx="1"/><rect width="6" height="6" x="3" y="15" rx="1"/><rect width="6" height="6" x="15" y="15" rx="1"/>',
    '<circle cx="12" cy="8" r="4"/><path d="M4 22a8 8 0 0 1 16 0"/>'
  ];
  const centres = [94, 174, 256, 336];
  for (let i = 0; i < navIcons.length; i++) {
    const active = i === 2;
    if (active) {
      const glow = lucide(phone, navIcons[i], centres[i] - 10, 861, 20, C.navActive, 3.1);
      glow.opacity = 0.52;
      glow.effects = [{ type: 'LAYER_BLUR', radius: 6, visible: true }];
    }
    lucide(phone, navIcons[i], centres[i] - 10, 861, 20, active ? C.navActive : C.muted, active ? 2.65 : 1.55);
  }
  const homeBar = rect(phone, 150, 908, 130, 5, C.text, 3, 0.96);
  homeBar.effects = [];
  figma.currentPage.selection = [phone];
  figma.viewport.scrollAndZoomIntoView([phone]);
}

runHomeReminderStudy().then(() => figma.closePlugin()).catch(error => {
  console.error(error);
  figma.closePlugin('Generation failed');
});
