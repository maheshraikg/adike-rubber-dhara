// Firestore security-rules tests. Run with the emulator:
//   cd firestore-tests && npm ci && npx firebase emulators:exec --only firestore \
//      --project demo-adike --config ../firebase.json "npm test"
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails, assertSucceeds, initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc, collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where,
} from 'firebase/firestore';

let env;
const anon = (uid) => env.authenticatedContext(uid, { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const google = (uid, claims = {}) =>
  env.authenticatedContext(uid, { ...claims, firebase: { sign_in_provider: 'google.com' } }).firestore();
const admin = () => google('admin1', { admin: true });
const partner = (uid = 'p1', sourceId = 'puttur_society') => google(uid, { partner: true, sourceId });
const guest = () => env.unauthenticatedContext().firestore();

const alert = (uid, extra = {}) => ({
  uid, fcmToken: 'tok', crop: 'arecanut', variety: 'rashi', marketId: 'shivamogga',
  condition: 'above', value: 52000, active: true, ...extra,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-adike',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => env && env.cleanup());
beforeEach(async () => env.clearFirestore());

describe('alerts', () => {
  test('owner (anonymous) can create, read, update, delete own alert', async () => {
    const db = anon('u1');
    const ref = doc(db, 'alerts/a1');
    await assertSucceeds(setDoc(ref, alert('u1')));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(updateDoc(ref, { value: 53000 }));
    await assertSucceeds(getDocs(query(collection(db, 'alerts'), where('uid', '==', 'u1'))));
    await assertSucceeds(deleteDoc(ref));
  });
  test('cannot create alert for someone else or with bad fields', async () => {
    await assertFails(setDoc(doc(anon('u1'), 'alerts/a1'), alert('u2')));
    await assertFails(setDoc(doc(anon('u1'), 'alerts/a1'), alert('u1', { condition: 'equals' })));
    await assertFails(setDoc(doc(anon('u1'), 'alerts/a1'), alert('u1', { value: -5 })));
    await assertFails(setDoc(doc(anon('u1'), 'alerts/a1'), alert('u1', { extra: 1 })));
    await assertFails(setDoc(doc(guest(), 'alerts/a1'), alert('u1')));
  });
  test('other users cannot read, update, delete or list', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'alerts/a1'), alert('u1')));
    const other = anon('u2');
    await assertFails(getDoc(doc(other, 'alerts/a1')));
    await assertFails(updateDoc(doc(other, 'alerts/a1'), { value: 1 }));
    await assertFails(deleteDoc(doc(other, 'alerts/a1')));
    await assertFails(getDocs(collection(other, 'alerts')));
    await assertFails(updateDoc(doc(anon('u1'), 'alerts/a1'), { uid: 'u2' }));
  });
});

describe('submissions', () => {
  const sub = (uid = 'p1', sourceId = 'puttur_society', extra = {}) => ({
    partnerUid: uid, sourceId, status: 'new', text: 'ರಾಶಿ 52000', createdAt: serverTimestamp(), ...extra,
  });
  test('partner creates for own sourceId', async () => {
    await assertSucceeds(addDoc(collection(partner(), 'submissions'), sub()));
  });
  test('partner cannot submit for another source, as another uid, or oversized', async () => {
    await assertFails(addDoc(collection(partner(), 'submissions'), sub('p1', 'campco')));
    await assertFails(addDoc(collection(partner(), 'submissions'), sub('p2')));
    await assertFails(addDoc(collection(partner(), 'submissions'), sub('p1', 'puttur_society', { status: 'processed' })));
    await assertFails(addDoc(collection(partner(), 'submissions'),
      sub('p1', 'puttur_society', { imageB64: 'x'.repeat(430000) })));
  });
  test('non-partners cannot submit', async () => {
    await assertFails(addDoc(collection(anon('u1'), 'submissions'), sub('u1')));
    await assertFails(addDoc(collection(google('g1'), 'submissions'), sub('g1')));
  });
  test('partner reads only own; admin reads all; partner cannot update', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'submissions/s1'), { ...sub(), createdAt: 1 });
      await setDoc(doc(ctx.firestore(), 'submissions/s2'), { ...sub('p2', 'x'), createdAt: 1 });
    });
    await assertSucceeds(getDoc(doc(partner(), 'submissions/s1')));
    await assertFails(getDoc(doc(partner(), 'submissions/s2')));
    await assertSucceeds(getDocs(query(collection(partner(), 'submissions'), where('partnerUid', '==', 'p1'))));
    await assertFails(updateDoc(doc(partner(), 'submissions/s1'), { status: 'processed' }));
    await assertSucceeds(getDoc(doc(admin(), 'submissions/s2')));
  });
});

describe('admin-only collections', () => {
  for (const path of ['review/k1', 'config/validation', 'runs/r1']) {
    test(`${path} admin only`, async () => {
      await assertSucceeds(setDoc(doc(admin(), path), { a: 1 }));
      await assertSucceeds(getDoc(doc(admin(), path)));
      await assertFails(getDoc(doc(anon('u1'), path)));
      await assertFails(setDoc(doc(partner(), path), { a: 2 }));
      await assertFails(getDoc(doc(google('g1'), path)));
    });
  }
});

describe('partners', () => {
  test('Google user may apply (approved false) and read own; cannot self-approve', async () => {
    const db = google('g1');
    await assertSucceeds(setDoc(doc(db, 'partners/g1'), { name: 'Society', approved: false }));
    await assertSucceeds(getDoc(doc(db, 'partners/g1')));
    await assertFails(updateDoc(doc(db, 'partners/g1'), { approved: true }));
    await assertFails(setDoc(doc(google('g2'), 'partners/g3'), { name: 'X', approved: false }));
    await assertFails(setDoc(doc(google('g2'), 'partners/g2'), { name: 'X', approved: true }));
    await assertFails(setDoc(doc(anon('a1'), 'partners/a1'), { name: 'X', approved: false }));
    await assertFails(getDocs(collection(db, 'partners')));
  });
  test('admin manages partners', async () => {
    await assertSucceeds(setDoc(doc(admin(), 'partners/g1'), { name: 'S', approved: true, sourceId: 's' }));
    await assertSucceeds(getDocs(collection(admin(), 'partners')));
  });
});

describe('reports', () => {
  test('signed-in user can create, cannot read', async () => {
    const db = anon('u1');
    await assertSucceeds(setDoc(doc(db, 'reports/r1'), { uid: 'u1', priceKey: 'k', reason: 'wrong', createdAt: 1 }));
    await assertFails(getDoc(doc(db, 'reports/r1')));
    await assertFails(setDoc(doc(db, 'reports/r2'), { uid: 'u2', priceKey: 'k', reason: 'x' }));
    await assertFails(setDoc(doc(guest(), 'reports/r3'), { uid: 'u1', priceKey: 'k', reason: 'x' }));
    await assertSucceeds(getDoc(doc(admin(), 'reports/r1')));
  });
});

describe('everything else', () => {
  test('prices are not in Firestore; unknown paths denied', async () => {
    await assertFails(getDoc(doc(anon('u1'), 'prices/x')));
    await assertFails(setDoc(doc(admin(), 'prices/x'), { a: 1 }));
  });
});
