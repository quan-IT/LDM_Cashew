-- Run after schema.sql in the Supabase SQL Editor. The transaction is rolled
-- back and uses synthetic Firebase JWT claims to exercise the RLS policies.
BEGIN;

INSERT INTO public.users (uid, email, display_name) VALUES
  ('rls-fixture-a', 'rls-fixture-a@example.invalid', 'Owner A'),
  ('rls-fixture-b', 'rls-fixture-b@example.invalid', 'Viewer B'),
  ('rls-fixture-c', 'rls-fixture-c@example.invalid', 'Editor C');

INSERT INTO public.documents (id, owner_uid, title) VALUES
  ('10000000-0000-4000-8000-000000000001', 'rls-fixture-a', 'View-only fixture'),
  ('10000000-0000-4000-8000-000000000002', 'rls-fixture-a', 'Editable fixture');

INSERT INTO public.document_permissions
  (document_id, owner_uid, shared_with_uid, shared_with_email, permission)
VALUES
  ('10000000-0000-4000-8000-000000000001', 'rls-fixture-a',
   'rls-fixture-b', 'rls-fixture-b@example.invalid', 'view'),
  ('10000000-0000-4000-8000-000000000002', 'rls-fixture-a',
   'rls-fixture-c', 'rls-fixture-c@example.invalid', 'edit');

SET LOCAL ROLE authenticated;

SELECT set_config(
  'request.jwt.claims',
  '{"iss":"https://securetoken.google.com/rls-test-project","aud":"rls-test-project","sub":"rls-fixture-a","role":"authenticated"}',
  true
);
DO $$
DECLARE
  affected INTEGER;
BEGIN
  IF (SELECT count(*) FROM public.documents WHERE owner_uid = 'rls-fixture-a') <> 2 THEN
    RAISE EXCEPTION 'Owner A must see both owned documents';
  END IF;
  UPDATE public.document_permissions SET permission = 'edit'
    WHERE document_id = '10000000-0000-4000-8000-000000000001'
      AND shared_with_uid = 'rls-fixture-b';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN
    RAISE EXCEPTION 'Owner A must be able to change B permission';
  END IF;
  UPDATE public.document_permissions SET permission = 'view'
    WHERE document_id = '10000000-0000-4000-8000-000000000001'
      AND shared_with_uid = 'rls-fixture-b';
END;
$$;

SELECT set_config(
  'request.jwt.claims',
  '{"iss":"https://securetoken.google.com/rls-test-project","aud":"rls-test-project","sub":"rls-fixture-b","role":"authenticated"}',
  true
);
DO $$
DECLARE
  affected INTEGER;
  insert_rejected BOOLEAN := FALSE;
  ownership_change_rejected BOOLEAN := FALSE;
  file_change_rejected BOOLEAN := FALSE;
BEGIN
  IF (SELECT count(*) FROM public.documents) <> 1 THEN
    RAISE EXCEPTION 'Viewer B must see exactly the view-shared document';
  END IF;
  UPDATE public.documents SET title = 'Unauthorized edit'
    WHERE id = '10000000-0000-4000-8000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN
    RAISE EXCEPTION 'Viewer B must not edit a view-only document';
  END IF;
  DELETE FROM public.documents
    WHERE id = '10000000-0000-4000-8000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN
    RAISE EXCEPTION 'Viewer B must not delete a shared document';
  END IF;
  BEGIN
    INSERT INTO public.documents (owner_uid, title)
      VALUES ('rls-fixture-a', 'Forged owner document');
  EXCEPTION WHEN insufficient_privilege THEN
    insert_rejected := TRUE;
  END;
  IF NOT insert_rejected THEN
    RAISE EXCEPTION 'Viewer B must not insert a document as another user';
  END IF;
END;
$$;

SELECT set_config(
  'request.jwt.claims',
  '{"iss":"https://securetoken.google.com/rls-test-project","aud":"rls-test-project","sub":"rls-fixture-c","role":"authenticated"}',
  true
);
DO $$
DECLARE
  affected INTEGER;
  insert_rejected BOOLEAN := FALSE;
BEGIN
  IF (SELECT count(*) FROM public.documents) <> 1 THEN
    RAISE EXCEPTION 'Editor C must see only the document shared with C';
  END IF;
  UPDATE public.documents SET title = 'Authorized edit'
    WHERE id = '10000000-0000-4000-8000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN
    RAISE EXCEPTION 'Editor C must edit the document shared with edit permission';
  END IF;
  DELETE FROM public.documents
    WHERE id = '10000000-0000-4000-8000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN
    RAISE EXCEPTION 'Editor C must not delete a shared document';
  END IF;
  BEGIN
    UPDATE public.documents SET owner_uid = 'rls-fixture-c'
      WHERE id = '10000000-0000-4000-8000-000000000002';
  EXCEPTION WHEN raise_exception THEN
    ownership_change_rejected := TRUE;
  END;
  IF NOT ownership_change_rejected THEN
    RAISE EXCEPTION 'Editor C must not transfer document ownership';
  END IF;
  BEGIN
    UPDATE public.documents SET storage_path = 'documents/rls-fixture-c/forged.pdf'
      WHERE id = '10000000-0000-4000-8000-000000000002';
  EXCEPTION WHEN raise_exception THEN
    file_change_rejected := TRUE;
  END;
  IF NOT file_change_rejected THEN
    RAISE EXCEPTION 'Editor C must not replace the attached file';
  END IF;
END;
$$;

ROLLBACK;
