-- =====================================================================
-- Bâtiments communaux de Pasly — schéma complet de la base « mairie-pasly »
-- =====================================================================
-- Photographie de la structure de la base Supabase, générée le 2026-11-10
-- à partir de la base en service. Elle permet de reconstruire la base sur
-- un projet Supabase vierge (éditeur SQL), dans l'ordre du fichier.
--
-- CE FICHIER NE CONTIENT NI DONNÉE NI SECRET : uniquement la structure
-- (tables, fonctions, déclencheurs, règles d'accès, espaces de fichiers,
-- tâches planifiées). Les données se restaurent à partir d'une sauvegarde
-- (voir supabase/functions/sauvegarde).
--
-- À refaire à la main après une reconstruction :
--   * extensions pg_cron et pg_net (Database > Extensions) avant la section 15 ;
--   * la clé interne des tâches de nuit :
--       insert into public.cles_serveur (cle, valeur)
--       values ('entretien', jsonb_build_object('v', encode(gen_random_bytes(32), 'hex')));
--     (les clés des alertes téléphone se recréent seules au premier usage) ;
--   * les fonctions serveur du dossier supabase/functions (à déployer) ;
--   * les réglages de connexion (Authentication) et les comptes.
--
-- Après toute modification de structure, régénérer ce fichier.
-- =====================================================================

set check_function_bodies = off;

-- ---------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------

create table public.astreinte_abonnements (
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  compte uuid,
  appareil text,
  cree_le timestamp with time zone default now() not null,
  vu_le timestamp with time zone default now() not null
);

create table public.astreinte_alertes_envoyees (
  incident uuid not null,
  le timestamp with time zone default now() not null,
  destinataires integer
);

create table public.astreinte_incidents (
  uuid uuid not null,
  numero text not null,
  statut text not null,
  urgence text,
  categorie text,
  adresse text,
  latitude double precision,
  longitude double precision,
  donnees jsonb not null,
  cree_le timestamp with time zone not null,
  maj_le timestamp with time zone not null,
  recu_le timestamp with time zone default now() not null,
  maj_par uuid default auth.uid(),
  incident_id uuid,
  tri text default 'a_valider'::text not null,
  tri_motif text,
  tri_le timestamp with time zone,
  tri_par uuid,
  cree_par uuid default auth.uid(),
  clos_le timestamp with time zone
);

create table public.budget_historique (
  id bigint generated always as identity not null,
  objet_type text not null,
  objet_id uuid not null,
  action text not null,
  champ text,
  ancienne_valeur text,
  nouvelle_valeur text,
  auteur uuid,
  auteur_nom text,
  created_at timestamp with time zone default now() not null
);

create table public.cles_serveur (
  cle text not null,
  valeur jsonb not null,
  cree_le timestamp with time zone default now() not null
);

create table public.commission_prescriptions (
  id uuid default gen_random_uuid() not null,
  visite_id uuid not null,
  texte text not null,
  echeance date,
  levee boolean default false not null,
  date_levee date,
  observations text,
  intervention_id uuid,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null
);

create table public.commission_visites (
  id uuid default gen_random_uuid() not null,
  site_id uuid not null,
  date_visite date not null,
  nature text default 'periodique'::text not null,
  avis text default 'sans_avis'::text not null,
  observations text,
  prochaine_visite date,
  chemin text,
  nom_fichier text,
  taille_octets bigint,
  empreinte_sha256 text,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null
);

create table public.controle_groupes (
  id uuid default gen_random_uuid() not null,
  date_realisation date not null,
  intervenant text,
  prestataire text,
  observations text,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null
);

create table public.controles (
  id uuid default gen_random_uuid() not null,
  plan_id uuid not null,
  date_realisation date not null,
  intervenant text,
  resultat text not null,
  observations text,
  reserve_levee boolean default false not null,
  date_levee date,
  saisi_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null,
  groupe_id uuid,
  mesures jsonb
);

create table public.depenses (
  id uuid default gen_random_uuid() not null,
  site_id uuid not null,
  equipement_id uuid,
  objet text not null,
  nature_depense text default 'autre'::text not null,
  exercice smallint,
  prestataire_id uuid,
  estimation_ht numeric(12,2),
  estimation_ttc numeric(12,2),
  devis_ht numeric(12,2),
  devis_ttc numeric(12,2),
  engage_ht numeric(12,2),
  engage_ttc numeric(12,2),
  date_engagement date,
  notes text,
  annulee boolean default false not null,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.documents (
  id uuid default gen_random_uuid() not null,
  controle_id uuid not null,
  chemin text not null,
  nom text,
  type text,
  created_at timestamp with time zone default now() not null,
  taille_octets bigint,
  empreinte_sha256 text
);

create table public.equipement_cycle_vie (
  equipement_id uuid not null,
  annee_mise_en_service smallint,
  date_mise_en_service date,
  duree_vie_ans smallint,
  duree_vie_source text,
  etat text default 'non_evalue'::text not null,
  etat_date date,
  etat_commentaire text,
  cout_remplacement_ht numeric(12,2),
  cout_remplacement_ttc numeric(12,2),
  cout_source text,
  cout_date date,
  maj_par uuid default auth.uid(),
  updated_at timestamp with time zone default now() not null
);

create table public.equipement_pei (
  equipement_id uuid not null,
  numero text,
  type_pei text default 'poteau'::text not null,
  statut_juridique text default 'public'::text not null,
  adresse text,
  latitude double precision,
  longitude double precision,
  diametre_mm smallint,
  debit_requis_m3h numeric,
  capacite_m3 numeric,
  gestionnaire text,
  disponibilite text default 'disponible'::text not null,
  disponibilite_date date,
  disponibilite_motif text,
  signale_sdis boolean default false not null,
  signale_sdis_date date,
  notes text,
  maj_par uuid default auth.uid(),
  updated_at timestamp with time zone default now() not null
);

create table public.equipements (
  id uuid default gen_random_uuid() not null,
  site_id uuid not null,
  nom text not null,
  categorie text,
  localisation text,
  marque text,
  modele text,
  numero_serie text,
  notes text,
  actif boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table public.exercices_securite (
  id uuid default gen_random_uuid() not null,
  site_id uuid not null,
  date_exercice date not null,
  type text default 'evacuation'::text not null,
  intitule text,
  participants text,
  duree_minutes integer,
  observations text,
  anomalies text,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null
);

create table public.factures (
  id uuid default gen_random_uuid() not null,
  intervention_id uuid,
  depense_id uuid,
  prestataire_id uuid,
  reference text,
  date_facture date not null,
  exercice smallint not null,
  montant_ht numeric(12,2),
  taux_tva numeric(5,2),
  montant_tva numeric(12,2),
  montant_ttc numeric(12,2),
  intervention_document_id uuid,
  chemin text,
  nom_fichier text,
  paiement_statut text default 'non_renseigne'::text not null,
  date_paiement date,
  paiement_reference text,
  notes text,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  taille_octets bigint,
  empreinte_sha256 text
);

create table public.groupe_documents (
  id uuid default gen_random_uuid() not null,
  groupe_id uuid not null,
  chemin text not null,
  nom text,
  type text,
  taille_octets bigint,
  empreinte_sha256 text,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null
);

create table public.incident_documents (
  id uuid default gen_random_uuid() not null,
  incident_id uuid not null,
  type text default 'autre'::text not null,
  chemin text not null,
  nom text,
  mime text,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null,
  taille_octets bigint,
  empreinte_sha256 text
);

create table public.incident_historique (
  id bigint generated always as identity not null,
  incident_id uuid not null,
  action text not null,
  champ text,
  ancienne_valeur text,
  nouvelle_valeur text,
  auteur uuid,
  auteur_nom text,
  created_at timestamp with time zone default now() not null
);

create table public.incidents (
  id uuid default gen_random_uuid() not null,
  site_id uuid not null,
  equipement_id uuid,
  titre text not null,
  description text,
  categorie text not null,
  priorite text default 'normale'::text not null,
  statut text default 'nouveau'::text not null,
  date_signalement date default CURRENT_DATE not null,
  signale_par text,
  responsable text,
  entreprise text,
  devis_montant numeric(12,2),
  devis_reference text,
  facture_montant numeric(12,2),
  facture_reference text,
  date_resolution date,
  date_cloture date,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.intervention_commentaires (
  id uuid default gen_random_uuid() not null,
  intervention_id uuid not null,
  texte text not null,
  auteur uuid default auth.uid(),
  auteur_nom text,
  created_at timestamp with time zone default now() not null
);

create table public.intervention_documents (
  id uuid default gen_random_uuid() not null,
  intervention_id uuid not null,
  type text default 'autre'::text not null,
  chemin text not null,
  nom text,
  mime text,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null,
  taille_octets bigint,
  empreinte_sha256 text
);

create table public.intervention_historique (
  id bigint generated always as identity not null,
  intervention_id uuid not null,
  action text not null,
  champ text,
  ancienne_valeur text,
  nouvelle_valeur text,
  auteur uuid,
  auteur_nom text,
  created_at timestamp with time zone default now() not null
);

create table public.interventions (
  id uuid default gen_random_uuid() not null,
  incident_id uuid,
  nature text generated always as (
CASE
    WHEN (incident_id IS NULL) THEN 'preventive'::text
    ELSE 'corrective'::text
END) stored,
  site_id uuid not null,
  equipement_id uuid,
  objet text not null,
  description text,
  responsable_id uuid,
  prestataire_id uuid,
  statut text default 'a_planifier'::text not null,
  date_prevue_debut date,
  date_prevue_fin date,
  date_debut_reelle date,
  date_fin_reelle date,
  estimation_ht numeric(12,2),
  estimation_ttc numeric(12,2),
  devis_ht numeric(12,2),
  devis_ttc numeric(12,2),
  cout_reel_ht numeric(12,2),
  cout_reel_ttc numeric(12,2),
  compte_rendu text,
  date_cloture timestamp with time zone,
  cloture_par uuid,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  exercice smallint,
  nature_depense text,
  engage_ht numeric(12,2),
  engage_ttc numeric(12,2),
  date_engagement date
);

create table public.journal (
  id bigint generated always as identity not null,
  table_nom text not null,
  ligne_id text not null,
  action text not null,
  champ text,
  ancienne_valeur text,
  nouvelle_valeur text,
  auteur uuid,
  auteur_nom text,
  created_at timestamp with time zone default now() not null
);

create table public.parametres (
  cle text not null,
  valeur jsonb not null,
  updated_at timestamp with time zone default now() not null
);

create table public.plans (
  id uuid default gen_random_uuid() not null,
  equipement_id uuid not null,
  libelle text not null,
  periodicite_valeur integer not null,
  periodicite_unite text not null,
  date_depart date,
  prestataire text,
  contact text,
  rappel_jours integer default 30 not null,
  obligatoire boolean default true not null,
  notes text,
  actif boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table public.prestataires (
  id uuid default gen_random_uuid() not null,
  nom text not null,
  contact text,
  telephone text,
  email text,
  adresse text,
  notes text,
  actif boolean default true not null,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null
);

create table public.profils (
  id uuid not null,
  email text,
  nom text,
  role text default 'lecteur'::text not null,
  created_at timestamp with time zone default now() not null,
  doit_changer_mdp boolean default false not null,
  actif boolean default true not null
);

create table public.site_documents (
  id uuid default gen_random_uuid() not null,
  site_id uuid not null,
  type text default 'autre'::text not null,
  titre text,
  chemin text not null,
  nom text,
  mime text,
  date_document date,
  date_fin date,
  cree_par uuid default auth.uid(),
  created_at timestamp with time zone default now() not null,
  taille_octets bigint,
  empreinte_sha256 text,
  suite_echeance text,
  suite_date date,
  remplace_par uuid
);

create table public.site_erp (
  site_id uuid not null,
  est_erp boolean default true not null,
  type_erp text,
  categorie smallint,
  effectif_public integer,
  effectif_personnel integer,
  locaux_sommeil boolean default false not null,
  date_arrete_ouverture date,
  responsable_securite text,
  consignes text,
  moyens_secours text,
  periodicite_visite_ans smallint,
  notes text,
  maj_par uuid default auth.uid(),
  updated_at timestamp with time zone default now() not null
);

create table public.sites (
  id uuid default gen_random_uuid() not null,
  nom text not null,
  adresse text,
  notes text,
  ordre integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  actif boolean default true not null
);

-- ---------------------------------------------------------------------
-- 2. CLÉS PRIMAIRES, UNICITÉ ET CONTRÔLES
-- ---------------------------------------------------------------------

alter table public.astreinte_abonnements add constraint astreinte_abonnements_pkey PRIMARY KEY (endpoint);
alter table public.astreinte_alertes_envoyees add constraint astreinte_alertes_envoyees_pkey PRIMARY KEY (incident);
alter table public.astreinte_incidents add constraint astreinte_incidents_pkey PRIMARY KEY (uuid);
alter table public.astreinte_incidents add constraint astreinte_incidents_donnees_check CHECK ((jsonb_typeof(donnees) = 'object'::text));
alter table public.astreinte_incidents add constraint astreinte_tri_valeurs CHECK ((tri = ANY (ARRAY['a_valider'::text, 'transmis'::text, 'ecarte'::text])));
alter table public.budget_historique add constraint budget_historique_pkey PRIMARY KEY (id);
alter table public.cles_serveur add constraint cles_serveur_pkey PRIMARY KEY (cle);
alter table public.commission_prescriptions add constraint commission_prescriptions_pkey PRIMARY KEY (id);
alter table public.commission_prescriptions add constraint commission_prescriptions_texte_check CHECK ((length(btrim(texte)) > 0));
alter table public.commission_prescriptions add constraint prescriptions_levee CHECK ((levee = (date_levee IS NOT NULL)));
alter table public.commission_visites add constraint commission_visites_chemin_key UNIQUE (chemin);
alter table public.commission_visites add constraint commission_visites_pkey PRIMARY KEY (id);
alter table public.commission_visites add constraint commission_visites_avis_check CHECK ((avis = ANY (ARRAY['favorable'::text, 'defavorable'::text, 'sans_avis'::text])));
alter table public.commission_visites add constraint commission_visites_nature_check CHECK ((nature = ANY (ARRAY['periodique'::text, 'reception'::text, 'inopinee'::text, 'autre'::text])));
alter table public.controle_groupes add constraint controle_groupes_pkey PRIMARY KEY (id);
alter table public.controles add constraint controles_pkey PRIMARY KEY (id);
alter table public.controles add constraint controles_mesures_objet CHECK (((mesures IS NULL) OR (jsonb_typeof(mesures) = 'object'::text)));
alter table public.controles add constraint controles_resultat_check CHECK ((resultat = ANY (ARRAY['conforme'::text, 'reserves'::text, 'non_conforme'::text])));
alter table public.depenses add constraint depenses_pkey PRIMARY KEY (id);
alter table public.depenses add constraint depenses_exercice_check CHECK (((exercice IS NULL) OR ((exercice >= 2000) AND (exercice <= 2100))));
alter table public.depenses add constraint depenses_montants CHECK (((COALESCE(estimation_ht, (0)::numeric) >= (0)::numeric) AND (COALESCE(estimation_ttc, (0)::numeric) >= (0)::numeric) AND (COALESCE(devis_ht, (0)::numeric) >= (0)::numeric) AND (COALESCE(devis_ttc, (0)::numeric) >= (0)::numeric) AND (COALESCE(engage_ht, (0)::numeric) >= (0)::numeric) AND (COALESCE(engage_ttc, (0)::numeric) >= (0)::numeric) AND ((estimation_ht IS NULL) OR (estimation_ttc IS NULL) OR (estimation_ttc >= estimation_ht)) AND ((devis_ht IS NULL) OR (devis_ttc IS NULL) OR (devis_ttc >= devis_ht)) AND ((engage_ht IS NULL) OR (engage_ttc IS NULL) OR (engage_ttc >= engage_ht))));
alter table public.depenses add constraint depenses_nature_depense_check CHECK ((nature_depense = ANY (ARRAY['entretien_courant'::text, 'depannage'::text, 'controle_reglementaire'::text, 'contrat_maintenance'::text, 'renouvellement'::text, 'amelioration'::text, 'autre'::text])));
alter table public.depenses add constraint depenses_objet_check CHECK ((length(btrim(objet)) > 0));
alter table public.documents add constraint documents_pkey PRIMARY KEY (id);
alter table public.equipement_cycle_vie add constraint equipement_cycle_vie_pkey PRIMARY KEY (equipement_id);
alter table public.equipement_cycle_vie add constraint cycle_vie_annee_date CHECK (((date_mise_en_service IS NULL) OR (annee_mise_en_service IS NULL) OR (EXTRACT(year FROM date_mise_en_service) = (annee_mise_en_service)::numeric)));
alter table public.equipement_cycle_vie add constraint equipement_cycle_vie_annee_mise_en_service_check CHECK (((annee_mise_en_service >= 1900) AND (annee_mise_en_service <= 2100)));
alter table public.equipement_cycle_vie add constraint equipement_cycle_vie_cout_remplacement_ht_check CHECK (((cout_remplacement_ht IS NULL) OR (cout_remplacement_ht >= (0)::numeric)));
alter table public.equipement_cycle_vie add constraint equipement_cycle_vie_cout_remplacement_ttc_check CHECK (((cout_remplacement_ttc IS NULL) OR (cout_remplacement_ttc >= (0)::numeric)));
alter table public.equipement_cycle_vie add constraint equipement_cycle_vie_duree_vie_ans_check CHECK (((duree_vie_ans >= 1) AND (duree_vie_ans <= 100)));
alter table public.equipement_cycle_vie add constraint equipement_cycle_vie_etat_check CHECK ((etat = ANY (ARRAY['bon'::text, 'moyen'::text, 'mauvais'::text, 'hors_service'::text, 'non_evalue'::text])));
alter table public.equipement_pei add constraint equipement_pei_pkey PRIMARY KEY (equipement_id);
alter table public.equipement_pei add constraint equipement_pei_capacite_m3_check CHECK (((capacite_m3 IS NULL) OR (capacite_m3 >= (0)::numeric)));
alter table public.equipement_pei add constraint equipement_pei_debit_requis_m3h_check CHECK (((debit_requis_m3h IS NULL) OR (debit_requis_m3h >= (0)::numeric)));
alter table public.equipement_pei add constraint equipement_pei_diametre_mm_check CHECK (((diametre_mm >= 1) AND (diametre_mm <= 1000)));
alter table public.equipement_pei add constraint equipement_pei_disponibilite_check CHECK ((disponibilite = ANY (ARRAY['disponible'::text, 'restreint'::text, 'indisponible'::text])));
alter table public.equipement_pei add constraint equipement_pei_latitude_check CHECK (((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision)));
alter table public.equipement_pei add constraint equipement_pei_longitude_check CHECK (((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision)));
alter table public.equipement_pei add constraint equipement_pei_statut_juridique_check CHECK ((statut_juridique = ANY (ARRAY['public'::text, 'prive'::text])));
alter table public.equipement_pei add constraint equipement_pei_type_pei_check CHECK ((type_pei = ANY (ARRAY['poteau'::text, 'bouche'::text, 'reserve_aerienne'::text, 'reserve_enterree'::text, 'citerne_souple'::text, 'point_aspiration'::text, 'autre'::text])));
alter table public.equipement_pei add constraint pei_coordonnees CHECK (((latitude IS NULL) = (longitude IS NULL)));
alter table public.equipements add constraint equipements_pkey PRIMARY KEY (id);
alter table public.exercices_securite add constraint exercices_securite_pkey PRIMARY KEY (id);
alter table public.exercices_securite add constraint exercices_securite_duree_minutes_check CHECK ((duree_minutes >= 0));
alter table public.exercices_securite add constraint exercices_securite_type_check CHECK ((type = ANY (ARRAY['evacuation'::text, 'formation'::text, 'autre'::text])));
alter table public.factures add constraint factures_chemin_key UNIQUE (chemin);
alter table public.factures add constraint factures_pkey PRIMARY KEY (id);
alter table public.factures add constraint factures_exercice_check CHECK (((exercice >= 2000) AND (exercice <= 2100)));
alter table public.factures add constraint factures_montant_ht_check CHECK (((montant_ht IS NULL) OR (montant_ht >= (0)::numeric)));
alter table public.factures add constraint factures_montant_ttc_check CHECK (((montant_ttc IS NULL) OR (montant_ttc >= (0)::numeric)));
alter table public.factures add constraint factures_montant_tva_check CHECK (((montant_tva IS NULL) OR (montant_tva >= (0)::numeric)));
alter table public.factures add constraint factures_paiement CHECK (((paiement_statut = 'paye'::text) = (date_paiement IS NOT NULL)));
alter table public.factures add constraint factures_paiement_statut_check CHECK ((paiement_statut = ANY (ARRAY['non_renseigne'::text, 'paye'::text])));
alter table public.factures add constraint factures_rattachement CHECK (((intervention_id IS NULL) <> (depense_id IS NULL)));
alter table public.factures add constraint factures_taux_tva_check CHECK (((taux_tva IS NULL) OR ((taux_tva >= (0)::numeric) AND (taux_tva <= (100)::numeric))));
alter table public.factures add constraint factures_ttc CHECK (((montant_ht IS NULL) OR (montant_ttc IS NULL) OR (montant_ttc >= montant_ht)));
alter table public.factures add constraint factures_tva_coherente CHECK (((montant_ht IS NULL) OR (montant_tva IS NULL) OR (montant_ttc IS NULL) OR (abs(((montant_ht + montant_tva) - montant_ttc)) <= 0.01)));
alter table public.factures add constraint factures_un_justificatif CHECK (((intervention_document_id IS NULL) OR (chemin IS NULL)));
alter table public.factures add constraint factures_un_montant CHECK (((montant_ht IS NOT NULL) OR (montant_ttc IS NOT NULL)));
alter table public.groupe_documents add constraint groupe_documents_chemin_key UNIQUE (chemin);
alter table public.groupe_documents add constraint groupe_documents_pkey PRIMARY KEY (id);
alter table public.incident_documents add constraint incident_documents_chemin_key UNIQUE (chemin);
alter table public.incident_documents add constraint incident_documents_pkey PRIMARY KEY (id);
alter table public.incident_documents add constraint incident_documents_type_check CHECK ((type = ANY (ARRAY['photo_signalement'::text, 'photo_intervention'::text, 'devis'::text, 'facture'::text, 'autre'::text])));
alter table public.incident_historique add constraint incident_historique_pkey PRIMARY KEY (id);
alter table public.incidents add constraint incidents_pkey PRIMARY KEY (id);
alter table public.incidents add constraint incidents_categorie_check CHECK ((categorie = ANY (ARRAY['plomberie'::text, 'chauffage'::text, 'electricite'::text, 'menuiserie'::text, 'serrurerie'::text, 'nettoyage'::text, 'securite'::text, 'informatique'::text, 'espaces_exterieurs'::text, 'autre'::text])));
alter table public.incidents add constraint incidents_devis_montant_check CHECK (((devis_montant IS NULL) OR (devis_montant >= (0)::numeric)));
alter table public.incidents add constraint incidents_facture_montant_check CHECK (((facture_montant IS NULL) OR (facture_montant >= (0)::numeric)));
alter table public.incidents add constraint incidents_priorite_check CHECK ((priorite = ANY (ARRAY['basse'::text, 'normale'::text, 'haute'::text, 'urgente'::text])));
alter table public.incidents add constraint incidents_statut_check CHECK ((statut = ANY (ARRAY['nouveau'::text, 'a_traiter'::text, 'en_cours'::text, 'attente_prestataire'::text, 'resolu'::text, 'cloture'::text])));
alter table public.incidents add constraint incidents_titre_check CHECK ((length(btrim(titre)) > 0));
alter table public.intervention_commentaires add constraint intervention_commentaires_pkey PRIMARY KEY (id);
alter table public.intervention_commentaires add constraint intervention_commentaires_texte_check CHECK (((length(btrim(texte)) >= 1) AND (length(btrim(texte)) <= 5000)));
alter table public.intervention_documents add constraint intervention_documents_chemin_key UNIQUE (chemin);
alter table public.intervention_documents add constraint intervention_documents_pkey PRIMARY KEY (id);
alter table public.intervention_documents add constraint intervention_documents_type_check CHECK ((type = ANY (ARRAY['devis'::text, 'bon_commande'::text, 'facture'::text, 'rapport'::text, 'photo_avant'::text, 'photo_apres'::text, 'autre'::text])));
alter table public.intervention_historique add constraint intervention_historique_pkey PRIMARY KEY (id);
alter table public.interventions add constraint interventions_pkey PRIMARY KEY (id);
alter table public.interventions add constraint interventions_budget_checks CHECK ((((exercice IS NULL) OR ((exercice >= 2000) AND (exercice <= 2100))) AND ((nature_depense IS NULL) OR (nature_depense = ANY (ARRAY['entretien_courant'::text, 'depannage'::text, 'controle_reglementaire'::text, 'contrat_maintenance'::text, 'renouvellement'::text, 'amelioration'::text, 'autre'::text]))) AND (COALESCE(engage_ht, (0)::numeric) >= (0)::numeric) AND (COALESCE(engage_ttc, (0)::numeric) >= (0)::numeric) AND ((engage_ht IS NULL) OR (engage_ttc IS NULL) OR (engage_ttc >= engage_ht))));
alter table public.interventions add constraint interventions_dates_prevues CHECK (((date_prevue_fin IS NULL) OR (date_prevue_debut IS NULL) OR (date_prevue_fin >= date_prevue_debut)));
alter table public.interventions add constraint interventions_dates_reelles CHECK (((date_fin_reelle IS NULL) OR (date_debut_reelle IS NULL) OR (date_fin_reelle >= date_debut_reelle)));
alter table public.interventions add constraint interventions_montants_positifs CHECK (((COALESCE(estimation_ht, (0)::numeric) >= (0)::numeric) AND (COALESCE(estimation_ttc, (0)::numeric) >= (0)::numeric) AND (COALESCE(devis_ht, (0)::numeric) >= (0)::numeric) AND (COALESCE(devis_ttc, (0)::numeric) >= (0)::numeric) AND (COALESCE(cout_reel_ht, (0)::numeric) >= (0)::numeric) AND (COALESCE(cout_reel_ttc, (0)::numeric) >= (0)::numeric)));
alter table public.interventions add constraint interventions_objet_check CHECK ((length(btrim(objet)) > 0));
alter table public.interventions add constraint interventions_statut_check CHECK ((statut = ANY (ARRAY['a_planifier'::text, 'devis_demande'::text, 'devis_recu'::text, 'valide'::text, 'planifie'::text, 'en_cours'::text, 'en_attente'::text, 'termine'::text, 'annule'::text])));
alter table public.interventions add constraint interventions_ttc_sup_ht CHECK ((((estimation_ht IS NULL) OR (estimation_ttc IS NULL) OR (estimation_ttc >= estimation_ht)) AND ((devis_ht IS NULL) OR (devis_ttc IS NULL) OR (devis_ttc >= devis_ht)) AND ((cout_reel_ht IS NULL) OR (cout_reel_ttc IS NULL) OR (cout_reel_ttc >= cout_reel_ht))));
alter table public.journal add constraint journal_pkey PRIMARY KEY (id);
alter table public.parametres add constraint parametres_pkey PRIMARY KEY (cle);
alter table public.plans add constraint plans_pkey PRIMARY KEY (id);
alter table public.plans add constraint plans_periodicite_unite_check CHECK ((periodicite_unite = ANY (ARRAY['jour'::text, 'semaine'::text, 'mois'::text, 'an'::text])));
alter table public.plans add constraint plans_periodicite_valeur_check CHECK ((periodicite_valeur > 0));
alter table public.plans add constraint plans_rappel_jours_check CHECK ((rappel_jours >= 0));
alter table public.prestataires add constraint prestataires_pkey PRIMARY KEY (id);
alter table public.prestataires add constraint prestataires_nom_check CHECK ((length(btrim(nom)) > 0));
alter table public.profils add constraint profils_pkey PRIMARY KEY (id);
alter table public.profils add constraint profils_role_check CHECK ((role = ANY (ARRAY['admin'::text, 'contributeur'::text, 'lecteur'::text, 'agent'::text])));
alter table public.site_documents add constraint site_documents_chemin_key UNIQUE (chemin);
alter table public.site_documents add constraint site_documents_pkey PRIMARY KEY (id);
alter table public.site_documents add constraint site_documents_suite_echeance_check CHECK (((suite_echeance IS NULL) OR (suite_echeance = ANY (ARRAY['renouvele'::text, 'resilie'::text, 'sans_objet'::text]))));
alter table public.site_documents add constraint site_documents_type_check CHECK ((type = ANY (ARRAY['contrat'::text, 'plan'::text, 'diagnostic'::text, 'photo'::text, 'autre'::text])));
alter table public.site_erp add constraint site_erp_pkey PRIMARY KEY (site_id);
alter table public.site_erp add constraint site_erp_categorie_check CHECK (((categorie >= 1) AND (categorie <= 5)));
alter table public.site_erp add constraint site_erp_effectif_personnel_check CHECK ((effectif_personnel >= 0));
alter table public.site_erp add constraint site_erp_effectif_public_check CHECK ((effectif_public >= 0));
alter table public.site_erp add constraint site_erp_periodicite_visite_ans_check CHECK (((periodicite_visite_ans >= 1) AND (periodicite_visite_ans <= 10)));
alter table public.sites add constraint sites_pkey PRIMARY KEY (id);

-- ---------------------------------------------------------------------
-- 3. CLÉS ÉTRANGÈRES
-- ---------------------------------------------------------------------

alter table public.astreinte_abonnements add constraint astreinte_abonnements_compte_fkey FOREIGN KEY (compte) REFERENCES profils(id) ON DELETE CASCADE;
alter table public.astreinte_incidents add constraint astreinte_incidents_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES incidents(id) ON DELETE SET NULL;
alter table public.astreinte_incidents add constraint astreinte_incidents_tri_par_fkey FOREIGN KEY (tri_par) REFERENCES profils(id);
alter table public.commission_prescriptions add constraint commission_prescriptions_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.commission_prescriptions add constraint commission_prescriptions_intervention_id_fkey FOREIGN KEY (intervention_id) REFERENCES interventions(id) ON DELETE SET NULL;
alter table public.commission_prescriptions add constraint commission_prescriptions_visite_id_fkey FOREIGN KEY (visite_id) REFERENCES commission_visites(id) ON DELETE RESTRICT;
alter table public.commission_visites add constraint commission_visites_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.commission_visites add constraint commission_visites_site_id_fkey FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE RESTRICT;
alter table public.controle_groupes add constraint controle_groupes_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.controles add constraint controles_groupe_id_fkey FOREIGN KEY (groupe_id) REFERENCES controle_groupes(id) ON DELETE RESTRICT;
alter table public.controles add constraint controles_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE RESTRICT;
alter table public.controles add constraint controles_saisi_par_fkey FOREIGN KEY (saisi_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.depenses add constraint depenses_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.depenses add constraint depenses_equipement_id_fkey FOREIGN KEY (equipement_id) REFERENCES equipements(id) ON DELETE RESTRICT;
alter table public.depenses add constraint depenses_prestataire_id_fkey FOREIGN KEY (prestataire_id) REFERENCES prestataires(id) ON DELETE RESTRICT;
alter table public.depenses add constraint depenses_site_id_fkey FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE RESTRICT;
alter table public.documents add constraint documents_controle_id_fkey FOREIGN KEY (controle_id) REFERENCES controles(id) ON DELETE CASCADE;
alter table public.equipement_cycle_vie add constraint equipement_cycle_vie_equipement_id_fkey FOREIGN KEY (equipement_id) REFERENCES equipements(id) ON DELETE CASCADE;
alter table public.equipement_cycle_vie add constraint equipement_cycle_vie_maj_par_fkey FOREIGN KEY (maj_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.equipement_pei add constraint equipement_pei_equipement_id_fkey FOREIGN KEY (equipement_id) REFERENCES equipements(id) ON DELETE CASCADE;
alter table public.equipements add constraint equipements_site_id_fkey FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE RESTRICT;
alter table public.exercices_securite add constraint exercices_securite_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.exercices_securite add constraint exercices_securite_site_id_fkey FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE RESTRICT;
alter table public.factures add constraint factures_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.factures add constraint factures_depense_id_fkey FOREIGN KEY (depense_id) REFERENCES depenses(id) ON DELETE RESTRICT;
alter table public.factures add constraint factures_intervention_document_id_fkey FOREIGN KEY (intervention_document_id) REFERENCES intervention_documents(id) ON DELETE RESTRICT;
alter table public.factures add constraint factures_intervention_id_fkey FOREIGN KEY (intervention_id) REFERENCES interventions(id) ON DELETE RESTRICT;
alter table public.factures add constraint factures_prestataire_id_fkey FOREIGN KEY (prestataire_id) REFERENCES prestataires(id) ON DELETE RESTRICT;
alter table public.groupe_documents add constraint groupe_documents_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.groupe_documents add constraint groupe_documents_groupe_id_fkey FOREIGN KEY (groupe_id) REFERENCES controle_groupes(id) ON DELETE RESTRICT;
alter table public.incident_documents add constraint incident_documents_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.incident_documents add constraint incident_documents_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES incidents(id) ON DELETE CASCADE;
alter table public.incidents add constraint incidents_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.incidents add constraint incidents_equipement_id_fkey FOREIGN KEY (equipement_id) REFERENCES equipements(id) ON DELETE RESTRICT;
alter table public.incidents add constraint incidents_site_id_fkey FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE RESTRICT;
alter table public.intervention_commentaires add constraint intervention_commentaires_auteur_fkey FOREIGN KEY (auteur) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.intervention_commentaires add constraint intervention_commentaires_intervention_id_fkey FOREIGN KEY (intervention_id) REFERENCES interventions(id) ON DELETE CASCADE;
alter table public.intervention_documents add constraint intervention_documents_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.intervention_documents add constraint intervention_documents_intervention_id_fkey FOREIGN KEY (intervention_id) REFERENCES interventions(id) ON DELETE CASCADE;
alter table public.interventions add constraint interventions_cloture_par_fkey FOREIGN KEY (cloture_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.interventions add constraint interventions_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.interventions add constraint interventions_equipement_id_fkey FOREIGN KEY (equipement_id) REFERENCES equipements(id) ON DELETE RESTRICT;
alter table public.interventions add constraint interventions_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES incidents(id) ON DELETE RESTRICT;
alter table public.interventions add constraint interventions_prestataire_id_fkey FOREIGN KEY (prestataire_id) REFERENCES prestataires(id) ON DELETE RESTRICT;
alter table public.interventions add constraint interventions_responsable_id_fkey FOREIGN KEY (responsable_id) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.interventions add constraint interventions_site_id_fkey FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE RESTRICT;
alter table public.plans add constraint plans_equipement_id_fkey FOREIGN KEY (equipement_id) REFERENCES equipements(id) ON DELETE CASCADE;
alter table public.prestataires add constraint prestataires_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.profils add constraint profils_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.site_documents add constraint site_documents_cree_par_fkey FOREIGN KEY (cree_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.site_documents add constraint site_documents_remplace_par_fkey FOREIGN KEY (remplace_par) REFERENCES site_documents(id) ON DELETE SET NULL;
alter table public.site_documents add constraint site_documents_site_id_fkey FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE RESTRICT;
alter table public.site_erp add constraint site_erp_maj_par_fkey FOREIGN KEY (maj_par) REFERENCES profils(id) ON DELETE SET NULL;
alter table public.site_erp add constraint site_erp_site_id_fkey FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE RESTRICT;

-- ---------------------------------------------------------------------
-- 4. INDEX
-- ---------------------------------------------------------------------

CREATE INDEX astreinte_incidents_incident_idx ON public.astreinte_incidents USING btree (incident_id);
CREATE INDEX astreinte_incidents_recu_idx ON public.astreinte_incidents USING btree (recu_le);
CREATE INDEX astreinte_incidents_tri_idx ON public.astreinte_incidents USING btree (tri);
CREATE INDEX budget_hist_idx ON public.budget_historique USING btree (objet_type, objet_id, created_at);
CREATE INDEX commission_prescriptions_idx ON public.commission_prescriptions USING btree (visite_id);
CREATE INDEX commission_visites_idx ON public.commission_visites USING btree (site_id, date_visite DESC);
CREATE INDEX controle_groupes_date_idx ON public.controle_groupes USING btree (date_realisation);
CREATE INDEX controles_groupe_idx ON public.controles USING btree (groupe_id);
CREATE INDEX controles_plan_idx ON public.controles USING btree (plan_id, date_realisation DESC);
CREATE INDEX depenses_equip_idx ON public.depenses USING btree (equipement_id);
CREATE INDEX depenses_exercice_idx ON public.depenses USING btree (exercice);
CREATE INDEX depenses_site_idx ON public.depenses USING btree (site_id);
CREATE UNIQUE INDEX documents_chemin_unique ON public.documents USING btree (chemin);
CREATE INDEX documents_ctrl_idx ON public.documents USING btree (controle_id);
CREATE UNIQUE INDEX equipement_pei_numero_unique ON public.equipement_pei USING btree (lower(btrim(numero))) WHERE ((numero IS NOT NULL) AND (btrim(numero) <> ''::text));
CREATE INDEX equipements_site_idx ON public.equipements USING btree (site_id);
CREATE INDEX exercices_securite_idx ON public.exercices_securite USING btree (site_id, date_exercice DESC);
CREATE INDEX factures_dep_idx ON public.factures USING btree (depense_id);
CREATE INDEX factures_ex_idx ON public.factures USING btree (exercice);
CREATE INDEX factures_int_idx ON public.factures USING btree (intervention_id);
CREATE UNIQUE INDEX factures_reference_unique ON public.factures USING btree (COALESCE(prestataire_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(btrim(reference))) WHERE ((reference IS NOT NULL) AND (btrim(reference) <> ''::text));
CREATE INDEX groupe_documents_idx ON public.groupe_documents USING btree (groupe_id);
CREATE INDEX incident_docs_idx ON public.incident_documents USING btree (incident_id);
CREATE INDEX incident_hist_idx ON public.incident_historique USING btree (incident_id, created_at);
CREATE INDEX incidents_date_idx ON public.incidents USING btree (date_signalement DESC);
CREATE INDEX incidents_equip_idx ON public.incidents USING btree (equipement_id);
CREATE INDEX incidents_site_idx ON public.incidents USING btree (site_id);
CREATE INDEX incidents_statut_idx ON public.incidents USING btree (statut, priorite);
CREATE INDEX intervention_comm_idx ON public.intervention_commentaires USING btree (intervention_id, created_at);
CREATE INDEX intervention_docs_idx ON public.intervention_documents USING btree (intervention_id);
CREATE INDEX intervention_hist_idx ON public.intervention_historique USING btree (intervention_id, created_at);
CREATE INDEX interventions_dates_idx ON public.interventions USING btree (date_prevue_debut);
CREATE INDEX interventions_incident_idx ON public.interventions USING btree (incident_id);
CREATE INDEX interventions_prest_idx ON public.interventions USING btree (prestataire_id);
CREATE INDEX interventions_resp_idx ON public.interventions USING btree (responsable_id);
CREATE INDEX interventions_site_idx ON public.interventions USING btree (site_id);
CREATE INDEX interventions_statut_idx ON public.interventions USING btree (statut);
CREATE INDEX journal_idx ON public.journal USING btree (table_nom, ligne_id, created_at);
CREATE INDEX plans_equipement_idx ON public.plans USING btree (equipement_id);
CREATE UNIQUE INDEX prestataires_nom_unique ON public.prestataires USING btree (lower(btrim(nom)));
CREATE INDEX site_documents_idx ON public.site_documents USING btree (site_id);

-- ---------------------------------------------------------------------
-- 5. FONCTIONS
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.astreinte_anonymiser(delai interval DEFAULT '30 days'::interval)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  n integer;
  ts text := to_char(clock_timestamp() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
begin
  update public.astreinte_incidents a set
    maj_le = clock_timestamp(),
    donnees = a.donnees || jsonb_build_object(
      'reporterName', case when coalesce(a.donnees->>'reporterName', '') = '' then '' else 'Habitant (anonymisé)' end,
      'reporterPhone', '', 'reporterComment', '', 'anonymise', true, 'updatedAt', ts,
      'fieldTs', coalesce(a.donnees->'fieldTs', '{}'::jsonb) || jsonb_build_object('reporterName', ts, 'reporterPhone', ts, 'reporterComment', ts),
      'history', coalesce(a.donnees->'history', '[]'::jsonb) || jsonb_build_array(jsonb_build_object('ts', ts,
        'text', '🔒 Coordonnées de l''habitant effacées (' || extract(day from delai)::int || ' jours après la clôture)')))
  where a.statut in ('RESOLU', 'ARCHIVE') and a.clos_le < now() - delai
    and coalesce(a.donnees->>'anonymise', '') <> 'true'
    and (coalesce(a.donnees->>'reporterName', '') <> '' or coalesce(a.donnees->>'reporterPhone', '') <> '' or coalesce(a.donnees->>'reporterComment', '') <> '');
  get diagnostics n = row_count;
  return n;
end; $function$
;

CREATE OR REPLACE FUNCTION public.astreinte_avant_ecriture()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r text := mon_role();
begin
  new.recu_le := clock_timestamp(); new.maj_par := auth.uid();
  if tg_op = 'INSERT' then
    if new.statut in ('RESOLU', 'ARCHIVE') and new.cree_le < now() - interval '5 years' then return null; end if;
    new.cree_par := auth.uid();
    if r = any (array['lecteur','agent']) then
      new.statut := 'NOUVEAU'; new.incident_id := null; new.tri := 'a_valider'; new.tri_motif := null;
      new.donnees := (new.donnees - 'travauxId' - 'travauxEnCours') || jsonb_build_object('status', 'NOUVEAU');
    end if;
  else
    new.cree_par := old.cree_par;
    new.incident_id := coalesce(new.incident_id, old.incident_id);
    if old.donnees ? 'travauxId' and not (new.donnees ? 'travauxId') then
      new.donnees := new.donnees || jsonb_build_object('travauxId', old.donnees->'travauxId');
    end if;
    if r = any (array['lecteur','agent']) then
      new.statut := old.statut; new.urgence := old.urgence; new.categorie := old.categorie; new.adresse := old.adresse;
      new.latitude := old.latitude; new.longitude := old.longitude; new.numero := old.numero; new.cree_le := old.cree_le;
      new.incident_id := old.incident_id; new.tri := old.tri; new.tri_motif := old.tri_motif;
      new.donnees := old.donnees || jsonb_build_object(
        'photos', (select coalesce(jsonb_agg(p), '[]'::jsonb) from (
            select distinct on (p->>'chemin') p
            from jsonb_array_elements(coalesce(old.donnees->'photos', '[]'::jsonb) || coalesce(new.donnees->'photos', '[]'::jsonb)) p
            where jsonb_typeof(p) = 'object' and p ? 'chemin' order by p->>'chemin') x),
        'history', coalesce(old.donnees->'history', '[]'::jsonb) || coalesce((
            select jsonb_agg(h) from jsonb_array_elements(coalesce(new.donnees->'history', '[]'::jsonb)) h
            where not (coalesce(old.donnees->'history', '[]'::jsonb) @> jsonb_build_array(h))), '[]'::jsonb),
        'updatedAt', coalesce(new.donnees->'updatedAt', old.donnees->'updatedAt'));
    end if;
    if new.tri is distinct from old.tri then
      new.tri_le := now(); new.tri_par := auth.uid();
      if new.tri = 'ecarte' or (new.tri = 'a_valider' and old.tri = 'ecarte') then
        new.donnees := new.donnees || jsonb_build_object('history', coalesce(new.donnees->'history', '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
          'ts', to_char(clock_timestamp() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
          'text', case when new.tri = 'ecarte'
                    then '🗂️ Écarté par la mairie (pas de suivi bâtiments)' || coalesce(' : ' || nullif(trim(new.tri_motif), ''), '')
                    else '↩️ Remis à valider par la mairie' end
                  || coalesce(' · par ' || (select coalesce(nullif(trim(nom), ''), email) from public.profils where id = auth.uid()), ''))));
      end if;
    end if;
    -- Photos supprimées par la mairie : un téléphone ne peut pas les renvoyer
    if jsonb_typeof(old.donnees->'photosSupprimees') = 'array' then
      new.donnees := new.donnees || jsonb_build_object(
        'photosSupprimees', (select coalesce(jsonb_agg(distinct c), '[]'::jsonb) from jsonb_array_elements(
            old.donnees->'photosSupprimees' || case when jsonb_typeof(new.donnees->'photosSupprimees') = 'array' then new.donnees->'photosSupprimees' else '[]'::jsonb end) c),
        'photos', (select coalesce(jsonb_agg(p), '[]'::jsonb) from jsonb_array_elements(coalesce(new.donnees->'photos', '[]'::jsonb)) p
            where not (old.donnees->'photosSupprimees' @> jsonb_build_array(p->'chemin'))));
    end if;
    -- Une anonymisation est définitive : un téléphone ne peut pas renvoyer les coordonnées effacées
    if (old.donnees->>'anonymise') = 'true' then
      new.donnees := new.donnees || jsonb_build_object('anonymise', true,
        'reporterName', case when coalesce(new.donnees->>'reporterName', '') = '' then '' else 'Habitant (anonymisé)' end,
        'reporterPhone', '', 'reporterComment', '');
    end if;
  end if;
  -- Date de clôture : fixée au passage en Résolu ou Archivé, effacée si l'incident est rouvert
  if new.statut in ('RESOLU', 'ARCHIVE') then
    if tg_op = 'UPDATE' and old.statut in ('RESOLU', 'ARCHIVE') then
      new.clos_le := coalesce(old.clos_le, new.clos_le, clock_timestamp());
    else
      new.clos_le := clock_timestamp();
    end if;
  else
    new.clos_le := null;
  end if;
  if new.incident_id is not null and new.tri <> 'transmis' then
    new.tri := 'transmis'; new.tri_le := coalesce(new.tri_le, now()); new.tri_par := coalesce(new.tri_par, auth.uid());
  end if;
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.astreinte_retour_resolution()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  ts text := to_char(clock_timestamp() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  qui text := (select coalesce(nullif(trim(nom), ''), email) from public.profils where id = auth.uid());
begin
  if new.statut in ('resolu', 'cloture') and old.statut is distinct from new.statut then
    update public.astreinte_incidents a set
      statut = 'RESOLU',
      maj_le = clock_timestamp(),
      donnees = a.donnees
        || jsonb_build_object('status', 'RESOLU', 'updatedAt', ts)
        || jsonb_build_object('fieldTs', coalesce(a.donnees->'fieldTs', '{}'::jsonb) || jsonb_build_object('status', ts))
        || jsonb_build_object('history', coalesce(a.donnees->'history', '[]'::jsonb)
             || jsonb_build_array(jsonb_build_object('ts', ts,
                  'text', 'Statut : Résolu dans le suivi des bâtiments' || coalesce(' · par ' || qui, ''))))
    where a.incident_id = new.id and a.statut not in ('RESOLU', 'ARCHIVE');
  end if;
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.budget_avant_ecriture()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare est_admin boolean := auth.uid() is null or coalesce(public.mon_role(), '') = 'admin';
        v_int uuid;
begin
  if tg_op = 'INSERT' then
    if tg_table_name in ('depenses','factures') then new.cree_par := auth.uid(); new.created_at := now(); end if;
  elsif tg_table_name in ('depenses','factures') then
    new.cree_par := old.cree_par; new.created_at := old.created_at;
  end if;

  if tg_table_name = 'factures' then
    -- Le paiement n'est jamais déduit : seul un administrateur le renseigne
    if (tg_op = 'INSERT' and new.paiement_statut <> 'non_renseigne' and not est_admin)
       or (tg_op = 'UPDATE' and not est_admin and (new.paiement_statut, new.date_paiement, new.paiement_reference)
            is distinct from (old.paiement_statut, old.date_paiement, old.paiement_reference)) then
      raise exception 'Seul un administrateur peut renseigner le paiement d''une facture.' using errcode = '42501';
    end if;
    -- Un justificatif existant doit appartenir à la même intervention
    if new.intervention_document_id is not null then
      select intervention_id into v_int from public.intervention_documents where id = new.intervention_document_id;
      if v_int is distinct from new.intervention_id then
        raise exception 'Le justificatif choisi n''appartient pas à cette intervention.' using errcode = '23514';
      end if;
    end if;
  end if;

  if tg_table_name = 'equipement_cycle_vie' then new.maj_par := auth.uid(); end if;
  new.updated_at := now();
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.budget_journal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  k text; a jsonb; n jsonb; v_id uuid;
  typ text := case tg_table_name when 'depenses' then 'depense' when 'factures' then 'facture' else 'cycle_vie' end;
  cle text := case when tg_table_name = 'equipement_cycle_vie' then 'equipement_id' else 'id' end;
  nom text := (select coalesce(nom, email) from public.profils where id = auth.uid());
begin
  if tg_op = 'DELETE' then
    v_id := (to_jsonb(old) ->> cle)::uuid;
    insert into public.budget_historique(objet_type, objet_id, action, auteur, auteur_nom) values (typ, v_id, 'suppression', auth.uid(), nom);
    return old;
  end if;
  v_id := (to_jsonb(new) ->> cle)::uuid;
  if tg_op = 'INSERT' then
    insert into public.budget_historique(objet_type, objet_id, action, auteur, auteur_nom) values (typ, v_id, 'creation', auth.uid(), nom);
    return new;
  end if;
  a := to_jsonb(old); n := to_jsonb(new);
  for k in select jsonb_object_keys(n) loop
    continue when k in ('updated_at','created_at','cree_par','maj_par','id');
    if (a -> k) is distinct from (n -> k) then
      insert into public.budget_historique(objet_type, objet_id, action, champ, ancienne_valeur, nouvelle_valeur, auteur, auteur_nom)
      values (typ, v_id, 'modification', k, a ->> k, n ->> k, auth.uid(), nom);
    end if;
  end loop;
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.compte_actif()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((select actif from public.profils where id = auth.uid()), false)
$function$
;

CREATE OR REPLACE FUNCTION public.comptes_activite()
 RETURNS TABLE(id uuid, derniere_activite timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select u.id, greatest(u.last_sign_in_at,
    (select max(coalesce(s.refreshed_at, s.updated_at))::timestamptz from auth.sessions s where s.user_id = u.id))
  from auth.users u
  where public.mon_role() = 'admin';
$function$
;

CREATE OR REPLACE FUNCTION public.conservation_purger()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a int; j int; e int; s int;
begin
  delete from public.astreinte_incidents where statut in ('RESOLU', 'ARCHIVE') and clos_le < now() - interval '5 years';
  get diagnostics a = row_count;
  delete from public.journal where created_at < now() - interval '5 years';
  get diagnostics j = row_count;
  delete from public.astreinte_alertes_envoyees where le < now() - interval '1 year';
  get diagnostics e = row_count;
  delete from public.astreinte_abonnements where vu_le < now() - interval '6 months';
  get diagnostics s = row_count;
  return jsonb_build_object('incidents_astreinte', a, 'journal', j, 'traces_alertes', e, 'abonnements', s);
end; $function$
;

CREATE OR REPLACE FUNCTION public.contacts_plans()
 RETURNS TABLE(id uuid, contact text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.id, p.contact from public.plans p where public.mon_role() in ('admin','contributeur')
$function$
;

CREATE OR REPLACE FUNCTION public.controles_coherence_groupe()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare d date;
begin
  if new.groupe_id is not null then
    select date_realisation into d from public.controle_groupes where id = new.groupe_id;
    if d is distinct from new.date_realisation then
      raise exception 'Un contrôle d''une visite groupée doit porter la date de cette visite.' using errcode = '23514';
    end if;
  end if;
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.controles_protection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null or coalesce(public.mon_role(), '') = 'admin' then return new; end if;
  if (to_jsonb(new) - 'reserve_levee' - 'date_levee') is distinct from (to_jsonb(old) - 'reserve_levee' - 'date_levee') then
    raise exception 'Seul un administrateur peut corriger un contrôle déjà enregistré (seule la levée de réserve est permise).' using errcode = '42501';
  end if;
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.coordonnees_prestataires()
 RETURNS TABLE(id uuid, contact text, telephone text, email text, adresse text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.id, p.contact, p.telephone, p.email, p.adresse from public.prestataires p
  where public.mon_role() in ('admin','contributeur')
$function$
;

CREATE OR REPLACE FUNCTION public.couts_remplacement()
 RETURNS TABLE(equipement_id uuid, cout_remplacement_ht numeric, cout_remplacement_ttc numeric, cout_source text, cout_date date)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select c.equipement_id, c.cout_remplacement_ht, c.cout_remplacement_ttc, c.cout_source, c.cout_date
  from public.equipement_cycle_vie c
  where public.mon_role() in ('admin','contributeur')
$function$
;

CREATE OR REPLACE FUNCTION public.creer_profil()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.profils (id, email, nom, doit_changer_mdp, actif)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'nom', split_part(new.email, '@', 1)), true, false)
  on conflict (id) do nothing;
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.erp_avant_ecriture()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_table_name = 'site_erp' then new.maj_par := auth.uid(); new.updated_at := now(); return new; end if;
  if tg_op = 'INSERT' then new.cree_par := auth.uid(); new.created_at := now();
  else new.cree_par := old.cree_par; new.created_at := old.created_at; end if;
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.groupes_avant_ecriture()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op = 'INSERT' then new.cree_par := auth.uid(); new.created_at := now();
  else new.cree_par := old.cree_par; new.created_at := old.created_at; end if;
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.incident_documents_journal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare nom text := (select coalesce(nom, email) from public.profils where id = auth.uid());
begin
  if tg_op = 'INSERT' then
    insert into public.incident_historique(incident_id, action, champ, nouvelle_valeur, auteur, auteur_nom)
    values (new.incident_id, 'document', new.type, new.nom, auth.uid(), nom);
    return new;
  end if;
  -- Retrait d'un document (sauf lors de la suppression de l'incident lui-même)
  if exists (select 1 from public.incidents where id = old.incident_id) then
    insert into public.incident_historique(incident_id, action, champ, ancienne_valeur, auteur, auteur_nom)
    values (old.incident_id, 'document_retire', old.type, old.nom, auth.uid(), nom);
  end if;
  return old;
end; $function$
;

CREATE OR REPLACE FUNCTION public.incidents_avant_ecriture()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op = 'INSERT' then
    new.cree_par := auth.uid();
    new.created_at := now();
    if new.statut = 'cloture' and coalesce(public.mon_role(), '') <> 'admin' then
      raise exception 'Seul un administrateur peut clôturer un incident.' using errcode = '42501';
    end if;
  else
    new.cree_par := old.cree_par;
    new.created_at := old.created_at;
    if old.statut = 'cloture' and coalesce(public.mon_role(), '') <> 'admin' then
      raise exception 'Incident clôturé : seul un administrateur peut le modifier.' using errcode = '42501';
    end if;
    if new.statut = 'cloture' and old.statut <> 'cloture' and coalesce(public.mon_role(), '') <> 'admin' then
      raise exception 'Seul un administrateur peut clôturer un incident.' using errcode = '42501';
    end if;
  end if;
  new.updated_at := now();
  -- Dates de résolution / clôture
  if new.statut in ('resolu','cloture') then
    new.date_resolution := coalesce(new.date_resolution, current_date);
  else
    new.date_resolution := null;
  end if;
  if new.statut = 'cloture' then
    new.date_cloture := coalesce(new.date_cloture, current_date);
  else
    new.date_cloture := null;
  end if;
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.incidents_journal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  k text; a jsonb; n jsonb;
  qui uuid := auth.uid();
  nom text := (select coalesce(nom, email) from public.profils where id = auth.uid());
begin
  if tg_op = 'INSERT' then
    insert into public.incident_historique(incident_id, action, nouvelle_valeur, auteur, auteur_nom)
    values (new.id, 'creation', new.titre, qui, nom);
    return new;
  elsif tg_op = 'DELETE' then
    insert into public.incident_historique(incident_id, action, ancienne_valeur, auteur, auteur_nom)
    values (old.id, 'suppression', old.titre, qui, nom);
    return old;
  end if;
  a := to_jsonb(old); n := to_jsonb(new);
  for k in select jsonb_object_keys(n) loop
    continue when k in ('updated_at','created_at','cree_par','id');
    if (a -> k) is distinct from (n -> k) then
      insert into public.incident_historique(incident_id, action, champ, ancienne_valeur, nouvelle_valeur, auteur, auteur_nom)
      values (new.id, case when k = 'statut' then 'statut' else 'modification' end,
              k, a ->> k, n ->> k, qui, nom);
    end if;
  end loop;
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.intervention_commentaires_avant()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  new.auteur := auth.uid();
  new.auteur_nom := (select coalesce(nom, email) from public.profils where id = auth.uid());
  new.created_at := now();
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.intervention_documents_journal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare nom text := (select coalesce(nom, email) from public.profils where id = auth.uid());
begin
  if tg_op = 'INSERT' then
    insert into public.intervention_historique(intervention_id, action, champ, nouvelle_valeur, auteur, auteur_nom)
    values (new.intervention_id, 'document', new.type, new.nom, auth.uid(), nom);
    return new;
  end if;
  if exists (select 1 from public.interventions where id = old.intervention_id) then
    insert into public.intervention_historique(intervention_id, action, champ, ancienne_valeur, auteur, auteur_nom)
    values (old.intervention_id, 'document_retire', old.type, old.nom, auth.uid(), nom);
  end if;
  return old;
end; $function$
;

CREATE OR REPLACE FUNCTION public.interventions_avant_ecriture()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_site uuid; v_equip uuid; v_role text;
  est_admin boolean := auth.uid() is null or coalesce(public.mon_role(), '') = 'admin';
begin
  if tg_op = 'INSERT' then
    new.cree_par   := auth.uid();
    new.created_at := now();
    new.date_cloture := null; new.cloture_par := null;
  else
    new.cree_par   := old.cree_par;
    new.created_at := old.created_at;
    if old.statut in ('termine','annule') and not est_admin then
      raise exception 'Intervention terminée ou annulée : seul un administrateur peut la modifier ou la rouvrir.' using errcode = '42501';
    end if;
  end if;

  -- Cohérence avec l'incident lié
  if new.incident_id is not null then
    select site_id, equipement_id into v_site, v_equip from public.incidents where id = new.incident_id;
    if not found then raise exception 'Incident lié introuvable.' using errcode = '23503'; end if;
    new.site_id := v_site;
    new.equipement_id := coalesce(new.equipement_id, v_equip);
  end if;

  -- Responsable : administrateur ou contributeur (vérifié à l'attribution)
  if new.responsable_id is not null and (tg_op = 'INSERT' or new.responsable_id is distinct from old.responsable_id) then
    select role into v_role from public.profils where id = new.responsable_id;
    if coalesce(v_role, '') not in ('admin','contributeur') then
      raise exception 'Le responsable doit être un administrateur ou un contributeur.' using errcode = '23514';
    end if;
  end if;

  -- Clôture
  if new.statut = 'termine' then
    if new.compte_rendu is null or length(btrim(new.compte_rendu)) = 0 then
      raise exception 'Un compte rendu est obligatoire pour terminer l''intervention.' using errcode = '23514';
    end if;
    if new.date_fin_reelle is null then
      raise exception 'La date de fin réelle est obligatoire pour terminer l''intervention.' using errcode = '23514';
    end if;
    if tg_op = 'INSERT' or old.statut <> 'termine' then
      new.date_cloture := now(); new.cloture_par := auth.uid();
    else
      new.date_cloture := old.date_cloture; new.cloture_par := old.cloture_par;
    end if;
  else
    new.date_cloture := null; new.cloture_par := null;
  end if;

  new.updated_at := now();
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.interventions_journal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  k text; a jsonb; n jsonb;
  qui uuid := auth.uid();
  nom text := (select coalesce(nom, email) from public.profils where id = auth.uid());
begin
  if tg_op = 'INSERT' then
    insert into public.intervention_historique(intervention_id, action, nouvelle_valeur, auteur, auteur_nom)
    values (new.id, 'creation', new.objet, qui, nom);
    return new;
  elsif tg_op = 'DELETE' then
    insert into public.intervention_historique(intervention_id, action, ancienne_valeur, auteur, auteur_nom)
    values (old.id, 'suppression', old.objet, qui, nom);
    return old;
  end if;
  a := to_jsonb(old); n := to_jsonb(new);
  for k in select jsonb_object_keys(n) loop
    continue when k in ('updated_at','created_at','cree_par','id','nature','date_cloture','cloture_par');
    if (a -> k) is distinct from (n -> k) then
      insert into public.intervention_historique(intervention_id, action, champ, ancienne_valeur, nouvelle_valeur, auteur, auteur_nom)
      values (new.id,
              case when k <> 'statut' then 'modification'
                   when n ->> k = 'termine' then 'cloture'
                   when a ->> k in ('termine','annule') then 'reouverture'
                   else 'statut' end,
              k, a ->> k, n ->> k, qui, nom);
    end if;
  end loop;
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.journal_general()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end; $function$
;

CREATE OR REPLACE FUNCTION public.mon_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select role from public.profils where id = auth.uid() and actif
$function$
;

CREATE OR REPLACE FUNCTION public.montants_incidents()
 RETURNS TABLE(id uuid, devis_montant numeric, devis_reference text, facture_montant numeric, facture_reference text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select i.id, i.devis_montant, i.devis_reference, i.facture_montant, i.facture_reference
  from public.incidents i
  where public.mon_role() in ('admin','contributeur')
$function$
;

CREATE OR REPLACE FUNCTION public.montants_interventions()
 RETURNS TABLE(id uuid, estimation_ht numeric, estimation_ttc numeric, devis_ht numeric, devis_ttc numeric, cout_reel_ht numeric, cout_reel_ttc numeric, engage_ht numeric, engage_ttc numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select i.id, i.estimation_ht, i.estimation_ttc, i.devis_ht, i.devis_ttc, i.cout_reel_ht, i.cout_reel_ttc,
         i.engage_ht, i.engage_ttc
  from public.interventions i
  where public.mon_role() in ('admin','contributeur')
$function$
;

CREATE OR REPLACE FUNCTION public.mot_de_passe_change()
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update public.profils set doit_changer_mdp = false where id = auth.uid()
$function$
;

CREATE OR REPLACE FUNCTION public.pei_avant_ecriture()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  new.maj_par := auth.uid(); new.updated_at := now();
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.profils_activation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.actif is distinct from old.actif and auth.uid() is not null then
    if coalesce(public.mon_role(), '') <> 'admin' then
      raise exception 'Seul un administrateur peut activer ou désactiver un compte.' using errcode = '42501';
    end if;
    if new.id = auth.uid() then
      raise exception 'Vous ne pouvez pas désactiver votre propre compte.' using errcode = '42501';
    end if;
  end if;
  return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.profils_dernier_admin()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if old.role = 'admin' and old.actif and (tg_op = 'DELETE' or new.role <> 'admin' or not new.actif)
     and (select count(*) from public.profils where role = 'admin' and actif and id <> old.id) = 0 then
    raise exception 'Il doit rester au moins un administrateur.' using errcode = '23514';
  end if;
  return coalesce(new, old);
end; $function$
;

CREATE OR REPLACE FUNCTION public.profils_detail()
 RETURNS TABLE(id uuid, email text, doit_changer_mdp boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.id, p.email, p.doit_changer_mdp from public.profils p
  where p.id = auth.uid() or public.mon_role() = 'admin'
$function$
;

CREATE OR REPLACE FUNCTION public.revoquer_sessions(p_compte uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare n integer;
begin
  delete from auth.sessions where user_id = p_compte;
  get diagnostics n = row_count;
  delete from auth.refresh_tokens where user_id = p_compte::text;
  delete from public.astreinte_abonnements where compte = p_compte;
  return n;
end; $function$
;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.signalants_incidents()
 RETURNS TABLE(id uuid, signale_par text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select i.id, i.signale_par from public.incidents i
  where public.mon_role() in ('admin','contributeur')
$function$
;

-- ---------------------------------------------------------------------
-- 6. VUES
-- ---------------------------------------------------------------------

create or replace view public.v_echeances with (security_invoker=true) as
 SELECT p.id AS plan_id,
    p.libelle,
    p.periodicite_valeur,
    p.periodicite_unite,
    p.prestataire,
    p.rappel_jours,
    p.obligatoire,
    e.id AS equipement_id,
    e.nom AS equipement,
    e.categorie,
    s.id AS site_id,
    s.nom AS site,
    d.date_realisation AS dernier_controle,
    d.resultat AS dernier_resultat,
        CASE
            WHEN d.date_realisation IS NULL THEN p.date_depart
            ELSE (d.date_realisation +
            CASE p.periodicite_unite
                WHEN 'jour'::text THEN make_interval(days => p.periodicite_valeur)
                WHEN 'semaine'::text THEN make_interval(weeks => p.periodicite_valeur)
                WHEN 'mois'::text THEN make_interval(months => p.periodicite_valeur)
                ELSE make_interval(years => p.periodicite_valeur)
            END)::date
        END AS prochaine,
    ( SELECT count(*) AS count
           FROM controles r
          WHERE r.plan_id = p.id AND r.resultat <> 'conforme'::text AND NOT r.reserve_levee) AS reserves_ouvertes
   FROM plans p
     JOIN equipements e ON e.id = p.equipement_id
     JOIN sites s ON s.id = e.site_id
     LEFT JOIN LATERAL ( SELECT c.date_realisation,
            c.resultat
           FROM controles c
          WHERE c.plan_id = p.id
          ORDER BY c.date_realisation DESC, c.created_at DESC
         LIMIT 1) d ON true
  WHERE p.actif AND e.actif AND s.actif;

-- ---------------------------------------------------------------------
-- 7. DÉCLENCHEURS
-- ---------------------------------------------------------------------

CREATE TRIGGER astreinte_avant BEFORE INSERT OR UPDATE ON public.astreinte_incidents FOR EACH ROW EXECUTE FUNCTION astreinte_avant_ecriture();
CREATE TRIGGER erp_avant BEFORE INSERT OR UPDATE ON public.commission_prescriptions FOR EACH ROW EXECUTE FUNCTION erp_avant_ecriture();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.commission_prescriptions FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER erp_avant BEFORE INSERT OR UPDATE ON public.commission_visites FOR EACH ROW EXECUTE FUNCTION erp_avant_ecriture();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.commission_visites FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER controle_groupes_avant BEFORE INSERT OR UPDATE ON public.controle_groupes FOR EACH ROW EXECUTE FUNCTION groupes_avant_ecriture();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.controle_groupes FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER controles_coherence_groupe BEFORE INSERT OR UPDATE ON public.controles FOR EACH ROW EXECUTE FUNCTION controles_coherence_groupe();
CREATE TRIGGER controles_protection BEFORE UPDATE ON public.controles FOR EACH ROW EXECUTE FUNCTION controles_protection();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.controles FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER depenses_avant BEFORE INSERT OR UPDATE ON public.depenses FOR EACH ROW EXECUTE FUNCTION budget_avant_ecriture();
CREATE TRIGGER depenses_journal AFTER INSERT OR DELETE OR UPDATE ON public.depenses FOR EACH ROW EXECUTE FUNCTION budget_journal();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.documents FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER cycle_vie_avant BEFORE INSERT OR UPDATE ON public.equipement_cycle_vie FOR EACH ROW EXECUTE FUNCTION budget_avant_ecriture();
CREATE TRIGGER cycle_vie_journal AFTER INSERT OR DELETE OR UPDATE ON public.equipement_cycle_vie FOR EACH ROW EXECUTE FUNCTION budget_journal();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.equipement_pei FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER pei_avant BEFORE INSERT OR UPDATE ON public.equipement_pei FOR EACH ROW EXECUTE FUNCTION pei_avant_ecriture();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.equipements FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER erp_avant BEFORE INSERT OR UPDATE ON public.exercices_securite FOR EACH ROW EXECUTE FUNCTION erp_avant_ecriture();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.exercices_securite FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER factures_avant BEFORE INSERT OR UPDATE ON public.factures FOR EACH ROW EXECUTE FUNCTION budget_avant_ecriture();
CREATE TRIGGER factures_journal AFTER INSERT OR DELETE OR UPDATE ON public.factures FOR EACH ROW EXECUTE FUNCTION budget_journal();
CREATE TRIGGER groupe_documents_avant BEFORE INSERT OR UPDATE ON public.groupe_documents FOR EACH ROW EXECUTE FUNCTION groupes_avant_ecriture();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.groupe_documents FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER incident_documents_journal AFTER INSERT OR DELETE ON public.incident_documents FOR EACH ROW EXECUTE FUNCTION incident_documents_journal();
CREATE TRIGGER astreinte_retour AFTER UPDATE OF statut ON public.incidents FOR EACH ROW EXECUTE FUNCTION astreinte_retour_resolution();
CREATE TRIGGER incidents_avant_ecriture BEFORE INSERT OR UPDATE ON public.incidents FOR EACH ROW EXECUTE FUNCTION incidents_avant_ecriture();
CREATE TRIGGER incidents_journal AFTER INSERT OR DELETE OR UPDATE ON public.incidents FOR EACH ROW EXECUTE FUNCTION incidents_journal();
CREATE TRIGGER intervention_commentaires_avant BEFORE INSERT ON public.intervention_commentaires FOR EACH ROW EXECUTE FUNCTION intervention_commentaires_avant();
CREATE TRIGGER intervention_documents_journal AFTER INSERT OR DELETE ON public.intervention_documents FOR EACH ROW EXECUTE FUNCTION intervention_documents_journal();
CREATE TRIGGER interventions_avant_ecriture BEFORE INSERT OR UPDATE ON public.interventions FOR EACH ROW EXECUTE FUNCTION interventions_avant_ecriture();
CREATE TRIGGER interventions_journal AFTER INSERT OR DELETE OR UPDATE ON public.interventions FOR EACH ROW EXECUTE FUNCTION interventions_journal();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.plans FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.profils FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER profils_activation BEFORE UPDATE ON public.profils FOR EACH ROW EXECUTE FUNCTION profils_activation();
CREATE TRIGGER profils_dernier_admin BEFORE DELETE OR UPDATE ON public.profils FOR EACH ROW EXECUTE FUNCTION profils_dernier_admin();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.site_documents FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER erp_avant BEFORE INSERT OR UPDATE ON public.site_erp FOR EACH ROW EXECUTE FUNCTION erp_avant_ecriture();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.site_erp FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER journal_general AFTER INSERT OR DELETE OR UPDATE ON public.sites FOR EACH ROW EXECUTE FUNCTION journal_general();
CREATE TRIGGER creer_profil_apres_inscription AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION creer_profil();

-- ---------------------------------------------------------------------
-- 8. DÉCLENCHEURS D'ÉVÉNEMENT
-- ---------------------------------------------------------------------

create event trigger ensure_rls on ddl_command_end when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO') execute function rls_auto_enable();

-- ---------------------------------------------------------------------
-- 9. SÉCURITÉ PAR LIGNE (RLS)
-- ---------------------------------------------------------------------

alter table public.astreinte_abonnements enable row level security;
alter table public.astreinte_alertes_envoyees enable row level security;
alter table public.astreinte_incidents enable row level security;
alter table public.budget_historique enable row level security;
alter table public.cles_serveur enable row level security;
alter table public.commission_prescriptions enable row level security;
alter table public.commission_visites enable row level security;
alter table public.controle_groupes enable row level security;
alter table public.controles enable row level security;
alter table public.depenses enable row level security;
alter table public.documents enable row level security;
alter table public.equipement_cycle_vie enable row level security;
alter table public.equipement_pei enable row level security;
alter table public.equipements enable row level security;
alter table public.exercices_securite enable row level security;
alter table public.factures enable row level security;
alter table public.groupe_documents enable row level security;
alter table public.incident_documents enable row level security;
alter table public.incident_historique enable row level security;
alter table public.incidents enable row level security;
alter table public.intervention_commentaires enable row level security;
alter table public.intervention_documents enable row level security;
alter table public.intervention_historique enable row level security;
alter table public.interventions enable row level security;
alter table public.journal enable row level security;
alter table public.parametres enable row level security;
alter table public.plans enable row level security;
alter table public.prestataires enable row level security;
alter table public.profils enable row level security;
alter table public.site_documents enable row level security;
alter table public.site_erp enable row level security;
alter table public.sites enable row level security;

-- ---------------------------------------------------------------------
-- 10. RÈGLES D'ACCÈS (tables et fichiers)
-- ---------------------------------------------------------------------

create policy "astreinte ajout" on public.astreinte_incidents as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text, 'lecteur'::text, 'agent'::text])));
create policy "astreinte lecture" on public.astreinte_incidents as permissive for select to authenticated
  using (((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])) OR ((mon_role() = ANY (ARRAY['lecteur'::text, 'agent'::text])) AND (cree_par = auth.uid()))));
create policy "astreinte modification" on public.astreinte_incidents as permissive for update to authenticated
  using (((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])) OR ((mon_role() = ANY (ARRAY['lecteur'::text, 'agent'::text])) AND (cree_par = auth.uid()))))
  with check (((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])) OR ((mon_role() = ANY (ARRAY['lecteur'::text, 'agent'::text])) AND (cree_par = auth.uid()))));
create policy "compte actif" on public.astreinte_incidents as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "budget historique lecture" on public.budget_historique as permissive for select to authenticated
  using (((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])) OR ((objet_type = 'cycle_vie'::text) AND (COALESCE(champ, ''::text) !~~ 'cout%'::text))));
create policy "compte actif" on public.budget_historique as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "pas agent" on public.budget_historique as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "commission_prescriptions ajout" on public.commission_prescriptions as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "commission_prescriptions lecture" on public.commission_prescriptions as permissive for select to authenticated
  using (true);
create policy "commission_prescriptions modification" on public.commission_prescriptions as permissive for update to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])))
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "commission_prescriptions suppression" on public.commission_prescriptions as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "compte actif" on public.commission_prescriptions as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "pas agent" on public.commission_prescriptions as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "commission_visites ajout" on public.commission_visites as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "commission_visites lecture" on public.commission_visites as permissive for select to authenticated
  using (true);
create policy "commission_visites modification" on public.commission_visites as permissive for update to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])))
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "commission_visites suppression" on public.commission_visites as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "compte actif" on public.commission_visites as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "pas agent" on public.commission_visites as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.controle_groupes as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "groupes ajout" on public.controle_groupes as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "groupes lecture" on public.controle_groupes as permissive for select to authenticated
  using (true);
create policy "groupes modification" on public.controle_groupes as permissive for update to authenticated
  using ((mon_role() = 'admin'::text))
  with check ((mon_role() = 'admin'::text));
create policy "groupes suppression" on public.controle_groupes as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "pas agent" on public.controle_groupes as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.controles as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "controles ajout" on public.controles as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "controles lecture" on public.controles as permissive for select to authenticated
  using (true);
create policy "controles modification" on public.controles as permissive for update to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])))
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "controles suppression" on public.controles as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "pas agent" on public.controles as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.depenses as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "depenses ajout" on public.depenses as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "depenses lecture" on public.depenses as permissive for select to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "depenses modification" on public.depenses as permissive for update to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])))
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "depenses suppression" on public.depenses as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "pas agent" on public.depenses as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.documents as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "documents ajout" on public.documents as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "documents lecture" on public.documents as permissive for select to authenticated
  using (true);
create policy "documents suppression" on public.documents as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "pas agent" on public.documents as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.equipement_cycle_vie as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "cycle vie ajout" on public.equipement_cycle_vie as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "cycle vie lecture" on public.equipement_cycle_vie as permissive for select to authenticated
  using (true);
create policy "cycle vie modification" on public.equipement_cycle_vie as permissive for update to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])))
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "pas agent" on public.equipement_cycle_vie as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.equipement_pei as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "pas agent" on public.equipement_pei as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "pei ajout" on public.equipement_pei as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "pei lecture" on public.equipement_pei as permissive for select to authenticated
  using (true);
create policy "pei modification" on public.equipement_pei as permissive for update to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])))
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "pei suppression" on public.equipement_pei as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "compte actif" on public.equipements as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "equipements gestion admin" on public.equipements as permissive for all to authenticated
  using ((mon_role() = 'admin'::text))
  with check ((mon_role() = 'admin'::text));
create policy "equipements lecture" on public.equipements as permissive for select to authenticated
  using (true);
create policy "pas agent" on public.equipements as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.exercices_securite as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "exercices_securite ajout" on public.exercices_securite as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "exercices_securite lecture" on public.exercices_securite as permissive for select to authenticated
  using (true);
create policy "exercices_securite modification" on public.exercices_securite as permissive for update to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])))
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "exercices_securite suppression" on public.exercices_securite as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "pas agent" on public.exercices_securite as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.factures as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "factures ajout" on public.factures as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "factures lecture" on public.factures as permissive for select to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "factures modification" on public.factures as permissive for update to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])))
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "factures suppression" on public.factures as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "pas agent" on public.factures as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.groupe_documents as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "groupe docs ajout" on public.groupe_documents as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "groupe docs lecture" on public.groupe_documents as permissive for select to authenticated
  using (true);
create policy "groupe docs suppression" on public.groupe_documents as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "pas agent" on public.groupe_documents as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.incident_documents as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "incident docs ajout" on public.incident_documents as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "incident docs lecture" on public.incident_documents as permissive for select to authenticated
  using (((type <> ALL (ARRAY['devis'::text, 'facture'::text])) OR (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text]))));
create policy "incident docs suppression" on public.incident_documents as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "pas agent" on public.incident_documents as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.incident_historique as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "incident historique lecture" on public.incident_historique as permissive for select to authenticated
  using (((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])) OR (champ IS NULL) OR (champ <> ALL (ARRAY['devis_montant'::text, 'devis_reference'::text, 'facture_montant'::text, 'facture_reference'::text, 'signale_par'::text]))));
create policy "pas agent" on public.incident_historique as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.incidents as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "incidents ajout" on public.incidents as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "incidents lecture" on public.incidents as permissive for select to authenticated
  using (true);
create policy "incidents modification" on public.incidents as permissive for update to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])))
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "incidents suppression" on public.incidents as permissive for delete to authenticated
  using (((mon_role() = 'admin'::text) AND (statut = 'nouveau'::text)));
create policy "pas agent" on public.incidents as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.intervention_commentaires as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "intervention comm ajout" on public.intervention_commentaires as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "intervention comm lecture" on public.intervention_commentaires as permissive for select to authenticated
  using (true);
create policy "pas agent" on public.intervention_commentaires as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.intervention_documents as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "intervention docs ajout" on public.intervention_documents as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "intervention docs lecture" on public.intervention_documents as permissive for select to authenticated
  using (((type <> ALL (ARRAY['devis'::text, 'bon_commande'::text, 'facture'::text])) OR (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text]))));
create policy "intervention docs suppression" on public.intervention_documents as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "pas agent" on public.intervention_documents as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.intervention_historique as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "intervention historique lecture" on public.intervention_historique as permissive for select to authenticated
  using (((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])) OR (champ IS NULL) OR (champ <> ALL (ARRAY['estimation_ht'::text, 'estimation_ttc'::text, 'devis_ht'::text, 'devis_ttc'::text, 'cout_reel_ht'::text, 'cout_reel_ttc'::text, 'engage_ht'::text, 'engage_ttc'::text, 'devis'::text, 'bon_commande'::text, 'facture'::text]))));
create policy "pas agent" on public.intervention_historique as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.interventions as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "interventions ajout" on public.interventions as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "interventions lecture" on public.interventions as permissive for select to authenticated
  using (true);
create policy "interventions modification" on public.interventions as permissive for update to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])))
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "interventions suppression" on public.interventions as permissive for delete to authenticated
  using (((mon_role() = 'admin'::text) AND (statut = 'a_planifier'::text) AND (NOT (EXISTS ( SELECT 1
   FROM intervention_documents d
  WHERE (d.intervention_id = interventions.id))))));
create policy "pas agent" on public.interventions as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.journal as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "journal lecture" on public.journal as permissive for select to authenticated
  using (((mon_role() = 'admin'::text) OR ((mon_role() = 'contributeur'::text) AND (table_nom <> 'profils'::text))));
create policy "pas agent" on public.journal as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.parametres as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "parametres astreinte lecture" on public.parametres as restrictive for select to authenticated
  using (((cle <> ALL (ARRAY['astreinte_config'::text, 'planning_astreinte'::text])) OR (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text, 'lecteur'::text, 'agent'::text]))));
create policy "parametres astreinte modification" on public.parametres as permissive for update to authenticated
  using (((cle = 'astreinte_config'::text) AND (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text]))))
  with check (((cle = 'astreinte_config'::text) AND (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text]))));
create policy "parametres lecture" on public.parametres as permissive for select to authenticated
  using (true);
create policy "parametres modification" on public.parametres as permissive for update to authenticated
  using ((mon_role() = 'admin'::text))
  with check ((mon_role() = 'admin'::text));
create policy "pas agent" on public.parametres as restrictive for all to authenticated
  using (((COALESCE(mon_role(), ''::text) <> 'agent'::text) OR (cle = ANY (ARRAY['astreinte_config'::text, 'planning_astreinte'::text]))))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "compte actif" on public.plans as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "pas agent" on public.plans as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "plans gestion admin" on public.plans as permissive for all to authenticated
  using ((mon_role() = 'admin'::text))
  with check ((mon_role() = 'admin'::text));
create policy "plans lecture" on public.plans as permissive for select to authenticated
  using (true);
create policy "compte actif" on public.prestataires as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "pas agent" on public.prestataires as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "prestataires ajout" on public.prestataires as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "prestataires lecture" on public.prestataires as permissive for select to authenticated
  using (true);
create policy "prestataires modification" on public.prestataires as permissive for update to authenticated
  using ((mon_role() = 'admin'::text))
  with check ((mon_role() = 'admin'::text));
create policy "compte actif" on public.profils as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "pas agent" on public.profils as restrictive for select to authenticated
  using (((COALESCE(mon_role(), ''::text) <> 'agent'::text) OR (id = auth.uid())));
create policy "profils lecture" on public.profils as permissive for select to authenticated
  using (true);
create policy "profils modification admin" on public.profils as permissive for update to authenticated
  using ((mon_role() = 'admin'::text))
  with check ((mon_role() = 'admin'::text));
create policy "profils modification soi" on public.profils as permissive for update to authenticated
  using ((id = auth.uid()))
  with check (((id = auth.uid()) AND (role = mon_role())));
create policy "compte actif" on public.site_documents as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "pas agent" on public.site_documents as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "site docs ajout" on public.site_documents as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "site docs lecture" on public.site_documents as permissive for select to authenticated
  using (((type <> 'contrat'::text) OR (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text]))));
create policy "site docs modification" on public.site_documents as permissive for update to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])))
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "site docs suppression" on public.site_documents as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "compte actif" on public.site_erp as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "pas agent" on public.site_erp as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "site_erp ajout" on public.site_erp as permissive for insert to authenticated
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "site_erp lecture" on public.site_erp as permissive for select to authenticated
  using (true);
create policy "site_erp modification" on public.site_erp as permissive for update to authenticated
  using ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])))
  with check ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])));
create policy "site_erp suppression" on public.site_erp as permissive for delete to authenticated
  using ((mon_role() = 'admin'::text));
create policy "compte actif" on public.sites as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "pas agent" on public.sites as restrictive for all to authenticated
  using ((COALESCE(mon_role(), ''::text) <> 'agent'::text))
  with check ((COALESCE(mon_role(), ''::text) <> 'agent'::text));
create policy "sites gestion admin" on public.sites as permissive for all to authenticated
  using ((mon_role() = 'admin'::text))
  with check ((mon_role() = 'admin'::text));
create policy "sites lecture" on public.sites as permissive for select to authenticated
  using (true);
create policy "astreinte fichiers ajout" on storage.objects as permissive for insert to authenticated
  with check (((bucket_id = 'astreinte'::text) AND (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text, 'lecteur'::text, 'agent'::text]))));
create policy "astreinte fichiers lecture" on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'astreinte'::text) AND ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])) OR ((mon_role() = ANY (ARRAY['lecteur'::text, 'agent'::text])) AND (EXISTS ( SELECT 1
   FROM astreinte_incidents a
  WHERE (((a.uuid)::text = split_part(objects.name, '/'::text, 1)) AND (a.cree_par = auth.uid()))))))));
create policy "astreinte fichiers suppression" on storage.objects as permissive for delete to authenticated
  using (((bucket_id = 'astreinte'::text) AND (mon_role() = 'admin'::text)));
create policy "batiments fichiers ajout" on storage.objects as permissive for insert to authenticated
  with check (((bucket_id = 'batiments'::text) AND (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text]))));
create policy "batiments fichiers lecture" on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'batiments'::text) AND ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])) OR (EXISTS ( SELECT 1
   FROM site_documents d
  WHERE (d.chemin = objects.name))) OR (EXISTS ( SELECT 1
   FROM commission_visites v
  WHERE (v.chemin = objects.name))))));
create policy "batiments fichiers suppression" on storage.objects as permissive for delete to authenticated
  using (((bucket_id = 'batiments'::text) AND (mon_role() = 'admin'::text)));
create policy "compte actif" on storage.objects as restrictive for all to authenticated
  using (compte_actif())
  with check (compte_actif());
create policy "factures fichiers ajout" on storage.objects as permissive for insert to authenticated
  with check (((bucket_id = 'factures'::text) AND (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text]))));
create policy "factures fichiers lecture" on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'factures'::text) AND (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text]))));
create policy "factures fichiers suppression" on storage.objects as permissive for delete to authenticated
  using (((bucket_id = 'factures'::text) AND (mon_role() = 'admin'::text)));
create policy "incidents fichiers ajout" on storage.objects as permissive for insert to authenticated
  with check (((bucket_id = 'incidents'::text) AND (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text]))));
create policy "incidents fichiers lecture" on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'incidents'::text) AND ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])) OR (EXISTS ( SELECT 1
   FROM incident_documents d
  WHERE (d.chemin = objects.name))))));
create policy "incidents fichiers suppression" on storage.objects as permissive for delete to authenticated
  using (((bucket_id = 'incidents'::text) AND (mon_role() = 'admin'::text)));
create policy "interventions fichiers ajout" on storage.objects as permissive for insert to authenticated
  with check (((bucket_id = 'interventions'::text) AND (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text]))));
create policy "interventions fichiers lecture" on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'interventions'::text) AND ((mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text])) OR (EXISTS ( SELECT 1
   FROM intervention_documents d
  WHERE (d.chemin = objects.name))))));
create policy "interventions fichiers suppression" on storage.objects as permissive for delete to authenticated
  using (((bucket_id = 'interventions'::text) AND (mon_role() = 'admin'::text)));
create policy "pas agent" on storage.objects as restrictive for all to authenticated
  using (((COALESCE(mon_role(), ''::text) <> 'agent'::text) OR (bucket_id = 'astreinte'::text)))
  with check (((COALESCE(mon_role(), ''::text) <> 'agent'::text) OR (bucket_id = 'astreinte'::text)));
create policy "rapports ajout" on storage.objects as permissive for insert to authenticated
  with check (((bucket_id = 'rapports'::text) AND (mon_role() = ANY (ARRAY['admin'::text, 'contributeur'::text]))));
create policy "rapports lecture" on storage.objects as permissive for select to authenticated
  using ((bucket_id = 'rapports'::text));
create policy "rapports suppression" on storage.objects as permissive for delete to authenticated
  using (((bucket_id = 'rapports'::text) AND (mon_role() = 'admin'::text)));

-- ---------------------------------------------------------------------
-- 11. DROITS SUR LES FONCTIONS
-- ---------------------------------------------------------------------

revoke all on function public.astreinte_anonymiser(delai interval) from public, anon, authenticated;
grant execute on function public.astreinte_anonymiser(delai interval) to service_role;
revoke all on function public.astreinte_avant_ecriture() from public, anon, authenticated;
grant execute on function public.astreinte_avant_ecriture() to service_role;
revoke all on function public.astreinte_retour_resolution() from public, anon, authenticated;
grant execute on function public.astreinte_retour_resolution() to service_role;
revoke all on function public.budget_avant_ecriture() from public, anon, authenticated;
grant execute on function public.budget_avant_ecriture() to service_role;
revoke all on function public.budget_journal() from public, anon, authenticated;
grant execute on function public.budget_journal() to service_role;
revoke all on function public.compte_actif() from public, anon, authenticated;
grant execute on function public.compte_actif() to authenticated;
grant execute on function public.compte_actif() to service_role;
revoke all on function public.comptes_activite() from public, anon, authenticated;
grant execute on function public.comptes_activite() to authenticated;
grant execute on function public.comptes_activite() to service_role;
revoke all on function public.conservation_purger() from public, anon, authenticated;
grant execute on function public.conservation_purger() to service_role;
revoke all on function public.contacts_plans() from public, anon, authenticated;
grant execute on function public.contacts_plans() to authenticated;
grant execute on function public.contacts_plans() to service_role;
revoke all on function public.controles_coherence_groupe() from public, anon, authenticated;
grant execute on function public.controles_coherence_groupe() to service_role;
revoke all on function public.controles_protection() from public, anon, authenticated;
grant execute on function public.controles_protection() to service_role;
revoke all on function public.coordonnees_prestataires() from public, anon, authenticated;
grant execute on function public.coordonnees_prestataires() to authenticated;
grant execute on function public.coordonnees_prestataires() to service_role;
revoke all on function public.couts_remplacement() from public, anon, authenticated;
grant execute on function public.couts_remplacement() to authenticated;
grant execute on function public.couts_remplacement() to service_role;
revoke all on function public.creer_profil() from public, anon, authenticated;
grant execute on function public.creer_profil() to service_role;
revoke all on function public.erp_avant_ecriture() from public, anon, authenticated;
grant execute on function public.erp_avant_ecriture() to service_role;
revoke all on function public.groupes_avant_ecriture() from public, anon, authenticated;
grant execute on function public.groupes_avant_ecriture() to service_role;
revoke all on function public.incident_documents_journal() from public, anon, authenticated;
grant execute on function public.incident_documents_journal() to service_role;
revoke all on function public.incidents_avant_ecriture() from public, anon, authenticated;
grant execute on function public.incidents_avant_ecriture() to service_role;
revoke all on function public.incidents_journal() from public, anon, authenticated;
grant execute on function public.incidents_journal() to service_role;
revoke all on function public.intervention_commentaires_avant() from public, anon, authenticated;
grant execute on function public.intervention_commentaires_avant() to service_role;
revoke all on function public.intervention_documents_journal() from public, anon, authenticated;
grant execute on function public.intervention_documents_journal() to service_role;
revoke all on function public.interventions_avant_ecriture() from public, anon, authenticated;
grant execute on function public.interventions_avant_ecriture() to service_role;
revoke all on function public.interventions_journal() from public, anon, authenticated;
grant execute on function public.interventions_journal() to service_role;
revoke all on function public.journal_general() from public, anon, authenticated;
grant execute on function public.journal_general() to service_role;
revoke all on function public.mon_role() from public, anon, authenticated;
grant execute on function public.mon_role() to authenticated;
grant execute on function public.mon_role() to service_role;
revoke all on function public.montants_incidents() from public, anon, authenticated;
grant execute on function public.montants_incidents() to authenticated;
grant execute on function public.montants_incidents() to service_role;
revoke all on function public.montants_interventions() from public, anon, authenticated;
grant execute on function public.montants_interventions() to authenticated;
grant execute on function public.montants_interventions() to service_role;
revoke all on function public.mot_de_passe_change() from public, anon, authenticated;
grant execute on function public.mot_de_passe_change() to authenticated;
grant execute on function public.mot_de_passe_change() to service_role;
revoke all on function public.pei_avant_ecriture() from public, anon, authenticated;
grant execute on function public.pei_avant_ecriture() to service_role;
revoke all on function public.profils_activation() from public, anon, authenticated;
grant execute on function public.profils_activation() to service_role;
revoke all on function public.profils_dernier_admin() from public, anon, authenticated;
grant execute on function public.profils_dernier_admin() to service_role;
revoke all on function public.profils_detail() from public, anon, authenticated;
grant execute on function public.profils_detail() to authenticated;
grant execute on function public.profils_detail() to service_role;
revoke all on function public.revoquer_sessions(p_compte uuid) from public, anon, authenticated;
grant execute on function public.revoquer_sessions(p_compte uuid) to service_role;
revoke all on function public.rls_auto_enable() from public, anon, authenticated;
grant execute on function public.rls_auto_enable() to service_role;
revoke all on function public.signalants_incidents() from public, anon, authenticated;
grant execute on function public.signalants_incidents() to authenticated;
grant execute on function public.signalants_incidents() to service_role;

-- ---------------------------------------------------------------------
-- 12. DROITS SUR LES TABLES ET VUES
-- ---------------------------------------------------------------------

grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.astreinte_abonnements to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.astreinte_alertes_envoyees to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.astreinte_incidents to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.astreinte_incidents to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.budget_historique to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.budget_historique to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.cles_serveur to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.commission_prescriptions to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.commission_prescriptions to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.commission_visites to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.commission_visites to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.controle_groupes to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.controle_groupes to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.controles to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.controles to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.depenses to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.depenses to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.documents to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.documents to service_role;
grant DELETE, INSERT, REFERENCES, TRIGGER, UPDATE on public.equipement_cycle_vie to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.equipement_cycle_vie to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.equipement_pei to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.equipement_pei to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.equipements to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.equipements to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.exercices_securite to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.exercices_securite to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.factures to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.factures to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.groupe_documents to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.groupe_documents to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.incident_documents to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.incident_documents to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.incident_historique to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.incident_historique to service_role;
grant DELETE, INSERT, REFERENCES, TRIGGER, UPDATE on public.incidents to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.incidents to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.intervention_commentaires to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.intervention_commentaires to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.intervention_documents to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.intervention_documents to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.intervention_historique to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.intervention_historique to service_role;
grant DELETE, INSERT, REFERENCES, TRIGGER, UPDATE on public.interventions to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.interventions to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.journal to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.journal to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.parametres to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.parametres to service_role;
grant DELETE, INSERT, REFERENCES, TRIGGER, UPDATE on public.plans to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.plans to service_role;
grant DELETE, INSERT, REFERENCES, TRIGGER, UPDATE on public.prestataires to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.prestataires to service_role;
grant DELETE, REFERENCES, TRIGGER on public.profils to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.profils to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER on public.site_documents to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.site_documents to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.site_erp to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.site_erp to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.sites to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.sites to service_role;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, UPDATE on public.v_echeances to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.v_echeances to service_role;

-- ---------------------------------------------------------------------
-- 13. DROITS SUR LES SÉQUENCES
-- ---------------------------------------------------------------------

grant USAGE on sequence public.budget_historique_id_seq to anon;
grant USAGE on sequence public.budget_historique_id_seq to authenticated;
grant USAGE on sequence public.budget_historique_id_seq to service_role;
grant USAGE on sequence public.incident_historique_id_seq to anon;
grant USAGE on sequence public.incident_historique_id_seq to authenticated;
grant USAGE on sequence public.incident_historique_id_seq to service_role;
grant USAGE on sequence public.intervention_historique_id_seq to anon;
grant USAGE on sequence public.intervention_historique_id_seq to authenticated;
grant USAGE on sequence public.intervention_historique_id_seq to service_role;
grant USAGE on sequence public.journal_id_seq to anon;
grant USAGE on sequence public.journal_id_seq to authenticated;
grant USAGE on sequence public.journal_id_seq to service_role;

-- ---------------------------------------------------------------------
-- 14. ESPACES DE FICHIERS (Storage)
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('astreinte', 'astreinte', false, 10485760, '{image/*}') on conflict (id) do nothing;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('batiments', 'batiments', false, 26214400, '{image/*,application/pdf}') on conflict (id) do nothing;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('factures', 'factures', false, 26214400, '{image/*,application/pdf}') on conflict (id) do nothing;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('incidents', 'incidents', false, 26214400, '{image/*,application/pdf}') on conflict (id) do nothing;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('interventions', 'interventions', false, 26214400, '{image/*,application/pdf}') on conflict (id) do nothing;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('rapports', 'rapports', false, 26214400, '{image/*,application/pdf}') on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 15. TÂCHES PLANIFIÉES (pg_cron)
-- ---------------------------------------------------------------------

select cron.schedule('astreinte-anonymisation', '17 3 * * *', 'select public.astreinte_anonymiser()');
select cron.schedule('astreinte-photos', '27 3 * * *', '
  select net.http_post(
    url := ''https://idswkljjaoajhevgsnfh.supabase.co/functions/v1/entretien-astreinte'',
    headers := jsonb_build_object(''Content-Type'', ''application/json'',
                                  ''x-cle-entretien'', (select valeur->>''v'' from public.cles_serveur where cle = ''entretien'')),
    body := ''{}''::jsonb)
');
select cron.schedule('conservation-purge', '37 3 * * *', 'select public.conservation_purger()');
