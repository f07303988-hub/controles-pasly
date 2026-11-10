-- Sauvegarde mensuelle automatique des données.
--
-- Le 1er de chaque mois, la fonction serveur « sauvegarde » enregistre une
-- copie complète des données (toutes les tables, au format JSON) dans
-- l'espace de fichiers privé « sauvegardes », lisible par l'administrateur
-- seulement, et l'envoie par email si un service d'envoi est configuré.
-- Les copies de plus de 12 mois sont supprimées.
--
-- Envoi par email : ce projet n'ayant pas de service d'envoi, la copie est
-- confiée au relais du projet « Planning Astreinte » (fonction
-- relais-sauvegarde), qui fixe lui-même le destinataire. L'adresse du relais
-- et le jeton sont dans cles_serveur (clé « relais_sauvegarde ») ; le jeton
-- a été créé dans la base et n'est écrit nulle part ailleurs — le relais
-- n'en conserve que l'empreinte.
--
-- Ne sont pas copiés : les secrets et données techniques (clés du serveur,
-- abonnements des téléphones, mémoire des alertes), les comptes et mots de
-- passe (gérés par Supabase), et les fichiers eux-mêmes (PDF, photos) —
-- seule leur liste figure dans la sauvegarde.

-- 1. Lecture de toutes les données en une fois. Les tables sont découvertes
--    automatiquement : une table ajoutée plus tard est sauvegardée d'office.
create or replace function public.sauvegarde_donnees()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_exclues text[] := array['cles_serveur', 'astreinte_abonnements', 'astreinte_alertes_envoyees'];
  v_tables jsonb := '{}'::jsonb;
  v_lignes jsonb;
  r record;
begin
  for r in
    select c.relname from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname <> all (v_exclues)
    order by c.relname
  loop
    execute format('select coalesce(jsonb_agg(to_jsonb(t)), ''[]''::jsonb) from public.%I t', r.relname) into v_lignes;
    v_tables := v_tables || jsonb_build_object(r.relname, v_lignes);
  end loop;
  return jsonb_build_object(
    'application', 'Bâtiments communaux de Pasly',
    'date', now(),
    'tables', v_tables,
    'tables_exclues', to_jsonb(v_exclues),
    'fichiers', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'espace', o.bucket_id, 'chemin', o.name,
        'taille', (o.metadata->>'size')::bigint, 'cree_le', o.created_at) order by o.bucket_id, o.name), '[]'::jsonb)
      from storage.objects o where o.bucket_id <> 'sauvegardes'));
end
$fn$;

-- Réservée au serveur : ni les comptes connectés ni les visiteurs ne peuvent l'appeler.
revoke all on function public.sauvegarde_donnees() from public, anon, authenticated;
grant execute on function public.sauvegarde_donnees() to service_role;

-- 2. Espace de fichiers privé pour les copies. Seul le serveur y écrit ;
--    seul l'administrateur peut les lire.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('sauvegardes', 'sauvegardes', false, 52428800, array['application/json'])
on conflict (id) do nothing;

create policy "sauvegardes lecture" on storage.objects for select to authenticated
  using (bucket_id = 'sauvegardes' and mon_role() = 'admin');

-- 3. Tâche planifiée : le 1er de chaque mois, tôt le matin. La clé interne
--    est lue dans la base au moment de l'appel, jamais écrite ici.
select cron.schedule('sauvegarde-mensuelle', '7 4 1 * *', $cron$
  select net.http_post(
    url := 'https://idswkljjaoajhevgsnfh.supabase.co/functions/v1/sauvegarde',
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'x-cle-entretien', (select valeur->>'v' from public.cles_serveur where cle = 'entretien')),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000)
$cron$);
