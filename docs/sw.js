// Permet d'ouvrir l'app hors connexion avec les dernières actualités téléchargées.
const CACHE = "veille-monde-v1";
const SHELL = ["./", "index.html", "style.css", "app.js", "manifest.webmanifest", "icons/icon-180.png", "icons/icon-192.png"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  if (event.request.method !== "GET" || url.origin !== location.origin) return;

  // Actualités et page : réseau d'abord, copie locale si hors ligne.
  if (url.pathname.endsWith("news.json") || event.request.mode === "navigate") {
    const key = url.pathname.endsWith("news.json") ? "news.json" : event.request;
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(key, copy));
          return response;
        })
        .catch(() => caches.match(key)),
    );
    return;
  }

  // Le reste (CSS, JS, icônes) : copie locale d'abord.
  event.respondWith(caches.match(event.request).then((hit) => hit || fetch(event.request)));
});
