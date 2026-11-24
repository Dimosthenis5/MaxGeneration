/* MaxGeneration: screens & interaction. */
'use strict';

const $ = (s, r = document) => r.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const bar = (frac, color, cls = '') => `<div class="bar ${cls}"><i style="width:${Math.round(clamp01(frac) * 100)}%;background:${color}"></i></div>`;
const toLocalInput = ms => { const d = new Date(ms); return `${dayKey(d)}T${pad(d.getHours())}:${pad(d.getMinutes())}`; };
const fromLocalInput = v => { const t = new Date(v).getTime(); return isFinite(t) ? t : Date.now(); };
const shortDate = ms => new Date(ms).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });
const weekdayLetter = d => d.toLocaleDateString('en-GB', { weekday: 'narrow' });

const UI = { tab: 'home', page: null, modal: null, draft: null, foodDay: new Date(), onb: null };

// ---------- sound (synthesized, original) ----------
let AC = null;
function ctx() {
  if (!AC) { const C = window.AudioContext || window.webkitAudioContext; if (!C) return null; AC = new C(); }
  if (AC.state === 'suspended') AC.resume();
  return AC;
}
function tone(freq, dur, type = 'square', vol = 0.12, when = 0, slide = 0) {
  const c = ctx(); if (!c) return;
  const t0 = c.currentTime + when, o = c.createOscillator(), g = c.createGain();
  o.type = type; o.frequency.setValueAtTime(freq, t0);
  if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq * (1 + slide)), t0 + dur);
  g.gain.setValueAtTime(0.0001, t0); g.gain.exponentialRampToValueAtTime(vol, t0 + 0.005);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  o.connect(g).connect(c.destination); o.start(t0); o.stop(t0 + dur + 0.02);
}
function noise(dur, vol = 0.2) {
  const c = ctx(); if (!c) return;
  const b = c.createBuffer(1, c.sampleRate * dur, c.sampleRate), d = b.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * Math.exp(-18 * i / c.sampleRate);
  const s = c.createBufferSource(), g = c.createGain(); g.gain.value = vol; s.buffer = b; s.connect(g).connect(c.destination); s.start();
}
const N = n => 440 * Math.pow(2, (n - 69) / 12);
const SFX = {
  tap: () => tone(N(84), 0.05, 'square', 0.06),
  tick: () => tone(N(91), 0.035, 'square', 0.05),
  claim: () => [76, 83, 88].forEach((n, i) => tone(N(n), i === 2 ? 0.22 : 0.07, 'square', 0.08, i * 0.065)),
  rank: () => { tone(80, 0.35, 'sine', 0.5, 0, -0.6); noise(0.25, 0.25); [72, 76, 79, 84].forEach(n => tone(N(n), 0.9, n === 84 ? 'triangle' : 'square', 0.06, 0.05)); },
  levelup: () => { [67, 72, 76, 79, 84].forEach((n, i) => tone(N(n), 0.09, 'square', 0.08, i * 0.09)); [84, 88, 91].forEach(n => tone(N(n), 0.8, 'square', 0.06, 0.45)); },
};
function play(name) { if (!S.settings || S.settings.sound === false) return; try { SFX[name] && SFX[name](); } catch (e) { /* ignore */ } }

// ---------- toasts & overlays ----------
const toastQ = []; let toastBusy = false;
function toast(t) { toastQ.push(t); if (!toastBusy) nextToast(); }
function nextToast() {
  const el = $('#toast');
  if (!toastQ.length) { toastBusy = false; el.innerHTML = ''; return; }
  toastBusy = true; el.innerHTML = `<div>${esc(toastQ.shift())}</div>`;
  setTimeout(nextToast, 2500);
}
function showLevelUp(l) {
  play('levelup');
  const o = document.createElement('div');
  o.className = 'overlay levelup';
  o.innerHTML = `<div class="t">LEVEL UP!</div><div class="n" style="color:${rankColor(l)};text-shadow:0 0 30px ${rankColor(l)}">${l}</div>
    <div class="bold mt" style="font-size:19px">You are now a ${rankTitle(l)}</div>
    <button class="btn mt" style="width:220px;margin-top:28px">Continue</button>`;
  o.addEventListener('click', () => o.remove());
  document.body.appendChild(o);
}
Hooks.toast = toast;
Hooks.sound = play;
let resultsOpen = false, pendingLevel = null;
Hooks.levelUp = l => { if (resultsOpen) pendingLevel = l; else setTimeout(() => showLevelUp(l), 300); };

function showResults(title, subtitle, r, bonus) {
  resultsOpen = true;
  const o = document.createElement('div');
  o.className = 'overlay results';
  const c = RANK_COLOR[r.rank];
  o.innerHTML = `<div class="stripes"></div><div class="results-inner">
    <div class="banner">${esc(title)}</div><div class="banner-sub">${esc(subtitle)}</div>
    ${r.lines.map(l => `<div class="res-row"><span style="font-size:20px">${l.e}</span>
      <div class="grow"><div class="t">${esc(l.t)}</div><div class="tiny" style="color:rgba(255,255,255,.65)">${esc(l.d)}</div></div>
      <span class="pts" style="color:${l.frac >= 1 ? '#ffd633' : '#fff'}">${l.points}</span><span class="tiny muted">/${l.weight}</span></div>`).join('')}
    <div class="res-total"><div class="row"><span class="rank" style="font-size:22px">TOTAL</span><span class="grow"></span>
      <span class="score" id="rs-score">0</span><span class="muted bold">&nbsp;/ 100</span></div>
      <div class="bar thick mt-s"><i id="rs-bar" style="width:0%;background:${c};transition:width 1.2s ease"></i></div></div>
    <div class="rank-badge" style="border-color:${c};color:${c};background:${c}22;font-size:${r.rank.length > 1 ? 74 : 96}px;text-shadow:0 0 24px ${c}">${r.rank}</div>
    <div class="center bold fadein" style="font-size:18px">${RANK_MSG[r.rank]}</div>
    <div class="center bold fadein mt-s" style="color:var(--accent)">+${bonus} XP rank bonus</div>
    <div class="grow" style="min-height:20px"></div>
    <button class="btn blue fadein rank" style="font-size:20px;letter-spacing:2px">CONTINUE</button></div>`;
  document.body.appendChild(o);
  const rows = [...o.querySelectorAll('.res-row')];
  let t = 300;
  rows.forEach(row => { setTimeout(() => { row.classList.add('in'); play('tick'); }, t); t += 230; });
  setTimeout(() => {
    o.querySelector('.res-total').classList.add('in');
    o.querySelector('#rs-bar').style.width = r.score + '%';
    const el = o.querySelector('#rs-score'); let i = 0;
    const iv = setInterval(() => { i++; el.textContent = Math.round(r.score * i / 24); el.style.color = RANK_COLOR[rankFor(+el.textContent)]; if (i % 2 === 0) play('tick'); if (i >= 24) clearInterval(iv); }, 50);
  }, t + 200);
  setTimeout(() => {
    o.querySelector('.rank-badge').classList.add('in'); play('rank');
    o.querySelectorAll('.fadein').forEach(x => x.classList.add('in'));
  }, t + 1700);
  o.querySelector('button.btn').addEventListener('click', () => {
    o.remove(); resultsOpen = false; render();
    if (pendingLevel) { const l = pendingLevel; pendingLevel = null; setTimeout(() => showLevelUp(l), 250); }
  });
}

// ---------- photos (IndexedDB) ----------
const PhotoDB = {
  db: null, cache: new Map(),
  open() {
    if (this.db) return Promise.resolve(this.db);
    return new Promise((res, rej) => {
      const r = indexedDB.open('maxgeneration-photos', 1);
      r.onupgradeneeded = () => r.result.createObjectStore('photos');
      r.onsuccess = () => { this.db = r.result; res(this.db); };
      r.onerror = () => rej(r.error);
    });
  },
  async put(key, dataUrl) {
    const db = await this.open();
    await new Promise((res, rej) => { const tx = db.transaction('photos', 'readwrite'); tx.objectStore('photos').put(dataUrl, key); tx.oncomplete = res; tx.onerror = () => rej(tx.error); });
    this.cache.set(key, dataUrl);
  },
  async get(key) {
    if (this.cache.has(key)) return this.cache.get(key);
    const db = await this.open();
    const v = await new Promise(res => { const r = db.transaction('photos').objectStore('photos').get(key); r.onsuccess = () => res(r.result || null); r.onerror = () => res(null); });
    if (v) this.cache.set(key, v);
    return v;
  },
};
function resizeImage(file, max = 1400) {
  return new Promise((res, rej) => {
    const img = new Image(), url = URL.createObjectURL(file);
    img.onload = () => {
      const s = Math.min(1, max / Math.max(img.width, img.height));
      const cv = document.createElement('canvas'); cv.width = Math.round(img.width * s); cv.height = Math.round(img.height * s);
      cv.getContext('2d').drawImage(img, 0, 0, cv.width, cv.height);
      URL.revokeObjectURL(url); res(cv.toDataURL('image/jpeg', 0.82));
    };
    img.onerror = () => { URL.revokeObjectURL(url); rej(new Error('bad image')); };
    img.src = url;
  });
}
function hydratePhotos() {
  document.querySelectorAll('img[data-photo]').forEach(async img => {
    const v = await PhotoDB.get(img.dataset.photo).catch(() => null);
    if (v) img.src = v;
  });
}

// ---------- charts ----------
function lineChart(points, color, { h = 170, zero = false } = {}) {
  if (points.length < 2) return '';
  const W = 320, pad = 26, vals = points.map(p => p.value);
  let lo = Math.min(...vals), hi = Math.max(...vals);
  if (zero) lo = 0; if (hi - lo < 1) { hi += 1; lo -= 1; }
  const x = i => pad + i * (W - pad - 8) / (points.length - 1);
  const y = v => 10 + (h - 34) * (1 - (v - lo) / (hi - lo));
  const path = points.map((p, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(p.value).toFixed(1)}`).join(' ');
  return `<svg viewBox="0 0 ${W} ${h}" width="100%" height="${h}">
    <text x="0" y="${y(hi) + 4}">${fmt(hi)}</text><text x="0" y="${y(lo) + 4}">${fmt(lo)}</text>
    <path d="${path}" fill="none" stroke="${color}" stroke-width="2.5" stroke-linejoin="round"/>
    ${points.map((p, i) => `<circle cx="${x(i)}" cy="${y(p.value)}" r="3.5" fill="${color}"/>`).join('')}
    <text x="${pad}" y="${h - 4}">${shortDate(points[0].date)}</text><text x="${W - 8}" y="${h - 4}" text-anchor="end">${shortDate(points[points.length - 1].date)}</text>
  </svg>`;
}
function barChart(points, target, color, { h = 150, unit = '' } = {}) {
  const W = 320, max = Math.max(target || 0, ...points.map(p => p.value), 1), bw = (W - 20) / points.length;
  const y = v => 8 + (h - 30) * (1 - v / max);
  return `<svg viewBox="0 0 ${W} ${h}" width="100%" height="${h}">
    ${points.map((p, i) => `<rect x="${10 + i * bw + 5}" y="${y(p.value)}" width="${bw - 10}" height="${Math.max(0, h - 22 - y(p.value))}" rx="5" fill="${p.value >= target ? color : color + '88'}"/>
      <text x="${10 + i * bw + bw / 2}" y="${h - 6}" text-anchor="middle">${weekdayLetter(p.date)}</text>`).join('')}
    ${target ? `<line x1="10" x2="${W - 10}" y1="${y(target)}" y2="${y(target)}" stroke="rgba(255,255,255,.4)" stroke-dasharray="4 4"/>
      <text x="${W - 10}" y="${y(target) - 4}" text-anchor="end">${fmt(target)}${unit}</text>` : ''}
  </svg>`;
}

// ---------- commit ----------
function commit() { saveState(); render(); }

// =====================================================================
// SCREENS
// =====================================================================
function render() {
  const app = $('#app');
  if (!S.profile) { app.innerHTML = renderOnboarding(); $('#nav').innerHTML = ''; $('#nav').style.display = 'none'; return; }
  $('#nav').style.display = '';
  let html;
  if (UI.page) html = renderPage(UI.page);
  else html = ({ home: renderHome, train: renderTrain, study: renderStudy, food: renderFood, goals: renderGoals }[UI.tab] || renderHome)();
  app.innerHTML = html;
  renderNav();
  renderModal();
  hydratePhotos();
}

function renderNav() {
  const tabs = [['home', '⚡', 'Hero'], has('gym') && ['train', '🥊', 'Train'], has('study') && ['study', '📚', 'Study'], has('food') && ['food', '🍽️', 'Food'], ['goals', '🎯', 'Goals']].filter(Boolean);
  $('#nav').innerHTML = tabs.map(([id, ic, t]) => `<button data-a="tab" data-v="${id}" class="${UI.tab === id && !UI.page ? 'on' : ''}"><span class="ic">${ic}</span>${t}</button>`).join('');
}

const topbar = (title, right = '') => `<div class="topbar"><h1>${title}</h1>${right}</div>`;
const backbar = (title, to = null) => `<div class="topbar"><button class="back" data-a="back" data-v="${to || ''}">‹ Back</button></div><h1 style="margin:0 0 14px;font-size:28px">${title}</h1>`;

// ---------- HOME ----------
function renderHome() {
  const p = P(), li = levelInfo(totalXP()), rc = rankColor(li.level);
  const live = dayScore(), log = dayLog();
  const quests = todaysQuests(), claimed = quests.filter(q => questClaimed(q.id)).length;
  const wl = weekLog(), wlive = weekScore(), gdone = wl.goals.filter(g => g.done).length;

  const hero = `<div class="card"><div class="row" style="gap:14px">
      <div class="hero-avatar" style="border-color:${rc};background:${rc}2e;box-shadow:0 0 18px ${rc}66">${esc(p.avatar)}</div>
      <div class="grow"><div class="bold" style="font-size:22px">${esc(p.name)}</div>
        <div class="bold small" style="color:${rc}">Level ${li.level} · ${rankTitle(li.level)}</div>
        <div class="row small mt-s"><span style="color:#ff9e26;font-weight:700">🔥 ${streak()} day streak</span><span class="muted">✨ ${totalXP()} XP</span></div></div></div>
      <div class="mt">${bar(li.frac, rc, 'thick')}</div>
      <div class="row between tiny muted mt-s"><span>${li.into} / ${li.needed} XP to level ${li.level + 1}</span><span>+${xpToday()} today</span></div></div>`;

  const supps = p.supplements || [];
  const daily = `<div class="card"><h3>Today's run <span class="right">Live rank <span class="rank" style="font-size:22px;color:${RANK_COLOR[live.rank]}">${live.rank}</span> ${live.score}</span></h3>
      <button class="list-item" data-a="modal" data-v="sleep" style="padding-top:0">
        <span style="font-size:26px">😴</span>
        <div class="grow">${log.sleep ? `<div class="bold">Slept ${hoursText(log.sleep)}</div><div class="mt-s">${bar(log.sleep / sleepTarget(), 'var(--vit)', 'thin')}</div>`
          : `<div class="bold">Log last night's sleep</div><div class="tiny muted">Goal ${fmt(p.sleep)}h · +15 XP, +15 more if you hit it</div>`}</div>
        <span style="color:var(--accent);font-size:22px">${log.sleep ? '✎' : '＋'}</span></button>
      ${supps.length ? `<div class="tiny muted bold mt mb" style="margin-bottom:8px">SUPPLEMENTS · ${suppCount()} / ${supps.length}</div>
      <div class="chips">${supps.map(s => { const on = suppTaken(s); return `<button class="chip ${on ? 'on' : ''}" data-a="supp" data-v="${s.id}">${s.emoji}<span><b>${esc(s.name)}</b><span class="sub">${SUPP_TIMES[s.time].e} ${SUPP_TIMES[s.time].t}</span></span><span style="color:${on ? 'var(--vit)' : 'var(--muted)'}">${on ? '✔' : '○'}</span></button>`; }).join('')}</div>` : ''}
      <button class="btn blue mt" data-a="finishDay">🏁 ${log.rank ? `Update today's rank (${log.rank})` : 'Finish day & get my rank'}</button>
      <div class="grid7 mt" style="display:grid;grid-template-columns:repeat(7,1fr);gap:6px">${rankHistory(7).map(d => `<div class="center"><div class="rank" style="font-size:15px;padding:6px 0;border-radius:8px;background:rgba(255,255,255,.06);color:${d.value ? RANK_COLOR[d.value] : 'var(--muted)'}">${d.value || '–'}</div><div class="tiny muted mt-s">${weekdayLetter(d.date)}</div></div>`).join('')}</div></div>`;

  const qcard = `<div class="card"><h3>Daily Quests <span class="right">${claimed}/${quests.length} · new at midnight</span></h3>
      ${quests.map(q => { const c = questClaimed(q.id), col = ATTR[q.attr].c; return `<div class="row" style="padding:8px 0">
        <span style="font-size:24px">${q.e}</span><div class="grow"><div class="bold small" style="${c ? 'text-decoration:line-through;color:var(--muted)' : ''}">${esc(q.title)}</div>
        <div class="mt-s">${bar(q.cur / q.target, col, 'thin')}</div><div class="tiny muted mt-s">${fmt(Math.min(q.cur, q.target))} / ${fmt(q.target)} ${q.unit}</div></div>
        ${c ? '<span style="font-size:24px">✅</span>' : `<button class="pill ${q.done ? 'on' : ''}" style="${q.done ? `background:${col}` : ''}" data-a="claim" data-v="${q.id}" ${q.done ? '' : 'disabled'}>${q.done ? 'Claim ' : ''}+${q.xp}</button>`}</div>`; }).join('')}
      <div class="tiny muted mt-s">Claim them all for a ✨ Perfect Day bonus.</div></div>`;

  const week = `<button class="card" style="width:100%;text-align:left;display:block" data-a="page" data-v="week">
      <h3>This week <span class="right">Week rank <span class="rank" style="font-size:22px;color:${RANK_COLOR[wlive.rank]}">${wlive.rank}</span> ›</span></h3>
      ${lastWeekNeedsCheckIn() ? '<div class="small bold" style="color:#ff9e26;margin-bottom:8px">📏 Last week\'s check-in is waiting. Log your stats to get its rank.</div>' : ''}
      ${wl.goals.length ? `${bar(gdone / wl.goals.length, 'var(--dis)')}<div class="tiny muted mt-s">${gdone} / ${wl.goals.length} goals done</div>` : '<div class="small muted">🎯 Set this week\'s goals so you know where you\'re heading.</div>'}</button>`;

  const tiles = [];
  const t = new Date();
  if (has('gym')) tiles.push(tile('🥊', 'Sessions this week', `${sessionsInWeek()} / ${p.perWeek}`, sessionsInWeek() / p.perWeek, ATTR.strength.c));
  if (has('study')) tiles.push(tile('📚', 'Study', `${studyMinutes(t)} / ${p.study} min`, studyMinutes(t) / p.study, ATTR.intellect.c));
  if (has('food')) {
    tiles.push(tile('🔥', 'Calories', `${kcalOn(t)} / ${p.kcal}`, kcalOn(t) / p.kcal, '#ff9e26'));
    tiles.push(tile('🥩', 'Protein', `${proteinOn(t)} / ${p.protein} g`, proteinOn(t) / p.protein, ATTR.vitality.c));
    tiles.push(tile('💧', 'Water', `${waterOn(t)} / ${p.water} cups`, waterOn(t) / p.water, '#33ccff'));
  }
  if (has('life') && S.habits.length) { const d = S.habits.filter(h => habitDone(h)).length; tiles.push(tile('✅', 'Habits', `${d} / ${S.habits.length}`, d / S.habits.length, ATTR.discipline.c)); }
  const today = tiles.length ? `<div class="card"><h3>Today</h3><div class="grid2">${tiles.join('')}</div></div>` : '';

  const stats = `<div class="card"><h3>Stats</h3><div class="grid2">${Object.entries(ATTR).map(([k, a]) => { const i = attrInfo(xpOf(k)); return `<div class="stat-tile" style="background:${a.c}14">
      <div class="row between"><span>${a.e} <b class="tiny" style="color:${a.c}">${a.s}</b></span><b class="small">Lv ${i.level}</b></div>
      <div class="mt-s">${bar(i.frac, a.c, 'thin')}</div><div class="tiny muted mt-s">${a.b}</div></div>`; }).join('')}</div></div>`;

  const recent = S.xp.slice(-6).reverse();
  const feed = `<div class="card"><h3>Recent XP</h3>${recent.length ? recent.map(e => `<div class="row small" style="padding:5px 0">
      <i style="width:8px;height:8px;border-radius:50%;background:${ATTR[e.attr].c};flex:none"></i><span class="grow ellipsis">${esc(e.reason)}</span>
      <b style="color:${ATTR[e.attr].c}">+${e.amount}</b></div>`).join('') : '<div class="empty">Log anything to start earning XP.</div>'}</div>`;

  return topbar('Hero', `<button class="iconbtn" data-a="page" data-v="badges">🏆</button><button class="iconbtn" data-a="page" data-v="settings">⚙️</button>`)
    + hero + daily + qcard + week + today + stats + feed;
}
function tile(e, title, value, frac, color) {
  return `<div class="stat-tile"><div class="tiny muted">${e} ${title}</div><div class="v">${value}</div>${bar(frac, color, 'thin')}</div>`;
}

// ---------- TRAIN ----------
function renderTrain() {
  const p = P(), done = sessionsInWeek(), i = attrInfo(xpOf('strength'));
  return topbar('Train') + `<div class="card"><div class="row" style="gap:16px">
      ${ring(done / p.perWeek, ATTR.strength.c, `${done}/${p.perWeek}`, 'week')}
      <div class="grow"><div class="bold">💪 Strength Lv ${i.level}</div><div class="mt-s">${bar(i.frac, ATTR.strength.c)}</div>
      <div class="tiny muted mt-s">Gym gives 20–80 XP, boxing 15 XP + 1 XP per 2 min, and every PR +25.</div></div></div></div>
    <div class="card"><h3>Start training</h3>
      <button class="btn" data-a="newWorkout">🏋️ New gym workout</button>
      <button class="btn ghost mt" data-a="modal" data-v="boxing">🥊 Log boxing session</button>
      ${workoutTemplates().map(w => `<button class="list-item" data-a="repeatWorkout" data-v="${w.id}"><span>🔁</span><span class="grow">Repeat <b>${esc(w.title)}</b></span><span class="muted tiny">${shortDate(w.date)}</span></button>`).join('')}</div>
    <div class="card"><h3>Progress</h3>
      <button class="list-item" data-a="page" data-v="exercises"><span>📈</span><span class="grow">Exercises & PRs</span><span class="muted">›</span></button>
      <button class="list-item" data-a="page" data-v="bodyweight"><span>⚖️</span><span class="grow">Bodyweight</span><span class="muted">›</span></button></div>
    ${S.boxing.length ? `<div class="card"><h3>🥊 Boxing</h3>${S.boxing.slice(0, 20).map(b => `<div class="list-item"><div class="grow"><div class="bold">Boxing · ${b.minutes} min</div>${b.note ? `<div class="tiny muted">${esc(b.note)}</div>` : ''}</div><span class="tiny muted">${shortDate(b.date)}</span><button class="swipe-del" data-a="delBoxing" data-v="${b.id}">Delete</button></div>`).join('')}</div>` : ''}
    <div class="card"><h3>Gym history</h3>${S.workouts.length ? S.workouts.slice(0, 40).map(w => `<button class="list-item" data-a="editWorkout" data-v="${w.id}">
      <div class="grow"><div class="row between"><b>${esc(w.title)}</b><span class="tiny muted">${shortDate(w.date)}</span></div>
      <div class="tiny muted ellipsis">${esc(w.exercises.map(e => e.name).join(' · '))}</div>
      <div class="tiny" style="color:var(--str)">${setCount(w)} sets · ${fmt(volume(w))} kg volume</div></div></button>`).join('') : '<div class="empty">No workouts yet. Your first one unlocks an achievement!</div>'}</div>`;
}
function ring(frac, color, big, small) {
  const r = 32, c = 2 * Math.PI * r, off = c * (1 - clamp01(frac));
  return `<div style="position:relative;width:78px;height:78px;flex:none"><svg width="78" height="78" viewBox="0 0 78 78">
    <circle cx="39" cy="39" r="${r}" stroke="rgba(255,255,255,.1)" stroke-width="9" fill="none"/>
    <circle cx="39" cy="39" r="${r}" stroke="${color}" stroke-width="9" fill="none" stroke-linecap="round" stroke-dasharray="${c}" stroke-dashoffset="${off}" transform="rotate(-90 39 39)"/></svg>
    <div style="position:absolute;inset:0;display:grid;place-items:center;text-align:center;line-height:1.1"><div><b>${big}</b><div class="tiny muted">${small}</div></div></div></div>`;
}

// ---------- STUDY ----------
function renderStudy() {
  const p = P(), m = studyMinutes(new Date()), i = attrInfo(xpOf('intellect')), ts = S.settings.timerStart;
  return topbar('Study') + `<div class="card"><div class="row" style="gap:16px">${ring(m / p.study, ATTR.intellect.c, m, `/ ${p.study}m`)}
      <div class="grow"><div class="bold">🧠 Intellect Lv ${i.level}</div><div class="mt-s">${bar(i.frac, ATTR.intellect.c)}</div>
      <div class="tiny muted mt-s">Total ${hoursText(totalStudy())} · 1 XP per 2 minutes</div></div></div></div>
    <div class="card"><h3>Focus timer</h3>
      ${ts ? `<div class="center" id="timer" style="font:800 48px ui-monospace,Menlo,monospace;color:var(--int);padding:8px 0">00:00</div>
        <button class="btn" data-a="stopTimer">✔ Finish & log session</button><button class="btn ghost mt" data-a="cancelTimer">Cancel timer</button>`
        : `<button class="btn" data-a="startTimer">⏱️ Start focus session</button><div class="tiny muted mt-s">Keeps counting even if you close the app.</div>`}
      <button class="btn ghost mt" data-a="modal" data-v="study">✎ Log a session manually</button></div>
    <div class="card"><h3>Last 7 days</h3>${barChart(lastDays(7, studyMinutes), p.study, ATTR.intellect.c, { unit: 'm' })}</div>
    ${S.study.length ? `<div class="card"><h3>By subject</h3>${bySubject().map(([s, mm]) => `<div class="row between small" style="padding:6px 0"><span>${esc(s)}</span><b style="color:var(--int)">${hoursText(mm)}</b></div>`).join('')}</div>` : ''}
    <div class="card"><h3>Sessions</h3>${S.study.length ? S.study.slice(0, 40).map(s => `<div class="list-item"><div class="grow"><div class="row between"><b>${esc(s.subject || 'General')}</b><b style="color:var(--int)">${s.minutes} min</b></div>
      <div class="tiny muted">${new Date(s.date).toLocaleString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}${s.note ? ' · ' + esc(s.note) : ''}</div></div>
      <button class="swipe-del" data-a="delStudy" data-v="${s.id}">Delete</button></div>`).join('') : '<div class="empty">No sessions yet. Start the focus timer!</div>'}</div>`;
}
function tickTimer() {
  const el = $('#timer'), ts = S.settings.timerStart; if (!el || !ts) return;
  const s = Math.max(0, Math.floor((Date.now() - ts) / 1000)), h = Math.floor(s / 3600);
  el.textContent = (h ? h + ':' : '') + pad(Math.floor(s % 3600 / 60)) + ':' + pad(s % 60);
}
setInterval(tickTimer, 1000);

// ---------- FOOD ----------
function renderFood() {
  const p = P(), d = UI.foodDay, today = isToday(d);
  const kc = kcalOn(d), pr = proteinOn(d), cups = waterOn(d);
  return topbar('Food', `<button class="iconbtn" data-a="modal" data-v="food" style="background:var(--accent)">＋</button>`) + `
    <div class="card"><div class="row between"><button class="iconbtn" data-a="foodDay" data-v="-1">‹</button>
      <b>${today ? 'Today' : d.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'short' })}</b>
      <button class="iconbtn" data-a="foodDay" data-v="1" ${today ? 'disabled style="opacity:.3"' : ''}>›</button></div>
      <div class="mt"><div class="row between small"><b>🔥 Calories</b><span style="color:${kc > p.kcal ? '#ff6b6b' : 'var(--muted)'}">${kc} / ${p.kcal} kcal</span></div><div class="mt-s">${bar(kc / p.kcal, '#ff9e26')}</div></div>
      <div class="mt"><div class="row between small"><b>🥩 Protein</b><span class="muted">${pr} / ${p.protein} g</span></div><div class="mt-s">${bar(pr / p.protein, 'var(--vit)')}</div></div></div>
    <div class="card"><div class="row"><b class="grow">💧 ${cups} / ${p.water} cups</b>
      <button class="iconbtn" data-a="water" data-v="-1">－</button><button class="iconbtn" data-a="water" data-v="1" style="background:#1f7fd1">＋</button></div>
      <div class="row mt" style="gap:3px;flex-wrap:wrap;font-size:18px">${Array.from({ length: Math.max(p.water, cups) }, (_, i) => `<span style="${i < cups ? '' : 'filter:grayscale(1);opacity:.35'}">💧</span>`).join('')}</div></div>
    <details class="card"><summary>🎚️ Adjust my targets</summary><div class="mt">
      ${stepper('🔥 Calories', p.kcal, 'kcal', 'kcal', 50)}${stepper('🥩 Protein', p.protein, 'g', 'protein', 5)}${stepper('💧 Water', p.water, 'cups', 'water', 1)}</div></details>
    ${Object.entries(MEALS).map(([k, m]) => { const items = foodsOn(d).filter(f => f.meal === k); return `<div class="card"><h3>${m.e} ${m.t}<span class="right">${sum(items, f => f.kcal)} kcal</span></h3>
      ${items.length ? items.map(f => `<div class="list-item"><div class="grow"><div>${esc(f.name)}</div><div class="tiny muted">${f.protein} g protein</div></div><span style="color:#ff9e26">${f.kcal} kcal</span><button class="swipe-del" data-a="delFood" data-v="${f.id}">✕</button></div>`).join('') : '<div class="empty">Nothing logged</div>'}</div>`; }).join('')}`;
}
function stepper(label, value, unit, field, step) {
  return `<div class="stepper"><span>${label}: <b>${value}</b> ${unit}</span><span class="ctl"><button data-a="step" data-f="${field}" data-v="${-step}">−</button><button data-a="step" data-f="${field}" data-v="${step}">+</button></span></div>`;
}
const STEP_LIMITS = { kcal: [1200, 5000], protein: [30, 350], water: [1, 20], study: [15, 600], perWeek: [1, 7], sleep: [5, 11], age: [10, 99] };

// ---------- GOALS ----------
function renderGoals() {
  const days = lastDays(7, d => d);
  return topbar('Goals') + `<div class="card"><h3>Daily habits <span class="right">+10 XP each</span></h3>
      ${S.habits.length ? S.habits.map(h => { const on = habitDone(h), st = currentStreak(new Set(h.done || [])), c = ATTR[h.attr].c; return `<div class="list-item">
        <button class="check ${on ? 'on' : ''}" style="${on ? `background:${c}` : ''}" data-a="habit" data-v="${h.id}">${on ? '✓' : ''}</button>
        <button class="grow" style="text-align:left" data-a="habit" data-v="${h.id}"><div>${h.emoji} ${esc(h.name)}</div><div class="dots">${days.map(dd => `<i style="${(h.done || []).includes(dayKey(dd.date)) ? `background:${c}` : ''}"></i>`).join('')}</div></button>
        ${st ? `<b style="color:#ff9e26">🔥 ${st}</b>` : ''}<button class="swipe-del" data-a="delHabit" data-v="${h.id}">✕</button></div>`; }).join('') : '<div class="empty">No habits yet.</div>'}
      <button class="btn ghost mt" data-a="modal" data-v="habit">＋ Add habit</button></div>
    <div class="card"><h3>Boss battles <span class="right">big goals</span></h3>
      ${activeBosses().length ? activeBosses().map(b => `<div style="padding:10px 0;border-bottom:1px solid var(--line)"><div class="row">
        <span style="font-size:40px">${b.emoji}</span><div class="grow"><b>${esc(b.name)}</b><div class="tiny" style="color:${ATTR[b.attr].c}">${ATTR[b.attr].e} ${ATTR[b.attr].t} boss</div>
        ${b.deadline ? `<div class="tiny ${b.deadline < Date.now() ? '' : 'muted'}" style="${b.deadline < Date.now() ? 'color:#ff6b6b' : ''}">${deadlineText(b.deadline)}</div>` : ''}</div>
        <button class="btn red sm" data-a="modal" data-v="attack" data-id="${b.id}">Attack</button></div>
        <div class="mt-s">${bar(1 - bossProgress(b), '#ff4d4d', 'thick')}</div>
        <div class="row between tiny muted mt-s"><span>HP ${fmt(bossHP(b))} / ${fmt(b.target)} ${esc(b.unit)}</span><span>${Math.round(bossProgress(b) * 100)}% defeated <button class="swipe-del" data-a="delBoss" data-v="${b.id}">✕</button></span></div></div>`).join('')
        : '<div class="small muted">Turn a big goal into a boss: "Read 12 books", "Lose 5 kg", "Save €1000". Every bit of progress deals damage.</div>'}
      <button class="btn ghost mt" data-a="modal" data-v="boss">🔥 Summon a boss</button></div>
    ${defeatedBosses().length ? `<div class="card"><h3>Hall of fame</h3>${defeatedBosses().map(b => `<div class="list-item"><span style="font-size:26px;filter:grayscale(1)">${b.emoji}</span><div class="grow"><s>${esc(b.name)}</s><div class="tiny muted">Defeated ${shortDate(b.defeatedAt)}</div></div>🏆</div>`).join('')}</div>` : ''}
    <button class="card" style="width:100%;text-align:left" data-a="page" data-v="week"><b>📅 Week goals & check-in ›</b></button>`;
}
function deadlineText(d) {
  const days = Math.round((startOfDay(d) - startOfDay(new Date())) / 86400000);
  if (days < 0) return `Overdue by ${-days} days`; if (days === 0) return 'Deadline: today!'; return `${days} days left`;
}

// ---------- SUB PAGES ----------
function renderPage(page) {
  if (page === 'badges') return renderBadges();
  if (page === 'settings') return renderSettings();
  if (page === 'week') return renderWeek();
  if (page === 'exercises') return renderExercises();
  if (page === 'bodyweight') return renderBodyweight();
  if (page.startsWith('exercise:')) return renderExercise(page.slice(9));
  return renderHome();
}
function renderBadges() {
  const un = ACHIEVEMENTS.filter(a => S.seen.includes(a.id) || a.check()).length;
  return backbar('Achievements') + `<div class="muted bold mb">${un} of ${ACHIEVEMENTS.length} unlocked</div><div class="badge-grid">
    ${ACHIEVEMENTS.map(a => { const on = S.seen.includes(a.id) || a.check(); return `<div class="badge ${on ? 'on' : 'off'}"><div class="e">${on ? a.e : '🔒'}</div><div class="bold small mt-s">${a.t}</div><div class="tiny muted mt-s">${a.d}</div></div>`; }).join('')}</div>`;
}
function renderExercises() {
  const names = exerciseNames();
  return backbar('Exercises', 'train') + `<div class="card">${names.length ? names.map(n => `<button class="list-item" data-a="page" data-v="exercise:${esc(n)}"><span class="grow">${esc(n)}</span><span class="tiny" style="color:var(--str)">e1RM ${fmt(bestE1RM(n))} kg</span><span class="muted">›</span></button>`).join('') : '<div class="empty">Log a workout to see your exercises here.</div>'}</div>`;
}
function renderExercise(name) {
  const pts = exerciseProgress(name), hist = exerciseHistory(name);
  return backbar(esc(name), 'exercises') + `<div class="card"><h3>Estimated 1-rep max (kg)</h3>
    ${pts.length >= 2 ? lineChart(pts, ATTR.strength.c) : '<div class="empty">Log this exercise in 2+ workouts to see your trend.</div>'}
    <div class="tiny muted mt-s">Best: ${fmt(bestE1RM(name))} kg. Beat it to earn a PR.</div></div>
    <div class="card"><h3>History</h3>${hist.map(h => `<div class="list-item"><div><b class="small">${shortDate(h.date)}</b><div class="tiny muted" style="font-family:ui-monospace,Menlo,monospace">${h.sets.map(s => `${fmt(s.weight)}×${s.reps}`).join('  ')}</div></div></div>`).join('')}</div>`;
}
function renderBodyweight() {
  const pts = S.bodyweight.map(b => ({ date: b.date, value: b.kg })).sort((a, b) => a.date - b.date);
  return backbar('Bodyweight', 'train') + `<div class="card"><h3>Log weigh-in</h3><div class="row"><input id="bw-in" inputmode="decimal" placeholder="kg"><button class="btn sm" data-a="addBw">Add +5 XP</button></div></div>
    ${pts.length >= 2 ? `<div class="card"><h3>Trend</h3>${lineChart(pts, ATTR.vitality.c)}</div>` : ''}
    <div class="card"><h3>History</h3>${S.bodyweight.length ? S.bodyweight.map(b => `<div class="list-item"><span class="grow">${shortDate(b.date)}</span><b>${fmt(b.kg)} kg</b><button class="swipe-del" data-a="delBw" data-v="${b.id}">✕</button></div>`).join('') : '<div class="empty">No weigh-ins yet.</div>'}</div>`;
}
function renderWeek() {
  const log = weekLog(), live = weekScore(), hist = weekHistory(), photos = hist.filter(w => w.log.photo).sort((a, b) => a.start - b.start);
  const bfPts = hist.filter(w => w.log.bf != null).map(w => ({ date: w.start.getTime(), value: w.log.bf })).sort((a, b) => a.date - b.date);
  return backbar('Week') + `<div class="card"><div class="row"><div class="grow"><b>${weekTitle(weekBounds().start)}</b><div class="tiny muted">Score so far: ${live.score} / 100</div></div>
      <span class="rank" style="font-size:44px;color:${RANK_COLOR[live.rank]}">${live.rank}</span></div>
      ${live.lines.map(l => `<div class="row between small" style="padding:5px 0"><span>${l.e} ${l.t}</span><span class="muted tiny">${esc(l.d)}</span></div>`).join('')}
      <div class="tiny muted mt-s">Week rank = 50% your daily ranks + 25% week goals + 15% training sessions + 10% body check-in.</div></div>
    ${lastWeekNeedsCheckIn() ? `<button class="btn" style="background:#c46a00" data-a="modal" data-v="checkin" data-id="last">📏 Do last week's check-in</button><div style="height:14px"></div>` : ''}
    <div class="card"><h3>🎯 This week's goals <span class="right">+25 XP each</span></h3>
      ${log.goals.map(g => `<div class="list-item"><button class="check ${g.done ? 'on' : ''}" style="${g.done ? 'background:var(--dis)' : ''}" data-a="weekGoal" data-v="${g.id}">${g.done ? '✓' : ''}</button>
        <button class="grow" style="text-align:left;${g.done ? 'text-decoration:line-through;color:var(--muted)' : ''}" data-a="weekGoal" data-v="${g.id}">${esc(g.text)}</button><button class="swipe-del" data-a="delWeekGoal" data-v="${g.id}">✕</button></div>`).join('')}
      <div class="row mt"><input id="goal-in" placeholder="e.g. Train 4x, sleep 7h+ every night"><button class="btn sm" data-a="addWeekGoal">Add</button></div>
      <div class="tiny muted mt-s">Set these on Monday.</div></div>
    <button class="btn blue" data-a="modal" data-v="checkin">🏁 ${log.rank ? `Redo this week's check-in (${log.rank})` : 'End-of-week check-in'}</button>
    <div class="tiny muted mt-s mb center">On Sunday, log your weight, body fat %, a progress photo and how the week felt to get your week rank (double rank XP).</div>
    ${photos.length ? `<div class="card"><h3>📸 Progress photos</h3><div class="photo-strip">${photos.map(w => `<button class="ph" data-a="viewer" data-v="${w.key}"><img data-photo="${w.key}" alt=""><div class="tiny bold mt-s">${shortDate(w.start)}</div>${w.log.rank ? `<div class="rank small" style="color:${RANK_COLOR[w.log.rank]}">${w.log.rank}</div>` : ''}</button>`).join('')}</div><div class="tiny muted mt-s">Tap a photo to swipe through your progress.</div></div>` : ''}
    ${bfPts.length >= 2 ? `<div class="card"><h3>Body fat %</h3>${lineChart(bfPts, ATTR.vitality.c)}</div>` : ''}
    ${hist.length ? `<div class="card"><h3>Past weeks</h3>${hist.map(w => `<div class="list-item"><span class="rank" style="font-size:26px;width:44px;color:${w.log.rank ? RANK_COLOR[w.log.rank] : 'var(--muted)'}">${w.log.rank || '–'}</span>
      <div class="grow"><b class="small">${weekTitle(w.start)}</b><div class="tiny muted">${[w.log.weight != null && fmt(w.log.weight) + ' kg', w.log.bf != null && fmt(w.log.bf) + '% BF', w.log.feeling && FEELINGS[w.log.feeling][0]].filter(Boolean).join(' · ') || 'No body stats'}</div>
      ${w.log.note ? `<div class="tiny muted">${esc(w.log.note)}</div>` : ''}</div></div>`).join('')}</div>` : ''}`;
}
function renderSettings() {
  const p = P(), supps = p.supplements || [];
  return backbar('Settings') + `<div class="card"><h3>Hero</h3>
      <div class="field"><label>Name</label><input data-set="name" value="${esc(p.name)}"></div>
      <div class="pick-grid">${AVATARS.map(a => `<button class="${a === p.avatar ? 'on' : ''}" data-a="avatar" data-v="${a}">${a}</button>`).join('')}</div></div>
    <div class="card"><h3>My details</h3>
      ${stepper('🎂 Age', p.age || 20, '', 'age', 1)}
      ${detailRow('📏 Height', 'height', p.height, 'cm')}${detailRow('⚖️ Starting weight', 'startWeight', p.startWeight, 'kg')}${detailRow('📉 Starting body fat', 'startBF', p.startBF, '%')}
      <div class="field mt"><label>Main goal</label><select data-set="goal">${Object.entries(GOALS).map(([k, t]) => `<option value="${k}" ${p.goal === k ? 'selected' : ''}>${t}</option>`).join('')}</select></div></div>
    <div class="card"><h3>Supplements</h3>
      ${supps.map(s => `<div class="list-item"><span>${s.emoji}</span><span class="grow">${esc(s.name)}</span><span class="tiny muted">${SUPP_TIMES[s.time].e} ${SUPP_TIMES[s.time].t}</span><button class="swipe-del" data-a="delSupp" data-v="${s.id}">✕</button></div>`).join('')}
      <div class="row mt"><input id="supp-emoji" value="💊" style="width:56px;flex:none;text-align:center"><input id="supp-name" placeholder="Add (e.g. Vitamin D)"></div>
      <div class="row mt-s"><select id="supp-time">${Object.entries(SUPP_TIMES).map(([k, t]) => `<option value="${k}">${t.e} ${t.t}</option>`).join('')}</select><button class="btn sm" data-a="addSupp">Add</button></div></div>
    <div class="card"><h3>Areas</h3>${Object.entries(AREAS).map(([k, a]) => `<button class="list-item" data-a="area" data-v="${k}"><span>${a.e}</span><span class="grow">${a.t}</span><span class="check ${has(k) ? 'on' : ''}" style="${has(k) ? 'background:var(--accent)' : ''}">${has(k) ? '✓' : ''}</span></button>`).join('')}
      <div class="tiny muted mt-s">Turning an area off hides its tab and quests. Your data stays.</div></div>
    <div class="card"><h3>Targets</h3>${stepper('😴 Sleep', fmt(p.sleep), 'h', 'sleep', 0.5)}${stepper('🥊 Training', p.perWeek, '/ week', 'perWeek', 1)}${stepper('📚 Study', p.study, 'min', 'study', 15)}
      ${stepper('🔥 Calories', p.kcal, 'kcal', 'kcal', 50)}${stepper('🥩 Protein', p.protein, 'g', 'protein', 5)}${stepper('💧 Water', p.water, 'cups', 'water', 1)}</div>
    <div class="card"><h3>Sound</h3><button class="list-item" data-a="sound"><span>🔊</span><span class="grow">Sound effects</span><span class="check ${S.settings.sound !== false ? 'on' : ''}" style="${S.settings.sound !== false ? 'background:var(--accent)' : ''}">${S.settings.sound !== false ? '✓' : ''}</span></button></div>
    <div class="card"><h3>Your data</h3>
      <button class="btn ghost" data-a="export">⬇️ Export backup</button>
      <label class="btn ghost mt" style="display:block">⬆️ Import backup<input type="file" accept="application/json,.json" id="import-file" hidden></label>
      <div class="tiny muted mt-s">Everything is stored only on this phone. Export a backup now and then and save it to Files or iCloud Drive. Photos stay on the phone and aren't in the backup.</div></div>
    <div class="card"><h3>Stats</h3>${[['Total XP', totalXP()], ['Level', level()], ['Best streak', best() + ' days'], ['Workouts', S.workouts.length], ['Boxing sessions', S.boxing.length], ['Study time', hoursText(totalStudy())], ['Meals logged', S.foods.length]].map(([k, v]) => `<div class="row between small" style="padding:5px 0"><span class="muted">${k}</span><b>${v}</b></div>`).join('')}</div>
    <button class="btn red" data-a="reset">Reset everything</button><div style="height:20px"></div>`;
}
function detailRow(label, field, value, unit) {
  return `<div class="stepper"><span>${label}</span><span class="inline-field" style="width:130px"><input data-set="${field}" inputmode="decimal" value="${value != null ? fmt(value) : ''}" placeholder="–"><span class="unit">${unit}</span></span></div>`;
}

// =====================================================================
// MODALS
// =====================================================================
function openModal(type, data = {}) {
  UI.modal = { type, ...data };
  if (type === 'checkin') {
    UI.checkinWeek = data.id === 'last' ? lastWeekDate() : new Date();
    UI.checkinPhoto = null;
    UI.feeling = weekLog(UI.checkinWeek).feeling || 4;
  }
  renderModal();
}
function closeModal() { UI.modal = null; UI.draft = null; $('#modal').innerHTML = ''; }
const sheet = (title, body, saveLabel = 'Save', saveAction = 'save') => `<div class="sheet-wrap" data-a="closeBg"><div class="sheet">
  <div class="sheet-head"><button data-a="close">Cancel</button><h2>${title}</h2>${saveLabel ? `<button class="save" data-a="${saveAction}">${saveLabel}</button>` : '<span style="width:50px"></span>'}</div>${body}</div></div>`;

function renderModal() {
  const m = UI.modal, el = $('#modal');
  if (!m) { el.innerHTML = ''; return; }
  const p = P();
  let html = '';
  if (m.type === 'sleep') {
    const l = dayLog();
    html = sheet('😴 Sleep', `<div class="grid2"><div class="field"><label>🌙 Went to bed</label><input type="time" id="sl-bed" value="${l.bed || '23:30'}" data-live="sleep"></div>
      <div class="field"><label>☀️ Woke up</label><input type="time" id="sl-wake" value="${l.wake || '07:30'}" data-live="sleep"></div></div>
      <div class="field"><label>Morning of</label><input type="date" id="sl-day" value="${dayKey()}" max="${dayKey()}"></div>
      <div class="card" id="sl-sum"></div>
      <div class="tiny muted mb">Copy the times from Samsung Health. Samsung doesn't let other apps read its data.</div>
      <div class="card"><h3>Last 7 nights</h3>${barChart(lastDays(7, d => (dayLog(d).sleep || 0) / 60), p.sleep || 8, ATTR.vitality.c, { unit: 'h' })}</div>`, 'Save', 'saveSleep');
  } else if (m.type === 'workout') {
    const d = UI.draft;
    const sugg = [...exerciseNames(), ...COMMON_EXERCISES.filter(c => !exerciseNames().some(n => n.toLowerCase() === c.toLowerCase()))];
    html = sheet(d.existing ? 'Edit workout' : 'Workout', `<div class="field"><input data-d="title" value="${esc(d.title)}" placeholder="Name (e.g. Push Day, Legs)"></div>
      <div class="field"><input type="datetime-local" data-d="date" value="${toLocalInput(d.date)}"></div>
      ${d.exercises.map((ex, i) => `<div class="ex-block"><div class="row"><input data-d="name" data-i="${i}" value="${esc(ex.name)}" placeholder="Exercise" style="font-weight:700"><button class="swipe-del" data-a="exDel" data-v="${i}">Remove</button></div>
        <div class="mt">${ex.sets.map((s, j) => `<div class="set-row"><span class="tiny muted">Set ${j + 1}</span>
          <input data-d="w" data-i="${i}" data-j="${j}" value="${esc(s.w)}" inputmode="decimal" placeholder="0"><span class="tiny muted">kg ×</span>
          <input data-d="r" data-i="${i}" data-j="${j}" value="${esc(s.r)}" inputmode="numeric" placeholder="0"><span class="tiny muted">reps</span>
          <button class="swipe-del" data-a="setDel" data-v="${i}" data-j="${j}">✕</button></div>`).join('')}</div>
        <button class="pill" data-a="setAdd" data-v="${i}">＋ Add set</button></div>`).join('')}
      <div class="field"><label>Add exercise</label><select id="ex-pick"><option value="">Choose…</option><option value="__custom">✎ Custom exercise…</option>${sugg.map(n => `<option>${esc(n)}</option>`).join('')}</select></div>
      <div class="tiny muted mb">Leave reps empty to skip a set. Weight 0 is fine for bodyweight moves.</div>
      ${d.existing ? `<button class="btn red" data-a="delWorkout">Delete workout</button>` : ''}`, 'Save', 'saveWorkout');
  } else if (m.type === 'boxing') {
    html = sheet('🥊 Boxing', `<div class="field"><label>Duration (minutes)</label><input id="bx-min" inputmode="numeric" value="60"></div>
      <div class="field"><label>When</label><input type="datetime-local" id="bx-date" value="${toLocalInput(Date.now())}"></div>
      <div class="field"><label>Note</label><input id="bx-note" placeholder="Sparring, pads, bag work…"></div>
      <div class="tiny muted">Worth 15 XP + 1 XP per 2 minutes (max 80).</div>`, 'Save', 'saveBoxing');
  } else if (m.type === 'study') {
    html = sheet('📚 Log study', `<div class="field"><label>Subject</label><input id="st-sub" placeholder="e.g. Math, Biology" list="subj"><datalist id="subj">${S.subjects.map(s => `<option value="${esc(s)}">`).join('')}</datalist></div>
      ${S.subjects.length ? `<div class="chips mb">${S.subjects.map(s => `<button class="chip" data-a="pickSubj" data-v="${esc(s)}">${esc(s)}</button>`).join('')}</div>` : ''}
      <div class="field"><label>Duration (minutes)</label><input id="st-min" inputmode="numeric" value="${m.minutes || 30}"></div>
      <div class="field"><label>When</label><input type="datetime-local" id="st-date" value="${toLocalInput(Date.now())}"></div>
      <div class="field"><label>Note</label><input id="st-note" placeholder="Optional"></div>`, 'Save', 'saveStudy');
  } else if (m.type === 'food') {
    const recents = recentFoods(), meal = guessMeal();
    html = sheet('🍽️ Log food', `<div class="field"><input id="fd-name" placeholder="What did you eat?"></div>
      <div class="field"><select id="fd-meal">${Object.entries(MEALS).map(([k, x]) => `<option value="${k}" ${k === meal ? 'selected' : ''}>${x.e} ${x.t}</option>`).join('')}</select></div>
      <div class="grid2"><div class="field inline-field"><input id="fd-kcal" inputmode="numeric" placeholder="Calories"><span class="unit">kcal</span></div>
      <div class="field inline-field"><input id="fd-prot" inputmode="numeric" placeholder="Protein"><span class="unit">g</span></div></div>
      ${recents.length ? `<div class="card"><h3>Quick add (recent)</h3>${recents.map(f => `<button class="list-item" data-a="quickFood" data-v="${f.id}"><span class="grow">${esc(f.name)}</span><span class="tiny muted">${f.kcal} kcal · ${f.protein} g</span><span style="color:var(--vit)">＋</span></button>`).join('')}</div>` : ''}`, 'Save', 'saveFood');
  } else if (m.type === 'habit') {
    html = sheet('New habit', `<div class="field"><input id="hb-name" placeholder="e.g. Journal, Cold shower"></div>
      <div class="field"><label>Emoji</label><div class="pick-grid" id="hb-emoji">${HABIT_EMOJIS.map((e, i) => `<button class="${i === 0 ? 'on' : ''}" data-a="pick" data-v="${e}">${e}</button>`).join('')}</div></div>
      <div class="field"><label>Levels up</label><select id="hb-attr">${Object.entries(ATTR).map(([k, a]) => `<option value="${k}" ${k === 'discipline' ? 'selected' : ''}>${a.e} ${a.t}</option>`).join('')}</select></div>
      <div class="card"><h3>Ideas</h3>${STARTER_HABITS.map((h, i) => `<button class="list-item" data-a="habitIdea" data-v="${i}">${h.emoji} ${esc(h.name)}</button>`).join('')}</div>`, 'Add', 'saveHabit');
  } else if (m.type === 'boss') {
    html = sheet('Summon a boss', `<div class="field"><input id="bs-name" placeholder="Goal (e.g. Read 12 books)"></div>
      <div class="field"><label>Emoji</label><div class="pick-grid" id="bs-emoji">${BOSS_EMOJIS.map((e, i) => `<button class="${i === 0 ? 'on' : ''}" data-a="pick" data-v="${e}">${e}</button>`).join('')}</div></div>
      <div class="grid2"><div class="field"><label>Target HP</label><input id="bs-target" inputmode="decimal" placeholder="12"></div><div class="field"><label>Unit</label><input id="bs-unit" placeholder="books, kg, km…"></div></div>
      <div class="field"><label>Stat</label><select id="bs-attr">${Object.entries(ATTR).map(([k, a]) => `<option value="${k}" ${k === 'discipline' ? 'selected' : ''}>${a.e} ${a.t}</option>`).join('')}</select></div>
      <div class="field"><label>Deadline (optional)</label><input type="date" id="bs-deadline"></div>
      <div class="tiny muted mb">Each hit gives +10 XP. Defeating it gives +150 XP.</div>
      <div class="card"><h3>Templates</h3>${BOSS_TEMPLATES.map((t, i) => `<button class="list-item" data-a="bossTpl" data-v="${i}">${t.emoji} ${esc(t.name)}</button>`).join('')}</div>`, 'Summon', 'saveBoss');
  } else if (m.type === 'attack') {
    const b = S.bosses.find(x => x.id === m.id);
    html = sheet('⚔️ Deal damage', `<div class="center" style="font-size:60px">${b ? b.emoji : ''}</div><div class="center bold mb">${b ? esc(b.name) : ''}</div>
      <div class="field"><label>How much progress did you make? (${b ? esc(b.unit) : ''})</label><input id="atk" inputmode="decimal" placeholder="1"></div>`, 'Attack!', 'saveAttack');
  } else if (m.type === 'checkin') {
    const wd = UI.checkinWeek || new Date(), l = weekLog(wd), prev = weekScore(wd);
    html = sheet('Week check-in', `<div class="bold mb">${weekTitle(weekBounds(wd).start)}</div>
      <div class="grid2"><div class="field"><label>⚖️ Weight</label><div class="inline-field"><input id="ck-w" inputmode="decimal" value="${l.weight != null ? fmt(l.weight) : ''}"><span class="unit">kg</span></div></div>
      <div class="field"><label>📉 Body fat</label><div class="inline-field"><input id="ck-bf" inputmode="decimal" value="${l.bf != null ? fmt(l.bf) : ''}"><span class="unit">%</span></div></div></div>
      <div class="field"><label>📸 Progress photo (+10 XP)</label>
        <img id="ck-img" ${l.photo ? `data-photo="${weekKey(wd)}"` : ''} style="max-width:100%;max-height:260px;border-radius:14px;display:${l.photo ? 'block' : 'none'};margin:0 auto 8px">
        <label class="btn ghost">${l.photo ? 'Change photo' : 'Add this week\'s photo'}<input type="file" accept="image/*" id="ck-file" hidden></label>
        <div class="tiny muted mt-s">Same spot and lighting each week makes the comparison fair. Photos stay private on your phone.</div></div>
      <div class="field"><label>How did you feel this week?</label><div class="grid3" style="grid-template-columns:repeat(5,1fr)" id="ck-feel">
        ${Object.entries(FEELINGS).map(([v, [e, t]]) => `<button class="opt" style="flex-direction:column;padding:8px 2px;gap:2px;margin:0" data-a="feel" data-v="${v}" ${(+v === (l.feeling || 4)) ? 'data-on="1"' : ''}><span style="font-size:28px">${e}</span><span class="tiny">${t}</span></button>`).join('')}</div></div>
      <div class="field"><label>Notes</label><textarea id="ck-note" placeholder="Energy, wins, what to fix next week…">${esc(l.note || '')}</textarea></div>
      <div class="card"><h3>Preview</h3>${prev.lines.map(x => `<div class="row between small" style="padding:4px 0"><span>${x.e} ${x.t}</span><span class="muted">${x.points}/${x.weight}</span></div>`).join('')}</div>`, 'Get rank', 'saveCheckin');
  } else if (m.type === 'viewer') {
    const photos = weekHistory().filter(w => w.log.photo).sort((a, b) => a.start - b.start);
    const i = Math.max(0, photos.findIndex(w => w.key === m.id)), w = photos[i];
    if (w) html = `<div class="overlay viewer"><button class="close" data-a="close">✕</button>
      <img data-photo="${w.key}" alt=""><div class="bold mt">${weekTitle(w.start)}</div>
      <div class="muted small mt-s">${[w.log.rank && 'Rank ' + w.log.rank, w.log.weight != null && fmt(w.log.weight) + ' kg', w.log.bf != null && fmt(w.log.bf) + '% BF', w.log.feeling && FEELINGS[w.log.feeling][0]].filter(Boolean).join(' · ')}</div>
      <div class="row mt" style="gap:30px"><button class="iconbtn" data-a="viewer" data-v="${photos[i - 1] ? photos[i - 1].key : w.key}" ${i ? '' : 'disabled style="opacity:.3"'}>‹</button><span class="muted small">${i + 1} / ${photos.length}</span><button class="iconbtn" data-a="viewer" data-v="${photos[i + 1] ? photos[i + 1].key : w.key}" ${i < photos.length - 1 ? '' : 'disabled style="opacity:.3"'}>›</button></div></div>`;
  }
  el.innerHTML = html;
  if (m.type === 'sleep') updateSleepSummary();
  if (m.type === 'checkin') markFeeling();
  hydratePhotos();
}
function updateSleepSummary() {
  const b = $('#sl-bed'), w = $('#sl-wake'), box = $('#sl-sum'); if (!b || !box) return;
  const mins = sleepMinutesFrom(b.value || '23:30', w.value || '07:30'), t = sleepTarget(), ok = mins >= t;
  box.innerHTML = `<div class="row between"><span>Total sleep</span><b style="font-size:24px;color:${ok ? 'var(--vit)' : '#ff9e26'}">${hoursText(mins)}</b></div>
    <div class="mt-s">${bar(mins / t, 'var(--vit)')}</div><div class="tiny muted mt-s">${ok ? 'Goal hit! +30 XP' : `${hoursText(Math.max(0, t - mins))} short of your goal · +15 XP`}</div>`;
}
function markFeeling() { document.querySelectorAll('#ck-feel button').forEach(b => b.classList.toggle('on', +b.dataset.v === UI.feeling)); }

// =====================================================================
// ACTIONS
// =====================================================================
const val = id => { const e = $('#' + id); return e ? e.value.trim() : ''; };
const A = {
  tab: d => { UI.tab = d.v; UI.page = null; window.scrollTo(0, 0); render(); },
  page: d => { UI.page = d.v; window.scrollTo(0, 0); render(); },
  back: d => { UI.page = d.v ? (d.v === 'train' ? null : d.v) : null; if (d.v === 'train') UI.tab = 'train'; window.scrollTo(0, 0); render(); },
  modal: d => openModal(d.v, { id: d.id }),
  close: () => closeModal(),
  closeBg: (d, el, e) => { if (e.target === el) closeModal(); },
  supp: d => { toggleSupp(d.v); commit(); },
  claim: d => { claimQuest(d.v); commit(); },
  finishDay: () => { resultsOpen = true; const r = finishDay(); saveState(); showResults('DAY CLEAR!', new Date().toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' }), r, RANK_BONUS[r.rank]); },
  saveSleep: () => { const day = val('sl-day') ? fromKey(val('sl-day')) : new Date(); logSleep(day, val('sl-bed') || '23:30', val('sl-wake') || '07:30'); closeModal(); commit(); },

  newWorkout: () => { UI.draft = { id: uid(), title: '', date: Date.now(), exercises: [], existing: false }; openModal('workout'); },
  repeatWorkout: d => { const w = S.workouts.find(x => x.id === d.v); if (!w) return; UI.draft = { id: uid(), title: w.title, date: Date.now(), exercises: w.exercises.map(ex => ({ name: ex.name, sets: ex.sets.map(s => ({ w: fmt(s.weight), r: String(s.reps) })) })), existing: false }; openModal('workout'); },
  editWorkout: d => { const w = S.workouts.find(x => x.id === d.v); if (!w) return; UI.draft = { id: w.id, title: w.title, date: w.date, exercises: w.exercises.map(ex => ({ name: ex.name, sets: ex.sets.map(s => ({ w: fmt(s.weight), r: String(s.reps) })) })), existing: true }; openModal('workout'); },
  exDel: d => { UI.draft.exercises.splice(+d.v, 1); renderModal(); },
  setAdd: d => { const ex = UI.draft.exercises[+d.v], last = ex.sets[ex.sets.length - 1]; ex.sets.push({ w: last ? last.w : '', r: last ? last.r : '' }); renderModal(); },
  setDel: d => { UI.draft.exercises[+d.v].sets.splice(+d.j, 1); renderModal(); },
  saveWorkout: () => {
    const d = UI.draft;
    const exercises = d.exercises.map(ex => ({ name: ex.name.trim(), sets: ex.sets.map(s => ({ reps: parseInt(s.r, 10), weight: Math.max(0, num(s.w) || 0) })).filter(s => s.reps > 0) })).filter(ex => ex.name && ex.sets.length);
    if (!exercises.length) { toast('Add at least one exercise with reps'); return; }
    saveWorkout({ id: d.id, date: d.date, title: d.title.trim() || 'Workout', exercises });
    closeModal(); commit();
  },
  delWorkout: () => { if (confirm('Delete this workout?')) { deleteWorkout(UI.draft.id); closeModal(); commit(); } },
  saveBoxing: () => { const m = parseInt(val('bx-min'), 10); if (!(m > 0)) return toast('Enter the minutes'); addBoxing({ id: uid(), date: fromLocalInput(val('bx-date')), minutes: m, note: val('bx-note') }); closeModal(); commit(); },
  delBoxing: d => { if (confirm('Delete this boxing session?')) { deleteBoxing(d.v); commit(); } },
  addBw: () => { const kg = num(val('bw-in')); if (!(kg > 0)) return toast('Enter your weight'); addBodyweight(kg); commit(); },
  delBw: d => { deleteBodyweight(d.v); commit(); },

  startTimer: () => { S.settings.timerStart = Date.now(); play('tap'); commit(); },
  cancelTimer: () => { delete S.settings.timerStart; commit(); },
  stopTimer: () => { const mins = Math.max(1, Math.round((Date.now() - S.settings.timerStart) / 60000)); delete S.settings.timerStart; saveState(); render(); openModal('study', { minutes: mins }); },
  pickSubj: d => { $('#st-sub').value = d.v; },
  saveStudy: () => { const m = parseInt(val('st-min'), 10); if (!(m > 0)) return toast('Enter the minutes'); addStudy({ id: uid(), date: fromLocalInput(val('st-date')), subject: val('st-sub'), minutes: m, note: val('st-note') }); closeModal(); commit(); },
  delStudy: d => { if (confirm('Delete this session?')) { deleteStudy(d.v); commit(); } },

  foodDay: d => { const n = addDays(UI.foodDay, +d.v); if (n <= new Date()) UI.foodDay = n; render(); },
  water: d => { changeWater(UI.foodDay, +d.v); commit(); },
  step: d => {
    const f = d.f, [lo, hi] = STEP_LIMITS[f], cur = (f === 'age' ? (P().age || 20) : P()[f]);
    S.profile[f] = Math.min(hi, Math.max(lo, Math.round((cur + parseFloat(d.v)) * 10) / 10)); commit();
  },
  saveFood: () => {
    const name = val('fd-name'); if (!name) return toast('What did you eat?');
    const day = isToday(UI.foodDay) ? Date.now() : UI.foodDay.getTime() + 12 * 3600000;
    addFood({ id: uid(), date: day, name, meal: val('fd-meal'), kcal: Math.round(num(val('fd-kcal')) || 0), protein: Math.round(num(val('fd-prot')) || 0) }); closeModal(); commit();
  },
  quickFood: d => { const f = S.foods.find(x => x.id === d.v); if (!f) return; const day = isToday(UI.foodDay) ? Date.now() : UI.foodDay.getTime() + 12 * 3600000; addFood({ id: uid(), date: day, name: f.name, meal: val('fd-meal'), kcal: f.kcal, protein: f.protein }); closeModal(); commit(); },
  delFood: d => { deleteFood(d.v); commit(); },

  habit: d => { toggleHabit(d.v); commit(); },
  delHabit: d => { if (confirm('Delete this habit?')) { deleteHabit(d.v); commit(); } },
  pick: (d, el) => { el.parentElement.querySelectorAll('button').forEach(b => b.classList.remove('on')); el.classList.add('on'); },
  habitIdea: d => { const h = STARTER_HABITS[+d.v]; $('#hb-name').value = h.name; $('#hb-attr').value = h.attr; document.querySelectorAll('#hb-emoji button').forEach(b => b.classList.toggle('on', b.dataset.v === h.emoji)); },
  saveHabit: () => { const name = val('hb-name'); if (!name) return toast('Name your habit'); const e = $('#hb-emoji .on'); S.habits.push({ id: uid(), name, emoji: e ? e.dataset.v : '✅', attr: val('hb-attr'), done: [] }); closeModal(); commit(); },
  bossTpl: d => { const t = BOSS_TEMPLATES[+d.v]; $('#bs-name').value = t.name; $('#bs-target').value = t.target; $('#bs-unit').value = t.unit; $('#bs-attr').value = t.attr; document.querySelectorAll('#bs-emoji button').forEach(b => b.classList.toggle('on', b.dataset.v === t.emoji)); },
  saveBoss: () => {
    const name = val('bs-name'), target = num(val('bs-target'));
    if (!name || !(target > 0)) return toast('Add a goal and target HP');
    const e = $('#bs-emoji .on'), dl = val('bs-deadline');
    S.bosses.push({ id: uid(), name, emoji: e ? e.dataset.v : '🐉', attr: val('bs-attr'), target, unit: val('bs-unit'), hits: [], deadline: dl ? fromKey(dl).getTime() : null, defeatedAt: null });
    closeModal(); commit();
  },
  saveAttack: () => { const a = num(val('atk')); if (!(a > 0)) return toast('Enter an amount'); hitBoss(UI.modal.id, a); closeModal(); commit(); },
  delBoss: d => { if (confirm('Delete this boss?')) { deleteBoss(d.v); commit(); } },

  weekGoal: d => { toggleWeekGoal(d.v); commit(); },
  delWeekGoal: d => { deleteWeekGoal(d.v); commit(); },
  addWeekGoal: () => { addWeekGoal(val('goal-in')); commit(); },
  feel: d => { UI.feeling = +d.v; markFeeling(); play('tap'); },
  saveCheckin: async () => {
    const wd = UI.checkinWeek || new Date(), wk = weekKey(wd);
    resultsOpen = true;
    if (UI.checkinPhoto) {
      try { await PhotoDB.put(wk, UI.checkinPhoto); updateWeekLog(wd, l => { l.photo = true; }); award(10, 'discipline', 'Progress photo 📸', 'photo:' + wk); }
      catch (e) { toast('Could not save the photo'); }
    }
    const r = finishWeek(wd, { weight: num(val('ck-w')), bf: num(val('ck-bf')), feeling: UI.feeling, note: val('ck-note') });
    closeModal(); saveState();
    showResults('WEEK CLEAR!', weekTitle(weekBounds(wd).start), r, RANK_BONUS[r.rank] * 2);
  },
  viewer: d => openModal('viewer', { id: d.v }),

  avatar: d => { S.profile.avatar = d.v; commit(); },
  area: d => { const a = S.profile.areas; S.profile.areas = a.includes(d.v) ? a.filter(x => x !== d.v) : [...a, d.v]; commit(); },
  addSupp: () => { const name = val('supp-name'); if (!name) return; S.profile.supplements.push({ id: uid(), name, emoji: val('supp-emoji') || '💊', time: val('supp-time') }); commit(); },
  delSupp: d => { S.profile.supplements = S.profile.supplements.filter(s => s.id !== d.v); commit(); },
  sound: () => { S.settings.sound = S.settings.sound === false; commit(); play('claim'); },
  export: async () => {
    const name = `MaxGeneration-backup-${dayKey()}.json`;
    const blob = new Blob([JSON.stringify(S, null, 1)], { type: 'application/json' });
    try {
      const file = new File([blob], name, { type: 'application/json' });
      if (navigator.canShare && navigator.canShare({ files: [file] })) { await navigator.share({ files: [file], title: 'MaxGeneration backup' }); return; }
    } catch (err) { if (err && err.name === 'AbortError') return; }
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = name; a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 3000);
  },
  reset: () => { if (confirm('Delete ALL progress? This cannot be undone. Export a backup first.')) { replaceState(blankState()); UI.tab = 'home'; UI.page = null; render(); } },
};

// ---------- onboarding ----------
function renderOnboarding() {
  const o = UI.onb || (UI.onb = { step: 0, name: '', avatar: '⚡', age: 20, height: '', weight: '', bf: '', goal: 'recomp', areas: ['gym', 'study', 'food', 'life'], sleep: 8, perWeek: 4, study: 60, kcal: 2500, protein: 150, water: 8, habits: ['Read 20 minutes'] });
  const steps = 6, s = o.step;
  let body = '';
  if (s === 0) body = `<div class="center" style="margin-top:12vh"><img src="icon-192.png" width="110" height="110" style="border-radius:26px;box-shadow:0 0 40px rgba(64,136,255,.5)" alt=""><h1 class="rank" style="font-size:40px;margin-top:22px">MaxGeneration</h1>
      <p class="muted" style="font-size:17px;line-height:1.5">Your life is the game.<br>Sleep, train, eat, study and build habits to earn XP, level up, and get ranked C → S+ every day and every week.</p></div>`;
  if (s === 1) body = `<h1>Create your hero</h1><div class="field mt"><label>What should we call you?</label><input data-o="name" value="${esc(o.name)}" placeholder="Your name"></div>
      <div class="field"><label>Pick your avatar</label><div class="pick-grid">${AVATARS.map(a => `<button class="${a === o.avatar ? 'on' : ''}" data-a="onbSet" data-f="avatar" data-v="${a}">${a}</button>`).join('')}</div></div>
      <div class="center" style="font-size:90px">${o.avatar}</div>`;
  if (s === 2) body = `<h1>Your details</h1><p class="muted">Your starting point. Everything stays private on your phone.</p>
      <div class="card">${onbStep('🎂 Age', o.age, '', 'age', 1)}
        <div class="stepper"><span>📏 Height</span><span class="inline-field" style="width:130px"><input data-o="height" inputmode="decimal" value="${esc(o.height)}" placeholder="180"><span class="unit">cm</span></span></div>
        <div class="stepper"><span>⚖️ Weight</span><span class="inline-field" style="width:130px"><input data-o="weight" inputmode="decimal" value="${esc(o.weight)}" placeholder="75"><span class="unit">kg</span></span></div>
        <div class="stepper"><span>📉 Body fat</span><span class="inline-field" style="width:130px"><input data-o="bf" inputmode="decimal" value="${esc(o.bf)}" placeholder="15"><span class="unit">%</span></span></div></div>
      <div class="bold mb">Main goal</div>${Object.entries(GOALS).map(([k, t]) => `<button class="opt ${o.goal === k ? 'on' : ''}" data-a="onbSet" data-f="goal" data-v="${k}">${t}</button>`).join('')}`;
  if (s === 3) body = `<h1>What do you want to level up?</h1><p class="muted">Each area gets its own tab. Sleep & supplements are always on.</p>
      ${Object.entries(AREAS).map(([k, a]) => `<button class="opt ${o.areas.includes(k) ? 'on' : ''}" data-a="onbArea" data-v="${k}"><span style="font-size:26px">${a.e}</span><b class="grow">${a.t}</b>${o.areas.includes(k) ? '✅' : '⚪'}</button>`).join('')}`;
  if (s === 4) body = `<h1>Daily targets</h1><p class="muted">Quests and ranks are built from these. You can change them any time.</p>
      <div class="card">${onbStep('😴 Sleep', fmt(o.sleep), 'h / night', 'sleep', 0.5)}
        ${o.areas.includes('gym') ? onbStep('🥊 Training', o.perWeek, '/ week', 'perWeek', 1) : ''}
        ${o.areas.includes('study') ? onbStep('📚 Study', o.study, 'min / day', 'study', 15) : ''}
        ${o.areas.includes('food') ? onbStep('🔥 Calories', o.kcal, 'kcal', 'kcal', 50) + onbStep('🥩 Protein', o.protein, 'g', 'protein', 5) + onbStep('💧 Water', o.water, 'cups', 'water', 1) : ''}</div>
      <div class="small muted">💊 Supplements set up: Multivitamin, Omega-3, Creatine, Magnesium (night). Edit them in Settings.</div>`;
  if (s === 5) body = `<h1>Starter habits</h1><p class="muted">Tick them off daily for XP and streaks. Pick a few now.</p>
      ${STARTER_HABITS.map(h => `<button class="opt ${o.habits.includes(h.name) ? 'on' : ''}" data-a="onbHabit" data-v="${esc(h.name)}"><span style="font-size:22px">${h.emoji}</span><span class="grow"><b>${esc(h.name)}</b><div class="tiny" style="color:${ATTR[h.attr].c}">${ATTR[h.attr].e} ${ATTR[h.attr].t}</div></span>${o.habits.includes(h.name) ? '✅' : '⚪'}</button>`).join('')}`;
  return `<div class="onb"><div class="steps">${Array.from({ length: steps }, (_, i) => `<i class="${i <= s ? 'on' : ''}"></i>`).join('')}</div>
    <div class="body">${body}</div>
    <div class="row mt">${s > 0 ? '<button class="btn ghost" style="width:110px" data-a="onbBack">Back</button>' : ''}<button class="btn" data-a="onbNext">${s < steps - 1 ? 'Next' : 'Begin your quest ⚔️'}</button></div></div>`;
}
function onbStep(label, value, unit, field, step) {
  return `<div class="stepper"><span>${label}: <b>${value}</b> ${unit}</span><span class="ctl"><button data-a="onbStep" data-f="${field}" data-v="${-step}">−</button><button data-a="onbStep" data-f="${field}" data-v="${step}">+</button></span></div>`;
}
Object.assign(A, {
  onbSet: d => { UI.onb[d.f] = d.v; render(); },
  onbArea: d => { const a = UI.onb.areas; UI.onb.areas = a.includes(d.v) ? a.filter(x => x !== d.v) : [...a, d.v]; render(); },
  onbHabit: d => { const h = UI.onb.habits; UI.onb.habits = h.includes(d.v) ? h.filter(x => x !== d.v) : [...h, d.v]; render(); },
  onbStep: d => { const [lo, hi] = STEP_LIMITS[d.f]; UI.onb[d.f] = Math.min(hi, Math.max(lo, Math.round((UI.onb[d.f] + parseFloat(d.v)) * 10) / 10)); render(); },
  onbBack: () => { UI.onb.step--; render(); window.scrollTo(0, 0); },
  onbNext: () => {
    const o = UI.onb;
    if (o.step < 5) { o.step++; play('tap'); render(); window.scrollTo(0, 0); return; }
    S.profile = {
      name: o.name.trim() || 'Hero', avatar: o.avatar, areas: o.areas.length ? o.areas : ['life'], age: o.age,
      height: num(o.height), startWeight: num(o.weight), startBF: num(o.bf), goal: o.goal,
      sleep: o.sleep, perWeek: o.perWeek, study: o.study, kcal: o.kcal, protein: o.protein, water: o.water,
      supplements: defaultSupplements(),
    };
    S.habits = STARTER_HABITS.filter(h => o.habits.includes(h.name)).map(h => ({ id: uid(), name: h.name, emoji: h.emoji, attr: h.attr, done: [] }));
    if (S.profile.startWeight) addBodyweight(S.profile.startWeight);
    award(10, 'discipline', 'Began the adventure', 'start');
    UI.onb = null; UI.tab = 'home'; play('claim'); commit(); window.scrollTo(0, 0);
  },
});

// ---------- events ----------
document.addEventListener('click', e => {
  const el = e.target.closest('[data-a]'); if (!el || el.disabled) return;
  const fn = A[el.dataset.a]; if (!fn) return;
  if (el.dataset.a !== 'closeBg') e.preventDefault();
  fn(el.dataset, el, e);
});
document.addEventListener('input', e => {
  const t = e.target;
  if (t.dataset.live === 'sleep') updateSleepSummary();
  if (t.dataset.o !== undefined && UI.onb) UI.onb[t.dataset.o] = t.value;
  if (t.dataset.d && UI.draft) {
    const d = UI.draft, f = t.dataset.d, i = +t.dataset.i, j = +t.dataset.j;
    if (f === 'title') d.title = t.value;
    else if (f === 'date') d.date = fromLocalInput(t.value);
    else if (f === 'name') d.exercises[i].name = t.value;
    else if (f === 'w') d.exercises[i].sets[j].w = t.value;
    else if (f === 'r') d.exercises[i].sets[j].r = t.value;
  }
});
document.addEventListener('change', async e => {
  const t = e.target;
  if (t.id === 'ex-pick' && UI.draft) {
    let name = t.value; if (!name) return;
    if (name === '__custom') { name = (prompt('Exercise name') || '').trim(); if (!name) { t.value = ''; return; } }
    const prev = exerciseHistory(name)[0];
    UI.draft.exercises.push({ name, sets: prev ? prev.sets.map(s => ({ w: fmt(s.weight), r: String(s.reps) })) : [{ w: '', r: '' }, { w: '', r: '' }, { w: '', r: '' }] });
    renderModal();
  }
  if (t.dataset.set) {
    const f = t.dataset.set;
    if (['height', 'startWeight', 'startBF'].includes(f)) S.profile[f] = num(t.value);
    else S.profile[f] = t.value;
    if (f === 'name' && !t.value.trim()) S.profile.name = 'Hero';
    saveState();
  }
  if (t.id === 'ck-file' && t.files && t.files[0]) {
    try { UI.checkinPhoto = await resizeImage(t.files[0]); const img = $('#ck-img'); img.removeAttribute('data-photo'); img.src = UI.checkinPhoto; img.style.display = 'block'; }
    catch (err) { toast('Could not read that photo'); }
  }
  if (t.id === 'import-file' && t.files && t.files[0]) {
    try {
      const obj = JSON.parse(await t.files[0].text());
      if (!obj || typeof obj !== 'object' || !('xp' in obj)) throw new Error('not a backup');
      replaceState(obj); toast('✅ Backup restored'); render();
    } catch (err) { toast('⚠️ That file isn\'t a MaxGeneration backup'); }
  }
});

// ---------- boot ----------
loadState();
render();
if (S.profile) checkAchievements(true);
// Refresh when coming back to the app (new day, timer), but never while a form is open.
document.addEventListener('visibilitychange', () => { if (!document.hidden && !UI.modal) render(); });
if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js').catch(() => {});
