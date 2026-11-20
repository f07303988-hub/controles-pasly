-- =====================================================================
-- Module EPI (équipements de protection individuelle des agents)
-- Contrôles périodiques Pasly — projet Supabase « mairie-pasly »
-- À exécuter une fois dans Supabase > SQL Editor.
-- Le script ne supprime aucune donnée et peut être relancé sans risque.
-- =====================================================================

-- Agents dotés (indépendant des comptes de l'application)
create table if not exists public.epi_agents (
  id uuid primary key default gen_random_uuid(),
  nom text not null check (length(btrim(nom)) > 0),
  prenom text,
  fonction text,
  date_entree date,
  taille_chaussures text,
  taille_haut text,
  taille_bas text,
  taille_gants text,
  notes text,
  actif boolean not null default true,
  cree_par uuid default auth.uid() references public.profils(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Catalogue des articles (durée de vie, quantité de dotation)
create table if not exists public.epi_articles (
  id uuid primary key default gen_random_uuid(),
  libelle text not null check (length(btrim(libelle)) > 0),
  categorie text not null default 'autre' check (categorie in ('pieds','corps','haute_visibilite','mains','tete','yeux','auditif','respiratoire','antichute','autre')),
  norme text,
  duree_vie_mois smallint check (duree_vie_mois is null or duree_vie_mois between 1 and 240),   -- vide : remplacement à l'usure
  base_duree text not null default 'perception' check (base_duree in ('perception','fabrication')),
  quantite_dotation smallint not null default 1 check (quantite_dotation between 0 and 20),     -- 0 : à la demande
  rappel_jours smallint not null default 30 check (rappel_jours between 0 and 365),
  notes text,
  ordre integer not null default 0,
  actif boolean not null default true,
  cree_par uuid default auth.uid() references public.profils(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists epi_articles_libelle_unique on public.epi_articles (lower(btrim(libelle)));

-- Remises d'EPI aux agents
create table if not exists public.epi_dotations (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references public.epi_agents(id) on delete restrict,
  article_id uuid not null references public.epi_articles(id) on delete restrict,
  date_perception date not null,
  quantite smallint not null default 1 check (quantite between 1 and 20),
  taille text,
  marque_modele text,
  date_fabrication date,
  date_renouvellement date,            -- vide : calculée (perception ou fabrication + durée de vie)
  cout_ttc numeric check (cout_ttc is null or cout_ttc >= 0),
  remis_par text,
  statut text not null default 'en_service' check (statut in ('en_service','remplace','perdu','use','rendu')),
  date_fin date,
  motif_fin text,
  notes text,
  cree_par uuid default auth.uid() references public.profils(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint epi_dotations_fin check (date_fin is null or date_fin >= date_perception),
  constraint epi_dotations_fabrication check (date_fabrication is null or date_fabrication <= date_perception)
);
create index if not exists epi_dotations_agent on public.epi_dotations (agent_id);
create index if not exists epi_dotations_article on public.epi_dotations (article_id);

-- Échéances calculées (lecture avec les droits de la personne connectée)
create or replace view public.v_epi_echeances with (security_invoker = true) as
select d.id, d.agent_id, d.article_id, d.date_perception, d.statut,
  trim(coalesce(g.prenom, '') || ' ' || g.nom) as agent, a.libelle as article, a.rappel_jours,
  coalesce(d.date_renouvellement,
    case when a.duree_vie_mois is null then null
         when a.base_duree = 'fabrication' and d.date_fabrication is not null then (d.date_fabrication + make_interval(months => a.duree_vie_mois))::date
         else (d.date_perception + make_interval(months => a.duree_vie_mois))::date end) as echeance
from public.epi_dotations d
join public.epi_agents g on g.id = d.agent_id
join public.epi_articles a on a.id = d.article_id
where d.statut = 'en_service' and g.actif;

-- Auteur et dates fixés par la base
create or replace function public.epi_avant_ecriture() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if tg_op = 'INSERT' then new.cree_par := auth.uid(); new.created_at := now();
  else new.cree_par := old.cree_par; new.created_at := old.created_at; end if;
  new.updated_at := now();
  return new;
end; $$;

do $$
declare t text;
begin
  foreach t in array array['epi_agents','epi_articles','epi_dotations'] loop
    execute format('drop trigger if exists epi_avant on public.%I', t);
    execute format('create trigger epi_avant before insert or update on public.%I for each row execute function public.epi_avant_ecriture()', t);
    execute format('drop trigger if exists journal_general on public.%I', t);
    execute format('create trigger journal_general after insert or update or delete on public.%I for each row execute function public.journal_general()', t);

    -- Droits : lecture pour les comptes actifs (sauf « agent »), saisie admin et contributeurs, suppression admin
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('drop policy if exists "compte actif" on public.%I', t);
    execute format('drop policy if exists "pas agent" on public.%I', t);
    execute format('drop policy if exists "epi lecture" on public.%I', t);
    execute format('drop policy if exists "epi ajout" on public.%I', t);
    execute format('drop policy if exists "epi modification" on public.%I', t);
    execute format('drop policy if exists "epi suppression" on public.%I', t);
    execute format('create policy "compte actif" on public.%I as restrictive for all to authenticated using (compte_actif()) with check (compte_actif())', t);
    execute format('create policy "pas agent" on public.%I as restrictive for all to authenticated using (coalesce(mon_role(), '''') <> ''agent'') with check (coalesce(mon_role(), '''') <> ''agent'')', t);
    execute format('create policy "epi lecture" on public.%I for select to authenticated using (true)', t);
    execute format('create policy "epi ajout" on public.%I for insert to authenticated with check (mon_role() = any (array[''admin'',''contributeur'']))', t);
    execute format('create policy "epi modification" on public.%I for update to authenticated using (mon_role() = any (array[''admin'',''contributeur''])) with check (mon_role() = any (array[''admin'',''contributeur'']))', t);
    execute format('create policy "epi suppression" on public.%I for delete to authenticated using (mon_role() = ''admin'')', t);
  end loop;
end $$;
revoke all on public.v_epi_echeances from anon;
grant select on public.v_epi_echeances to authenticated;

-- Catalogue de départ (durées indicatives, à ajuster selon les notices des fabricants)
insert into public.epi_articles (libelle, categorie, norme, duree_vie_mois, base_duree, quantite_dotation, rappel_jours, ordre, notes) values
  ('Chaussures de sécurité',            'pieds',            'EN ISO 20345 (S3)', 12,   'perception',  1, 30, 10, null),
  ('Bottes de sécurité',                'pieds',            'EN ISO 20345',      24,   'perception',  1, 30, 20, null),
  ('Pantalon de travail',               'corps',            null,                12,   'perception',  2, 30, 30, null),
  ('Veste de travail',                  'corps',            null,                12,   'perception',  2, 30, 40, null),
  ('Parka d''hiver',                    'corps',            'EN 342',            36,   'perception',  1, 30, 50, null),
  ('Vêtement de pluie',                 'corps',            'EN 343',            24,   'perception',  1, 30, 60, null),
  ('Gilet haute visibilité',            'haute_visibilite', 'EN ISO 20471',      24,   'perception',  1, 30, 70, 'Ou selon le nombre maximal de lavages indiqué par le fabricant.'),
  ('Gants de manutention',              'mains',            'EN 388',            null, 'perception',  0, 30, 80, 'Remplacés à l''usure.'),
  ('Lunettes de protection',            'yeux',             'EN 166',            null, 'perception',  1, 30, 90, 'Remplacées à l''usure ou si rayées.'),
  ('Protections auditives',             'auditif',          'EN 352',            null, 'perception',  1, 30, 100, 'Bouchons : consommable. Casque antibruit : selon notice.'),
  ('Casque de chantier',                'tete',             'EN 397',            48,   'fabrication', 1, 60, 110, 'Durée à vérifier sur la notice du fabricant ; à remplacer après tout choc.'),
  ('Harnais antichute',                 'antichute',        'EN 361',            120,  'fabrication', 0, 60, 120, 'Vérification périodique annuelle obligatoire ; durée selon notice.')
on conflict do nothing;

-- La fonction de déclencheur n'est pas appelable directement
revoke execute on function public.epi_avant_ecriture() from public, anon, authenticated;
