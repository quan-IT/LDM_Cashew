import { getAuth } from "firebase-admin/auth";
import { initializeApp } from "firebase-admin/app";
import { getStorage } from "firebase-admin/storage";
import { createClient } from "@supabase/supabase-js";
import { defineSecret, defineString } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";

initializeApp();

const supabaseUrl = defineString("SUPABASE_URL");
const storageBucket = defineString("FIREBASE_STORAGE_BUCKET");
const supabaseServiceRoleKey = defineSecret("SUPABASE_SERVICE_ROLE_KEY");

export const ensureSupabaseRole = onCall({ maxInstances: 10 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in before requesting access.");
  }

  const auth = getAuth();
  const user = await auth.getUser(uid);
  if (user.customClaims?.role !== "authenticated") {
    await auth.setCustomUserClaims(uid, {
      ...user.customClaims,
      role: "authenticated",
    });
  }

  return { role: "authenticated" };
});

export const getAuthorizedDocumentUrl = onCall(
  {
    maxInstances: 20,
    secrets: [supabaseServiceRoleKey],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in before requesting a file.");
    }

    const documentId = request.data?.documentId;
    if (
      typeof documentId !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(documentId)
    ) {
      throw new HttpsError("invalid-argument", "A valid document ID is required.");
    }

    const supabase = createClient(
      supabaseUrl.value(),
      supabaseServiceRoleKey.value(),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const { data: document, error: documentError } = await supabase
      .from("documents")
      .select("owner_uid,storage_path")
      .eq("id", documentId)
      .maybeSingle();

    if (documentError) {
      console.error("Unable to check document access.", documentError);
      throw new HttpsError("internal", "Unable to verify document access.");
    }
    if (!document || !document.storage_path) {
      throw new HttpsError("permission-denied", "This document is not available.");
    }

    if (document.owner_uid !== uid) {
      const { data: permission, error: permissionError } = await supabase
        .from("document_permissions")
        .select("id")
        .eq("document_id", documentId)
        .eq("shared_with_uid", uid)
        .maybeSingle();
      if (permissionError) {
        console.error("Unable to check document share permission.", permissionError);
        throw new HttpsError("internal", "Unable to verify document access.");
      }
      if (!permission) {
        throw new HttpsError("permission-denied", "This document is not available.");
      }
    }

    const expectedPrefix = `documents/${document.owner_uid}/${documentId}/`;
    if (!document.storage_path.startsWith(expectedPrefix)) {
      console.error("Document storage path does not match its owner and ID.");
      throw new HttpsError("failed-precondition", "The stored file path is invalid.");
    }

    const file = getStorage()
      .bucket(storageBucket.value())
      .file(document.storage_path);
    const [exists] = await file.exists();
    if (!exists) {
      throw new HttpsError("not-found", "The document file could not be found.");
    }

    const [url] = await file.getSignedUrl({
      action: "read",
      expires: Date.now() + 5 * 60 * 1000,
      version: "v4",
    });
    return { url };
  },
);
