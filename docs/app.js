"use strict";

const TABS = {
  une: { title: "À la une", category: null },
  geo: { title: "Géopolitique", category: "geo" },
  eco: { title: "Économie", category: "eco" },
  transport: { title: "Transport", category: "transport" },
};

// Sous-thèmes affichés en pastilles ; les clés correspondent à "topic" dans news.json.
const TOPICS = {
  world: { title: "International", category: "geo" },
  africa: { title: "Afrique", category: "geo" },
  defense: { title: "Défense", category: "geo" },
  france: { title: "France", category: "eco" },
  global: { title: "Monde", category: "eco" },
  air: { title: "Aérien", category: "transport" },
  road: { title: "Routier", category: "transport" },
  sea: { title: "Maritime", category: "transport" },
  logistics: { title: "Logistique", category: "transport" },
};

const STALE_AFTER = 10 * 60 * 1000;

const state = { tab: "une", topic: null, source: null, query: "", data: null, loadedAt: 0 };

const $ = (id) => document.getElementById(id);
const els = {
  title: $("title"),
  search: $("search"),
  chips: $("chips"),
  select: $("source-select"),
  refresh: $("refresh"),
  list: $("list"),
  footer: $("footer"),
};

const rtf = new Intl.RelativeTimeFormat("fr", { numeric: "auto" });
const timeFmt = new Intl.DateTimeFormat("fr", { hour: "2-digit", minute: "2-digit" });
const dayFmt = new Intl.DateTimeFormat("fr", { weekday: "long", day: "numeric", month: "long" });

function escapeHTML(text) {
  return String(text ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[c]);
}

const categoryOf = (article) => TOPICS[article.topic]?.category ?? "geo";

function isSameDay(a, b) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function dayTitle(date) {
  if (!date) return "Plus ancien";
  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  if (isSameDay(date, today)) return "Aujourd'hui";
  if (isSameDay(date, yesterday)) return "Hier";
  const label = dayFmt.format(date);
  return label.charAt(0).toUpperCase() + label.slice(1);
}

function timeLabel(date) {
  if (!date) return "";
  if (!isSameDay(date, new Date())) return timeFmt.format(date);
  const minutes = Math.round((date - Date.now()) / 60000);
  if (minutes > -1) return "à l'instant";
  if (minutes > -60) return rtf.format(Math.min(minutes, 0), "minute");
  return rtf.format(Math.round(minutes / 60), "hour");
}

// --- Données ---

async function load({ force = false } = {}) {
  if (!force && state.data && Date.now() - state.loadedAt < STALE_AFTER) return;
  els.refresh.classList.add("spinning");
  try {
    const response = await fetch(`news.json?t=${Date.now()}`, { cache: "no-store" });
    if (!response.ok) throw new Error(response.status);
    const data = await response.json();
    for (const article of data.articles) {
      article.dateObj = article.date ? new Date(article.date) : null;
      article.category = categoryOf(article);
    }
    state.data = data;
    state.loadedAt = Date.now();
    render();
  } catch (error) {
    if (!state.data) {
      els.list.innerHTML = `<p class="status">Impossible de charger les actualités.<br>Vérifie ta connexion puis touche ↻.</p>`;
    }
  } finally {
    els.refresh.classList.remove("spinning");
  }
}

// --- Filtres ---

function scopedArticles() {
  const category = TABS[state.tab].category;
  return state.data.articles.filter((a) =>
    (!category || a.category === category) && (!state.topic || a.topic === state.topic));
}

function filteredArticles() {
  const query = state.query.trim().toLocaleLowerCase("fr");
  return scopedArticles().filter((a) =>
    (!state.source || a.source === state.source)
    && (!query || a.title.toLocaleLowerCase("fr").includes(query)
      || a.summary.toLocaleLowerCase("fr").includes(query)));
}

// --- Affichage ---

function renderHeader() {
  const tab = TABS[state.tab];
  els.title.textContent = tab.title;
  document.title = state.tab === "une" ? "Veille Monde" : `${tab.title} · Veille Monde`;
  document.documentElement.style.setProperty("--accent", `var(--${tab.category ?? "geo"})`);

  for (const link of document.querySelectorAll(".tabbar a")) {
    link.classList.toggle("on", link.dataset.tab === state.tab);
  }

  const chips = [];
  if (tab.category) {
    chips.push(`<button class="chip${state.topic ? "" : " on"}" data-topic="">Tout</button>`);
    for (const [key, topic] of Object.entries(TOPICS)) {
      if (topic.category !== tab.category) continue;
      chips.push(`<button class="chip${state.topic === key ? " on" : ""}" data-topic="${key}">${topic.title}</button>`);
    }
  }
  if (state.source) {
    chips.push(`<button class="chip source" data-clear-source>${escapeHTML(state.source)} ✕</button>`);
  }
  els.chips.innerHTML = chips.join("");
}

function renderSourceMenu() {
  const sources = [...new Set(scopedArticles().map((a) => a.source))].sort((a, b) => a.localeCompare(b, "fr"));
  if (state.source && !sources.includes(state.source)) state.source = null;
  els.select.innerHTML = [`<option value="">Toutes les sources</option>`]
    .concat(sources.map((s) => `<option value="${escapeHTML(s)}">${escapeHTML(s)}</option>`))
    .join("");
  els.select.value = state.source ?? "";
  els.select.parentElement.classList.toggle("active", Boolean(state.source));
}

function articleHTML(article, hero) {
  const date = article.dateObj;
  const meta = `<div class="meta ${article.category}"><b>${escapeHTML(article.source)}</b>${date ? ` · <span>${timeLabel(date)}</span>` : ""}</div>`;
  const image = article.image
    ? `<img class="thumb" src="${escapeHTML(article.image)}" alt="" loading="lazy" decoding="async" referrerpolicy="no-referrer" onerror="this.remove()">`
    : "";
  const link = `href="${escapeHTML(article.link)}" target="_blank" rel="noopener noreferrer"`;
  if (hero) {
    return `<a class="article hero" ${link}>${image}${meta}<h2 class="title">${escapeHTML(article.title)}</h2>${
      article.summary ? `<p class="summary">${escapeHTML(article.summary)}</p>` : ""}</a>`;
  }
  return `<a class="article" ${link}><div class="body">${meta}<h2 class="title">${escapeHTML(article.title)}</h2></div>${image}</a>`;
}

function renderList() {
  const articles = filteredArticles();
  if (!articles.length) {
    els.list.innerHTML = state.query
      ? `<p class="status">Aucun résultat pour « ${escapeHTML(state.query)} ».</p>`
      : `<p class="status">Aucun article pour le moment.</p>`;
    return;
  }

  // Le premier article avec photo parmi les plus récents passe en tête, en grand.
  const hero = state.query ? null : articles.slice(0, 5).find((a) => a.image);
  if (hero) {
    articles.splice(articles.indexOf(hero), 1);
    articles.unshift(hero);
  }
  const heroID = hero?.link;
  const html = [];
  let currentDay = null;
  for (const article of articles) {
    const day = dayTitle(article.dateObj);
    if (day !== currentDay) {
      html.push(`<h3 class="day">${day}</h3>`);
      currentDay = day;
    }
    html.push(articleHTML(article, article.link === heroID));
  }
  els.list.innerHTML = html.join("");
}

function renderFooter() {
  const { updated, failed } = state.data;
  const parts = [`Mis à jour à ${timeFmt.format(new Date(updated))}`];
  if (failed?.length) parts.push(`Indisponible : ${failed.map(escapeHTML).join(", ")}`);
  els.footer.innerHTML = parts.join("<br>");
}

function render() {
  // Le menu des sources passe en premier : il efface une source qui n'existe plus dans l'onglet.
  if (state.data) renderSourceMenu();
  renderHeader();
  if (!state.data) return;
  renderList();
  renderFooter();
}

// --- Navigation ---

function openTab(tab) {
  if (!TABS[tab]) tab = "une";
  if (tab !== state.tab) {
    state.tab = tab;
    state.topic = null;
    state.source = null;
  }
  render();
  window.scrollTo(0, 0);
}

window.addEventListener("hashchange", () => openTab(location.hash.slice(1)));

els.chips.addEventListener("click", (event) => {
  const chip = event.target.closest(".chip");
  if (!chip) return;
  if (chip.hasAttribute("data-clear-source")) {
    state.source = null;
  } else {
    state.topic = chip.dataset.topic || null;
  }
  render();
});

els.select.addEventListener("change", () => {
  state.source = els.select.value || null;
  render();
});

let searchTimer;
els.search.addEventListener("input", () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    state.query = els.search.value;
    renderList();
  }, 150);
});

els.refresh.addEventListener("click", () => load({ force: true }));

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") load();
});

// --- Démarrage ---

state.tab = TABS[location.hash.slice(1)] ? location.hash.slice(1) : "une";
render();
load({ force: true });

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("sw.js").catch(() => {});
}
