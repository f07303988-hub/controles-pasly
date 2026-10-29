-- =====================================================================
-- Rôle « agent » : signalements dans Pasly Astreinte uniquement.
-- Un agent n'a AUCUN accès à l'application des contrôles (bâtiments, travaux, factures…).
-- À exécuter une fois dans Supabase > SQL Editor (projet mairie-pasly). Ne supprime aucune donnée.
-- =====================================================================
alter table public.profils drop constraint if exists profils_role_check;
alter table public.profils add constraint profils_role_check check (role = any (array['admin','contributeur','lecteur','agent']));

-- 1. Toutes les tables de l'application des contrôles : fermées aux agents
do $$
declare t text;
begin
  for t in select c.relname from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
           and c.relname not in ('astreinte_incidents','parametres','profils')
  loop
    execute format('drop policy if exists "pas agent" on public.%I', t);
    execute format('create policy "pas agent" on public.%I as restrictive for all to authenticated using (coalesce(public.mon_role(), '''') <> ''agent'') with check (coalesce(public.mon_role(), '''') <> ''agent'')', t);
  end loop;
end $$;

-- 2. Paramètres : un agent ne lit que les réglages d'astreinte et le planning
drop policy if exists "pas agent" on public.parametres;
create policy "pas agent" on public.parametres as restrictive for all to authenticated
  using (coalesce(mon_role(), '') <> 'agent' or cle = any (array['astreinte_config','planning_astreinte']))
  with check (coalesce(mon_role(), '') <> 'agent');
drop policy if exists "parametres astreinte lecture" on public.parametres;
create policy "parametres astreinte lecture" on public.parametres as restrictive for select to authenticated
  using ((cle <> all (array['astreinte_config','planning_astreinte'])) or mon_role() = any (array['admin','contributeur','lecteur','agent']));

-- 3. Profils : un agent ne voit que le sien
drop policy if exists "pas agent" on public.profils;
create policy "pas agent" on public.profils as restrictive for select to authenticated
  using (coalesce(mon_role(), '') <> 'agent' or id = auth.uid());

-- 4. Fichiers : un agent n'accède qu'aux photos d'astreinte
drop policy if exists "pas agent" on storage.objects;
create policy "pas agent" on storage.objects as restrictive for all to authenticated
  using (coalesce(public.mon_role(), '') <> 'agent' or bucket_id = 'astreinte')
  with check (coalesce(public.mon_role(), '') <> 'agent' or bucket_id = 'astreinte');
drop policy if exists "astreinte fichiers ajout" on storage.objects;
create policy "astreinte fichiers ajout" on storage.objects for insert to authenticated
  with check (bucket_id = 'astreinte' and mon_role() = any (array['admin','contributeur','lecteur','agent']));

-- 5. Carnet d'astreinte : l'agent signale comme un lecteur (mode signalement)
drop policy if exists "astreinte ajout" on public.astreinte_incidents;
drop policy if exists "astreinte modification" on public.astreinte_incidents;
create policy "astreinte ajout" on public.astreinte_incidents for insert to authenticated
  with check (mon_role() = any (array['admin','contributeur','lecteur','agent']));
create policy "astreinte modification" on public.astreinte_incidents for update to authenticated
  using (mon_role() = any (array['admin','contributeur']) or (mon_role() = any (array['lecteur','agent']) and cree_par = auth.uid()))
  with check (mon_role() = any (array['admin','contributeur']) or (mon_role() = any (array['lecteur','agent']) and cree_par = auth.uid()));

create or replace function public.astreinte_avant_ecriture() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if tg_op = 'INSERT' then new.cree_par := auth.uid(); else new.cree_par := old.cree_par; end if;
  if mon_role() = any (array['lecteur','agent']) then
    if tg_op = 'INSERT' and (new.statut <> 'NOUVEAU' or new.incident_id is not null) then
      raise exception 'Mode signalement : un nouvel incident doit avoir le statut Nouveau';
    end if;
    if tg_op = 'UPDATE' and (old.cree_par is distinct from auth.uid() or new.statut <> old.statut
        or new.incident_id is distinct from old.incident_id) then
      raise exception 'Mode signalement : seul l''auteur peut compléter son incident, sans changer le statut';
    end if;
  end if;
  new.recu_le := clock_timestamp(); new.maj_par := auth.uid();
  return new;
end; $$;
revoke execute on function public.astreinte_avant_ecriture() from public, anon, authenticated;
