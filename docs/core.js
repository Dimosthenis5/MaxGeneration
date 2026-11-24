/* MaxGeneration: data, rules and game logic (no DOM here). */
'use strict';

// ---------- helpers ----------
const uid = () => (typeof crypto !== 'undefined' && crypto.randomUUID) ? crypto.randomUUID() : Date.now().toString(36) + Math.random().toString(36).slice(2);
const pad = n => String(n).padStart(2, '0');
const dayKey = (d = new Date()) => { const x = new Date(d); return `${x.getFullYear()}-${pad(x.getMonth() + 1)}-${pad(x.getDate())}`; };
const fromKey = k => { const [y, m, d] = k.split('-').map(Number); return new Date(y, m - 1, d); };
const addDays = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x; };
const startOfDay = d => { const x = new Date(d); x.setHours(0, 0, 0, 0); return x; };
const sameDay = (a, b) => dayKey(a) === dayKey(b);
const isToday = d => sameDay(d, new Date());
const num = s => { if (s === null || s === undefined || s === '') return null; const v = parseFloat(String(s).replace(',', '.')); return isFinite(v) ? v : null; };
const fmt = v => { if (v === null || v === undefined || !isFinite(v)) return '–'; const r = Math.round(v * 10) / 10; return Number.isInteger(r) ? String(r) : r.toFixed(1); };
const clamp01 = v => Math.min(1, Math.max(0, v || 0));
const hoursText = m => { const h = Math.floor(m / 60), mm = m % 60; return mm ? `${h}h ${mm}m` : `${h}h`; };
const sum = (arr, f) => arr.reduce((a, x) => a + (f ? f(x) : x), 0);

// ---------- constants ----------
const ATTR = {
  strength:   { t: 'Strength',   s: 'STR', e: '💪', c: '#ff6161', b: 'Gym & boxing' },
  intellect:  { t: 'Intellect',  s: 'INT', e: '🧠', c: '#61a1ff', b: 'Studying & learning' },
  vitality:   { t: 'Vitality',   s: 'VIT', e: '❤️', c: '#4dd985', b: 'Sleep, food, water' },
  discipline: { t: 'Discipline', s: 'DIS', e: '🔥', c: '#ffb838', b: 'Habits & goals' },
};
const AREAS = {
  gym:   { t: 'Training (gym & boxing)', e: '🥊' },
  study: { t: 'Studies', e: '📚' },
  food:  { t: 'Food & water', e: '🍽️' },
  life:  { t: 'Habits & big goals', e: '🎯' },
};
const MEALS = {
  breakfast: { t: 'Breakfast', e: '🍳' },
  lunch:     { t: 'Lunch', e: '🥗' },
  dinner:    { t: 'Dinner', e: '🍝' },
  snack:     { t: 'Snacks', e: '🍎' },
};
const SUPP_TIMES = { morning: { t: 'Morning', e: '☀️' }, anytime: { t: 'Any time', e: '🕐' }, night: { t: 'Night', e: '🌙' } };
const GOALS = { loseFat: '🔥 Lose fat', buildMuscle: '💪 Build muscle', recomp: '⚖️ Recomp (both)', maintain: '🧘 Maintain & perform' };
const AVATARS = ['🧙‍♂️', '🥷', '🦸‍♂️', '🧝', '🐉', '🦁', '🐺', '🤖', '👑', '🧑‍🚀', '🦊', '🐻', '🦅', '⚡', '🥊', '🏎️'];
const HABIT_EMOJIS = ['✅', '🛏️', '📖', '🧘', '🥗', '🚶', '⏰', '📵', '🤸', '💧', '🧹', '🎸', '✍️', '🌅', '🚭', '🧊'];
const BOSS_EMOJIS = ['🐉', '👹', '🧟', '🦖', '👾', '🐙', '💀', '🧌', '🦂', '🌪️'];
const FEELINGS = { 1: ['😫', 'Drained'], 2: ['😕', 'Meh'], 3: ['😐', 'OK'], 4: ['🙂', 'Good'], 5: ['🔥', 'On fire'] };
const COMMON_EXERCISES = ['Bench Press', 'Squat', 'Deadlift', 'Overhead Press', 'Pull-up', 'Barbell Row', 'Incline Dumbbell Press', 'Lat Pulldown', 'Romanian Deadlift', 'Leg Press', 'Bicep Curl', 'Tricep Pushdown', 'Lateral Raise', 'Dips', 'Hip Thrust', 'Calf Raise'];
const STARTER_HABITS = [
  { name: 'In bed by 23:30', emoji: '🛏️', attr: 'discipline' },
  { name: 'Read 20 minutes', emoji: '📖', attr: 'intellect' },
  { name: 'Meditate 10 minutes', emoji: '🧘', attr: 'discipline' },
  { name: 'No junk food', emoji: '🥗', attr: 'vitality' },
  { name: '10k steps', emoji: '🚶', attr: 'strength' },
  { name: 'Wake up before 8', emoji: '⏰', attr: 'discipline' },
  { name: 'No phone first hour', emoji: '📵', attr: 'discipline' },
  { name: 'Stretch / mobility', emoji: '🤸', attr: 'strength' },
];
const BOSS_TEMPLATES = [
  { name: 'Read 12 books', emoji: '🐉', target: 12, unit: 'books', attr: 'intellect' },
  { name: 'Lose 5 kg', emoji: '👹', target: 5, unit: 'kg', attr: 'vitality' },
  { name: '30 boxing sessions', emoji: '🦖', target: 30, unit: 'sessions', attr: 'strength' },
  { name: 'Study 50 hours for exams', emoji: '🧟', target: 50, unit: 'hours', attr: 'intellect' },
  { name: 'Save €1000', emoji: '💀', target: 1000, unit: '€', attr: 'discipline' },
  { name: '30 gym sessions', emoji: '🧌', target: 30, unit: 'sessions', attr: 'strength' },
];
const defaultSupplements = () => [
  { id: uid(), name: 'Multivitamin', emoji: '💊', time: 'morning' },
  { id: uid(), name: 'Omega-3', emoji: '🐟', time: 'morning' },
  { id: uid(), name: 'Creatine', emoji: '⚡', time: 'anytime' },
  { id: uid(), name: 'Magnesium', emoji: '🌙', time: 'night' },
];

// ---------- state ----------
const STORAGE_KEY = 'maxgeneration-data-v1';
const blankState = () => ({
  v: 1, profile: null, workouts: [], bodyweight: [], study: [], subjects: [], foods: [], water: {},
  habits: [], bosses: [], xp: [], claimed: {}, seen: [], dayLogs: {}, boxing: [], weekLogs: {},
  settings: { sound: true },
});
let S = blankState();

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) S = Object.assign(blankState(), JSON.parse(raw));
  } catch (e) { console.warn('load failed', e); }
  return S;
}
function saveState() {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(S)); } catch (e) { console.warn('save failed', e); }
}
function replaceState(obj) { S = Object.assign(blankState(), obj); saveState(); }

// Event hooks the UI layer fills in.
const Hooks = { toast: () => {}, levelUp: () => {}, sound: () => {} };

const P = () => S.profile || {};
const has = area => (P().areas || []).includes(area);

// ---------- XP & levels ----------
const xpToNext = lvl => 100 + (lvl - 1) * 50;
function levelInfo(total) {
  let level = 1, rem = Math.max(0, total);
  while (rem >= xpToNext(level)) { rem -= xpToNext(level); level++; }
  return { level, into: rem, needed: xpToNext(level), frac: rem / xpToNext(level) };
}
function attrInfo(xp) {
  let level = 1, rem = Math.max(0, xp);
  const need = l => 60 + (l - 1) * 30;
  while (rem >= need(level)) { rem -= need(level); level++; }
  return { level, into: rem, needed: need(level), frac: rem / need(level) };
}
function rankTitle(l) {
  if (l < 3) return 'Novice'; if (l < 6) return 'Apprentice'; if (l < 10) return 'Adventurer';
  if (l < 15) return 'Warrior'; if (l < 20) return 'Champion'; if (l < 30) return 'Hero';
  if (l < 40) return 'Legend'; return 'Mythic';
}
function rankColor(l) {
  if (l < 3) return '#b3b3bf'; if (l < 6) return '#73d980'; if (l < 10) return '#59a6ff';
  if (l < 15) return '#a673ff'; if (l < 20) return '#ff73b3'; if (l < 30) return '#ff9933'; return '#ffd140';
}
const totalXP = () => sum(S.xp, e => e.amount);
const level = () => levelInfo(totalXP()).level;
const xpOf = a => sum(S.xp.filter(e => e.attr === a), e => e.amount);
const xpToday = () => sum(S.xp.filter(e => isToday(e.date)), e => e.amount);

function award(amount, attr, reason, key) {
  if (amount <= 0) return;
  if (key && S.xp.some(e => e.key === key)) return;
  const before = level();
  S.xp.push({ id: uid(), date: Date.now(), amount, attr, reason, key: key || null });
  const after = level();
  if (after > before) Hooks.levelUp(after);
  checkAchievements();
}
const revoke = key => { S.xp = S.xp.filter(e => e.key !== key); };
const revokePrefix = p => { S.xp = S.xp.filter(e => !(e.key || '').startsWith(p)); };

// ---------- streaks ----------
function currentStreak(days) {
  let d = new Date();
  if (!days.has(dayKey(d))) d = addDays(d, -1);
  let n = 0;
  while (days.has(dayKey(d))) { n++; d = addDays(d, -1); }
  return n;
}
function bestStreak(days) {
  const keys = [...days].sort();
  let best = 0, run = 0, last = null;
  for (const k of keys) {
    run = (last && dayKey(addDays(fromKey(last), 1)) === k) ? run + 1 : 1;
    best = Math.max(best, run); last = k;
  }
  return best;
}
const activeDays = () => new Set(S.xp.map(e => dayKey(e.date)));
const streak = () => currentStreak(activeDays());
const best = () => bestStreak(activeDays());

// ---------- gym ----------
const e1rm = s => (s.reps > 0 && s.weight > 0) ? s.weight * (1 + s.reps / 30) : 0;
const setCount = w => sum(w.exercises, ex => ex.sets.length);
const volume = w => sum(w.exercises, ex => sum(ex.sets, s => s.reps * s.weight));
function bestE1RM(name, excludeId) {
  const t = name.toLowerCase(); let b = 0;
  for (const w of S.workouts) if (w.id !== excludeId)
    for (const ex of w.exercises) if (ex.name.toLowerCase() === t)
      for (const s of ex.sets) b = Math.max(b, e1rm(s));
  return b;
}
function saveWorkout(w) {
  const key = 'w:' + w.id;
  revokePrefix(key);
  S.workouts = S.workouts.filter(x => x.id !== w.id);
  const prs = [];
  for (const ex of w.exercises) {
    const prev = bestE1RM(ex.name, w.id);
    const cur = Math.max(0, ...ex.sets.map(e1rm));
    if (prev > 0 && cur > prev + 0.01) prs.push(ex.name);
  }
  S.workouts.push(w);
  S.workouts.sort((a, b) => b.date - a.date);
  award(Math.min(80, 20 + setCount(w) * 2), 'strength', 'Workout: ' + w.title, key);
  for (const n of prs) award(25, 'strength', 'New PR: ' + n, `${key}:pr:${n}`);
  if (prs.length) { Hooks.toast('🏆 New PR: ' + prs.join(', ')); Hooks.sound('claim'); }
}
function deleteWorkout(id) { S.workouts = S.workouts.filter(w => w.id !== id); revokePrefix('w:' + id); }
function exerciseNames() {
  const seen = new Set(), out = [];
  for (const w of S.workouts) for (const ex of w.exercises) {
    const k = ex.name.toLowerCase(); if (!seen.has(k)) { seen.add(k); out.push(ex.name); }
  }
  return out;
}
function workoutTemplates(limit = 4) {
  const seen = new Set(), out = [];
  for (const w of S.workouts) {
    const k = w.title.toLowerCase();
    if (!seen.has(k) && w.exercises.length) { seen.add(k); out.push(w); }
    if (out.length >= limit) break;
  }
  return out;
}
function exerciseHistory(name) {
  const t = name.toLowerCase(), out = [];
  for (const w of S.workouts) {
    const sets = w.exercises.filter(ex => ex.name.toLowerCase() === t).flatMap(ex => ex.sets);
    if (sets.length) out.push({ id: w.id, date: w.date, sets });
  }
  return out;
}
const exerciseProgress = name => exerciseHistory(name)
  .map(h => ({ date: h.date, value: Math.max(...h.sets.map(e1rm)) })).filter(p => p.value > 0).sort((a, b) => a.date - b.date);

function weekBounds(date = new Date()) {
  const d = startOfDay(date);
  const dow = (d.getDay() + 6) % 7; // Monday = 0
  const start = addDays(d, -dow);
  return { start, end: addDays(start, 7) };
}
const weekKey = (date = new Date()) => dayKey(weekBounds(date).start);
function sessionsInWeek(date = new Date()) {
  const { start, end } = weekBounds(date);
  const inW = x => x.date >= start.getTime() && x.date < end.getTime();
  return S.workouts.filter(inW).length + S.boxing.filter(inW).length;
}

function addBodyweight(kg) {
  const e = { id: uid(), date: Date.now(), kg };
  S.bodyweight.push(e); S.bodyweight.sort((a, b) => b.date - a.date);
  award(5, 'vitality', 'Weigh-in', 'bw:' + e.id);
}
function deleteBodyweight(id) { S.bodyweight = S.bodyweight.filter(b => b.id !== id); revoke('bw:' + id); }

function addBoxing(b) {
  S.boxing.push(b); S.boxing.sort((a, c) => c.date - a.date);
  award(Math.min(80, 15 + Math.floor(b.minutes / 2)), 'strength', `Boxing ${b.minutes} min 🥊`, 'box:' + b.id);
  Hooks.sound('claim');
}
function deleteBoxing(id) { S.boxing = S.boxing.filter(b => b.id !== id); revoke('box:' + id); }
const boxingMinutes = day => sum(S.boxing.filter(b => sameDay(b.date, day)), b => b.minutes);
const trained = day => S.workouts.some(w => sameDay(w.date, day)) || S.boxing.some(b => sameDay(b.date, day));

// ---------- study ----------
const studyMinutes = day => sum(S.study.filter(s => sameDay(s.date, day)), s => s.minutes);
const totalStudy = () => sum(S.study, s => s.minutes);
function addStudy(s) {
  const before = studyMinutes(s.date);
  S.study.push(s); S.study.sort((a, b) => b.date - a.date);
  if (s.subject && !S.subjects.includes(s.subject)) S.subjects.push(s.subject);
  const key = 's:' + s.id;
  award(Math.max(5, Math.floor(s.minutes / 2)), 'intellect', `Studied ${s.subject || 'General'} (${s.minutes}m)`, key);
  const t = P().study || 60;
  if (before < t && before + s.minutes >= t) { award(20, 'intellect', 'Daily study target hit', key + ':target'); Hooks.toast('🧠 Study target complete!'); }
}
function deleteStudy(id) { S.study = S.study.filter(s => s.id !== id); revokePrefix('s:' + id); }
function bySubject() {
  const m = {}; for (const s of S.study) m[s.subject || 'General'] = (m[s.subject || 'General'] || 0) + s.minutes;
  return Object.entries(m).sort((a, b) => b[1] - a[1]);
}
function lastDays(n, f) {
  const out = []; const today = startOfDay(new Date());
  for (let i = n - 1; i >= 0; i--) { const d = addDays(today, -i); out.push({ date: d, value: f(d) }); }
  return out;
}

// ---------- food ----------
const foodsOn = day => S.foods.filter(f => sameDay(f.date, day));
const kcalOn = day => sum(foodsOn(day), f => f.kcal);
const proteinOn = day => sum(foodsOn(day), f => f.protein);
function addFood(f) {
  const before = proteinOn(f.date);
  S.foods.push(f);
  const key = 'f:' + f.id;
  award(5, 'vitality', 'Logged ' + f.name, key);
  const t = P().protein || 0;
  if (t > 0 && before < t && before + f.protein >= t) { award(20, 'vitality', 'Protein target hit', key + ':protein'); Hooks.toast('🥩 Protein target smashed!'); }
}
function deleteFood(id) { S.foods = S.foods.filter(f => f.id !== id); revokePrefix('f:' + id); }
function recentFoods() {
  const seen = new Set(), out = [];
  for (const f of [...S.foods].sort((a, b) => b.date - a.date)) {
    const k = f.name.toLowerCase(); if (!seen.has(k)) { seen.add(k); out.push(f); }
    if (out.length >= 12) break;
  }
  return out;
}
const waterOn = day => S.water[dayKey(day)] || 0;
function changeWater(day, delta) {
  const k = dayKey(day), cur = S.water[k] || 0, next = Math.max(0, cur + delta);
  if (next === cur) return;
  S.water[k] = next;
  const t = P().water || 8;
  if (delta > 0) {
    if (next <= t) award(2, 'vitality', 'Cup of water', `water:${k}:${next}`);
    if (next === t) { award(10, 'vitality', 'Hydration goal hit', `water:${k}:goal`); Hooks.toast('💧 Hydration goal hit!'); }
    Hooks.sound('tap');
  } else {
    revoke(`water:${k}:${cur}`);
    if (cur === t) revoke(`water:${k}:goal`);
  }
}
function guessMeal() {
  const h = new Date().getHours();
  if (h >= 4 && h < 11) return 'breakfast'; if (h < 16 && h >= 11) return 'lunch'; if (h >= 16 && h < 22) return 'dinner'; return 'snack';
}

// ---------- habits ----------
const habitDone = (h, day = new Date()) => (h.done || []).includes(dayKey(day));
function toggleHabit(id, day = new Date()) {
  const h = S.habits.find(x => x.id === id); if (!h) return;
  const k = dayKey(day), key = `h:${id}:${k}`;
  h.done = h.done || [];
  if (h.done.includes(k)) { h.done = h.done.filter(x => x !== k); revoke(key); }
  else { h.done.push(k); award(10, h.attr, `${h.emoji} ${h.name}`, key); Hooks.sound('tap'); }
}
function deleteHabit(id) { S.habits = S.habits.filter(h => h.id !== id); revokePrefix('h:' + id); }

// ---------- bosses ----------
const bossDamage = b => sum(b.hits || [], h => h.amount);
const bossHP = b => Math.max(0, b.target - bossDamage(b));
const bossProgress = b => b.target > 0 ? Math.min(1, bossDamage(b) / b.target) : 0;
const activeBosses = () => S.bosses.filter(b => !b.defeatedAt);
const defeatedBosses = () => S.bosses.filter(b => b.defeatedAt);
function hitBoss(id, amount) {
  const b = S.bosses.find(x => x.id === id);
  if (!b || b.defeatedAt || !(amount > 0)) return;
  const hit = { id: uid(), date: Date.now(), amount };
  b.hits = b.hits || []; b.hits.push(hit);
  award(10, b.attr, 'Hit ' + b.name, `b:${b.id}:${hit.id}`);
  if (bossHP(b) <= 0) {
    b.defeatedAt = Date.now();
    award(150, b.attr, `Defeated ${b.name}!`, `b:${b.id}:defeat`);
    Hooks.toast(`⚔️ ${b.name} defeated! +150 XP`); Hooks.sound('levelup');
  } else Hooks.sound('tap');
}
function deleteBoss(id) { S.bosses = S.bosses.filter(b => b.id !== id); revokePrefix('b:' + id); }

// ---------- sleep & supplements ----------
const dayLog = (day = new Date()) => S.dayLogs[dayKey(day)] || {};
function updateDayLog(day, fn) { const k = dayKey(day); const log = S.dayLogs[k] || {}; fn(log); S.dayLogs[k] = log; }
function sleepMinutesFrom(bed, wake) {
  const [bh, bm] = bed.split(':').map(Number), [wh, wm] = wake.split(':').map(Number);
  let d = (wh * 60 + wm) - (bh * 60 + bm); if (d <= 0) d += 1440; return d;
}
const sleepTarget = () => Math.round((P().sleep || 8) * 60);
function logSleep(day, bed, wake) {
  const mins = sleepMinutesFrom(bed, wake), k = dayKey(day);
  updateDayLog(day, l => { l.sleep = mins; l.bed = bed; l.wake = wake; });
  revokePrefix('sleep:' + k);
  award(15, 'vitality', `Logged sleep (${hoursText(mins)})`, 'sleep:' + k);
  if (mins >= sleepTarget()) { award(15, 'vitality', 'Sleep goal hit', `sleep:${k}:goal`); Hooks.toast('😴 Fully recharged! Sleep goal hit'); }
  Hooks.sound('claim');
}
const suppTaken = (s, day = new Date()) => (dayLog(day).supps || []).includes(s.id);
const suppCount = (day = new Date()) => (P().supplements || []).filter(s => suppTaken(s, day)).length;
function toggleSupp(id, day = new Date()) {
  const s = (P().supplements || []).find(x => x.id === id); if (!s) return;
  const k = dayKey(day), key = `sup:${k}:${id}`;
  if (suppTaken(s, day)) {
    updateDayLog(day, l => { l.supps = (l.supps || []).filter(x => x !== id); });
    revoke(key); revoke(`sup:${k}:all`);
  } else {
    updateDayLog(day, l => { l.supps = [...(l.supps || []), id]; });
    award(5, 'vitality', `${s.emoji} ${s.name}`, key);
    const all = P().supplements || [];
    if (all.length && all.every(x => suppTaken(x, day))) { award(10, 'vitality', 'All supplements taken', `sup:${k}:all`); Hooks.toast('💊 Stack complete!'); }
    Hooks.sound('tap');
  }
}

// ---------- ranks ----------
function rankFor(score) { if (score >= 95) return 'S+'; if (score >= 85) return 'S'; if (score >= 70) return 'A'; if (score >= 50) return 'B'; return 'C'; }
const RANK_COLOR = { 'S+': '#ffd633', S: '#ff9e26', A: '#59d9ff', B: '#66e680', C: '#bfbfcc' };
const RANK_BONUS = { 'S+': 100, S: 75, A: 50, B: 30, C: 15 };
const RANK_MSG = { 'S+': 'FLAWLESS. A legendary day.', S: 'Outstanding run. Elite day.', A: 'Great day. Almost perfect.', B: 'Solid. You showed up.', C: 'Day cleared. Tomorrow, go faster.' };
function finalize(lines) {
  const tw = sum(lines, l => l.weight), earned = sum(lines, l => clamp01(l.frac) * l.weight);
  const score = tw ? Math.round(earned / tw * 100) : 0;
  lines.forEach(l => { l.points = Math.round(clamp01(l.frac) * l.weight); });
  return { lines, score, rank: rankFor(score) };
}
function dayScore(day = new Date()) {
  const p = P(), lines = [];
  const sl = dayLog(day).sleep;
  lines.push({ e: '😴', t: 'Sleep', d: sl ? `${hoursText(sl)} / ${fmt(p.sleep || 8)}h` : 'Not logged', frac: (sl || 0) / sleepTarget(), weight: 20 });
  if (has('gym')) {
    const gym = S.workouts.some(w => sameDay(w.date, day)), box = boxingMinutes(day), parts = [];
    if (gym) parts.push('Gym'); if (box) parts.push(`Boxing ${box}m`);
    lines.push({ e: '🥊', t: 'Training', d: parts.length ? parts.join(' + ') : 'Rest day', frac: parts.length ? 1 : 0.3, weight: 20 });
  }
  if (has('food')) {
    const pr = proteinOn(day), kc = kcalOn(day), t = Math.max(1, p.kcal || 2200), cups = waterOn(day);
    lines.push({ e: '🥩', t: 'Protein', d: `${pr} / ${p.protein} g`, frac: pr / Math.max(1, p.protein), weight: 15 });
    lines.push({ e: '🔥', t: 'Calories', d: `${kc} / ${p.kcal} kcal`, frac: kc === 0 ? 0 : Math.max(0, 1 - Math.abs(kc - t) / (t * 0.5)), weight: 10 });
    lines.push({ e: '💧', t: 'Water', d: `${cups} / ${p.water} cups`, frac: cups / Math.max(1, p.water), weight: 10 });
  }
  const supps = p.supplements || [];
  if (supps.length) { const c = suppCount(day); lines.push({ e: '💊', t: 'Supplements', d: `${c} / ${supps.length}`, frac: c / supps.length, weight: 10 }); }
  if (has('study')) { const m = studyMinutes(day); lines.push({ e: '📚', t: 'Study', d: `${m} / ${p.study} min`, frac: m / Math.max(1, p.study), weight: 10 }); }
  if (has('life') && S.habits.length) { const d = S.habits.filter(h => habitDone(h, day)).length; lines.push({ e: '✅', t: 'Habits', d: `${d} / ${S.habits.length}`, frac: d / S.habits.length, weight: 5 }); }
  return finalize(lines);
}
function finishDay() {
  const r = dayScore(), k = dayKey();
  updateDayLog(new Date(), l => { l.score = r.score; l.rank = r.rank; });
  revoke('rank:' + k);
  award(RANK_BONUS[r.rank], 'discipline', 'Day rank ' + r.rank, 'rank:' + k);
  return r;
}
const rankHistory = n => lastDays(n, d => dayLog(d).rank || null);
const countRanks = ranks => Object.values(S.dayLogs).filter(l => ranks.includes(l.rank)).length;

// ---------- weeks ----------
const weekLog = (date = new Date()) => S.weekLogs[weekKey(date)] || { goals: [] };
function updateWeekLog(date, fn) { const k = weekKey(date); const l = S.weekLogs[k] || { goals: [] }; fn(l); S.weekLogs[k] = l; }
function addWeekGoal(text, date = new Date()) {
  const t = text.trim(); if (!t) return;
  updateWeekLog(date, l => l.goals.push({ id: uid(), text: t, done: false }));
  Hooks.sound('tap');
}
function toggleWeekGoal(id, date = new Date()) {
  let was = false;
  updateWeekLog(date, l => { const g = l.goals.find(x => x.id === id); if (g) { was = g.done; g.done = !g.done; } });
  const g = weekLog(date).goals.find(x => x.id === id);
  if (was) revoke('wg:' + id); else { award(25, 'discipline', 'Week goal: ' + (g ? g.text : ''), 'wg:' + id); Hooks.sound('claim'); }
}
function deleteWeekGoal(id, date = new Date()) { updateWeekLog(date, l => { l.goals = l.goals.filter(g => g.id !== id); }); revoke('wg:' + id); }
function elapsedDays(date) {
  const { start } = weekBounds(date), today = startOfDay(new Date()), out = [];
  for (let i = 0; i < 7; i++) { const d = addDays(start, i); if (d <= today) out.push(d); }
  return out;
}
function weekScore(date = new Date()) {
  const days = elapsedDays(date), log = weekLog(date), lines = [];
  const scores = days.map(d => dayScore(d).score);
  const avg = scores.length ? sum(scores) / scores.length : 0;
  lines.push({ e: '📅', t: 'Daily ranks', d: `Avg ${Math.round(avg)} (${rankFor(Math.round(avg))}) over ${days.length} days`, frac: avg / 100, weight: 50 });
  const done = log.goals.filter(g => g.done).length;
  lines.push({ e: '🎯', t: 'Week goals', d: log.goals.length ? `${done} / ${log.goals.length} done` : 'No goals set', frac: log.goals.length ? done / log.goals.length : 0, weight: 25 });
  if (has('gym')) { const s = sessionsInWeek(date); lines.push({ e: '🏋️', t: 'Training sessions', d: `${s} / ${P().perWeek}`, frac: s / Math.max(1, P().perWeek), weight: 15 }); }
  const checked = log.weight != null || log.bf != null;
  lines.push({ e: '📏', t: 'Body check-in', d: checked ? 'Logged' : 'Not yet', frac: checked ? 1 : 0, weight: 10 });
  return finalize(lines);
}
function finishWeek(date, { weight, bf, feeling, note }) {
  updateWeekLog(date, l => { l.weight = weight; l.bf = bf; l.feeling = feeling; l.note = note; });
  if (weight != null) {
    const wk = weekKey(date);
    if (!S.bodyweight.some(b => weekKey(b.date) === wk && Math.abs(b.kg - weight) < 0.01)) addBodyweight(weight);
  }
  const r = weekScore(date);
  updateWeekLog(date, l => { l.score = r.score; l.rank = r.rank; });
  const key = 'week:' + weekKey(date);
  revoke(key); award(RANK_BONUS[r.rank] * 2, 'discipline', 'Week rank ' + r.rank, key);
  return r;
}
const lastWeekDate = () => addDays(new Date(), -7);
function lastWeekNeedsCheckIn() {
  const d = lastWeekDate(); if (weekLog(d).rank) return false;
  const { start, end } = weekBounds(d);
  return S.xp.some(e => e.date >= start.getTime() && e.date < end.getTime());
}
function weekHistory() {
  return Object.entries(S.weekLogs).filter(([, l]) => l.rank || l.weight != null || l.bf != null || l.photo)
    .map(([k, l]) => ({ key: k, start: fromKey(k), log: l })).sort((a, b) => b.start - a.start);
}
function weekTitle(start) {
  const end = addDays(start, 6), o = { day: 'numeric', month: 'short' };
  return `Week of ${start.toLocaleDateString('en-GB', o)} – ${end.toLocaleDateString('en-GB', o)}`;
}

// ---------- quests ----------
function seededShuffle(arr, seedStr) {
  let h = 5381; for (const ch of seedStr) h = ((h * 33) ^ ch.charCodeAt(0)) >>> 0;
  const rnd = () => { h ^= h << 13; h >>>= 0; h ^= h >>> 17; h ^= h << 5; h >>>= 0; return h / 4294967296; };
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; }
  return a;
}
function todaysQuests() {
  const p = P(), today = new Date(), list = [];
  const q = (id, title, e, xp, attr, cur, target, unit = '') => ({ id, title, e, xp, attr, cur, target, unit, done: cur >= target });
  const sleepQ = q('sleep', `Sleep ${fmt(p.sleep || 8)} hours`, '😴', 30, 'vitality', (dayLog(today).sleep || 0) / 60, p.sleep || 8, 'h');
  if ((p.supplements || []).length) list.push(q('supps', 'Take all your supplements', '💊', 20, 'vitality', suppCount(today), p.supplements.length));
  if (has('gym')) {
    const sets = sum(S.workouts.filter(w => isToday(w.date)), setCount);
    list.push(q('train', 'Train today (gym or boxing)', '🥊', 30, 'strength', trained(today) ? 1 : 0, 1));
    list.push(q('sets', 'Crush 15 working sets', '🔩', 35, 'strength', sets, 15, 'sets'));
    list.push(q('box', 'Box for 45 minutes', '🥊', 35, 'strength', boxingMinutes(today), 45, 'min'));
  }
  if (has('study')) {
    const m = studyMinutes(today), half = Math.max(15, Math.floor((p.study || 60) / 2));
    list.push(q('study', `Study ${half} minutes`, '📚', 25, 'intellect', m, half, 'min'));
    list.push(q('study2', `Hit your ${p.study}-min study goal`, '🧠', 40, 'intellect', m, Math.max(1, p.study), 'min'));
  }
  if (has('food')) {
    list.push(q('protein', `Eat ${p.protein}g protein`, '🥩', 30, 'vitality', proteinOn(today), Math.max(1, p.protein), 'g'));
    list.push(q('water', `Drink ${p.water} cups of water`, '💧', 20, 'vitality', waterOn(today), Math.max(1, p.water)));
    list.push(q('meals', 'Log 3 different meals', '🍽️', 20, 'vitality', new Set(foodsOn(today).map(f => f.meal)).size, 3));
  }
  if (has('life')) {
    if (S.habits.length) list.push(q('habits', 'Complete all your habits', '✅', 40, 'discipline', S.habits.filter(h => habitDone(h)).length, S.habits.length));
    if (activeBosses().length) list.push(q('boss', 'Deal damage to a boss', '⚔️', 25, 'discipline', activeBosses().some(b => (b.hits || []).some(h => isToday(h.date))) ? 1 : 0, 1));
  }
  return [sleepQ, ...seededShuffle(list, dayKey(today)).slice(0, 3)];
}
const questClaimed = qid => (S.claimed[dayKey()] || []).includes(qid);
function claimQuest(qid) {
  const qs = todaysQuests(), quest = qs.find(x => x.id === qid);
  if (!quest || !quest.done || questClaimed(qid)) return;
  const k = dayKey();
  S.claimed[k] = [...(S.claimed[k] || []), qid];
  award(quest.xp, quest.attr, 'Quest: ' + quest.title, `q:${k}:${qid}`);
  if (qs.every(x => questClaimed(x.id))) { award(50, 'discipline', 'Perfect Day bonus', 'perfect:' + k); Hooks.toast('✨ Perfect Day! +50 XP'); }
  Hooks.sound('claim');
}

// ---------- achievements ----------
const ACHIEVEMENTS = [
  ['first_workout', '🏋️', 'First Rep', 'Log your first workout', () => S.workouts.length >= 1],
  ['workouts_10', '💪', 'Gym Regular', 'Log 10 workouts', () => S.workouts.length >= 10],
  ['workouts_50', '🦍', 'Iron Addict', 'Log 50 workouts', () => S.workouts.length >= 50],
  ['workouts_100', '🗿', 'Unbreakable', 'Log 100 workouts', () => S.workouts.length >= 100],
  ['first_pr', '🏆', 'Personal Best', 'Set your first PR', () => S.xp.some(e => (e.key || '').includes(':pr:'))],
  ['first_box', '🥊', 'Gloves On', 'Log your first boxing session', () => S.boxing.length >= 1],
  ['box_20', '🥋', 'Ring Veteran', 'Log 20 boxing sessions', () => S.boxing.length >= 20],
  ['well_rested', '😴', 'Well Rested', 'Hit your sleep goal', () => Object.values(S.dayLogs).some(l => (l.sleep || 0) >= sleepTarget())],
  ['sleep_7', '🌙', 'Sleep Streak', 'Log sleep 7 days in a row', () => bestStreak(new Set(Object.keys(S.dayLogs).filter(k => S.dayLogs[k].sleep))) >= 7],
  ['study_1h', '📖', 'Bookworm', 'Study for 1 hour total', () => totalStudy() >= 60],
  ['study_10h', '🎓', 'Scholar', 'Study for 10 hours total', () => totalStudy() >= 600],
  ['study_100h', '🧙', 'Archmage', 'Study for 100 hours total', () => totalStudy() >= 6000],
  ['meals_10', '🍽️', 'Food Logger', 'Log 10 meals', () => S.foods.length >= 10],
  ['meals_100', '👨‍🍳', 'Nutrition Nerd', 'Log 100 meals', () => S.foods.length >= 100],
  ['hydrated', '💧', 'Hydrated', 'Hit your water goal', () => Object.values(S.water).some(v => v >= (P().water || 8))],
  ['streak_3', '🔥', 'On Fire', '3-day activity streak', () => best() >= 3],
  ['streak_7', '☄️', 'Week Warrior', '7-day activity streak', () => best() >= 7],
  ['streak_30', '🌋', 'Unstoppable', '30-day activity streak', () => best() >= 30],
  ['level_5', '⭐', 'Rising Star', 'Reach level 5', () => level() >= 5],
  ['level_10', '🌟', 'Warrior', 'Reach level 10', () => level() >= 10],
  ['level_25', '👑', 'Hero of Legend', 'Reach level 25', () => level() >= 25],
  ['rank_a', '🅰️', 'A-Game', 'Finish a day with rank A or better', () => countRanks(['A', 'S', 'S+']) >= 1],
  ['rank_s', '🌠', 'S-Rank', 'Finish a day with rank S or better', () => countRanks(['S', 'S+']) >= 1],
  ['rank_splus', '💎', 'Flawless', 'Finish a day with rank S+', () => countRanks(['S+']) >= 1],
  ['rank_s_10', '🌌', 'Speed Demon', 'Get 10 S-rank days or better', () => countRanks(['S', 'S+']) >= 10],
  ['week_s', '🏁', 'Week Champion', 'Get an S week or better', () => Object.values(S.weekLogs).some(l => l.rank === 'S' || l.rank === 'S+')],
  ['photo_4', '📸', 'Transformation', 'Log 4 weekly progress photos', () => Object.values(S.weekLogs).filter(l => l.photo).length >= 4],
  ['boss_1', '⚔️', 'Boss Slayer', 'Defeat your first boss', () => S.bosses.some(b => b.defeatedAt)],
  ['boss_5', '🐉', 'Dragon Hunter', 'Defeat 5 bosses', () => S.bosses.filter(b => b.defeatedAt).length >= 5],
  ['habits_50', '✅', 'Creature of Habit', 'Complete 50 habits', () => sum(S.habits, h => (h.done || []).length) >= 50],
  ['perfect_day', '✨', 'Perfect Day', 'Claim all daily quests in a day', () => S.xp.some(e => (e.key || '').startsWith('perfect:'))],
].map(([id, e, t, d, check]) => ({ id, e, t, d, check }));
let checking = false;
function checkAchievements(silent = false) {
  if (checking) return; checking = true;
  try {
    const fresh = ACHIEVEMENTS.filter(a => !S.seen.includes(a.id) && a.check());
    if (fresh.length) {
      S.seen.push(...fresh.map(a => a.id));
      if (!silent) fresh.forEach(a => Hooks.toast(`${a.e} Achievement: ${a.t}`));
    }
  } finally { checking = false; }
}

if (typeof module !== 'undefined') module.exports = { get S() { return S; }, replaceState, blankState, Hooks, uid, dayKey, addDays, levelInfo, award, saveWorkout, deleteWorkout, addBoxing, addStudy, addFood, changeWater, toggleHabit, hitBoss, logSleep, toggleSupp, dayScore, finishDay, weekScore, finishWeek, todaysQuests, claimQuest, addWeekGoal, toggleWeekGoal, checkAchievements, ACHIEVEMENTS, defaultSupplements, exerciseProgress, sessionsInWeek, streak, totalXP, level };
