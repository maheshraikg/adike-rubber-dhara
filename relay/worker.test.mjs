import { test } from "node:test";
import assert from "node:assert/strict";
import { handle } from "./worker.js";

const env = { RELAY_TOKEN: "s3cret" };
const ok = "https://relay.example/resource/9ef84268-d588-465a-a308-a864a43d0070?api-key=K&format=json&limit=10";
const req = (url, token = "s3cret", method = "GET") =>
  new Request(url, { method, headers: token ? { "x-relay-token": token } : {} });

test("forwards an allowed dataset with its query string", async () => {
  let called;
  const fake = async (u) => { called = u; return new Response('{"total":1}', { headers: { "content-type": "application/json" } }); };
  const r = await handle(req(ok), env, fake);
  assert.equal(r.status, 200);
  assert.equal(await r.text(), '{"total":1}');
  assert.equal(called, "https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070?api-key=K&format=json&limit=10");
});

test("rejects a missing or wrong token", async () => {
  assert.equal((await handle(req(ok, null), env)).status, 401);
  assert.equal((await handle(req(ok, "nope"), env)).status, 401);
  assert.equal((await handle(req(ok), {})).status, 401); // no secret configured
});

test("only the mandi datasets, only GET", async () => {
  const other = "https://relay.example/resource/00000000-0000-0000-0000-000000000000";
  assert.equal((await handle(req(other), env, async () => assert.fail("must not fetch"))).status, 404);
  assert.equal((await handle(req("https://relay.example/anything"), env)).status, 404);
  assert.equal((await handle(req(ok, "s3cret", "POST"), env)).status, 405);
});

test("upstream failure becomes 502", async () => {
  const r = await handle(req(ok), env, async () => { throw new Error("refused"); });
  assert.equal(r.status, 502);
});
