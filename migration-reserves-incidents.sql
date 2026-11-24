-- =====================================================================
-- Réserves et incidents
-- Contrôles périodiques Pasly — projet Supabase « mairie-pasly »
-- 1. Commentaire de levée de réserve (modifiable par un contributeur)
-- 2. Lien entre un contrôle avec réserves et les incidents qu'il a fait naître
-- Le script ne supprime aucune donnée et peut être relancé sans risque.
-- =====================================================================

-- 1. Commentaire de levée
alter table public.controles add column if not exists commentaire_levee text;

-- La levée reste la seule modification permise à un non-administrateur
create or replace function public.controles_protection()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if auth.uid() is null or coalesce(public.mon_role(), '') = 'admin' then return new; end if;
  if (to_jsonb(new) - 'reserve_levee' - 'date_levee' - 'commentaire_levee')
     is distinct from (to_jsonb(old) - 'reserve_levee' - 'date_levee' - 'commentaire_levee') then
    raise exception 'Seul un administrateur peut corriger un contrôle déjà enregistré (seule la levée de réserve est permise).' using errcode = '42501';
  end if;
  return new;
end; $function$;
revoke all on function public.controles_protection() from public, anon, authenticated;
grant execute on function public.controles_protection() to service_role;

-- 2. Lien incidents <-> contrôles (un incident peut couvrir plusieurs contrôles, et l'inverse)
create table if not exists public.incident_controles (
  incident_id uuid not null references public.incidents(id) on delete cascade,
  controle_id uuid not null references public.controles(id) on delete cascade,
  cree_par uuid default auth.uid() references public.profils(id),
  created_at timestamptz not null default now(),
  primary key (incident_id, controle_id)
);
create index if not exists incident_controles_controle on public.incident_controles(controle_id);

alter table public.incident_controles enable row level security;
drop policy if exists "compte actif" on public.incident_controles;
create policy "compte actif" on public.incident_controles as restrictive for all to authenticated
  using (compte_actif()) with check (compte_actif());
drop policy if exists "pas agent" on public.incident_controles;
create policy "pas agent" on public.incident_controles as restrictive for all to authenticated
  using (coalesce(mon_role(), '') <> 'agent') with check (coalesce(mon_role(), '') <> 'agent');
drop policy if exists "liens lecture" on public.incident_controles;
create policy "liens lecture" on public.incident_controles as permissive for select to authenticated
  using (true);
drop policy if exists "liens ajout" on public.incident_controles;
create policy "liens ajout" on public.incident_controles as permissive for insert to authenticated
  with check (mon_role() = any (array['admin', 'contributeur']));
drop policy if exists "liens suppression" on public.incident_controles;
create policy "liens suppression" on public.incident_controles as permissive for delete to authenticated
  using (mon_role() = any (array['admin', 'contributeur']));
revoke all on public.incident_controles from anon;
grant select, insert, delete on public.incident_controles to authenticated;

-- Rattachement des incidents existants : même équipement, signalés le jour du contrôle avec réserves
insert into public.incident_controles (incident_id, controle_id, cree_par)
select i.id, c.id, null
from public.incidents i
join public.plans p on p.equipement_id = i.equipement_id
join public.controles c on c.plan_id = p.id
where c.resultat <> 'conforme' and c.date_realisation = i.date_signalement
on conflict do nothing;
