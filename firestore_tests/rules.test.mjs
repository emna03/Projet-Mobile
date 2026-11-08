import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDoc, updateDoc, deleteDoc, collection, getDocs, query, where,
  serverTimestamp, Timestamp, deleteField, runTransaction, writeBatch,
} from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'demo-studymate',
  firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
});

let passed = 0, failed = 0;
async function t(name, fn) {
  try { await fn(); passed++; console.log('  ok  ', name); }
  catch (e) { failed++; console.log('  FAIL', name, '\n       ', e.message.split('\n')[0]); }
}
const _dbs = new Map();
const db = (uid) => {
  const k = uid ?? "";
  if (!_dbs.has(k)) _dbs.set(k, (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore());
  return _dbs.get(k);
};

// Données de départ (sans règles)
await env.withSecurityRulesDisabled(async (ctx) => {
  const d = ctx.firestore();
  await setDoc(doc(d, 'groups/pub'), { name: 'Public', description: 'desc', level: 'Licence 2', isPublic: true, maxMembers: 3, ownerId: 'owner', memberIds: ['owner', 'm1'], createdAt: Timestamp.now() });
  await setDoc(doc(d, 'groups/priv'), { name: 'Prive', description: 'desc', level: 'Master 1', isPublic: false, maxMembers: 5, ownerId: 'owner', memberIds: ['owner'], createdAt: Timestamp.now() });
  await setDoc(doc(d, 'groups/pub/messages/msg1'), { senderId: 'm1', senderName: 'M1', type: 'text', content: 'hello', createdAt: Timestamp.now(), deletedAt: null, reactions: {} });
  await setDoc(doc(d, 'groups/pub/polls/msg2'), { question: 'Q', createdBy: 'm1', closedAt: null, options: [{ id: 'opt_0' }, { id: 'opt_1' }], votes: {} });
});

console.log('Profils');
await t('écrire son profil', () => assertSucceeds(setDoc(doc(db('m1'), 'users/m1'), { displayName: 'M1', role: 'student', updatedAt: serverTimestamp() }, { merge: true })));
await t('refus : écrire le profil d\'un autre', () => assertFails(setDoc(doc(db('m1'), 'users/owner'), { displayName: 'X', role: 'student' })));
await t('refus : rôle invalide', () => assertFails(setDoc(doc(db('m1'), 'users/m1'), { displayName: 'M1', role: 'admin' })));
await t('refus : lecture non connectée', () => assertFails(getDoc(doc(db(null), 'users/m1'))));

console.log('Groupes');
await t('créer un groupe dont on est propriétaire', () => assertSucceeds(setDoc(doc(db('x'), 'groups/new1'), { name: 'Nouveau', description: 'd', level: 'L2', isPublic: true, maxMembers: 4, ownerId: 'x', memberIds: ['x'], createdAt: Timestamp.now() })));
await t('refus : créer au nom d\'un autre', () => assertFails(setDoc(doc(db('x'), 'groups/new2'), { name: 'Nouveau', description: 'd', level: 'L2', isPublic: true, maxMembers: 4, ownerId: 'owner', memberIds: ['owner'], createdAt: Timestamp.now() })));
await t('adhésion directe à un groupe public (transaction)', () => assertSucceeds(runTransaction(db('j1'), async (tx) => {
  const s = await tx.get(doc(db('j1'), 'groups/pub'));
  tx.update(s.ref, { memberIds: [...s.data().memberIds, 'j1'] });
})));
await t('refus : groupe complet (capacité 3)', () => assertFails(updateDoc(doc(db('j2'), 'groups/pub'), { memberIds: ['owner', 'm1', 'j1', 'j2'] })));
await t('refus : adhésion directe à un groupe privé', () => assertFails(updateDoc(doc(db('j2'), 'groups/priv'), { memberIds: ['owner', 'j2'] })));
await t('refus : ajouter un autre utilisateur sans être propriétaire', () => assertFails(updateDoc(doc(db('m1'), 'groups/priv'), { memberIds: ['owner', 'zz'] })));
await t('refus : un membre renomme le groupe', () => assertFails(updateDoc(doc(db('m1'), 'groups/pub'), { name: 'Pirate' })));
await t('le propriétaire modifie le groupe', () => assertSucceeds(updateDoc(doc(db('owner'), 'groups/pub'), { name: 'Public 2' })));
await t('quitter un groupe', () => assertSucceeds(updateDoc(doc(db('j1'), 'groups/pub'), { memberIds: ['owner', 'm1'] })));
await t('refus : le propriétaire quitte son groupe', () => assertFails(updateDoc(doc(db('owner'), 'groups/pub'), { memberIds: ['m1'] })));
await t('refus : supprimer le groupe d\'un autre', () => assertFails(deleteDoc(doc(db('m1'), 'groups/pub'))));

console.log('Demandes d\'adhésion');
const req = (uid) => doc(db(uid), 'group_join_requests/priv__' + uid);
await t('lire sa demande inexistante (transaction)', () => assertSucceeds(getDoc(req('r1'))));
await t('envoyer une demande', () => assertSucceeds(setDoc(req('r1'), { groupId: 'priv', userId: 'r1', userName: 'R1', ownerId: 'owner', status: 'pending', createdAt: serverTimestamp(), reviewedAt: null })));
await t('refus : faux propriétaire dans la demande', () => assertFails(setDoc(req('r2'), { groupId: 'priv', userId: 'r2', ownerId: 'r2', status: 'pending' })));
await t('refus : demande au nom d\'un autre', () => assertFails(setDoc(doc(db('r2'), 'group_join_requests/priv__r1'), { groupId: 'priv', userId: 'r1', ownerId: 'owner', status: 'pending' })));
await t('le propriétaire liste ses demandes', () => assertSucceeds(getDocs(query(collection(db('owner'), 'group_join_requests'), where('ownerId', '==', 'owner')))));
await t('le demandeur liste ses demandes', () => assertSucceeds(getDocs(query(collection(db('r1'), 'group_join_requests'), where('userId', '==', 'r1')))));
await t('refus : un tiers lit la demande', () => assertFails(getDoc(doc(db('m1'), 'group_join_requests/priv__r1'))));
await t('refus : le demandeur s\'accepte lui-même', () => assertFails(updateDoc(req('r1'), { status: 'accepted' })));
await t('le propriétaire accepte (transaction groupe + demande)', () => assertSucceeds(runTransaction(db('owner'), async (tx) => {
  const g = await tx.get(doc(db('owner'), 'groups/priv'));
  const r = await tx.get(doc(db('owner'), 'group_join_requests/priv__r1'));
  tx.update(g.ref, { memberIds: [...g.data().memberIds, 'r1'] });
  tx.update(r.ref, { status: 'accepted', reviewedAt: serverTimestamp() });
})));

console.log('Chat');
const msgs = (uid, g = 'pub') => collection(db(uid), `groups/${g}/messages`);
await t('un membre lit les messages', () => assertSucceeds(getDocs(msgs('m1'))));
await t('refus : un non-membre lit les messages', () => assertFails(getDocs(msgs('outsider'))));
await t('refus : un non-membre lit le chat d\'un groupe privé', () => assertFails(getDocs(msgs('outsider', 'priv'))));
await t('un membre envoie un message', () => assertSucceeds(setDoc(doc(msgs('m1')), { senderId: 'm1', senderName: 'M1', type: 'text', content: 'x', createdAt: serverTimestamp(), updatedAt: null, deletedAt: null, reactions: {} })));
await t('refus : usurper l\'expéditeur', () => assertFails(setDoc(doc(msgs('m1')), { senderId: 'owner', type: 'text', content: 'x', deletedAt: null, reactions: {} })));
await t('réagir (sa propre clé)', () => assertSucceeds(updateDoc(doc(db('owner'), 'groups/pub/messages/msg1'), { 'reactions.owner': { name: 'O', emojis: ['👍'] } })));
await t('retirer sa réaction', () => assertSucceeds(updateDoc(doc(db('owner'), 'groups/pub/messages/msg1'), { 'reactions.owner': deleteField() })));
await t('refus : réagir au nom d\'un autre', () => assertFails(updateDoc(doc(db('owner'), 'groups/pub/messages/msg1'), { 'reactions.m1': { name: 'M1', emojis: ['❤️'] } })));
await t('refus : modifier le message d\'un autre', () => assertFails(updateDoc(doc(db('owner'), 'groups/pub/messages/msg1'), { content: 'edit' })));
await t('l\'auteur modifie son message', () => assertSucceeds(updateDoc(doc(db('m1'), 'groups/pub/messages/msg1'), { content: 'edit', updatedAt: serverTimestamp() })));
await t('pièce jointe + copie (batch)', () => {
  const b = writeBatch(db('m1'));
  const ref = doc(msgs('m1'));
  b.set(doc(db('m1'), `groups/pub/attachmentData/${ref.id}`), { senderId: 'm1', fileName: 'a.pdf', mimeType: 'application/pdf', data: 'x' });
  b.set(ref, { senderId: 'm1', senderName: 'M1', type: 'attachment', content: 'a.pdf', createdAt: serverTimestamp(), deletedAt: null, reactions: {}, attachment: { id: 'a' } });
  return assertSucceeds(b.commit());
});

console.log('Sondages / épingles');
const poll = (uid) => doc(db(uid), 'groups/pub/polls/msg2');
await t('voter', () => assertSucceeds(updateDoc(poll('owner'), { 'votes.owner': 'opt_1' })));
await t('changer de vote', () => assertSucceeds(updateDoc(poll('owner'), { 'votes.owner': 'opt_0' })));
await t('refus : voter pour un autre', () => assertFails(updateDoc(poll('owner'), { 'votes.m1': 'opt_0' })));
await t('refus : un non-membre vote', () => assertFails(updateDoc(poll('outsider'), { 'votes.outsider': 'opt_0' })));
await t('le propriétaire du groupe clôt le sondage', () => assertSucceeds(updateDoc(poll('owner'), { closedAt: serverTimestamp() })));
await t('refus : voter sur un sondage clos', () => assertFails(updateDoc(poll('m1'), { 'votes.m1': 'opt_0' })));
await t('refus : un membre épingle', () => assertFails(setDoc(doc(db('m1'), 'groups/pub/pinned/msg1'), { pinnedBy: 'm1' })));
await t('le propriétaire épingle', () => assertSucceeds(setDoc(doc(db('owner'), 'groups/pub/pinned/msg1'), { pinnedBy: 'owner', pinnedAt: serverTimestamp() })));

console.log('Suppression du groupe par le propriétaire');
await t('vider les sous-collections puis supprimer', async () => {
  const d = db('owner');
  for (const sub of ['messages', 'polls', 'pinned', 'attachmentData']) {
    const s = await getDocs(collection(d, `groups/pub/${sub}`));
    for (const x of s.docs) await deleteDoc(x.ref);
  }
  await assertSucceeds(deleteDoc(doc(d, 'groups/pub')));
});

await env.cleanup();
console.log(`\n${passed} réussis, ${failed} échoués`);
process.exit(failed ? 1 : 0);
