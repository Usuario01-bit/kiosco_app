// Supabase Edge Function: cleanup-payment-captures
//
// Deletes payment-capture images older than the retention window from the
// `payment-captures` bucket.
//
// Why this exists as a function and not as SQL:
// Supabase blocks direct deletes against the storage tables. A SQL delete
// raises `Direct deletion from storage tables is not allowed. Use the Storage
// API instead.` (trigger storage.protect_delete). That guard is deliberate:
// removing the metadata row while the real object stays in the bucket would
// orphan the file, so the quota would never be freed. Objects can only be
// removed through the Storage API.
//
// Deploy (no CLI required):
//   Supabase Dashboard -> Edge Functions -> Create a new function
//   name: cleanup-payment-captures
//   paste this file, then Deploy.
// When a local supabase/ directory exists, the CLI equivalent is:
//   supabase functions deploy cleanup-payment-captures
//
// Callers: only a service_role token is accepted. The pg_cron job in
// lib/services/hardening_security.sql sends it from Supabase Vault.
//
// The response is the audit trail: net._http_response keeps the body, so
// `deletedPaths` records exactly which objects each run removed.

import { createClient } from "jsr:@supabase/supabase-js@2"

const BUCKET = "payment-captures"
const RETENTION_DAYS = 15
const LIST_PAGE_SIZE = 100
const REMOVE_BATCH_SIZE = 1000 // Storage API hard limit per request
const REPORTED_PATHS_LIMIT = 200 // keep the HTTP response body bounded

// The gateway already verified the JWT signature, so reading the role claim
// from the payload is safe and keeps anonymous callers out.
function bearerRole(authorization: string | null): string | undefined {
  const token = authorization?.replace(/^Bearer\s+/i, "").trim()
  const payload = token?.split(".")[1]
  if (!payload) return undefined
  try {
    const base64 = payload.replace(/-/g, "+").replace(/_/g, "/")
    const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4)
    return JSON.parse(atob(padded)).role
  } catch {
    return undefined
  }
}

Deno.serve(async (request) => {
  if (bearerRole(request.headers.get("Authorization")) !== "service_role") {
    return Response.json({ error: "forbidden" }, { status: 403 })
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  )

  const cutoff = Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000
  const isExpired = (createdAt?: string | null) =>
    !!createdAt && new Date(createdAt).getTime() < cutoff

  // Objects live at <student_id>/<file>, so walk one level down from the root.
  const { data: root, error: rootError } = await supabase.storage
    .from(BUCKET)
    .list("", { limit: 1000 })

  if (rootError) {
    return Response.json({ error: rootError.message }, { status: 500 })
  }

  const expired: string[] = []

  for (const entry of root ?? []) {
    // Supabase represents virtual folders as entries without an id.
    if (entry.id !== null) {
      if (isExpired(entry.created_at)) expired.push(entry.name)
      continue
    }

    for (let offset = 0; ; offset += LIST_PAGE_SIZE) {
      const { data: files, error } = await supabase.storage
        .from(BUCKET)
        .list(entry.name, { limit: LIST_PAGE_SIZE, offset })

      if (error) {
        return Response.json({ error: error.message }, { status: 500 })
      }

      for (const file of files ?? []) {
        if (isExpired(file.created_at)) expired.push(`${entry.name}/${file.name}`)
      }

      if (!files || files.length < LIST_PAGE_SIZE) break
    }
  }

  const deletedPaths: string[] = []

  for (let i = 0; i < expired.length; i += REMOVE_BATCH_SIZE) {
    const batch = expired.slice(i, i + REMOVE_BATCH_SIZE)
    const { data: removed, error } = await supabase.storage.from(BUCKET).remove(batch)

    if (error) {
      return Response.json(
        { error: error.message, requested: expired.length, deleted: deletedPaths.length, deletedPaths },
        { status: 500 },
      )
    }

    // remove() reports what it actually deleted. Fall back to the requested
    // batch when the response carries no names, so the count never under-reports
    // a successful call.
    const confirmed = (removed ?? [])
      .map((object) => object?.name)
      .filter((name): name is string => typeof name === "string" && name.length > 0)

    deletedPaths.push(...(confirmed.length > 0 ? confirmed : batch))
  }

  return Response.json({
    bucket: BUCKET,
    retentionDays: RETENTION_DAYS,
    scannedFolders: root?.length ?? 0,
    requested: expired.length,
    deleted: deletedPaths.length,
    deletedPaths: deletedPaths.slice(0, REPORTED_PATHS_LIMIT),
    deletedPathsTruncated: deletedPaths.length > REPORTED_PATHS_LIMIT,
  })
})
