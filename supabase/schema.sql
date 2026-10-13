-- Firebase Authentication is the identity provider and must be configured as
-- a Supabase third-party auth provider before clients can access these tables.
-- users stores profile metadata only; credentials remain with Firebase Auth.

CREATE TABLE IF NOT EXISTS public.users (
  uid TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  photo_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_uid TEXT NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  subject TEXT NOT NULL DEFAULT '',
  doc_type TEXT NOT NULL DEFAULT 'reference'
    CHECK (doc_type IN ('lecture', 'assignment', 'reference', 'exam')),
  storage_url TEXT NOT NULL DEFAULT '',
  storage_path TEXT NOT NULL DEFAULT '',
  file_name TEXT NOT NULL DEFAULT '',
  file_size BIGINT NOT NULL DEFAULT 0,
  tags TEXT NOT NULL DEFAULT '[]',
  is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (file_size >= 0)
);

CREATE TABLE IF NOT EXISTS public.document_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  owner_uid TEXT NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  shared_with_uid TEXT NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  shared_with_email TEXT NOT NULL DEFAULT '',
  permission TEXT NOT NULL DEFAULT 'view'
    CHECK (permission IN ('view', 'edit')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (document_id, shared_with_uid),
  CONSTRAINT document_permissions_owner_not_recipient CHECK (owner_uid <> shared_with_uid)
);

-- Keep owner/document pairs consistent even when data is written outside the
-- Flutter client. NOT VALID preserves existing rows while enforcing new writes.
CREATE UNIQUE INDEX IF NOT EXISTS idx_documents_id_owner
  ON public.documents(id, owner_uid);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.document_permissions'::regclass
      AND conname = 'document_permissions_document_owner_fk'
  ) THEN
    ALTER TABLE public.document_permissions
      ADD CONSTRAINT document_permissions_document_owner_fk
      FOREIGN KEY (document_id, owner_uid)
      REFERENCES public.documents(id, owner_uid)
      ON DELETE CASCADE
      NOT VALID;
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.document_permissions'::regclass
      AND conname = 'document_permissions_owner_not_recipient'
  ) THEN
    ALTER TABLE public.document_permissions
      ADD CONSTRAINT document_permissions_owner_not_recipient
      CHECK (owner_uid <> shared_with_uid);
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_documents_owner ON public.documents(owner_uid);
CREATE INDEX IF NOT EXISTS idx_documents_subject ON public.documents(subject);
CREATE INDEX IF NOT EXISTS idx_documents_doctype ON public.documents(doc_type);
CREATE INDEX IF NOT EXISTS idx_documents_created ON public.documents(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_perms_document ON public.document_permissions(document_id);
CREATE INDEX IF NOT EXISTS idx_perms_shared_with ON public.document_permissions(shared_with_uid);

-- Only accept Firebase ID tokens issued for a Firebase project. Supabase
-- validates the token signature after Firebase is configured as a third-party
-- auth provider; the UID comes from the verified token's subject claim.
CREATE OR REPLACE FUNCTION public.current_firebase_uid()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT CASE
    WHEN auth.jwt() ->> 'iss' = 'https://securetoken.google.com/' || (auth.jwt() ->> 'aud')
    THEN auth.jwt() ->> 'sub'
    ELSE NULL
  END;
$$;
REVOKE ALL ON FUNCTION public.current_firebase_uid() FROM PUBLIC, anon;

CREATE OR REPLACE FUNCTION public.prevent_document_identity_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.id <> OLD.id OR NEW.owner_uid <> OLD.owner_uid THEN
    RAISE EXCEPTION 'Document identity and owner cannot be changed';
  END IF;
  IF public.current_firebase_uid() IS DISTINCT FROM OLD.owner_uid
    AND (
      NEW.storage_url IS DISTINCT FROM OLD.storage_url
      OR NEW.storage_path IS DISTINCT FROM OLD.storage_path
      OR NEW.file_name IS DISTINCT FROM OLD.file_name
      OR NEW.file_size IS DISTINCT FROM OLD.file_size
    )
  THEN
    RAISE EXCEPTION 'Only the document owner can change its attached file';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_permission_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  actual_owner_uid TEXT;
BEGIN
  SELECT owner_uid INTO actual_owner_uid
  FROM public.documents
  WHERE id = NEW.document_id;

  IF actual_owner_uid IS NULL OR NEW.owner_uid <> actual_owner_uid THEN
    RAISE EXCEPTION 'Permission owner must own the referenced document';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS documents_identity_immutable ON public.documents;
CREATE TRIGGER documents_identity_immutable
  BEFORE UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.prevent_document_identity_change();
DROP TRIGGER IF EXISTS permissions_owner_matches_document ON public.document_permissions;
CREATE TRIGGER permissions_owner_matches_document
  BEFORE INSERT OR UPDATE ON public.document_permissions
  FOR EACH ROW EXECUTE FUNCTION public.enforce_permission_owner();

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select_authenticated ON public.users;
DROP POLICY IF EXISTS users_select_all ON public.users;
CREATE POLICY users_select_authenticated ON public.users
  FOR SELECT TO authenticated USING (public.current_firebase_uid() IS NOT NULL);
DROP POLICY IF EXISTS users_select_security_guard ON public.users;
CREATE POLICY users_select_security_guard ON public.users
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (public.current_firebase_uid() IS NOT NULL);
DROP POLICY IF EXISTS users_insert_own ON public.users;
CREATE POLICY users_insert_own ON public.users
  FOR INSERT TO authenticated
  WITH CHECK (uid = public.current_firebase_uid());
DROP POLICY IF EXISTS users_insert_security_guard ON public.users;
CREATE POLICY users_insert_security_guard ON public.users
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (uid = public.current_firebase_uid());
DROP POLICY IF EXISTS users_update_own ON public.users;
CREATE POLICY users_update_own ON public.users
  FOR UPDATE TO authenticated
  USING (uid = public.current_firebase_uid())
  WITH CHECK (uid = public.current_firebase_uid());
DROP POLICY IF EXISTS users_update_security_guard ON public.users;
CREATE POLICY users_update_security_guard ON public.users
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (uid = public.current_firebase_uid())
  WITH CHECK (uid = public.current_firebase_uid());

DROP POLICY IF EXISTS documents_select_owner_or_shared ON public.documents;
DROP POLICY IF EXISTS docs_select_owner_or_shared ON public.documents;
CREATE POLICY documents_select_owner_or_shared ON public.documents
  FOR SELECT TO authenticated
  USING (
    owner_uid = public.current_firebase_uid()
    OR EXISTS (
      SELECT 1 FROM public.document_permissions p
      WHERE p.document_id = documents.id
        AND p.owner_uid = documents.owner_uid
        AND p.shared_with_uid = public.current_firebase_uid()
    )
  );
DROP POLICY IF EXISTS documents_select_security_guard ON public.documents;
CREATE POLICY documents_select_security_guard ON public.documents
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    owner_uid = public.current_firebase_uid()
    OR EXISTS (
      SELECT 1 FROM public.document_permissions p
      WHERE p.document_id = documents.id
        AND p.owner_uid = documents.owner_uid
        AND p.shared_with_uid = public.current_firebase_uid()
    )
  );
DROP POLICY IF EXISTS documents_insert_owner ON public.documents;
DROP POLICY IF EXISTS docs_insert_own ON public.documents;
CREATE POLICY documents_insert_owner ON public.documents
  FOR INSERT TO authenticated
  WITH CHECK (owner_uid = public.current_firebase_uid());
DROP POLICY IF EXISTS documents_insert_security_guard ON public.documents;
CREATE POLICY documents_insert_security_guard ON public.documents
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (owner_uid = public.current_firebase_uid());
DROP POLICY IF EXISTS documents_update_owner_or_editor ON public.documents;
DROP POLICY IF EXISTS docs_update_owner_or_editor ON public.documents;
CREATE POLICY documents_update_owner_or_editor ON public.documents
  FOR UPDATE TO authenticated
  USING (
    owner_uid = public.current_firebase_uid()
    OR EXISTS (
      SELECT 1 FROM public.document_permissions p
      WHERE p.document_id = documents.id
        AND p.owner_uid = documents.owner_uid
        AND p.shared_with_uid = public.current_firebase_uid()
        AND p.permission = 'edit'
    )
  )
  WITH CHECK (
    owner_uid = public.current_firebase_uid()
    OR EXISTS (
      SELECT 1 FROM public.document_permissions p
      WHERE p.document_id = documents.id
        AND p.owner_uid = documents.owner_uid
        AND p.shared_with_uid = public.current_firebase_uid()
        AND p.permission = 'edit'
    )
  );
DROP POLICY IF EXISTS documents_update_security_guard ON public.documents;
CREATE POLICY documents_update_security_guard ON public.documents
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (
    owner_uid = public.current_firebase_uid()
    OR EXISTS (
      SELECT 1 FROM public.document_permissions p
      WHERE p.document_id = documents.id
        AND p.owner_uid = documents.owner_uid
        AND p.shared_with_uid = public.current_firebase_uid()
        AND p.permission = 'edit'
    )
  )
  WITH CHECK (
    owner_uid = public.current_firebase_uid()
    OR EXISTS (
      SELECT 1 FROM public.document_permissions p
      WHERE p.document_id = documents.id
        AND p.owner_uid = documents.owner_uid
        AND p.shared_with_uid = public.current_firebase_uid()
        AND p.permission = 'edit'
    )
  );
DROP POLICY IF EXISTS documents_delete_owner ON public.documents;
DROP POLICY IF EXISTS docs_delete_own ON public.documents;
CREATE POLICY documents_delete_owner ON public.documents
  FOR DELETE TO authenticated
  USING (owner_uid = public.current_firebase_uid());
DROP POLICY IF EXISTS documents_delete_security_guard ON public.documents;
CREATE POLICY documents_delete_security_guard ON public.documents
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (owner_uid = public.current_firebase_uid());

DROP POLICY IF EXISTS permissions_select_owner_or_recipient ON public.document_permissions;
DROP POLICY IF EXISTS perms_select ON public.document_permissions;
CREATE POLICY permissions_select_owner_or_recipient ON public.document_permissions
  FOR SELECT TO authenticated
  USING (
    owner_uid = public.current_firebase_uid()
    OR shared_with_uid = public.current_firebase_uid()
  );
DROP POLICY IF EXISTS permissions_select_security_guard ON public.document_permissions;
CREATE POLICY permissions_select_security_guard ON public.document_permissions
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    owner_uid = public.current_firebase_uid()
    OR shared_with_uid = public.current_firebase_uid()
  );
DROP POLICY IF EXISTS permissions_insert_owner ON public.document_permissions;
DROP POLICY IF EXISTS perms_insert_owner ON public.document_permissions;
CREATE POLICY permissions_insert_owner ON public.document_permissions
  FOR INSERT TO authenticated
  WITH CHECK (
    owner_uid = public.current_firebase_uid()
    AND EXISTS (
      SELECT 1 FROM public.documents d
      WHERE d.id = document_id AND d.owner_uid = public.current_firebase_uid()
    )
  );
DROP POLICY IF EXISTS permissions_insert_security_guard ON public.document_permissions;
CREATE POLICY permissions_insert_security_guard ON public.document_permissions
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (
    owner_uid = public.current_firebase_uid()
    AND EXISTS (
      SELECT 1 FROM public.documents d
      WHERE d.id = document_id AND d.owner_uid = public.current_firebase_uid()
    )
  );
DROP POLICY IF EXISTS permissions_update_owner ON public.document_permissions;
DROP POLICY IF EXISTS perms_update_owner ON public.document_permissions;
CREATE POLICY permissions_update_owner ON public.document_permissions
  FOR UPDATE TO authenticated
  USING (
    owner_uid = public.current_firebase_uid()
    AND EXISTS (
      SELECT 1 FROM public.documents d
      WHERE d.id = document_id AND d.owner_uid = public.current_firebase_uid()
    )
  )
  WITH CHECK (
    owner_uid = public.current_firebase_uid()
    AND EXISTS (
      SELECT 1 FROM public.documents d
      WHERE d.id = document_id AND d.owner_uid = public.current_firebase_uid()
    )
  );
DROP POLICY IF EXISTS permissions_update_security_guard ON public.document_permissions;
CREATE POLICY permissions_update_security_guard ON public.document_permissions
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (
    owner_uid = public.current_firebase_uid()
    AND EXISTS (
      SELECT 1 FROM public.documents d
      WHERE d.id = document_id AND d.owner_uid = public.current_firebase_uid()
    )
  )
  WITH CHECK (
    owner_uid = public.current_firebase_uid()
    AND EXISTS (
      SELECT 1 FROM public.documents d
      WHERE d.id = document_id AND d.owner_uid = public.current_firebase_uid()
    )
  );
DROP POLICY IF EXISTS permissions_delete_owner ON public.document_permissions;
DROP POLICY IF EXISTS perms_delete_owner ON public.document_permissions;
CREATE POLICY permissions_delete_owner ON public.document_permissions
  FOR DELETE TO authenticated
  USING (
    owner_uid = public.current_firebase_uid()
    AND EXISTS (
      SELECT 1 FROM public.documents d
      WHERE d.id = document_id AND d.owner_uid = public.current_firebase_uid()
    )
  );
DROP POLICY IF EXISTS permissions_delete_security_guard ON public.document_permissions;
CREATE POLICY permissions_delete_security_guard ON public.document_permissions
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (
    owner_uid = public.current_firebase_uid()
    AND EXISTS (
      SELECT 1 FROM public.documents d
      WHERE d.id = document_id AND d.owner_uid = public.current_firebase_uid()
    )
  );

REVOKE ALL ON public.users, public.documents, public.document_permissions
  FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.documents TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_permissions TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_firebase_uid() TO authenticated;
