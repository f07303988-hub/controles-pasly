// Création d'un compte depuis l'application (administrateurs uniquement).
// Le compte est créé confirmé, activé, avec le rôle choisi et un mot de passe provisoire
// que la personne devra remplacer à sa première connexion à l'application des contrôles.
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const rep = (corps: unknown, statut = 200) =>
  new Response(JSON.stringify(corps), { status: statut, headers: { ...CORS, "Content-Type": "application/json" } });

function motDePasse(): string {
  // Lisible à dicter : pas de 0/O, 1/l/I
  const a = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
  const o = crypto.getRandomValues(new Uint8Array(10));
  return Array.from(o, (x) => a[x % a.length]).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return rep({ erreur: "Méthode non autorisée" }, 405);
  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    // 1. Qui appelle ? Un administrateur actif uniquement.
    const jeton = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    if (!jeton) return rep({ erreur: "Connexion requise" }, 401);
    const { data: u, error: eu } = await admin.auth.getUser(jeton);
    if (eu || !u?.user) return rep({ erreur: "Session expirée : reconnectez-vous" }, 401);
    const { data: moi } = await admin.from("profils").select("role, actif").eq("id", u.user.id).maybeSingle();
    if (!moi || moi.role !== "admin" || moi.actif === false) return rep({ erreur: "Réservé aux administrateurs" }, 403);

    const b = await req.json().catch(() => ({}));

    // Nouveau mot de passe pour un compte existant (oubli, agent sans accès à l'application des contrôles)
    if (b.action === "mot_de_passe") {
      const id = String(b.id || "");
      if (!/^[0-9a-f-]{36}$/i.test(id)) return rep({ erreur: "Compte inconnu" }, 400);
      if (id === u.user.id) return rep({ erreur: "Changez votre propre mot de passe depuis Compte" }, 400);
      const { data: cible } = await admin.from("profils").select("email, nom, role").eq("id", id).maybeSingle();
      if (!cible) return rep({ erreur: "Compte inconnu" }, 404);
      const mdp = motDePasse();
      const { error: em } = await admin.auth.admin.updateUserById(id, { password: mdp });
      if (em) return rep({ erreur: "Modification impossible : " + em.message }, 500);
      await admin.from("profils").update({ doit_changer_mdp: cible.role !== "agent" }).eq("id", id);
      return rep({ ok: true, id, email: cible.email, nom: cible.nom, role: cible.role, motDePasse: mdp });
    }

    // 2. Données saisies
    const email = String(b.email || "").trim().toLowerCase();
    const nom = String(b.nom || "").trim().slice(0, 80);
    const role = String(b.role || "agent");
    if (!/^[^\s@<>"']+@[^\s@<>"']+\.[^\s@<>"']+$/.test(email)) return rep({ erreur: "Adresse e-mail invalide" }, 400);
    if (nom.length < 2) return rep({ erreur: "Indiquez le nom de la personne" }, 400);
    if (!["admin", "contributeur", "lecteur", "agent"].includes(role)) return rep({ erreur: "Rôle inconnu" }, 400);

    // 3. Création du compte (le profil est créé automatiquement par la base)
    const mdp = motDePasse();
    const { data: c, error: ec } = await admin.auth.admin.createUser({
      email, password: mdp, email_confirm: true, user_metadata: { nom },
    });
    if (ec || !c?.user) {
      const deja = /already|registered|exists/i.test(ec?.message || "");
      return rep({ erreur: deja ? "Un compte existe déjà avec cette adresse e-mail" : ("Création impossible : " + (ec?.message || "erreur inconnue")) }, deja ? 409 : 500);
    }
    // 4. Profil : nom, rôle, activé ; mot de passe à changer (sauf agent, qui n'a pas accès à l'application des contrôles)
    const { error: ep } = await admin.from("profils").upsert(
      { id: c.user.id, email, nom, role, actif: true, doit_changer_mdp: role !== "agent" }, { onConflict: "id" });
    if (ep) {
      await admin.auth.admin.deleteUser(c.user.id);   // pas de compte à moitié créé
      const contrainte = /role_check/.test(ep.message);
      return rep({ erreur: contrainte ? "Rôle « agent » pas encore installé : exécutez le script migration-role-agent.sql dans Supabase" : ("Profil non enregistré : " + ep.message) }, 500);
    }
    return rep({ ok: true, id: c.user.id, email, nom, role, motDePasse: mdp });
  } catch (e) {
    return rep({ erreur: "Erreur : " + (e instanceof Error ? e.message : String(e)) }, 500);
  }
});
