// Sauvegarde des données — Bâtiments communaux de Pasly.
//
// Enregistre une copie complète des données (toutes les tables, au format JSON)
// dans l'espace de fichiers privé « sauvegardes », supprime les copies de plus
// de 12 mois, puis envoie la copie par email :
//   - directement, si ce projet a un service d'envoi (secrets BREVO_API_KEY et
//     BREVO_SENDER_EMAIL), aux administrateurs ;
//   - sinon par le relais du projet « Planning Astreinte », qui détient la clé
//     d'envoi (fonction relais-sauvegarde ; adresse et jeton dans la table
//     cles_serveur, clé « relais_sauvegarde »). Le relais fixe lui-même le
//     destinataire.
//
// Deux appelants possibles :
//   - la tâche planifiée de la base, le 1er de chaque mois (clé interne vérifiée) ;
//   - un administrateur connecté (lancement à la main).
// Option { "test": true } : calcule la sauvegarde et en renvoie le résumé, sans
// rien enregistrer ni envoyer.
//
// Ne sont pas copiés : les secrets et données techniques, les comptes et mots de
// passe (gérés par Supabase) et les fichiers eux-mêmes (PDF, photos) — seule
// leur liste figure dans la sauvegarde. Voir migration-sauvegarde.sql.
import { createClient } from "jsr:@supabase/supabase-js@2";

const ESPACE = "sauvegardes";
const CONSERVATION_JOURS = 366;
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const rep = (corps: unknown, statut = 200) =>
  new Response(JSON.stringify(corps), { status: statut, headers: { ...CORS, "Content-Type": "application/json" } });

function enBase64(octets: Uint8Array): string {
  let s = "";
  for (let i = 0; i < octets.length; i += 0x8000) s += String.fromCharCode(...octets.subarray(i, i + 0x8000));
  return btoa(s);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return rep({ erreur: "Méthode non autorisée" }, 405);
  try {
    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false, autoRefreshToken: false } });

    // Appelant : la tâche planifiée (clé interne) ou un administrateur connecté.
    const cle = await db.from("cles_serveur").select("valeur").eq("cle", "entretien").maybeSingle();
    const attendu = cle.data?.valeur?.v;
    const planifie = !!attendu && req.headers.get("x-cle-entretien") === attendu;
    if (!planifie) {
      const jeton = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
      const { data: u } = await db.auth.getUser(jeton);
      if (!u?.user) return rep({ erreur: "Connexion requise" }, 401);
      const { data: moi } = await db.from("profils").select("role, actif").eq("id", u.user.id).maybeSingle();
      if (!moi || moi.actif === false || moi.role !== "admin") return rep({ erreur: "Réservé à l'administrateur" }, 403);
    }
    const b = await req.json().catch(() => ({}));

    // Lecture de toutes les données en une fois (fonction de la base).
    const { data, error } = await db.rpc("sauvegarde_donnees");
    if (error) throw new Error(`Lecture des données : ${error.message}`);
    const tables = (data?.tables || {}) as Record<string, unknown[]>;
    const lignes = Object.values(tables).reduce((n, l) => n + (Array.isArray(l) ? l.length : 0), 0);
    const nonVides = Object.entries(tables).filter(([, l]) => Array.isArray(l) && l.length)
      .map(([t, l]) => `${t} : ${l.length}`).join(" · ") || "aucune donnée";
    const octets = new TextEncoder().encode(JSON.stringify(data, null, 1));
    const jour = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Paris" });      // AAAA-MM-JJ
    const nom = `sauvegarde-batiments-pasly-${jour}.json`;
    const cleEmail = Deno.env.get("BREVO_API_KEY") || "";
    const expediteur = Deno.env.get("BREVO_SENDER_EMAIL") || "";
    const resume = {
      tables: Object.keys(tables).length, lignes, fichiers_listes: (data?.fichiers || []).length,
      taille: octets.length, detail: nonVides,
    };

    const { data: cleRelais } = await db.from("cles_serveur").select("valeur").eq("cle", "relais_sauvegarde").maybeSingle();
    const relais = cleRelais?.valeur?.v && cleRelais?.valeur?.url ? cleRelais.valeur as { v: string; url: string } : null;

    if (b.test) return rep({ test: true, ...resume, email: cleEmail && expediteur ? "configuré" : relais ? "relais configuré" : "non configuré" });

    // 1. Copie dans l'espace privé (une par jour : relancer le même jour remplace la copie).
    const chemin = `${jour.slice(0, 4)}/${nom}`;
    const depot = await db.storage.from(ESPACE).upload(chemin, octets, { contentType: "application/json", upsert: true });
    if (depot.error) throw new Error(`Enregistrement de la copie : ${depot.error.message}`);

    // 2. Suppression des copies de plus de 12 mois.
    let supprimees = 0;
    const limite = new Date(Date.now() - CONSERVATION_JOURS * 86400000).toISOString().slice(0, 10);
    const annees = await db.storage.from(ESPACE).list("", { limit: 100 });
    for (const a of annees.data || []) {
      if (!/^\d{4}$/.test(a.name)) continue;
      const copies = await db.storage.from(ESPACE).list(a.name, { limit: 1000 });
      const perimees = (copies.data || [])
        .filter((f) => { const m = f.name.match(/(\d{4}-\d{2}-\d{2})\.json$/); return !!m && m[1] < limite; })
        .map((f) => `${a.name}/${f.name}`);
      if (perimees.length) { const rm = await db.storage.from(ESPACE).remove(perimees); if (!rm.error) supprimees += perimees.length; }
    }

    // 3. Envoi par email : directement si ce projet a un service d'envoi, sinon par le relais.
    let email = "non configuré";
    if (cleEmail && expediteur) {
      const { data: admins } = await db.from("profils").select("email, nom").eq("role", "admin").eq("actif", true);
      const destinataires = (admins || []).filter((a) => a.email).map((a) => ({ email: a.email, name: a.nom || a.email }));
      if (!destinataires.length) email = "aucun administrateur avec une adresse";
      else {
        const horodatage = new Date().toLocaleString("fr-FR", { timeZone: "Europe/Paris" });
        const r = await fetch("https://api.brevo.com/v3/smtp/email", {
          method: "POST",
          headers: { "api-key": cleEmail, "Content-Type": "application/json", Accept: "application/json" },
          body: JSON.stringify({
            sender: { name: "Commune de Pasly — Bâtiments", email: expediteur },
            to: destinataires,
            subject: `Sauvegarde mensuelle — Bâtiments communaux (${jour})`,
            textContent: `Sauvegarde automatique du ${horodatage}.\n\n${nonVides}\n\n` +
              `Le fichier joint (format JSON) permet de restaurer les données. Il ne contient pas les fichiers ` +
              `(PDF, photos), dont il donne seulement la liste, ni les comptes.\n` +
              `Il contient des données personnelles : conservez-le en lieu sûr et supprimez les copies de plus d'un an.`,
            // Brevo refuse l'extension .json : même contenu, en .txt.
            attachment: [{ name: nom.replace(/\.json$/, "-json.txt"), content: enBase64(octets) }],
          }),
        });
        email = r.ok ? `envoyé à ${destinataires.length} administrateur${destinataires.length > 1 ? "s" : ""}` : `échec (${r.status})`;
        await r.body?.cancel();
      }
    } else if (relais) {
      try {
        const r = await fetch(relais.url, {
          method: "POST",
          headers: { "Content-Type": "application/json", "x-jeton-relais": relais.v },
          body: JSON.stringify({ jour, resume: nonVides, contenu_base64: enBase64(octets) }),
        });
        email = r.ok ? "envoyé par le relais" : `échec du relais (${r.status})`;
        await r.body?.cancel();
      } catch { email = "relais injoignable"; }
    }

    return rep({ ok: true, copie: chemin, ...resume, copies_supprimees: supprimees, email });
  } catch (e) {
    return rep({ erreur: e instanceof Error ? e.message : String(e) }, 500);
  }
});
