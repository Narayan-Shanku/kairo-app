// Kairō frontend — vanilla JS, talks to the local FastAPI backend.

const $ = (sel) => document.querySelector(sel);
const TOKEN_KEY = "kairo_token";

// Attaches a bearer token (from localStorage) when the server requires one.
// Local/unsecured servers send no token and are unaffected. On a 401 we prompt
// once for the access token, store it, and retry.
const api = async (path, opts = {}) => {
  const send = (token) => {
    const headers = { ...(opts.headers || {}) };
    if (token) headers["Authorization"] = `Bearer ${token}`;
    return fetch(path, { ...opts, headers });
  };
  let res = await send(localStorage.getItem(TOKEN_KEY));
  if (res.status === 401) {
    const entered = prompt("This Kairō server requires an access token:");
    if (entered) {
      localStorage.setItem(TOKEN_KEY, entered);
      res = await send(entered);
    }
  }
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: res.statusText }));
    throw new Error(err.detail || "Request failed");
  }
  return res.json();
};

const DOMAIN_COLORS = {
  Health: "#3ec98a", Career: "#5a93e0", Learning: "#b78fe0",
  Projects: "#e7b25e", Fitness: "#5fc9c1", Finance: "#d8b34a",
  Relationships: "#e07a9a",
};

// ---------- Tab navigation ----------
function showView(name) {
  document.querySelectorAll(".view").forEach((v) => v.classList.remove("active"));
  document.querySelectorAll(".tab").forEach((t) => t.classList.remove("active"));
  $("#" + name).classList.add("active");
  const tab = document.querySelector(`.tab[data-view="${name}"]`);
  if (tab) tab.classList.add("active");
  if (name === "home") loadHome();
  if (name === "review") loadReview();
  if (name === "digest") loadDigest(false);
  if (name === "timeline") loadTimeline();
  if (name === "insights") loadInsights();
}
document.querySelectorAll(".tab").forEach((t) =>
  t.addEventListener("click", () => showView(t.dataset.view))
);
document.querySelectorAll("[data-view-jump]").forEach((b) =>
  b.addEventListener("click", () => showView(b.dataset.viewJump))
);

// ---------- Health indicator ----------
async function checkHealth() {
  const el = $("#health");
  try {
    const h = await api("/api/health");
    const ready = h.ollama && Object.values(h.models || {}).every(Boolean);
    el.className = "health " + (ready ? "ok" : "bad");
    el.title = ready ? "Local models ready" : "Ollama/model not ready — see README";
  } catch {
    el.className = "health bad";
    el.title = "Backend unreachable";
  }
}

// ---------- Home ----------
function memoryCard(m) {
  const domain = (m.domains && m.domains[0]) || "General";
  const color = DOMAIN_COLORS[domain] || "#9aa1b1";
  const date = new Date(m.timestamp).toLocaleDateString(undefined,
    { month: "short", day: "numeric", year: "numeric" });
  return `<div class="memory">
    <div class="meta">
      <span class="tag" style="color:${color};background:${color}22">${domain}</span>
      <span class="date">${date} · ${m.source_type}</span>
    </div>
    <div class="text">${escapeHtml(m.text)}</div>
  </div>`;
}

async function loadHome() {
  $("#greeting").textContent = greeting();
  try {
    const stats = await api("/api/stats");
    $("#home-stats").innerHTML = `
      <div class="stat"><div class="num">${stats.total_memories}</div><div class="label">Memories</div></div>
      <div class="stat"><div class="num">${stats.total_sessions}</div><div class="label">Check-ins</div></div>
      <div class="stat"><div class="num">${Object.values(stats.domains).filter(x=>x>0).length}</div><div class="label">Domains</div></div>`;
    // Offer demo data only while the store is empty.
    $("#demoBanner").hidden = stats.total_memories > 0;
    // Review-due badge
    try {
      const cs = await api("/api/cards/stats");
      const badge = $("#reviewBadge");
      if (cs.due > 0) {
        badge.hidden = false;
        badge.innerHTML = `🔁 <strong>${cs.due}</strong> ${cs.due === 1 ? "memory" : "memories"} to review`
          + (cs.streak ? ` · 🔥 ${cs.streak}-day streak` : "") + " →";
      } else {
        badge.hidden = true;
      }
    } catch { /* cards optional */ }
    const mems = await api("/api/memories?limit=5");
    $("#home-recent").innerHTML = mems.length
      ? mems.map(memoryCard).join("")
      : `<div class="empty">No memories yet. Record your first check-in →</div>`;
    loadProactive();
  } catch (e) {
    $("#home-recent").innerHTML = `<div class="empty">${e.message}</div>`;
  }
}

// ---------- Proactive Engine (streak, Day-3 recall, nudges) ----------
async function loadProactive() {
  const el = $("#proactive");
  try {
    const p = await api("/api/proactive/today");
    let html = "";
    if (p.streak && p.streak.current > 0) {
      html += `<div class="streak-chip">🔥 <strong>${p.streak.current}</strong>-day streak`
        + (p.streak.checked_in_today ? " · checked in today ✓" : "") + `</div>`;
    }
    if (p.recall) {
      const color = DOMAIN_COLORS[p.recall.domain] || "#e7b25e";
      html += `<div class="recall-card" data-id="${p.recall.memory_id}">
        <div class="recall-badge" style="color:${color};background:${color}22">↩ ${p.recall.date} · ${p.recall.domain}</div>
        <div class="recall-prompt">${escapeHtml(p.recall.prompt)}</div>
        <div class="recall-snippet">“${escapeHtml(p.recall.snippet)}”</div>
        <textarea class="recall-input" placeholder="Reply — it's saved as a new memory…"></textarea>
        <div class="recall-actions">
          <button class="primary recall-save">Save reflection</button>
          <button class="ghost-sm recall-dismiss">Dismiss</button>
        </div>
      </div>`;
    }
    if (p.nudges && p.nudges.length) {
      html += `<div class="nudges">`
        + p.nudges.map((n) => `<div class="nudge">💡 ${escapeHtml(n.message)}</div>`).join("")
        + `</div>`;
    }
    el.innerHTML = html;

    const card = el.querySelector(".recall-card");
    if (card) {
      const id = card.dataset.id;
      card.querySelector(".recall-save").addEventListener("click", async (e) => {
        const text = card.querySelector(".recall-input").value.trim();
        if (!text) return;
        e.target.disabled = true;
        e.target.textContent = "Saving…";
        try {
          await api("/api/proactive/respond", {
            method: "POST", headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ memory_id: id, response: text }),
          });
          card.innerHTML = `<div class="recall-badge">✓ Saved as a new memory</div>`;
        } catch (err) { e.target.textContent = err.message; }
      });
      card.querySelector(".recall-dismiss").addEventListener("click", async () => {
        try {
          await api("/api/proactive/dismiss", {
            method: "POST", headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ memory_id: id }),
          });
        } catch { /* ignore */ }
        card.remove();
      });
    }
  } catch {
    el.innerHTML = "";
  }
}

// ---------- Weekly digest ----------
async function loadDigest(refresh) {
  const el = $("#digestContent");
  el.innerHTML = `<div class="empty">${refresh ? "Regenerating your digest…" : "Loading your weekly digest…"}</div>`;
  try {
    const d = await api("/api/digest" + (refresh ? "?refresh=1" : ""));
    el.innerHTML = `<div class="digest-card">
      <div class="digest-meta">${d.week_start} → ${d.week_end} · ${d.memory_count ?? 0} memories</div>
      <div class="digest-text">${formatDigest(d.digest_text)}</div>
    </div>`;
  } catch (e) {
    el.innerHTML = `<div class="empty">${e.message}</div>`;
  }
}
function formatDigest(text) {
  return escapeHtml(text || "").replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
}
$("#refreshDigest").addEventListener("click", () => loadDigest(true));

// Seed demo memories
$("#seedBtn").addEventListener("click", async () => {
  const btn = $("#seedBtn");
  btn.disabled = true;
  btn.textContent = "Loading…";
  try {
    await api("/api/demo/seed", { method: "POST" });
    await loadHome();
  } catch (e) {
    btn.textContent = e.message;
  } finally {
    btn.disabled = false;
    btn.textContent = "Load demo memories";
  }
});

function greeting() {
  const h = new Date().getHours();
  if (h < 12) return "Good morning.";
  if (h < 18) return "Good afternoon.";
  return "Good evening.";
}

// ---------- Recording ----------
let mediaRecorder = null, chunks = [], timerInt = null, seconds = 0;

async function toggleRecord() {
  const btn = $("#recBtn");
  if (mediaRecorder && mediaRecorder.state === "recording") {
    mediaRecorder.stop();
    return;
  }
  let stream;
  try {
    stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  } catch {
    $("#recHint").textContent = "Microphone permission denied.";
    return;
  }
  chunks = [];
  mediaRecorder = new MediaRecorder(stream);
  mediaRecorder.ondataavailable = (e) => chunks.push(e.data);
  mediaRecorder.onstop = async () => {
    stream.getTracks().forEach((t) => t.stop());
    stopTimer();
    $("#waveform").classList.remove("active");
    btn.classList.remove("recording");
    btn.textContent = "Record";
    const blob = new Blob(chunks, { type: "audio/webm" });
    await uploadAudio(blob);
  };
  mediaRecorder.start();
  btn.classList.add("recording");
  btn.textContent = "Stop";
  $("#waveform").classList.add("active");
  $("#recHint").textContent = "Listening… tap Stop when you're done.";
  startTimer();
}

function startTimer() {
  seconds = 0; $("#timer").textContent = "0:00";
  timerInt = setInterval(() => {
    seconds++;
    const m = Math.floor(seconds / 60), s = String(seconds % 60).padStart(2, "0");
    $("#timer").textContent = `${m}:${s}`;
    if (seconds >= 300 && mediaRecorder?.state === "recording") mediaRecorder.stop();
  }, 1000);
}
function stopTimer() { clearInterval(timerInt); }

async function uploadAudio(blob) {
  const out = $("#captureResult");
  out.innerHTML = `<div class="empty">Transcribing on-device…</div>`;
  const fd = new FormData();
  fd.append("audio", blob, "checkin.webm");
  try {
    const r = await api("/api/capture/voice", { method: "POST", body: fd });
    out.innerHTML = renderCaptureResult(r);
  } catch (e) {
    out.innerHTML = `<div class="empty">${e.message}</div>`;
  }
}

function renderCaptureResult(r) {
  const tags = (r.domains || []).map((d) =>
    `<span class="tag" style="color:${DOMAIN_COLORS[d]||'#e0a94f'};background:${(DOMAIN_COLORS[d]||'#e0a94f')}22">${d}</span>`
  ).join(" ");
  const transcript = r.transcript ? `<div class="text" style="margin-top:8px">"${escapeHtml(r.transcript)}"</div>` : "";
  return `<div class="ok">
    ✓ Saved · ${r.chunk_count} memory chunk(s) · ${r.word_count} words<br>
    <div style="margin-top:8px">${tags || '<span class="tag">Learning</span>'}</div>
    ${transcript}
  </div>`;
}

$("#recBtn").addEventListener("click", toggleRecord);

$("#saveTextBtn").addEventListener("click", async () => {
  const text = $("#textEntry").value.trim();
  if (!text) return;
  const out = $("#captureResult");
  out.innerHTML = `<div class="empty">Saving…</div>`;
  try {
    const r = await api("/api/capture/text", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text, source: "text" }),
    });
    $("#textEntry").value = "";
    out.innerHTML = renderCaptureResult(r);
  } catch (e) {
    out.innerHTML = `<div class="empty">${e.message}</div>`;
  }
});

// ---------- Ask ----------
$("#askForm").addEventListener("submit", (e) => {
  e.preventDefault();
  const input = $("#askInput");
  const q = input.value.trim();
  input.value = "";
  if (q) askQuestion(q);
});

// Suggestion chips
document.querySelectorAll(".suggest").forEach((b) =>
  b.addEventListener("click", () => askQuestion(b.textContent)));

async function askQuestion(q) {
  const empty = $("#chatEmpty");
  if (empty) empty.remove();
  const chat = $("#chat");
  chat.insertAdjacentHTML("beforeend", `<div class="bubble user">${escapeHtml(q)}</div>`);
  const thinkingId = "t" + Date.now();
  chat.insertAdjacentHTML("beforeend",
    `<div class="bubble ai thinking" id="${thinkingId}">Searching your memories…</div>`);
  chat.scrollTop = chat.scrollHeight;
  try {
    const r = await api("/api/query", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ question: q }),
    });
    const sources = (r.sources || []).map((s, i) =>
      `<span class="source-chip" title="${escapeHtml(s.snippet)}">[${i+1}] ${s.date} · ${s.domain}</span>`
    ).join("");
    const el = $("#" + thinkingId);
    el.classList.remove("thinking");
    el.innerHTML = `${escapeHtml(r.answer)}${sources ? `<div class="sources">${sources}</div>` : ""}`
      + `<div class="answer-actions"><button class="remember-btn">⭐ Remember this</button></div>`;
    el.querySelector(".remember-btn").addEventListener("click", (ev) =>
      pinAnswer(q, r.answer, ev.target));
  } catch (e) {
    const el = $("#" + thinkingId);
    el.classList.remove("thinking");
    el.textContent = e.message;
  }
  chat.scrollTop = chat.scrollHeight;
}

// ---------- Timeline ----------
let activeDomain = null;
const DOMAINS = ["Health","Career","Learning","Projects","Fitness","Finance","Relationships"];

async function loadTimeline() {
  const pills = $("#domainPills");
  pills.innerHTML = [`<span class="pill ${!activeDomain?'active':''}" data-d="">All</span>`]
    .concat(DOMAINS.map((d) =>
      `<span class="pill ${activeDomain===d?'active':''}" data-d="${d}">${d}</span>`)).join("");
  pills.querySelectorAll(".pill").forEach((p) =>
    p.addEventListener("click", () => { activeDomain = p.dataset.d || null; loadTimeline(); }));
  const q = activeDomain ? `?domain=${encodeURIComponent(activeDomain)}` : "";
  try {
    const mems = await api("/api/memories" + q);
    $("#timelineList").innerHTML = mems.length
      ? mems.map(memoryCard).join("")
      : `<div class="empty">No memories in this domain yet.</div>`;
  } catch (e) {
    $("#timelineList").innerHTML = `<div class="empty">${e.message}</div>`;
  }
}

// ---------- Insights ----------
async function loadInsights() {
  try {
    const stats = await api("/api/stats");
    const total = stats.total_memories || 0;
    $("#insightsTotal").textContent = `${total} memories across ${Object.values(stats.domains).filter(x=>x>0).length} domains`;
    const max = Math.max(1, ...Object.values(stats.domains));
    $("#domainBars").innerHTML = DOMAINS.map((d) => {
      const n = stats.domains[d] || 0;
      const pct = Math.round((n / max) * 100);
      const color = DOMAIN_COLORS[d];
      return `<div class="bar-row">
        <div class="bar-label"><span>${d}</span><span>${n}</span></div>
        <div class="bar-track"><div class="bar-fill" style="width:${pct}%;background:${color}"></div></div>
      </div>`;
    }).join("");
  } catch (e) {
    $("#domainBars").innerHTML = `<div class="empty">${e.message}</div>`;
  }
}

// ---------- Review (spaced repetition) ----------
let reviewQueue = [];

async function loadReview() {
  const area = $("#reviewArea");
  area.innerHTML = `<div class="empty">Loading…</div>`;
  try {
    reviewQueue = await api("/api/cards/due?limit=50");
    renderCard();
  } catch (e) {
    area.innerHTML = `<div class="empty">${e.message}</div>`;
  }
}

function renderCard() {
  const area = $("#reviewArea");
  if (!reviewQueue.length) {
    area.innerHTML = `<div class="review-done">
      <div class="review-done-mark">✓</div>
      <h3>All caught up</h3>
      <p class="sub">No memories due right now. Come back tomorrow — or capture something new.</p>
    </div>`;
    return;
  }
  const card = reviewQueue[0];
  const color = DOMAIN_COLORS[card.domain] || "#e7b25e";
  const label = card.domain || card.type;
  area.innerHTML = `
    <div class="review-progress">${reviewQueue.length} to review</div>
    <div class="flashcard">
      <div class="fc-tag" style="color:${color};background:${color}22">${label}</div>
      <div class="fc-front">${escapeHtml(card.front)}</div>
      <div class="fc-back" id="fcBack" hidden>
        <div class="fc-divider"></div>
        <div class="fc-answer">${escapeHtml(card.back)}</div>
        ${card.type === "decision"
          ? `<textarea id="fcReflection" class="fc-reflection" placeholder="Did it hold up? Add a quick reflection — it's saved as a new memory…"></textarea>`
          : ""}
      </div>
    </div>
    <div id="fcControls" class="fc-controls">
      <button class="primary" id="fcReveal">Show answer</button>
    </div>`;
  $("#fcReveal").addEventListener("click", revealCard);
}

function revealCard() {
  $("#fcBack").hidden = false;
  $("#fcControls").innerHTML = `
    <button class="rate again" data-r="again">Again</button>
    <button class="rate hard" data-r="hard">Hard</button>
    <button class="rate good" data-r="good">Good</button>
    <button class="rate easy" data-r="easy">Easy</button>`;
  document.querySelectorAll(".rate").forEach((b) =>
    b.addEventListener("click", () => rateCard(b.dataset.r)));
}

async function rateCard(rating) {
  const card = reviewQueue[0];
  const refEl = $("#fcReflection");
  const reflection = refEl ? refEl.value.trim() : null;
  document.querySelectorAll(".rate").forEach((b) => (b.disabled = true));
  try {
    await api(`/api/cards/${card.card_id}/review`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ rating, reflection }),
    });
    reviewQueue.shift();
    renderCard();
  } catch (e) {
    $("#fcControls").innerHTML = `<div class="empty">${e.message}</div>`;
  }
}

async function pinAnswer(question, answer, btn) {
  btn.disabled = true;
  btn.textContent = "Saving…";
  try {
    await api("/api/cards/pin", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ front: question, back: answer }),
    });
    btn.textContent = "✓ Added to Review";
  } catch (e) {
    btn.textContent = e.message;
  }
}

// ---------- utils ----------
function escapeHtml(s) {
  return (s || "").replace(/[&<>"']/g, (c) =>
    ({ "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;" }[c]));
}

// ---------- init ----------
checkHealth();
loadHome();
