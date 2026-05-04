-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.actualites_chantier (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  projet_id uuid NOT NULL,
  type text NOT NULL DEFAULT 'Progrès'::text,
  contenu text NOT NULL,
  auteur text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT actualites_chantier_pkey PRIMARY KEY (id),
  CONSTRAINT actualites_chantier_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES public.projets(id)
);
CREATE TABLE public.architectes (
  id uuid NOT NULL,
  nom text NOT NULL DEFAULT ''::text,
  prenom text NOT NULL DEFAULT ''::text,
  email text NOT NULL DEFAULT ''::text,
  telephone text,
  cabinet text,
  avatar_url text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT architectes_pkey PRIMARY KEY (id)
);
CREATE TABLE public.client_portal_access (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  projet_id uuid,
  client_nom text NOT NULL,
  client_email text NOT NULL,
  password_hash text,
  password_raw text,
  actif boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  last_login timestamp with time zone,
  password_changed boolean DEFAULT false,
  CONSTRAINT client_portal_access_pkey PRIMARY KEY (id),
  CONSTRAINT client_portal_access_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES public.projets(id)
);
CREATE TABLE public.clients (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  nom text NOT NULL,
  email text,
  telephone text,
  created_at timestamp with time zone DEFAULT now(),
  acces_portail boolean DEFAULT true,
  CONSTRAINT clients_pkey PRIMARY KEY (id)
);
CREATE TABLE public.commentaires (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  projet_id uuid,
  auteur text NOT NULL,
  role text DEFAULT 'client'::text,
  contenu text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  client_portal_id uuid,
  fichier_url text,
  fichier_nom text,
  CONSTRAINT commentaires_pkey PRIMARY KEY (id),
  CONSTRAINT commentaires_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES public.projets(id),
  CONSTRAINT commentaires_client_portal_id_fkey FOREIGN KEY (client_portal_id) REFERENCES public.client_portal_access(id)
);
CREATE TABLE public.comptes_rendus (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  projet_id uuid,
  titre text NOT NULL,
  statut text DEFAULT 'conforme'::text,
  auteur text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  contenu text DEFAULT ''::text,
  document_id uuid,
  CONSTRAINT comptes_rendus_pkey PRIMARY KEY (id),
  CONSTRAINT comptes_rendus_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES public.projets(id)
);
CREATE TABLE public.conges (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  membre_id uuid NOT NULL,
  date_debut date NOT NULL,
  date_fin date NOT NULL,
  motif text DEFAULT ''::text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT conges_pkey PRIMARY KEY (id),
  CONSTRAINT conges_membre_id_fkey FOREIGN KEY (membre_id) REFERENCES public.membres(id)
);
CREATE TABLE public.defauts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  projet_id uuid,
  document_id text NOT NULL,
  document_nom text NOT NULL,
  titre text NOT NULL,
  statut text DEFAULT 'a_faire'::text,
  x double precision NOT NULL,
  y double precision NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT defauts_pkey PRIMARY KEY (id),
  CONSTRAINT defauts_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES public.projets(id)
);
CREATE TABLE public.documents (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  projet_id uuid,
  nom text NOT NULL,
  url text NOT NULL,
  type text DEFAULT 'pdf'::text,
  taille_kb integer,
  uploaded_at timestamp with time zone DEFAULT now(),
  CONSTRAINT documents_pkey PRIMARY KEY (id),
  CONSTRAINT documents_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES public.projets(id)
);
CREATE TABLE public.factures (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  projet_id uuid,
  numero text NOT NULL,
  montant numeric NOT NULL,
  statut text DEFAULT 'en_attente'::text CHECK (statut = ANY (ARRAY['en_attente'::text, 'payee'::text, 'en_retard'::text])),
  date_echeance date,
  url_pdf text,
  created_at timestamp with time zone DEFAULT now(),
  fournisseur text DEFAULT ''::text,
  tache_associee text DEFAULT ''::text,
  chef_projet text DEFAULT ''::text,
  phase_id uuid,
  facture_type text DEFAULT 'extra'::text CHECK (facture_type = ANY (ARRAY['initiale'::text, 'extra'::text])),
  CONSTRAINT factures_pkey PRIMARY KEY (id),
  CONSTRAINT factures_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES public.projets(id),
  CONSTRAINT factures_phase_id_fkey FOREIGN KEY (phase_id) REFERENCES public.phases(id)
);
CREATE TABLE public.membre_taches (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  membre_id uuid NOT NULL,
  tache_id uuid NOT NULL,
  projet_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT membre_taches_pkey PRIMARY KEY (id),
  CONSTRAINT membre_taches_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES public.projets(id),
  CONSTRAINT membre_taches_membre_id_fkey FOREIGN KEY (membre_id) REFERENCES public.membres(id),
  CONSTRAINT membre_taches_tache_id_fkey FOREIGN KEY (tache_id) REFERENCES public.taches(id)
);
CREATE TABLE public.membres (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  nom text NOT NULL,
  role text,
  email text,
  telephone text,
  disponible boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  specialite text,
  projets_assignes ARRAY DEFAULT '{}'::text[],
  CONSTRAINT membres_pkey PRIMARY KEY (id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  message text NOT NULL,
  projet text NOT NULL DEFAULT ''::text,
  date text NOT NULL DEFAULT ''::text,
  heure text NOT NULL DEFAULT ''::text,
  type text NOT NULL DEFAULT 'info'::text,
  lue boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.phases (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  projet_id uuid NOT NULL,
  user_id uuid,
  nom text NOT NULL,
  ordre integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT phases_pkey PRIMARY KEY (id),
  CONSTRAINT phases_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES public.projets(id),
  CONSTRAINT phases_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.photos_chantier (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  projet_id uuid NOT NULL,
  nom text NOT NULL,
  url text NOT NULL,
  description text DEFAULT ''::text,
  uploaded_at timestamp with time zone DEFAULT now(),
  CONSTRAINT photos_chantier_pkey PRIMARY KEY (id),
  CONSTRAINT photos_chantier_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES public.projets(id)
);
CREATE TABLE public.project_members (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  project_id uuid,
  membre_id uuid,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT project_members_pkey PRIMARY KEY (id),
  CONSTRAINT project_members_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projets(id),
  CONSTRAINT project_members_membre_id_fkey FOREIGN KEY (membre_id) REFERENCES public.membres(id)
);
CREATE TABLE public.projets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  client_id uuid,
  titre text NOT NULL,
  description text,
  statut text DEFAULT 'en_cours'::text CHECK (statut = ANY (ARRAY['en_cours'::text, 'en_attente'::text, 'termine'::text, 'annule'::text])),
  avancement integer DEFAULT 0 CHECK (avancement >= 0 AND avancement <= 100),
  date_debut date,
  date_fin date,
  created_at timestamp with time zone DEFAULT now(),
  budget_total numeric DEFAULT 0,
  budget_depense numeric DEFAULT 0,
  client text DEFAULT ''::text,
  localisation text DEFAULT ''::text,
  chef text DEFAULT ''::text,
  taches integer DEFAULT 0,
  user_id uuid,
  portail_client boolean DEFAULT false,
  membres ARRAY DEFAULT '{}'::text[],
  docs ARRAY DEFAULT '{}'::text[],
  latitude double precision,
  longitude double precision,
  CONSTRAINT projets_pkey PRIMARY KEY (id),
  CONSTRAINT projets_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id)
);
CREATE TABLE public.taches (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  projet_id uuid,
  titre text NOT NULL,
  description text,
  statut text DEFAULT 'en_attente'::text,
  date_debut date,
  date_fin date,
  budget_estime numeric DEFAULT 0,
  created_at timestamp without time zone DEFAULT now(),
  phase text DEFAULT 'Général'::text,
  phase_id uuid,
  cout_reel double precision DEFAULT 0,
  remarques text DEFAULT ''::text,
  CONSTRAINT taches_pkey PRIMARY KEY (id),
  CONSTRAINT taches_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES public.projets(id),
  CONSTRAINT taches_phase_id_fkey FOREIGN KEY (phase_id) REFERENCES public.phases(id)
);