-- =====================================================================
-- Module DECI (points d'eau incendie) — Contrôles périodiques Pasly
-- À exécuter une fois dans Supabase > SQL Editor (projet mairie-pasly).
-- Le script ne supprime aucune donnée et peut être relancé sans risque.
-- =====================================================================

-- Caractéristiques des points d'eau incendie (une ligne par équipement PEI)
create table if not exists public.equipement_pei (
  equipement_id uuid primary key references public.equipements(id) on delete cascade,
  numero text,
  type_pei text not null default 'poteau' check (type_pei in ('poteau','bouche','reserve_aerienne','reserve_enterree','citerne_souple','point_aspiration','autre')),
  statut_juridique text not null default 'public' check (statut_juridique in ('public','prive')),
  adresse text,
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  diametre_mm smallint check (diametre_mm between 1 and 1000),
  debit_requis_m3h numeric check (debit_requis_m3h is null or debit_requis_m3h >= 0),
  capacite_m3 numeric check (capacite_m3 is null or capacite_m3 >= 0),
  gestionnaire text,
  disponibilite text not null default 'disponible' check (disponibilite in ('disponible','restreint','indisponible')),
  disponibilite_date date,
  disponibilite_motif text,
  signale_sdis boolean not null default false,
  signale_sdis_date date,
  notes text,
  maj_par uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  constraint pei_coordonnees check ((latitude is null) = (longitude is null))
);
create unique index if not exists equipement_pei_numero_unique
  on public.equipement_pei (lower(btrim(numero))) where numero is not null and btrim(numero) <> '';

-- Mesures relevées lors d'un contrôle (débit, pression, volume, points vérifiés)
alter table public.controles add column if not exists mesures jsonb;
alter table public.controles drop constraint if exists controles_mesures_objet;
alter table public.controles add constraint controles_mesures_objet check (mesures is null or jsonb_typeof(mesures) = 'object');

-- Droits : lecture pour tous les comptes actifs, saisie pour admin et contributeurs, suppression pour admin
alter table public.equipement_pei enable row level security;
revoke all on public.equipement_pei from anon;
grant select, insert, update, delete on public.equipement_pei to authenticated;
drop policy if exists "compte actif" on public.equipement_pei;
drop policy if exists "pei lecture" on public.equipement_pei;
drop policy if exists "pei ajout" on public.equipement_pei;
drop policy if exists "pei modification" on public.equipement_pei;
drop policy if exists "pei suppression" on public.equipement_pei;
create policy "compte actif" on public.equipement_pei as restrictive for all to authenticated using (compte_actif()) with check (compte_actif());
create policy "pei lecture" on public.equipement_pei for select to authenticated using (true);
create policy "pei ajout" on public.equipement_pei for insert to authenticated with check (mon_role() = any (array['admin','contributeur']));
create policy "pei modification" on public.equipement_pei for update to authenticated
  using (mon_role() = any (array['admin','contributeur'])) with check (mon_role() = any (array['admin','contributeur']));
create policy "pei suppression" on public.equipement_pei for delete to authenticated using (mon_role() = 'admin');

-- Auteur et date de mise à jour fixés par la base
create or replace function public.pei_avant_ecriture() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  new.maj_par := auth.uid(); new.updated_at := now();
  return new;
end; $$;
drop trigger if exists pei_avant on public.equipement_pei;
create trigger pei_avant before insert or update on public.equipement_pei
  for each row execute function public.pei_avant_ecriture();

-- Journal général : ajoute la clé de la nouvelle table (le reste de la fonction est inchangé)
create or replace function public.journal_general() returns trigger
language plpgsql security definer set search_path to 'public' as $function$
declare
  k text; a jsonb; n jsonb;
  cle text := case tg_table_name when 'equipement_cycle_vie' then 'equipement_id' when 'equipement_pei' then 'equipement_id' when 'site_erp' then 'site_id' else 'id' end;
  v_id text; nom text := (select coalesce(nom, email) from public.profils where id = auth.uid());
begin
  if tg_op = 'DELETE' then
    v_id := to_jsonb(old) ->> cle;
    insert into public.journal(table_nom, ligne_id, action, ancienne_valeur, auteur, auteur_nom)
    values (tg_table_name, v_id, 'suppression', left((to_jsonb(old))::text, 2000), auth.uid(), nom);
    return old;
  end if;
  v_id := to_jsonb(new) ->> cle;
  if tg_op = 'INSERT' then
    insert into public.journal(table_nom, ligne_id, action, auteur, auteur_nom) values (tg_table_name, v_id, 'creation', auth.uid(), nom);
    return new;
  end if;
  a := to_jsonb(old); n := to_jsonb(new);
  for k in select jsonb_object_keys(n) loop
    continue when k in ('updated_at','created_at');
    if (a -> k) is distinct from (n -> k) then
      insert into public.journal(table_nom, ligne_id, action, champ, ancienne_valeur, nouvelle_valeur, auteur, auteur_nom)
      values (tg_table_name, v_id, 'modification', k, a ->> k, n ->> k, auth.uid(), nom);
    end if;
  end loop;
  return new;
end; $function$;
drop trigger if exists journal_general on public.equipement_pei;
create trigger journal_general after insert or update or delete on public.equipement_pei
  for each row execute function public.journal_general();

-- Site d'accueil des points d'eau (réseau public, hors bâtiments) et paramètres du module.
-- Périodicité des contrôles techniques : 3 ans (RDDECI de l'Aisne).
do $$
declare v_site uuid;
begin
  if not exists (select 1 from public.parametres where cle = 'deci') then
    insert into public.sites(nom, notes, ordre)
    values ('Défense incendie (points d''eau)',
            'Points d''eau incendie de la commune (DECI). Ranger ici l''arrêté communal DECI et les rapports du SDIS.', 20)
    returning id into v_site;
    insert into public.parametres(cle, valeur)
    values ('deci', jsonb_build_object('site_id', v_site, 'periodicite_ans', 3));
  end if;
end $$;
