// Variables used by Scriptable.
// These must be at the top of the file. Do not edit.
// icon-color: deep-green; icon-glyph: euro-sign;

/*
 * Einnahmen – Widget und Mini-App für Scriptable (iOS)
 *
 * • Widget auf dem Home- und Sperrbildschirm: Monatssumme, Vergleich zum
 *   Vormonat, Monatsziel, Mini-Balkendiagramm
 * • Antippen öffnet das Menü: Einnahme erfassen, wiederkehrende Einnahmen,
 *   Dividenden/Zinsen aus dem Portfolio, Übersicht mit Diagrammen
 * • Daten liegen als JSON in iCloud Drive › Scriptable (oder lokal, wenn
 *   iCloud aus ist). Keine Server, keine Tracker, alles offline.
 *
 * Widget-Parameter (Widget lange drücken › Widget bearbeiten › Parameter):
 *   privat  → Beträge im Widget immer ausblenden
 */

// ─────────────────────────────────────────────────────────────
// Konstanten
// ─────────────────────────────────────────────────────────────

const FILE_NAME = "einnahmen-daten.json";
const BACKUP_NAME = "einnahmen-daten.backup.json";
const HORIZON_MONTHS = 12;
const MASK = "•••• €";

const SOURCES = {
  salary:   { title: "Gehalt",        emoji: "💼", color: "#0A84FF" },
  dividend: { title: "Dividende",     emoji: "📈", color: "#30D158" },
  interest: { title: "Zinsen",        emoji: "🏦", color: "#40C8E0" },
  rent:     { title: "Mieteinnahmen", emoji: "🏠", color: "#FF9F0A" },
  sale:     { title: "Verkauf",       emoji: "🛒", color: "#BF5AF2" },
  other:    { title: "Sonstiges",     emoji: "✨", color: "#8E8E93" },
};
const SOURCE_KEYS = Object.keys(SOURCES);

const INTERVALS = {
  monthly:   { title: "Monatlich",       months: 1 },
  quarterly: { title: "Vierteljährlich", months: 3 },
  yearly:    { title: "Jährlich",        months: 12 },
};
const INTERVAL_KEYS = Object.keys(INTERVALS);

const KINDS = {
  stock:      { title: "Aktie",           emoji: "🏛️", source: "dividend" },
  etf:        { title: "ETF / Fonds",     emoji: "🧺", source: "dividend" },
  bond:       { title: "Anleihe",         emoji: "📜", source: "interest" },
  savings:    { title: "Tages-/Festgeld", emoji: "🏦", source: "interest" },
  realEstate: { title: "Immobilie",       emoji: "🏠", source: "rent" },
  other:      { title: "Sonstiges",       emoji: "📦", source: "other" },
};
const KIND_KEYS = Object.keys(KINDS);

const MONTHS = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli",
  "August", "September", "Oktober", "November", "Dezember"];
const MONTHS_SHORT = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug",
  "Sep", "Okt", "Nov", "Dez"];

// ─────────────────────────────────────────────────────────────
// Datum (immer als "JJJJ-MM-TT"-Text, lokale Zeit)
// ─────────────────────────────────────────────────────────────

function pad(n) { return String(n).padStart(2, "0"); }

function ymd(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function parseYmd(s) {
  const [y, m, d] = s.split("-").map(Number);
  return { y, m, d };
}

function toDate(s) {
  const { y, m, d } = parseYmd(s);
  return new Date(y, m - 1, d, 12, 0, 0);
}

function daysInMonth(y, m) { return new Date(y, m, 0).getDate(); }

/** Monate addieren; der Tag wird am Monatsende gekappt (31.01. + 1 = 28./29.02.). */
function addMonths(s, n) {
  const { y, m, d } = parseYmd(s);
  const t = (m - 1) + n;
  const ny = y + Math.floor(t / 12);
  const nm = ((t % 12) + 12) % 12 + 1;
  return `${ny}-${pad(nm)}-${pad(Math.min(d, daysInMonth(ny, nm)))}`;
}

function monthKey(s) { return s.slice(0, 7); }
function addMonthsKey(key, n) { return addMonths(key + "-01", n).slice(0, 7); }

function monthLabel(key, style) {
  const [y, m] = key.split("-").map(Number);
  if (style === "short") return MONTHS_SHORT[m - 1];
  if (style === "month") return MONTHS[m - 1];
  return `${MONTHS[m - 1]} ${y}`;
}

function fmtDate(s) {
  const { y, m, d } = parseYmd(s);
  return `${pad(d)}.${pad(m)}.${y}`;
}

// ─────────────────────────────────────────────────────────────
// Geld (intern immer ganze Cent)
// ─────────────────────────────────────────────────────────────

/** 123456 → "1.234,56 €" bzw. mit decimals=false → "1.235 €" */
function fmtEuro(cents, decimals) {
  const withDecimals = decimals !== false;
  const negative = cents < 0;
  const abs = Math.abs(Math.round(cents));
  const euros = withDecimals ? Math.floor(abs / 100) : Math.round(abs / 100);
  const intStr = String(euros).replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  const dec = withDecimals ? "," + pad(abs % 100) : "";
  return (negative ? "−" : "") + intStr + dec + " €";
}

/** 0.084 → "8 %", mit signed → "+8 %" */
function fmtPercent(x, signed) {
  const v = Math.round(x * 100);
  return (signed && v > 0 ? "+" : "") + String(v).replace("-", "−") + " %";
}

/** Richtung einer Veränderung nach Rundung: 1 = mehr, 0 = gleich, −1 = weniger */
function trend(change) {
  const v = Math.round(change * 100);
  return v > 0 ? 1 : v < 0 ? -1 : 0;
}

function trendArrow(change) {
  return ["▼", "●", "▲"][trend(change) + 1];
}

/** Für Eingabefelder: 125000 → "1250,00" */
function editString(cents) {
  if (!cents) return "";
  return `${Math.floor(cents / 100)},${pad(cents % 100)}`;
}

/** "1.234,56" · "1234,56" · "1234.56" · "1.234" · "12 €" → Cent; sonst null */
function parseCents(text) {
  if (text === null || text === undefined) return null;
  let s = String(text).replace(/€/g, "").replace(/[\s ]/g, "").trim();
  if (!s) return null;
  if (s.includes(",")) {
    s = s.replace(/\./g, "").replace(",", ".");
  } else if (/^\d{1,3}(\.\d{3})+$/.test(s)) {
    s = s.replace(/\./g, "");
  }
  if (!/^\d+(\.\d{1,2})?$/.test(s)) return null;
  const [int, frac = ""] = s.split(".");
  return Number(int) * 100 + Number((frac + "00").slice(0, 2));
}

// ─────────────────────────────────────────────────────────────
// Daten
// ─────────────────────────────────────────────────────────────

function uid() {
  if (typeof UUID !== "undefined") return UUID.string();
  return "id-" + Math.random().toString(36).slice(2) + Date.now().toString(36);
}

function emptyData() {
  return {
    version: 1,
    incomes: [],
    series: [],
    positions: [],
    settings: { goalCents: 0, hideAmounts: false },
  };
}

function normalize(raw) {
  const d = Object.assign(emptyData(), raw || {});
  d.settings = Object.assign({ goalCents: 0, hideAmounts: false }, d.settings || {});
  d.incomes = Array.isArray(d.incomes) ? d.incomes : [];
  d.series = Array.isArray(d.series) ? d.series : [];
  d.positions = Array.isArray(d.positions) ? d.positions : [];
  return d;
}

// ─────────────────────────────────────────────────────────────
// Wiederkehrende Einnahmen: Vorausplanung und Verbuchen
// ─────────────────────────────────────────────────────────────

/**
 * Verbucht fällige geplante Termine und plant alle aktiven Serien
 * 12 Monate im Voraus. Gibt true zurück, wenn sich etwas geändert hat.
 */
function refreshRecurring(data, today) {
  let changed = false;
  for (const income of data.incomes) {
    if (income.planned && income.date <= today) {
      income.planned = false;
      changed = true;
    }
  }
  for (const series of data.series) {
    if (series.active && generateOccurrences(data, series, today)) changed = true;
  }
  if (removeDuplicates(data)) changed = true;
  return changed;
}

function generateOccurrences(data, series, today) {
  const interval = INTERVALS[series.interval] || INTERVALS.monthly;
  const horizon = addMonths(today, HORIZON_MONTHS);
  const limit = series.end && series.end < horizon ? series.end : horizon;
  const existing = new Set(
    data.incomes.filter((i) => i.seriesId === series.id).map((i) => i.key)
  );

  let changed = false;
  for (let n = 0; n < 1200; n++) {
    const date = addMonths(series.start, n * interval.months);
    if (date > limit) break;
    if (series.generatedThrough && date <= series.generatedThrough) continue;
    const key = `${series.id}|${date}`;
    if (existing.has(key)) continue;
    data.incomes.push({
      id: uid(),
      cents: series.cents,
      source: series.source,
      date,
      note: series.note || "",
      planned: date > today,
      seriesId: series.id,
      positionId: series.positionId || null,
      key,
      created: Date.now(),
    });
    changed = true;
  }
  if (!series.generatedThrough || limit > series.generatedThrough) {
    series.generatedThrough = limit;
    changed = true;
  }
  return changed;
}

/** Nach dem Ändern einer Serie: nur zukünftige geplante Termine neu aufbauen. */
function rebuildSeries(data, series, today) {
  data.incomes = data.incomes.filter(
    (i) => !(i.seriesId === series.id && i.planned && i.date > today)
  );
  series.generatedThrough = today;
  if (series.active) generateOccurrences(data, series, today);
}

/** Serie löschen; bereits eingegangene Zahlungen bleiben als Einzelbuchungen. */
function deleteSeries(data, series) {
  data.incomes = data.incomes.filter((i) => !(i.seriesId === series.id && i.planned));
  for (const income of data.incomes) {
    if (income.seriesId === series.id) income.seriesId = null;
  }
  data.series = data.series.filter((s) => s.id !== series.id);
}

/** Doppelte Termine (z. B. durch zwei Geräte) entfernen. */
function removeDuplicates(data) {
  const byKey = new Map();
  for (const income of data.incomes) {
    if (!income.key) continue;
    const list = byKey.get(income.key) || [];
    list.push(income);
    byKey.set(income.key, list);
  }
  const drop = new Set();
  for (const list of byKey.values()) {
    if (list.length < 2) continue;
    list.sort((a, b) => (a.planned - b.planned) || ((a.created || 0) - (b.created || 0)));
    list.slice(1).forEach((i) => drop.add(i.id));
  }
  if (!drop.size) return false;
  data.incomes = data.incomes.filter((i) => !drop.has(i.id));
  return true;
}

// ─────────────────────────────────────────────────────────────
// Statistik
// ─────────────────────────────────────────────────────────────

/**
 * • current: alle Einnahmen im laufenden Monat (eingegangen + erwartet)
 * • change:  gegenüber dem gesamten Vormonat (null, wenn Vormonat 0 €)
 * • yearTotal: 1. Januar bis Ende des laufenden Monats
 * • average: yearTotal ÷ Monate seit Januar bzw. seit der ersten Einnahme
 */
function computeStats(incomes, today, pastMonths, futureMonths) {
  const past = pastMonths || 12;
  const future = futureMonths === undefined ? 3 : futureMonths;
  const thisKey = monthKey(today);
  const prevKey = addMonthsKey(thisKey, -1);
  const year = today.slice(0, 4);

  const byMonth = {};
  for (const i of incomes) {
    const k = monthKey(i.date);
    const b = byMonth[k] || (byMonth[k] = { received: 0, planned: 0 });
    if (i.planned) b.planned += i.cents; else b.received += i.cents;
  }
  const total = (k) => (byMonth[k] ? byMonth[k].received + byMonth[k].planned : 0);

  const current = total(thisKey);
  const currentPlanned = byMonth[thisKey] ? byMonth[thisKey].planned : 0;
  const previous = total(prevKey);
  const change = previous > 0 ? (current - previous) / previous : null;

  let yearTotal = 0;
  let firstMonth = null;
  for (const k of Object.keys(byMonth)) {
    if (k.slice(0, 4) === year && k <= thisKey) {
      yearTotal += total(k);
      if (total(k) > 0 && (!firstMonth || k < firstMonth)) firstMonth = k;
    }
  }
  const thisMonthNo = Number(thisKey.slice(5));
  const elapsed = firstMonth ? thisMonthNo - Number(firstMonth.slice(5)) + 1 : thisMonthNo;
  const average = Math.round(yearTotal / Math.max(elapsed, 1));

  const buckets = [];
  for (let o = -(past - 1); o <= future; o++) {
    const k = addMonthsKey(thisKey, o);
    const b = byMonth[k] || { received: 0, planned: 0 };
    buckets.push({ key: k, received: b.received, planned: b.planned, isCurrent: o === 0, isFuture: o > 0 });
  }

  return { thisKey, prevKey, year, current, currentPlanned, previous, change, yearTotal, average, buckets };
}

/** Anteile nach Quelle: period = "month" | "year" | "last12" */
function sourceSlices(incomes, today, period) {
  const thisKey = monthKey(today);
  let from = thisKey;
  if (period === "year") from = today.slice(0, 4) + "-01";
  if (period === "last12") from = addMonthsKey(thisKey, -11);

  const totals = {};
  for (const i of incomes) {
    const k = monthKey(i.date);
    if (k >= from && k <= thisKey) totals[i.source] = (totals[i.source] || 0) + i.cents;
  }
  const sum = Object.values(totals).reduce((a, b) => a + b, 0);
  if (!sum) return [];
  return Object.keys(totals)
    .filter((s) => totals[s] > 0)
    .map((s) => ({ source: s, cents: totals[s], share: totals[s] / sum }))
    .sort((a, b) => b.cents - a.cents);
}

// ─────────────────────────────────────────────────────────────
// Beispieldaten
// ─────────────────────────────────────────────────────────────

function sampleData(today) {
  const d = emptyData();
  const thisKey = monthKey(today);
  const day = (monthsAgo, dd) => {
    const k = addMonthsKey(thisKey, -monthsAgo);
    const [y, m] = k.split("-").map(Number);
    return `${k}-${pad(Math.min(dd, daysInMonth(y, m)))}`;
  };

  const etf = { id: uid(), name: "MSCI World ETF", identifier: "IE00B4L5Y983", kind: "etf", lastPayoutCents: 8430 };
  const allianz = { id: uid(), name: "Allianz SE", identifier: "DE0008404005", kind: "stock", lastPayoutCents: 69000 };
  const tagesgeld = { id: uid(), name: "Tagesgeld", identifier: "", kind: "savings", lastPayoutCents: 4120 };
  d.positions.push(etf, allianz, tagesgeld);

  const series = (cents, source, interval, start, note, positionId) => ({
    id: uid(), cents, source, interval, start, end: null, note,
    active: true, generatedThrough: null, positionId: positionId || null, created: Date.now(),
  });
  d.series.push(
    series(325000, "salary", "monthly", day(13, 27), "Nettogehalt"),
    series(65000, "rent", "monthly", day(13, 3), "Wohnung Lindenstraße"),
    series(8430, "dividend", "quarterly", day(12, 15), "Quartalsausschüttung", etf.id),
    series(4120, "interest", "monthly", day(13, 1), "Zinsgutschrift", tagesgeld.id)
  );

  const once = [
    [69000, "dividend", 7, 12, "Dividende Hauptversammlung", allianz.id],
    [120000, "sale", 4, 20, "E-Bike verkauft", null],
    [210000, "salary", 5, 27, "Urlaubsgeld", null],
    [48000, "other", 2, 9, "Steuererstattung", null],
    [8500, "sale", 1, 14, "Kleinanzeigen", null],
  ];
  for (const [cents, source, monthsAgo, dd, note, positionId] of once) {
    const date = day(monthsAgo, dd);
    d.incomes.push({ id: uid(), cents, source, date, note, planned: date > today, seriesId: null, positionId, key: "", created: Date.now() });
  }
  d.settings.goalCents = 450000;
  refreshRecurring(d, today);
  return d;
}

// ─────────────────────────────────────────────────────────────
// Speicher (iCloud Drive › Scriptable, sonst lokal)
// ─────────────────────────────────────────────────────────────

function fileManager() {
  try {
    const fm = FileManager.iCloud();
    fm.documentsDirectory();
    return fm;
  } catch (e) {
    return FileManager.local();
  }
}

function dataPath(name) {
  const fm = fileManager();
  return fm.joinPath(fm.documentsDirectory(), name || FILE_NAME);
}

async function loadData() {
  const fm = fileManager();
  const path = dataPath();
  if (!fm.fileExists(path)) return null;
  try {
    if (fm.isFileStoredIniCloud(path) && !fm.isFileDownloaded(path)) {
      await fm.downloadFileFromiCloud(path);
    }
  } catch (e) { /* lokal gespeichert */ }
  try {
    return normalize(JSON.parse(fm.readString(path)));
  } catch (e) {
    return null;
  }
}

function saveData(data) {
  const fm = fileManager();
  const path = dataPath();
  if (fm.fileExists(path)) {
    try { fm.writeString(dataPath(BACKUP_NAME), fm.readString(path)); } catch (e) { /* egal */ }
  }
  fm.writeString(path, JSON.stringify(data));
}

// ─────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────

function colors() {
  return {
    bg: Color.dynamic(new Color("#FFFFFF"), new Color("#1C1C1E")),
    text: Color.dynamic(new Color("#000000"), new Color("#FFFFFF")),
    secondary: new Color("#8E8E93"),
    accent: new Color("#0A84FF"),
    accentLight: new Color("#0A84FF", 0.35),
    green: new Color("#30D158"),
    red: new Color("#FF453A"),
    track: new Color("#8E8E93", 0.25),
  };
}

function font(kind, size) {
  const map = {
    roundedBold: ["boldRoundedSystemFont", "boldSystemFont"],
    bold: ["boldSystemFont", "boldSystemFont"],
    semibold: ["semiboldSystemFont", "boldSystemFont"],
    medium: ["mediumSystemFont", "systemFont"],
    regular: ["systemFont", "systemFont"],
  };
  const [preferred, fallback] = map[kind] || map.regular;
  try { return Font[preferred](size); } catch (e) { return Font[fallback](size); }
}

function scriptUrl(action) {
  const base = URLScheme.forRunningScript();
  if (!action) return base;
  return base + (base.includes("?") ? "&" : "?") + "action=" + action;
}

function roundedRect(ctx, rect, radius, color) {
  const path = new Path();
  path.addRoundedRect(rect, radius, radius);
  ctx.addPath(path);
  ctx.setFillColor(color);
  ctx.fillPath();
}

function progressImage(value, width, height, fg, bg) {
  const ctx = new DrawContext();
  ctx.size = new Size(width, height);
  ctx.opaque = false;
  ctx.respectScreenScale = true;
  roundedRect(ctx, new Rect(0, 0, width, height), height / 2, bg);
  if (value > 0) {
    const w = Math.max(height, width * Math.min(value, 1));
    roundedRect(ctx, new Rect(0, 0, w, height), height / 2, fg);
  }
  return ctx.getImage();
}

function barChartImage(buckets, width, height, c) {
  const ctx = new DrawContext();
  ctx.size = new Size(width, height);
  ctx.opaque = false;
  ctx.respectScreenScale = true;

  const labelH = 12;
  const chartH = height - labelH - 2;
  const gap = 5;
  const n = buckets.length;
  const bw = (width - gap * (n - 1)) / n;
  const max = Math.max(1, ...buckets.map((b) => b.received + b.planned));

  buckets.forEach((b, i) => {
    const x = i * (bw + gap);
    const totalH = ((b.received + b.planned) / max) * chartH;
    const recH = (b.received / max) * chartH;
    if (totalH <= 0) {
      roundedRect(ctx, new Rect(x, chartH - 2, bw, 2), 1, c.track);
    } else {
      roundedRect(ctx, new Rect(x, chartH - totalH, bw, totalH), 3, c.accentLight);
      if (recH > 0) {
        roundedRect(ctx, new Rect(x, chartH - recH, bw, recH), 3,
          b.isCurrent ? c.accent : new Color("#0A84FF", 0.75));
      }
    }
    ctx.setFont(b.isCurrent ? Font.boldSystemFont(8) : Font.systemFont(8));
    ctx.setTextColor(c.secondary);
    ctx.setTextAlignedCenter();
    ctx.drawTextInRect(monthLabel(b.key, "short"), new Rect(x - gap, chartH + 2, bw + gap * 2, labelH));
  });
  return ctx.getImage();
}

function addText(stack, text, fnt, color, opts) {
  const t = stack.addText(text);
  t.font = fnt;
  if (color) t.textColor = color;
  t.lineLimit = (opts && opts.lines) || 1;
  if (opts && opts.scale) t.minimumScaleFactor = opts.scale;
  if (opts && opts.right) t.rightAlignText();
  return t;
}

function addSymbol(stack, name, size, color) {
  const sym = SFSymbol.named(name);
  if (!sym) return null;
  sym.applyFont(Font.systemFont(size));
  const img = stack.addImage(sym.image);
  img.imageSize = new Size(size, size);
  if (color) img.tintColor = color;
  return img;
}

function buildWidget(data, today, family, parameter) {
  const c = colors();
  const w = new ListWidget();
  w.url = scriptUrl();
  w.refreshAfterDate = new Date(Date.now() + 30 * 60 * 1000);

  const fam = family || "medium";
  const isAccessory = fam.startsWith("accessory");
  if (!isAccessory) {
    w.backgroundColor = c.bg;
    w.setPadding(14, 14, 14, 14);
  }

  if (!data) {
    if (isAccessory) {
      addText(w, "Einnahmen: tippen", font("semibold", 12), null);
      return w;
    }
    const h = w.addStack();
    h.centerAlignContent();
    addSymbol(h, "eurosign.circle.fill", 16, c.green);
    h.addSpacer(6);
    addText(h, "Einnahmen", font("semibold", 13), c.text);
    w.addSpacer();
    addText(w, "Tippe hier, um deine erste Einnahme zu erfassen.", font("regular", 12), c.secondary, { lines: 3 });
    return w;
  }

  const hide = data.settings.hideAmounts || /privat|hide|versteck/i.test(parameter || "");
  const money = (cents) => (hide ? MASK : fmtEuro(cents));
  const moneyR = (cents) => (hide ? MASK : fmtEuro(cents, false));

  const st = computeStats(data.incomes, today, 6, 0);
  const goal = data.settings.goalCents || 0;
  const progress = goal > 0 ? st.current / goal : 0;
  const monthName = monthLabel(st.thisKey, "month");

  // ── Sperrbildschirm ──
  if (fam === "accessoryInline") {
    addText(w, `€ ${moneyR(st.current)} im ${monthName}`, font("regular", 12), null);
    return w;
  }
  if (fam === "accessoryCircular") {
    w.addAccessoryWidgetBackground = true;
    const t1 = addText(w, goal > 0 ? fmtPercent(progress) : "€", font("roundedBold", 14), null, { scale: 0.6 });
    t1.centerAlignText();
    const t2 = addText(w, goal > 0 ? "Ziel" : monthName.slice(0, 3), font("regular", 9), null);
    t2.centerAlignText();
    return w;
  }
  if (fam === "accessoryRectangular") {
    addText(w, `Einnahmen ${monthName}`, font("semibold", 11), null);
    addText(w, money(st.current), font("roundedBold", 17), null, { scale: 0.6 });
    if (goal > 0) {
      w.addSpacer(3);
      const img = w.addImage(progressImage(progress, 120, 5, Color.white(), new Color("#FFFFFF", 0.3)));
      img.imageSize = new Size(120, 5);
    }
    return w;
  }

  // ── Home-Bildschirm ──
  const summary = (container) => {
    const header = container.addStack();
    header.centerAlignContent();
    addSymbol(header, "eurosign.circle.fill", 15, c.green);
    header.addSpacer(5);
    addText(header, "Einnahmen", font("semibold", 13), c.text);
    container.addSpacer(1);
    addText(container, monthName, font("regular", 11), c.secondary);
    container.addSpacer();
    addText(container, money(st.current), font("roundedBold", 24), c.text, { scale: 0.5 });
    if (st.currentPlanned > 0) {
      addText(container, `davon ${moneyR(st.currentPlanned)} erwartet`, font("regular", 10), c.secondary, { scale: 0.7 });
    }
    container.addSpacer(6);
    if (goal > 0) {
      const img = container.addImage(progressImage(progress, 130, 7, progress >= 1 ? c.green : c.accent, c.track));
      img.imageSize = new Size(130, 7);
      container.addSpacer(3);
      addText(container, progress >= 1 ? "Ziel erreicht 🎉" : `${fmtPercent(progress)} vom Ziel`, font("medium", 10), c.secondary);
    } else if (st.change !== null) {
      addText(container, `${trendArrow(st.change)} ${fmtPercent(st.change, true)} ggü. Vormonat`,
        font("semibold", 10), [c.red, c.secondary, c.green][trend(st.change) + 1], { scale: 0.7 });
    }
  };

  if (fam === "small") {
    summary(w);
    return w;
  }

  // mittel / groß
  const row = w.addStack();
  row.layoutHorizontally();
  const left = row.addStack();
  left.layoutVertically();
  summary(left);
  row.addSpacer(14);

  const right = row.addStack();
  right.layoutVertically();
  const chart = right.addImage(barChartImage(st.buckets, 140, 72, c));
  chart.imageSize = new Size(140, 72);
  right.addSpacer(6);
  const prevLine = right.addStack();
  prevLine.centerAlignContent();
  addText(prevLine, "Vormonat ", font("regular", 10), c.secondary);
  addText(prevLine, moneyR(st.previous), font("semibold", 10), c.text);
  if (st.change !== null) {
    addText(right, `${trendArrow(st.change)} ${fmtPercent(st.change, true)}`,
      font("semibold", 10), [c.red, c.secondary, c.green][trend(st.change) + 1]);
  }
  right.addSpacer();
  const add = right.addStack();
  add.url = scriptUrl("add");
  add.backgroundColor = new Color("#0A84FF", 0.15);
  add.cornerRadius = 9;
  add.setPadding(4, 10, 4, 10);
  add.centerAlignContent();
  addSymbol(add, "plus", 10, c.accent);
  add.addSpacer(4);
  addText(add, "Erfassen", font("semibold", 11), c.accent);

  if (fam === "large" || fam === "extraLarge") {
    w.addSpacer(14);
    const upcoming = data.incomes.filter((i) => i.planned).sort((a, b) => a.date.localeCompare(b.date)).slice(0, 3);
    const recent = data.incomes.filter((i) => !i.planned).sort((a, b) => b.date.localeCompare(a.date)).slice(0, 4);
    const list = (title, items) => {
      if (!items.length) return;
      addText(w, title, font("semibold", 12), c.secondary);
      w.addSpacer(4);
      for (const i of items) {
        const r = w.addStack();
        r.centerAlignContent();
        addText(r, SOURCES[i.source] ? SOURCES[i.source].emoji : "•", font("regular", 13), null);
        r.addSpacer(6);
        addText(r, i.note || (SOURCES[i.source] || SOURCES.other).title, font("regular", 12), c.text);
        r.addSpacer();
        addText(r, `${fmtDate(i.date).slice(0, 6)}  `, font("regular", 11), c.secondary);
        addText(r, money(i.cents), font("semibold", 12), i.planned ? c.secondary : c.text);
        w.addSpacer(3);
      }
      w.addSpacer(8);
    };
    list("Demnächst erwartet", upcoming);
    list("Zuletzt eingegangen", recent);
    w.addSpacer();
  }
  return w;
}

// ─────────────────────────────────────────────────────────────
// Mini-App: Dialog-Helfer
// ─────────────────────────────────────────────────────────────

async function choose(title, options, message) {
  const a = new Alert();
  a.title = title;
  if (message) a.message = message;
  options.forEach((o) => a.addAction(o));
  a.addCancelAction("Abbrechen");
  return a.presentSheet();
}

async function info(title, message) {
  const a = new Alert();
  a.title = title;
  a.message = message || "";
  a.addAction("OK");
  await a.presentAlert();
}

async function confirm(title, message, destructiveLabel) {
  const a = new Alert();
  a.title = title;
  a.message = message || "";
  a.addDestructiveAction(destructiveLabel || "Löschen");
  a.addCancelAction("Abbrechen");
  return (await a.presentAlert()) === 0;
}

/** Betrag (und optional Notiz) abfragen. Gibt { cents, note } oder null. */
async function askAmount(title, message, initialCents, withNote, initialNote) {
  const a = new Alert();
  a.title = title;
  a.message = message || "";
  const field = a.addTextField("Betrag in €, z. B. 1.250,00", editString(initialCents));
  try { field.setDecimalPadKeyboard(); } catch (e) { /* ältere Version */ }
  if (withNote) a.addTextField("Notiz (optional)", initialNote || "");
  a.addAction("Weiter");
  a.addCancelAction("Abbrechen");
  if ((await a.presentAlert()) === -1) return null;
  const cents = parseCents(a.textFieldValue(0));
  if (!cents) {
    await info("Ungültiger Betrag", "Bitte einen Betrag wie 1.250,00 eingeben.");
    return askAmount(title, message, initialCents, withNote, initialNote);
  }
  return { cents, note: withNote ? a.textFieldValue(1).trim() : "" };
}

async function pickDate(initial) {
  const dp = new DatePicker();
  dp.initialDate = toDate(initial);
  try {
    return ymd(await dp.pickDate());
  } catch (e) {
    return null;
  }
}

/** „Heute" oder „Anderes Datum …" */
async function askDate(title, today, initial) {
  const start = initial || today;
  const i = await choose(title, [
    initial && initial !== today ? `Beibehalten (${fmtDate(initial)})` : `Heute (${fmtDate(today)})`,
    "Anderes Datum …",
  ]);
  if (i === -1) return null;
  if (i === 0) return start;
  return pickDate(start);
}

async function chooseSource(title) {
  const i = await choose(title || "Quelle wählen", SOURCE_KEYS.map((k) => `${SOURCES[k].emoji}  ${SOURCES[k].title}`));
  return i === -1 ? null : SOURCE_KEYS[i];
}

function sourceTitle(key) { return (SOURCES[key] || SOURCES.other).title; }
function sourceEmoji(key) { return (SOURCES[key] || SOURCES.other).emoji; }

// ─────────────────────────────────────────────────────────────
// Mini-App: Abläufe
// ─────────────────────────────────────────────────────────────

async function addIncomeFlow(data, today, presetSource, position) {
  const source = presetSource || (await chooseSource("Woher kommt das Geld?"));
  if (!source) return;
  const amount = await askAmount(
    `${sourceEmoji(source)} ${sourceTitle(source)}`,
    position ? `aus ${position.name}` : "",
    position ? position.lastPayoutCents : 0,
    true
  );
  if (!amount) return;
  const date = await askDate("Wann ist das Geld eingegangen?", today);
  if (!date) return;

  data.incomes.push({
    id: uid(), cents: amount.cents, source, date, note: amount.note,
    planned: date > today, seriesId: null,
    positionId: position ? position.id : null, key: "", created: Date.now(),
  });
  if (position && (source === "dividend" || source === "interest")) {
    position.lastPayoutCents = amount.cents;
  }
  saveData(data);
}

async function addSeriesFlow(data, today, presetSource, position) {
  const source = presetSource || (await chooseSource("Wiederkehrende Einnahme"));
  if (!source) return;
  const amount = await askAmount(`${sourceEmoji(source)} ${sourceTitle(source)}`, "Betrag pro Zahlung", 0, true);
  if (!amount) return;
  const iv = await choose("Wie oft?", INTERVAL_KEYS.map((k) => INTERVALS[k].title));
  if (iv === -1) return;
  const start = await askDate("Erste Zahlung", today);
  if (!start) return;
  const e = await choose("Endet die Einnahme?", ["Kein Enddatum", "Enddatum wählen …"]);
  if (e === -1) return;
  let end = null;
  if (e === 1) {
    end = await pickDate(addMonths(start, 12));
    if (!end || end < start) return;
  }

  const series = {
    id: uid(), cents: amount.cents, source, interval: INTERVAL_KEYS[iv], start, end,
    note: amount.note, active: true, generatedThrough: null,
    positionId: position ? position.id : null, created: Date.now(),
  };
  data.series.push(series);
  generateOccurrences(data, series, today);
  saveData(data);

  const next = data.incomes
    .filter((i) => i.seriesId === series.id && i.planned)
    .sort((a, b) => a.date.localeCompare(b.date))
    .slice(0, 3)
    .map((i) => fmtDate(i.date));
  await info("Angelegt ✅",
    `${INTERVALS[series.interval].title} ${fmtEuro(series.cents)}.\n` +
    (next.length ? `Nächste Zahlungen: ${next.join(", ")}.\n` : "") +
    `Termine werden ${HORIZON_MONTHS} Monate im Voraus geplant und am Fälligkeitstag automatisch verbucht.`);
}

async function manageSeriesFlow(data, today) {
  while (true) {
    const list = [...data.series].sort((a, b) => (b.active - a.active) || (b.cents - a.cents));
    const labels = list.map((s) =>
      `${s.active ? sourceEmoji(s.source) : "⏸"}  ${s.note || sourceTitle(s.source)} · ${fmtEuro(s.cents)} · ${INTERVALS[s.interval].title}`);
    const monthly = list.filter((s) => s.active)
      .reduce((sum, s) => sum + Math.round(s.cents / INTERVALS[s.interval].months), 0);
    const i = await choose("Wiederkehrende Einnahmen", [...labels, "➕  Neue wiederkehrende Einnahme"],
      list.length ? `Monatlich umgerechnet: ${fmtEuro(monthly)}` : "Noch keine angelegt.");
    if (i === -1) return;
    if (i === list.length) { await addSeriesFlow(data, today); continue; }

    const s = list[i];
    const next = data.incomes.filter((x) => x.seriesId === s.id && x.planned).map((x) => x.date).sort()[0];
    const action = await choose(
      `${s.note || sourceTitle(s.source)} · ${fmtEuro(s.cents)}`,
      ["✏️  Betrag/Notiz ändern", s.active ? "⏸  Pausieren" : "▶️  Fortsetzen",
        s.end ? `📅  Enddatum entfernen (${fmtDate(s.end)})` : "📅  Enddatum festlegen", "🗑  Löschen"],
      `${INTERVALS[s.interval].title}, seit ${fmtDate(s.start)}` + (next ? `\nNächste Zahlung: ${fmtDate(next)}` : "")
    );
    if (action === 0) {
      const amount = await askAmount("Neuer Betrag", "Gilt für alle zukünftigen Zahlungen.", s.cents, true, s.note);
      if (!amount) continue;
      s.cents = amount.cents;
      s.note = amount.note;
    } else if (action === 1) {
      s.active = !s.active;
    } else if (action === 2) {
      if (s.end) s.end = null;
      else {
        const end = await pickDate(addMonths(today, 12));
        if (!end) continue;
        s.end = end;
      }
    } else if (action === 3) {
      if (await confirm("Serie löschen?", "Geplante Zahlungen werden entfernt, bereits eingegangene bleiben erhalten.")) {
        deleteSeries(data, s);
        saveData(data);
      }
      continue;
    } else {
      continue;
    }
    rebuildSeries(data, s, today);
    saveData(data);
  }
}

async function portfolioFlow(data, today) {
  while (true) {
    const list = [...data.positions].sort((a, b) => a.name.localeCompare(b.name));
    const year = today.slice(0, 4);
    const labels = list.map((p) => {
      const received = data.incomes
        .filter((i) => i.positionId === p.id && !i.planned && i.date.startsWith(year))
        .reduce((s, i) => s + i.cents, 0);
      return `${(KINDS[p.kind] || KINDS.other).emoji}  ${p.name} · ${fmtEuro(received, false)} ${year}`;
    });
    const i = await choose("Portfolio", [...labels, "➕  Neue Position"],
      list.length ? "Position wählen, um eine Dividende oder Zinsen zu verbuchen." : "Lege Aktien, ETFs oder Tagesgeld an.");
    if (i === -1) return;
    if (i === list.length) { await addPositionFlow(data); continue; }
    await positionFlow(data, today, list[i]);
  }
}

async function addPositionFlow(data) {
  const a = new Alert();
  a.title = "Neue Position";
  a.addTextField("Name, z. B. MSCI World ETF", "");
  a.addTextField("ISIN / WKN / IBAN (optional)", "");
  a.addAction("Weiter");
  a.addCancelAction("Abbrechen");
  if ((await a.presentAlert()) === -1) return;
  const name = a.textFieldValue(0).trim();
  if (!name) return;
  const k = await choose("Art der Position", KIND_KEYS.map((key) => `${KINDS[key].emoji}  ${KINDS[key].title}`));
  if (k === -1) return;
  data.positions.push({ id: uid(), name, identifier: a.textFieldValue(1).trim(), kind: KIND_KEYS[k], lastPayoutCents: 0 });
  saveData(data);
}

async function positionFlow(data, today, p) {
  while (true) {
    const payouts = data.incomes.filter((i) => i.positionId === p.id).sort((a, b) => b.date.localeCompare(a.date));
    const total = payouts.filter((i) => !i.planned).reduce((s, i) => s + i.cents, 0);
    const kind = KINDS[p.kind] || KINDS.other;
    const i = await choose(`${kind.emoji} ${p.name}`, [
      "📈  Dividende verbuchen",
      "🏦  Zinsen verbuchen",
      "🔁  Regelmäßige Ausschüttung anlegen",
      "📋  Verlauf ansehen",
      "🗑  Position löschen",
    ], `${kind.title}${p.identifier ? " · " + p.identifier : ""}\nErhalten gesamt: ${fmtEuro(total)}`);
    if (i === -1) return;
    if (i === 0) await addIncomeFlow(data, today, "dividend", p);
    if (i === 1) await addIncomeFlow(data, today, "interest", p);
    if (i === 2) await addSeriesFlow(data, today, kind.source === "rent" ? "rent" : kind.source, p);
    if (i === 3) {
      const lines = payouts.slice(0, 15).map((x) =>
        `${fmtDate(x.date)}  ${fmtEuro(x.cents)}${x.planned ? " (erwartet)" : ""}`);
      await info(`Verlauf · ${p.name}`, lines.length ? lines.join("\n") : "Noch keine Ausschüttungen.");
    }
    if (i === 4) {
      if (await confirm("Position löschen?", "Bereits verbuchte Einnahmen bleiben erhalten.")) {
        data.positions = data.positions.filter((x) => x.id !== p.id);
        data.incomes.forEach((x) => { if (x.positionId === p.id) x.positionId = null; });
        data.series.forEach((x) => { if (x.positionId === p.id) x.positionId = null; });
        saveData(data);
        return;
      }
    }
  }
}

async function listFlow(data, today) {
  const thisKey = monthKey(today);
  while (true) {
    const hide = data.settings.hideAmounts;
    const money = (c) => (hide ? MASK : fmtEuro(c));
    const visible = data.incomes
      .filter((i) => !i.planned || monthKey(i.date) <= addMonthsKey(thisKey, 2))
      .sort((a, b) => b.date.localeCompare(a.date));

    const table = new UITable();
    table.showSeparators = true;
    let selected = null;

    if (!visible.length) {
      const r = new UITableRow();
      r.addText("Noch keine Einnahmen", "Über „Einnahme erfassen“ im Menü anlegen.");
      table.addRow(r);
    }

    let currentKey = null;
    for (const income of visible) {
      const k = monthKey(income.date);
      if (k !== currentKey) {
        currentKey = k;
        const sum = visible.filter((i) => monthKey(i.date) === k).reduce((s, i) => s + i.cents, 0);
        const header = new UITableRow();
        header.isHeader = true;
        header.height = 44;
        const left = header.addText(monthLabel(k));
        left.widthWeight = 60;
        const right = header.addText(money(sum));
        right.widthWeight = 40;
        right.rightAligned();
        table.addRow(header);
      }
      const r = new UITableRow();
      r.height = 56;
      r.dismissOnSelect = true;
      const emoji = r.addText(sourceEmoji(income.source));
      emoji.widthWeight = 10;
      const sub = [fmtDate(income.date)];
      if (income.planned) sub.push("erwartet");
      else if (income.seriesId) sub.push("wiederkehrend");
      if (income.note) sub.push(income.note);
      const text = r.addText(sourceTitle(income.source), sub.join(" · "));
      text.widthWeight = 58;
      text.subtitleColor = Color.gray();
      text.subtitleFont = Font.systemFont(12);
      const amount = r.addText(money(income.cents));
      amount.widthWeight = 32;
      amount.rightAligned();
      if (income.planned) amount.titleColor = Color.gray();
      r.onSelect = () => { selected = income; };
      table.addRow(r);
    }

    await table.present(false);
    if (!selected) return;

    const s = selected;
    const action = await choose(`${sourceTitle(s.source)} · ${fmtEuro(s.cents)}`,
      ["✏️  Betrag/Notiz ändern", "📅  Datum ändern", "🏷  Quelle ändern", "🗑  Löschen"],
      fmtDate(s.date) + (s.seriesId ? "\nTeil einer wiederkehrenden Einnahme – Änderung gilt nur für diese Zahlung." : ""));
    if (action === 0) {
      const amount = await askAmount("Betrag ändern", "", s.cents, true, s.note);
      if (amount) { s.cents = amount.cents; s.note = amount.note; }
    } else if (action === 1) {
      const date = await pickDate(s.date);
      if (date) { s.date = date; s.planned = date > today; }
    } else if (action === 2) {
      const source = await chooseSource();
      if (source) s.source = source;
    } else if (action === 3) {
      if (await confirm("Einnahme löschen?", "")) {
        data.incomes = data.incomes.filter((i) => i.id !== s.id);
      }
    }
    if (action !== -1) saveData(data);
  }
}

async function settingsFlow(data, today) {
  while (true) {
    const goal = data.settings.goalCents;
    const i = await choose("Einstellungen", [
      `🎯  Monatsziel: ${goal ? fmtEuro(goal, false) : "nicht festgelegt"}`,
      `🙈  Beträge ausblenden: ${data.settings.hideAmounts ? "An" : "Aus"}`,
      "🧩  Widget-Vorschau",
      "💾  Speicherort anzeigen",
      "🗑  Alle Daten löschen",
    ]);
    if (i === -1) return;
    if (i === 0) {
      const g = await choose("Monatsziel", ["Ziel festlegen …", "Ziel entfernen"],
        "Der Fortschritt zählt alle Einnahmen des laufenden Monats – eingegangene und erwartete.");
      if (g === 0) {
        const amount = await askAmount("Monatsziel", "z. B. 4.000", goal, false);
        if (amount) data.settings.goalCents = amount.cents;
      }
      if (g === 1) data.settings.goalCents = 0;
      saveData(data);
    }
    if (i === 1) {
      data.settings.hideAmounts = !data.settings.hideAmounts;
      saveData(data);
    }
    if (i === 2) {
      const size = await choose("Widget-Vorschau", ["Klein", "Mittel", "Groß"]);
      if (size === -1) continue;
      const fam = ["small", "medium", "large"][size];
      const w = buildWidget(data, today, fam, null);
      if (size === 0) await w.presentSmall();
      if (size === 1) await w.presentMedium();
      if (size === 2) await w.presentLarge();
    }
    if (i === 3) {
      const fm = fileManager();
      const inCloud = fm.isFileStoredIniCloud ? (() => { try { return fm.isFileStoredIniCloud(dataPath()); } catch (e) { return false; } })() : false;
      await info("Speicherort",
        (inCloud ? "iCloud Drive › Scriptable › " : "Lokal auf diesem iPhone (Scriptable) › ") + FILE_NAME +
        "\n\nBei jedem Speichern wird zusätzlich " + BACKUP_NAME + " als Sicherung der vorherigen Version angelegt." +
        "\n\nEs werden keine Daten an Server gesendet.");
    }
    if (i === 4) {
      if (await confirm("Alle Daten löschen?", "Alle Einnahmen, Serien und Positionen werden gelöscht. Die Sicherungsdatei bleibt erhalten.", "Alles löschen")) {
        const fresh = emptyData();
        Object.keys(fresh).forEach((k) => { data[k] = fresh[k]; });
        saveData(data);
      }
    }
  }
}

async function firstRun(today) {
  const a = new Alert();
  a.title = "Willkommen bei Einnahmen 💶";
  a.message = "Erfasse Gehalt, Dividenden, Zinsen, Mieteinnahmen und mehr. " +
    "Die Daten bleiben in deiner iCloud bzw. auf deinem iPhone.\n\n" +
    "Tipp: Leg danach ein Scriptable-Widget auf den Home-Bildschirm und wähle dieses Skript.";
  a.addAction("Leer starten");
  a.addAction("Mit Beispieldaten ausprobieren");
  a.addCancelAction("Abbrechen");
  const i = await a.presentAlert();
  if (i === -1) return null;
  const data = i === 1 ? sampleData(today) : emptyData();
  saveData(data);
  return data;
}

async function mainMenu(data, today) {
  while (true) {
    const st = computeStats(data.incomes, today);
    const hide = data.settings.hideAmounts;
    const money = (c, d) => (hide ? MASK : fmtEuro(c, d));
    const goal = data.settings.goalCents;

    let msg = `Diesen Monat: ${money(st.current)}`;
    if (st.currentPlanned) msg += `\ndavon ${money(st.currentPlanned)} noch erwartet`;
    if (st.change !== null) msg += `\n${trendArrow(st.change)} ${fmtPercent(st.change, true)} ggü. Vormonat`;
    if (goal) msg += `\n🎯 ${fmtPercent(st.current / goal)} vom Ziel (${money(goal, false)})`;
    msg += `\n\nJahr ${st.year}: ${money(st.yearTotal, false)} · Ø ${money(st.average, false)}/Monat`;

    const actions = [
      ["➕  Einnahme erfassen", () => addIncomeFlow(data, today)],
      ["📊  Übersicht & Diagramme", () => overviewFlow(data, today)],
      ["📋  Alle Einnahmen", () => listFlow(data, today)],
      ["🔁  Wiederkehrende Einnahmen", () => manageSeriesFlow(data, today)],
      ["💼  Portfolio: Dividenden & Zinsen", () => portfolioFlow(data, today)],
      [hide ? "👁  Beträge einblenden" : "🙈  Beträge ausblenden", async () => {
        data.settings.hideAmounts = !data.settings.hideAmounts;
        saveData(data);
      }],
      ["⚙️  Einstellungen", () => settingsFlow(data, today)],
    ];

    const a = new Alert();
    a.title = `Einnahmen · ${monthLabel(st.thisKey)}`;
    a.message = msg;
    actions.forEach(([label]) => a.addAction(label));
    a.addCancelAction("Schließen");
    const i = await a.presentSheet();
    if (i === -1) return;
    await actions[i][1]();
  }
}

// ─────────────────────────────────────────────────────────────
// Übersicht mit Diagrammen (HTML im WebView, komplett offline)
// ─────────────────────────────────────────────────────────────

async function overviewFlow(data, today) {
  const wv = new WebView();
  await wv.loadHTML(buildOverviewHTML(data, today));
  await wv.present(true);
}

function buildOverviewHTML(data, today) {
  const payload = JSON.stringify({
    incomes: data.incomes.map((i) => ({
      cents: i.cents, source: i.source, date: i.date, note: i.note || "",
      planned: !!i.planned, recurring: !!i.seriesId, positionId: i.positionId || null,
    })),
    positions: data.positions.map((p) => ({ id: p.id, name: p.name, kind: p.kind })),
    settings: data.settings,
    today,
  }).replace(/</g, "\\u003c");

  const helpers = [pad, parseYmd, daysInMonth, addMonths, monthKey, addMonthsKey, monthLabel,
    fmtDate, fmtEuro, fmtPercent, trend, trendArrow, computeStats, sourceSlices].map((f) => f.toString()).join("\n");

  return `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="color-scheme" content="light dark">
<title>Einnahmen</title>
<style>
:root{--bg:#F2F2F7;--card:#FFFFFF;--text:#000;--sec:#6C6C70;--ter:#C7C7CC;--sep:rgba(60,60,67,.18);--accent:#0A84FF;--green:#248A3D;--red:#D70015;--track:rgba(120,120,128,.18)}
@media (prefers-color-scheme:dark){:root{--bg:#000;--card:#1C1C1E;--text:#FFF;--sec:#98989F;--ter:#48484A;--sep:rgba(84,84,88,.6);--green:#30D158;--red:#FF453A;--track:rgba(120,120,128,.32)}}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
body{margin:0;background:var(--bg);color:var(--text);font:16px/1.35 -apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;padding:calc(env(safe-area-inset-top) + 12px) 16px calc(env(safe-area-inset-bottom) + 28px)}
h1{font-size:32px;font-weight:700;margin:4px 0 2px;letter-spacing:-.02em}
.sub{color:var(--sec);font-size:15px;margin-bottom:16px;display:flex;justify-content:space-between;align-items:center}
.eye{border:0;background:var(--card);color:var(--accent);font-size:14px;font-weight:600;border-radius:99px;padding:6px 12px}
.card{background:var(--card);border-radius:18px;padding:16px;margin-bottom:12px}
.label{color:var(--sec);font-size:14px;font-weight:500}
.hero .amount{font:700 38px/1.1 ui-rounded,-apple-system,sans-serif;margin:6px 0 4px;font-variant-numeric:tabular-nums;letter-spacing:-.01em}
.muted{color:var(--sec);font-size:13px}
.badge{display:inline-block;margin-top:8px;font-size:13px;font-weight:600}
.up{color:var(--green)}.down{color:var(--red)}
.tiles{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:12px}
.tile{background:var(--card);border-radius:14px;padding:12px 10px}
.tile .v{font:600 16px ui-rounded,-apple-system,sans-serif;margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-variant-numeric:tabular-nums}
.row{display:flex;justify-content:space-between;align-items:baseline;gap:8px}
h2{font-size:17px;font-weight:600;margin:0}
.bar{height:10px;border-radius:99px;background:var(--track);overflow:hidden;margin:12px 0 8px}
.bar>div{height:100%;border-radius:99px;background:var(--accent)}
.bar.done>div{background:var(--green)}
svg{display:block;width:100%;height:auto;overflow:visible}
.seg{display:flex;background:var(--track);border-radius:9px;padding:2px;margin:12px 0}
.seg button{flex:1;border:0;background:transparent;color:var(--text);font-size:13px;font-weight:500;padding:6px 0;border-radius:7px}
.seg button.on{background:var(--card);box-shadow:0 1px 3px rgba(0,0,0,.15);font-weight:600}
.legend div{display:flex;align-items:center;gap:8px;padding:6px 0;font-size:15px}
.legend .dot{width:10px;height:10px;border-radius:50%;flex:none}
.legend .p{color:var(--sec);margin-left:auto;font-variant-numeric:tabular-nums}
.legend .a{min-width:92px;text-align:right;font-variant-numeric:tabular-nums}
.item{display:flex;align-items:center;gap:12px;padding:10px 0;border-top:.5px solid var(--sep)}
.item:first-of-type{border-top:0}
.ico{width:34px;height:34px;border-radius:50%;display:grid;place-items:center;font-size:17px;flex:none}
.item .t{flex:1;min-width:0}
.item .t div:last-child{color:var(--sec);font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.item .v{font-weight:600;font-variant-numeric:tabular-nums;white-space:nowrap}
.item.pl .v{color:var(--sec)}
.empty{color:var(--sec);text-align:center;padding:24px 0}
.foot{color:var(--sec);font-size:12px;text-align:center;margin-top:18px}
.sel{font-size:13px;color:var(--sec);text-align:right}
.sel b{display:block;color:var(--text);font-size:15px}
</style>
</head>
<body>
<h1>Einnahmen</h1>
<div class="sub"><span id="month"></span><button class="eye" id="eye"></button></div>
<div id="app"></div>
<div class="foot">Gespeichert in deiner iCloud bzw. auf diesem iPhone · keine Server, keine Tracker</div>
<script>
const SOURCES = ${JSON.stringify(SOURCES)};
const MONTHS = ${JSON.stringify(MONTHS)};
const MONTHS_SHORT = ${JSON.stringify(MONTHS_SHORT)};
const MASK = ${JSON.stringify(MASK)};
${helpers}
const D = ${payload};
let hide = !!D.settings.hideAmounts;
let period = "year";
let selected = null;
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const money = (c, d) => hide ? MASK : fmtEuro(c, d);

function barChart(st, goal) {
  const W = 340, H = 170, top = 14, bottom = 20, chartH = H - top - bottom;
  const n = st.buckets.length, gap = 6, bw = (W - gap * (n - 1)) / n;
  const max = Math.max(1, goal, ...st.buckets.map(b => b.received + b.planned));
  let s = '<svg viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="Einnahmen pro Monat">';
  st.buckets.forEach((b, i) => {
    const x = i * (bw + gap), tot = b.received + b.planned;
    const th = tot / max * chartH, rh = b.received / max * chartH;
    const dim = selected !== null && selected !== i ? ' opacity=".35"' : '';
    s += '<g data-i="' + i + '"' + dim + '>';
    s += '<rect x="' + x + '" y="' + top + '" width="' + bw + '" height="' + chartH + '" fill="transparent"/>';
    if (tot > 0) {
      s += '<rect x="' + x + '" y="' + (top + chartH - th) + '" width="' + bw + '" height="' + th + '" rx="4" fill="var(--accent)" fill-opacity=".3"/>';
      if (rh > 0) s += '<rect x="' + x + '" y="' + (top + chartH - rh) + '" width="' + bw + '" height="' + rh + '" rx="4" fill="var(--accent)"' + (b.isCurrent ? '' : ' fill-opacity=".8"') + '/>';
    } else {
      s += '<rect x="' + x + '" y="' + (top + chartH - 2) + '" width="' + bw + '" height="2" rx="1" fill="var(--track)"/>';
    }
    s += '<text x="' + (x + bw / 2) + '" y="' + (H - 4) + '" text-anchor="middle" font-size="10" fill="var(--sec)"' + (b.isCurrent ? ' font-weight="700"' : '') + '>' + monthLabel(b.key, "short").charAt(0) + '</text></g>';
  });
  if (goal > 0) {
    const y = top + chartH - goal / max * chartH;
    s += '<line x1="0" x2="' + W + '" y1="' + y + '" y2="' + y + '" stroke="var(--green)" stroke-dasharray="5 4"/>';
    s += '<text x="0" y="' + (y - 4) + '" font-size="10" font-weight="600" fill="var(--green)">Ziel</text>';
  }
  return s + '</svg>';
}

function donut(slices) {
  const R = 70, C = 2 * Math.PI * R, sw = 26;
  let off = 0, s = '<svg viewBox="0 0 200 200" style="max-width:220px;margin:0 auto">';
  s += '<circle cx="100" cy="100" r="' + R + '" fill="none" stroke="var(--track)" stroke-width="' + sw + '"/>';
  slices.forEach(sl => {
    const len = Math.max(sl.share * C - (slices.length > 1 ? 2 : 0), 0.5);
    s += '<circle cx="100" cy="100" r="' + R + '" fill="none" stroke="' + SOURCES[sl.source].color + '" stroke-width="' + sw + '" stroke-dasharray="' + len + ' ' + (C - len) + '" stroke-dashoffset="' + (-off) + '" transform="rotate(-90 100 100)"/>';
    off += sl.share * C;
  });
  const total = slices.reduce((a, b) => a + b.cents, 0);
  s += '<text x="100" y="94" text-anchor="middle" font-size="12" fill="var(--sec)">Gesamt</text>';
  s += '<text x="100" y="116" text-anchor="middle" font-size="18" font-weight="700" fill="var(--text)">' + esc(money(total, false)) + '</text>';
  return s + '</svg>';
}

function item(i) {
  const src = SOURCES[i.source] || SOURCES.other;
  const pos = D.positions.find(p => p.id === i.positionId);
  const sub = [fmtDate(i.date), pos ? pos.name : "", i.note].filter(Boolean).join(" · ");
  return '<div class="item' + (i.planned ? ' pl' : '') + '"><div class="ico" style="background:' + src.color + '26">' + src.emoji + '</div>' +
    '<div class="t"><div>' + esc(src.title) + (i.recurring ? ' <span class="muted">↻</span>' : '') + '</div><div>' + esc(sub) + '</div></div>' +
    '<div class="v">' + esc(money(i.cents)) + '</div></div>';
}

function render() {
  const st = computeStats(D.incomes, D.today);
  const goal = D.settings.goalCents || 0;
  const prog = goal ? st.current / goal : 0;
  document.getElementById("month").textContent = monthLabel(st.thisKey);
  document.getElementById("eye").textContent = hide ? "Beträge zeigen" : "Beträge ausblenden";

  let h = '';
  h += '<div class="card hero" id="hero"><div class="row"><span class="label">Diesen Monat</span><span class="muted">antippen zum Ausblenden</span></div>';
  h += '<div class="amount">' + esc(money(st.current)) + '</div>';
  if (st.currentPlanned) h += '<div class="muted">davon ' + esc(money(st.currentPlanned)) + ' noch erwartet</div>';
  h += st.change === null ? '<div class="badge muted">Kein Vergleich zum Vormonat möglich</div>'
    : '<div class="badge ' + ['down', 'muted', 'up'][trend(st.change) + 1] + '">' + trendArrow(st.change) + ' ' + fmtPercent(st.change, true) + ' <span class="muted">ggü. Vormonat</span></div>';
  h += '</div>';

  h += '<div class="tiles">' +
    '<div class="tile"><div class="label">Vormonat</div><div class="v">' + esc(money(st.previous, false)) + '</div></div>' +
    '<div class="tile"><div class="label">Jahr ' + st.year + '</div><div class="v">' + esc(money(st.yearTotal, false)) + '</div></div>' +
    '<div class="tile"><div class="label">Ø / Monat</div><div class="v">' + esc(money(st.average, false)) + '</div></div></div>';

  h += '<div class="card"><div class="row"><h2>🎯 Monatsziel</h2><span class="label">' + (goal ? fmtPercent(prog) : '') + '</span></div>';
  if (goal) {
    h += '<div class="bar' + (prog >= 1 ? ' done' : '') + '"><div style="width:' + Math.min(prog, 1) * 100 + '%"></div></div>';
    h += '<div class="row muted"><span>' + esc(money(st.current, false)) + ' von ' + esc(money(goal, false)) + '</span><span>' +
      (prog >= 1 ? 'Erreicht 🎉' : 'fehlen ' + esc(money(goal - st.current, false))) + '</span></div>';
  } else {
    h += '<div class="muted" style="margin-top:8px">Im Menü unter Einstellungen › Monatsziel festlegen.</div>';
  }
  h += '</div>';

  const sel = selected !== null ? st.buckets[selected] : null;
  h += '<div class="card"><div class="row"><h2>Pro Monat</h2><div class="sel">' +
    (sel ? monthLabel(sel.key) + '<b>' + esc(money(sel.received + sel.planned)) + '</b>' : 'Balken antippen') + '</div></div>' +
    '<div id="bars" style="margin-top:10px">' + barChart(st, goal) + '</div>' +
    '<div class="muted" style="margin-top:8px"><span style="color:var(--accent)">■</span> eingegangen &nbsp; <span style="color:var(--accent);opacity:.35">■</span> erwartet</div></div>';

  const slices = sourceSlices(D.incomes, D.today, period);
  h += '<div class="card"><h2>Nach Quelle</h2><div class="seg">' +
    [["month","Monat"],["year","Jahr"],["last12","12 Monate"]].map(p => '<button data-p="' + p[0] + '" class="' + (period === p[0] ? 'on' : '') + '">' + p[1] + '</button>').join('') + '</div>';
  if (!slices.length) h += '<div class="empty">Keine Einnahmen in diesem Zeitraum</div>';
  else {
    h += donut(slices) + '<div class="legend" style="margin-top:10px">' + slices.map(sl =>
      '<div><span class="dot" style="background:' + SOURCES[sl.source].color + '"></span>' + esc(SOURCES[sl.source].title) +
      '<span class="p">' + fmtPercent(sl.share) + '</span><span class="a">' + esc(money(sl.cents)) + '</span></div>').join('') + '</div>';
  }
  h += '</div>';

  const upcoming = D.incomes.filter(i => i.planned).sort((a, b) => a.date.localeCompare(b.date)).slice(0, 5);
  const recent = D.incomes.filter(i => !i.planned).sort((a, b) => b.date.localeCompare(a.date)).slice(0, 8);
  if (upcoming.length) h += '<div class="card"><h2>Demnächst erwartet</h2><div style="margin-top:6px">' + upcoming.map(item).join('') + '</div></div>';
  h += '<div class="card"><h2>Zuletzt eingegangen</h2><div style="margin-top:6px">' +
    (recent.length ? recent.map(item).join('') : '<div class="empty">Noch keine Einnahmen</div>') + '</div></div>';

  document.getElementById("app").innerHTML = h;

  document.getElementById("hero").onclick = () => { hide = !hide; render(); };
  document.querySelectorAll(".seg button").forEach(b => b.onclick = () => { period = b.dataset.p; render(); });
  document.querySelectorAll("#bars g").forEach(g => g.onclick = () => {
    const i = Number(g.dataset.i); selected = selected === i ? null : i; render();
  });
}
document.getElementById("eye").onclick = () => { hide = !hide; render(); };
render();
</script>
</body>
</html>`;
}

// ─────────────────────────────────────────────────────────────
// Start
// ─────────────────────────────────────────────────────────────

async function run() {
  const today = ymd(new Date());
  let data = await loadData();

  if (config.runsInWidget || config.runsInAccessoryWidget) {
    if (data && refreshRecurring(data, today)) saveData(data);
    Script.setWidget(buildWidget(data, today, config.widgetFamily, args.widgetParameter));
    Script.complete();
    return;
  }

  if (!data) data = await firstRun(today);
  if (!data) { Script.complete(); return; }
  if (refreshRecurring(data, today)) saveData(data);

  const action = args.queryParameters ? args.queryParameters.action : null;
  if (action === "add") await addIncomeFlow(data, today);
  await mainMenu(data, today);
  Script.complete();
}

if (typeof config !== "undefined") {
  await run();
} else if (typeof globalThis !== "undefined") {
  // Nur für Tests außerhalb von Scriptable
  globalThis.__EINNAHMEN__ = {
    ymd, addMonths, addMonthsKey, fmtEuro, fmtPercent, parseCents, editString, emptyData,
    refreshRecurring, generateOccurrences, rebuildSeries, deleteSeries, removeDuplicates,
    computeStats, sourceSlices, sampleData, buildOverviewHTML,
  };
}
