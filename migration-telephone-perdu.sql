-- =====================================================================
-- « Téléphone perdu » : déconnexion à distance de tous les appareils d'un compte
-- Utilisée uniquement par la fonction serveur creer-utilisateur (administrateur), jamais par les applis.
-- À exécuter une fois dans Supabase > SQL Editor (projet mairie-pasly). Ne supprime aucune donnée de la mairie.
-- =====================================================================
create or replace function public.revoquer_sessions(p_compte uuid) returns integer
language plpgsql security definer set search_path to '' as $$
declare n integer;
begin
  delete from auth.sessions where user_id = p_compte;              -- les jetons de renouvellement liés partent avec
  get diagnostics n = row_count;
  delete from auth.refresh_tokens where user_id = p_compte::text;   -- anciens jetons sans session
  delete from public.astreinte_abonnements where compte = p_compte; -- plus d'alertes sur ces appareils
  return n;
end; $$;
revoke execute on function public.revoquer_sessions(uuid) from public, anon, authenticated;
grant execute on function public.revoquer_sessions(uuid) to service_role;
