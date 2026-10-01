// data.gov.in relay for the collection robot.
//
// data.gov.in refuses connections from GitHub's servers, so the robot asks this
// Cloudflare Worker (free plan) to fetch for it. Locked down so it is not an
// open proxy: GET only, a shared token (Worker secret RELAY_TOKEN, GitHub
// secret ADIKE_RELAY_TOKEN), and only the two Agmarknet mandi-price datasets.
// Query strings (api-key, filters, paging) are passed through unchanged.

export const UPSTREAM = "https://api.data.gov.in";
export const ALLOWED = new Set([
  "9ef84268-d588-465a-a308-a864a43d0070", // current daily mandi prices
  "35985678-0d79-46b4-9ed6-6f13308a1d24", // variety-wise history (backfill)
]);

function json(status, obj) {
  return new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });
}

function sameToken(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function handle(request, env, fetchFn = fetch) {
  if (request.method !== "GET") return json(405, { error: "GET only" });
  if (!env.RELAY_TOKEN || !sameToken(request.headers.get("x-relay-token") || "", env.RELAY_TOKEN)) {
    return json(401, { error: "unauthorized" });
  }
  const url = new URL(request.url);
  const m = url.pathname.match(/^\/resource\/([0-9a-f-]{36})\/?$/);
  if (!m || !ALLOWED.has(m[1])) return json(404, { error: "not an allowed dataset" });
  try {
    const r = await fetchFn(`${UPSTREAM}/resource/${m[1]}${url.search}`, {
      headers: { accept: "application/json", "user-agent": "AdikeRubberDhara-relay/1.0" },
    });
    return new Response(r.body, {
      status: r.status,
      headers: { "content-type": r.headers.get("content-type") || "application/json" },
    });
  } catch (e) {
    return json(502, { error: "upstream unreachable", detail: String(e).slice(0, 200) });
  }
}

export default { fetch: (request, env) => handle(request, env) };
