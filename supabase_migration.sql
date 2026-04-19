-- ═══════════════════════════════════════════════════════════
--  MIGRATION : Portail Client ArchiManager
--  Exécuter dans Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════

-- 1. Table accès portail client
CREATE TABLE IF NOT EXISTS client_portal_access (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  projet_id     UUID NOT NULL REFERENCES projets(id) ON DELETE CASCADE,
  client_nom    TEXT NOT NULL,
  client_email  TEXT NOT NULL,
  password_hash TEXT NOT NULL,          -- mot de passe haché (bcrypt)
  password_raw  TEXT,                   -- temporaire pour envoi email (effacé après)
  actif         BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  last_login    TIMESTAMPTZ,
  UNIQUE(projet_id, client_email)
);

-- 2. Index pour login rapide
CREATE INDEX IF NOT EXISTS idx_client_portal_email
  ON client_portal_access(client_email);

-- 3. RLS — seuls les architectes (users auth) peuvent gérer les accès
ALTER TABLE client_portal_access ENABLE ROW LEVEL SECURITY;

-- Les architectes voient tous les accès (adapter selon votre logique auth)
CREATE POLICY "architectes_full_access" ON client_portal_access
  FOR ALL USING (true);  -- à restreindre selon votre auth

-- 4. Table commentaires client (si pas encore créée, étend commentaires existants)
-- Les commentaires existants ont déjà role='client' ou 'architecte'
-- On ajoute juste un champ client_portal_id pour lier
ALTER TABLE commentaires
  ADD COLUMN IF NOT EXISTS client_portal_id UUID REFERENCES client_portal_access(id);

-- ═══════════════════════════════════════════════════════════
--  EXEMPLE d'insertion manuelle (pour test)
-- ═══════════════════════════════════════════════════════════
-- INSERT INTO client_portal_access (projet_id, client_nom, client_email, password_hash)
-- VALUES ('uuid-du-projet', 'M. Alami', 'alami@example.com', 'hash_ici');
