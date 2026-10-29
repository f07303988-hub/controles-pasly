-- =====================================================================
-- Signalements d'astreinte à valider (application des contrôles)
-- À exécuter une fois dans Supabase > SQL Editor (projet mairie-pasly),
-- après migration-astreinte.sql. Ne supprime aucune donnée, peut être relancé.
-- =====================================================================

-- Décision de la mairie sur chaque signalement d'astreinte
alter table public.astreinte_incidents add column if not exists tri text not null default 'a_valider';
alter table public.astreinte_incidents drop constraint if exists astreinte_tri_valeurs;
alter table public.astreinte_incidents add constraint astreinte_tri_valeurs check (tri in ('a_valider','transmis','ecarte'));
alter table public.astreinte_incidents add column if not exists tri_motif text;
alter table public.astreinte_incidents add column if not exists tri_le timestamptz;
alter table public.astreinte_incidents add column if not exists tri_par uuid references public.profils(id);
create index if not exists astreinte_incidents_tri_idx on public.astreinte_incidents (tri);

-- Les téléphones renvoient l'incident complet : la base garde le lien vers les Travaux
-- et la décision de la mairie, et marque « transmis » tout incident relié aux Travaux.
create or replace function public.astreinte_avant_ecriture() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  new.recu_le := clock_timestamp(); new.maj_par := auth.uid();
  if tg_op = 'UPDATE' then
    new.incident_id := coalesce(new.incident_id, old.incident_id);
    if new.tri is distinct from old.tri then new.tri_le := now(); new.tri_par := auth.uid(); end if;
  end if;
  if new.incident_id is not null and new.tri <> 'transmis' then
    new.tri := 'transmis'; new.tri_le := coalesce(new.tri_le, now()); new.tri_par := coalesce(new.tri_par, auth.uid());
  end if;
  return new;
end; $$;
revoke execute on function public.astreinte_avant_ecriture() from public, anon, authenticated;

-- Déjà reliés aux Travaux : marqués transmis
update public.astreinte_incidents set tri = 'transmis' where incident_id is not null and tri <> 'transmis';

-- Les signalements contiennent le nom et le téléphone des habitants : lecture réservée aux administrateurs et contributeurs
drop policy if exists "astreinte lecture" on public.astreinte_incidents;
create policy "astreinte lecture" on public.astreinte_incidents for select to authenticated using (mon_role() = any (array['admin','contributeur']));
drop policy if exists "astreinte fichiers lecture" on storage.objects;
create policy "astreinte fichiers lecture" on storage.objects for select to authenticated
  using (bucket_id = 'astreinte' and mon_role() = any (array['admin','contributeur']));
