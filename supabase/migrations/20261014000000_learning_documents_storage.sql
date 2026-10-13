-- Supabase Storage setup for private document files.
-- Apply supabase/schema.sql first. Existing Firebase Storage objects are not
-- copied or deleted by this migration.
-- Apply supabase/schema.sql first. Re-running this migration preserves objects.

BEGIN;

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'learning-documents',
  'learning-documents',
  FALSE,
  52428800,
  ARRAY[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'image/jpeg',
    'image/png',
    'text/plain',
    'application/zip'
  ]::TEXT[]
)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM storage.buckets
    WHERE id = 'learning-documents'
      AND public = FALSE
      AND file_size_limit = 52428800
      AND allowed_mime_types = ARRAY[
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'image/jpeg',
        'image/png',
        'text/plain',
        'application/zip'
      ]::TEXT[]
  ) THEN
    RAISE EXCEPTION
      'Bucket learning-documents already exists with unexpected settings; inspect it before applying Storage policies';
  END IF;
END;
$$;

DROP POLICY IF EXISTS learning_documents_read ON storage.objects;
CREATE POLICY learning_documents_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'learning-documents'
    AND public.current_firebase_uid() IS NOT NULL
    AND name ~ '^documents/[^/]+/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/original\.(pdf|doc|docx|ppt|pptx|xls|xlsx|jpg|jpeg|png|txt|zip)$'
    AND (
      split_part(name, '/', 2) = public.current_firebase_uid()
      OR EXISTS (
        SELECT 1
        FROM public.documents d
        JOIN public.document_permissions p
          ON p.document_id = d.id
         AND p.owner_uid = d.owner_uid
        WHERE d.id::TEXT = split_part(storage.objects.name, '/', 3)
          AND d.owner_uid = split_part(storage.objects.name, '/', 2)
          AND d.storage_path = storage.objects.name
          AND p.shared_with_uid = public.current_firebase_uid()
      )
    )
  );

DROP POLICY IF EXISTS learning_documents_read_security_guard ON storage.objects;
CREATE POLICY learning_documents_read_security_guard ON storage.objects
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    bucket_id <> 'learning-documents'
    OR (
      public.current_firebase_uid() IS NOT NULL
      AND name ~ '^documents/[^/]+/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/original\.(pdf|doc|docx|ppt|pptx|xls|xlsx|jpg|jpeg|png|txt|zip)$'
      AND (
        split_part(name, '/', 2) = public.current_firebase_uid()
        OR EXISTS (
          SELECT 1
          FROM public.documents d
          JOIN public.document_permissions p
            ON p.document_id = d.id
           AND p.owner_uid = d.owner_uid
          WHERE d.id::TEXT = split_part(storage.objects.name, '/', 3)
            AND d.owner_uid = split_part(storage.objects.name, '/', 2)
            AND d.storage_path = storage.objects.name
            AND p.shared_with_uid = public.current_firebase_uid()
        )
      )
    )
  );

DROP POLICY IF EXISTS learning_documents_insert_owner ON storage.objects;
CREATE POLICY learning_documents_insert_owner ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'learning-documents'
    AND split_part(name, '/', 1) = 'documents'
    AND split_part(name, '/', 2) = public.current_firebase_uid()
    AND name ~ '^documents/[^/]+/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/original\.(pdf|doc|docx|ppt|pptx|xls|xlsx|jpg|jpeg|png|txt|zip)$'
  );

DROP POLICY IF EXISTS learning_documents_insert_security_guard ON storage.objects;
CREATE POLICY learning_documents_insert_security_guard ON storage.objects
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id <> 'learning-documents'
    OR (
      split_part(name, '/', 1) = 'documents'
      AND split_part(name, '/', 2) = public.current_firebase_uid()
      AND name ~ '^documents/[^/]+/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/original\.(pdf|doc|docx|ppt|pptx|xls|xlsx|jpg|jpeg|png|txt|zip)$'
    )
  );

DROP POLICY IF EXISTS learning_documents_update_owner ON storage.objects;
CREATE POLICY learning_documents_update_owner ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'learning-documents'
    AND split_part(name, '/', 1) = 'documents'
    AND split_part(name, '/', 2) = public.current_firebase_uid()
  )
  WITH CHECK (
    bucket_id = 'learning-documents'
    AND split_part(name, '/', 1) = 'documents'
    AND split_part(name, '/', 2) = public.current_firebase_uid()
    AND name ~ '^documents/[^/]+/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/original\.(pdf|doc|docx|ppt|pptx|xls|xlsx|jpg|jpeg|png|txt|zip)$'
  );

DROP POLICY IF EXISTS learning_documents_update_security_guard ON storage.objects;
CREATE POLICY learning_documents_update_security_guard ON storage.objects
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (
    bucket_id <> 'learning-documents'
    OR (
      split_part(name, '/', 1) = 'documents'
      AND split_part(name, '/', 2) = public.current_firebase_uid()
    )
  )
  WITH CHECK (
    bucket_id <> 'learning-documents'
    OR (
      split_part(name, '/', 1) = 'documents'
      AND split_part(name, '/', 2) = public.current_firebase_uid()
      AND name ~ '^documents/[^/]+/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/original\.(pdf|doc|docx|ppt|pptx|xls|xlsx|jpg|jpeg|png|txt|zip)$'
    )
  );

DROP POLICY IF EXISTS learning_documents_delete_owner ON storage.objects;
CREATE POLICY learning_documents_delete_owner ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'learning-documents'
    AND split_part(name, '/', 1) = 'documents'
    AND split_part(name, '/', 2) = public.current_firebase_uid()
    AND name ~ '^documents/[^/]+/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/original\.(pdf|doc|docx|ppt|pptx|xls|xlsx|jpg|jpeg|png|txt|zip)$'
  );

DROP POLICY IF EXISTS learning_documents_delete_security_guard ON storage.objects;
CREATE POLICY learning_documents_delete_security_guard ON storage.objects
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (
    bucket_id <> 'learning-documents'
    OR (
      split_part(name, '/', 1) = 'documents'
      AND split_part(name, '/', 2) = public.current_firebase_uid()
      AND name ~ '^documents/[^/]+/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/original\.(pdf|doc|docx|ppt|pptx|xls|xlsx|jpg|jpeg|png|txt|zip)$'
    )
  );

COMMIT;
