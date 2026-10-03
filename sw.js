/* Service worker — Bâtiments communaux de Pasly
   Permet d'ouvrir l'application sans réseau (chaufferie, cave, aire de jeux).
   - Page : réseau d'abord (les mises à jour arrivent normalement), copie locale si pas de réseau.
   - Bibliothèque Supabase figée et icônes : copie locale.
   - Données Supabase : JAMAIS mises en cache par ce fichier. */
const CACHE = 'pasly-v1';
const BIBLIO = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js';
const FICHIERS = ['./', './index.html', './apple-touch-icon.png', './favicon.png', BIBLIO];

self.addEventListener('install', ev => {
  ev.waitUntil(caches.open(CACHE).then(c => Promise.allSettled(FICHIERS.map(u => c.add(new Request(u, { cache:'reload' }))))));
  self.skipWaiting();
});
self.addEventListener('activate', ev => {
  ev.waitUntil(caches.keys().then(k => Promise.all(k.filter(x => x !== CACHE).map(x => caches.delete(x)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', ev => {
  const req = ev.request, u = new URL(req.url);
  if (req.method !== 'GET' || u.hostname.endsWith('supabase.co')) return;            // données : toujours le réseau
  if (req.mode === 'navigate'){
    ev.respondWith(fetch(req).then(r => { if (r.ok){ const c = r.clone(); caches.open(CACHE).then(x => x.put('./index.html', c)); } return r; })
      .catch(() => caches.match('./index.html')));
    return;
  }
  if (u.href === BIBLIO || u.origin === self.location.origin){
    ev.respondWith(caches.match(req).then(r => r || fetch(req).then(res => {
      if (res.ok){ const c = res.clone(); caches.open(CACHE).then(x => x.put(req, c)); }
      return res;
    })));
  }
});
