// Pruebas de las reglas de Firestore con el emulador.
// Uso (desde esta carpeta):  npm install && npm test
// Requiere Java (para el emulador de Firestore). No usa servicios de pago.
import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, serverTimestamp, collection, getDocs } from 'firebase/firestore';

const CODE = 'ABC234';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-el-asesino',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());

const member = (uid, extra = {}) => ({
  uid, name: uid, joinedAtMs: 1, alive: true, online: true,
  revealedRole: null, left: false, isNarrator: false, ...extra,
});

// Estado inicial: sala en el lobby con host, ana y bea.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'rooms', CODE), {
      code: CODE, name: 'Sala', hostUid: 'host', narrator: 'auto', phase: 'lobby', round: 0,
      version: 1, config: {}, createdAtMs: 1, nightStep: null, voteSeq: 0,
      hostHeartbeat: new Date(),
    });
    for (const u of ['host', 'ana', 'bea']) {
      await setDoc(doc(db, 'rooms', CODE, 'members', u), member(u));
    }
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

async function setPhase(phase, extra = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'rooms', CODE), { phase, ...extra });
  });
}

test('sin sesión no se lee nada', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'rooms', CODE)));
});

test('se puede leer una sala por código pero no listar salas', async () => {
  await assertSucceeds(getDoc(doc(as('ana'), 'rooms', CODE)));
  await assertFails(getDocs(collection(as('ana'), 'rooms')));
});

test('el rol privado sólo lo leen su dueño y el anfitrión', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'rooms', CODE, 'private', 'ana'), { role: 'police', team: 'town' });
  });
  await assertSucceeds(getDoc(doc(as('ana'), 'rooms', CODE, 'private', 'ana')));
  await assertSucceeds(getDoc(doc(as('host'), 'rooms', CODE, 'private', 'ana')));
  await assertFails(getDoc(doc(as('bea'), 'rooms', CODE, 'private', 'ana')));
});

test('un jugador no puede escribir documentos privados ni el estado del anfitrión', async () => {
  await assertFails(setDoc(doc(as('ana'), 'rooms', CODE, 'private', 'ana'), { role: 'assassin', team: 'assassins' }));
  await assertFails(getDoc(doc(as('ana'), 'rooms', CODE, 'hostState', 'state')));
  await assertSucceeds(setDoc(doc(as('host'), 'rooms', CODE, 'private', 'ana'), { role: 'police', team: 'town' }));
});

test('unirse sólo en el lobby y sólo como uno mismo', async () => {
  await assertSucceeds(setDoc(doc(as('cris'), 'rooms', CODE, 'members', 'cris'), member('cris')));
  await assertFails(setDoc(doc(as('dani'), 'rooms', CODE, 'members', 'otro'), member('otro')));
  await assertFails(setDoc(doc(as('eva'), 'rooms', CODE, 'members', 'eva'), member('eva', { isNarrator: true })));
  await setPhase('night');
  await assertFails(setDoc(doc(as('fer'), 'rooms', CODE, 'members', 'fer'), member('fer')));
});

test('un jugador no puede cambiarse el estado de vida ni el rol revelado', async () => {
  await assertFails(updateDoc(doc(as('ana'), 'rooms', CODE, 'members', 'ana'), { alive: false }));
  await assertFails(updateDoc(doc(as('ana'), 'rooms', CODE, 'members', 'ana'), { revealedRole: 'civilian' }));
  await assertSucceeds(updateDoc(doc(as('host'), 'rooms', CODE, 'members', 'ana'), { alive: false }));
});

test('sólo el anfitrión cambia la sala, con versión +1 y fases válidas', async () => {
  const ref = (u) => doc(as(u), 'rooms', CODE);
  await assertFails(updateDoc(ref('ana'), { phase: 'roleReveal', version: 2 }));
  await assertFails(updateDoc(ref('host'), { phase: 'night', version: 2 })); // salta fases
  await assertFails(updateDoc(ref('host'), { phase: 'roleReveal', version: 5 })); // versión incorrecta
  await assertSucceeds(updateDoc(ref('host'), { phase: 'roleReveal', round: 1, version: 2 }));
});

test('acciones nocturnas: una vez, fase, turno y rol correctos', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'rooms', CODE, 'private', 'ana'), { role: 'police', team: 'town' });
    await updateDoc(doc(db, 'rooms', CODE), { phase: 'night', round: 1, nightStep: 'police', version: 2 });
  });
  const act = (role) => ({ uid: 'ana', round: 1, role, targets: ['bea'], opId: 'x' });
  const ref = doc(as('ana'), 'rooms', CODE, 'actions', '1_ana');
  await assertFails(setDoc(ref, act('assassin')));          // rol que no tiene
  await assertSucceeds(setDoc(ref, act('police')));
  await assertFails(setDoc(ref, act('police')));            // duplicada / edición
  await assertFails(setDoc(doc(as('bea'), 'rooms', CODE, 'actions', '1_ana'), act('police'))); // suplantación
  // Sólo la leen el anfitrión y su autor.
  await assertSucceeds(getDoc(doc(as('host'), 'rooms', CODE, 'actions', '1_ana')));
  await assertFails(getDoc(doc(as('bea'), 'rooms', CODE, 'actions', '1_ana')));
});

test('fuera de turno no se puede actuar; los muertos tampoco', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'rooms', CODE, 'private', 'ana'), { role: 'police', team: 'town' });
    await updateDoc(doc(db, 'rooms', CODE), { phase: 'night', round: 1, nightStep: 'doctor', version: 2 });
  });
  const ref = doc(as('ana'), 'rooms', CODE, 'actions', '1_ana');
  await assertFails(setDoc(ref, { uid: 'ana', round: 1, role: 'police', targets: [], opId: 'x' }));
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'rooms', CODE), { nightStep: 'police' });
    await updateDoc(doc(ctx.firestore(), 'rooms', CODE, 'members', 'ana'), { alive: false });
  });
  await assertFails(setDoc(ref, { uid: 'ana', round: 1, role: 'police', targets: [], opId: 'x' }));
});

test('votos: secretos, una vez, sólo vivos y en votación', async () => {
  await setPhase('voting', { voteSeq: 1, round: 1, version: 2 });
  const v = { uid: 'ana', seq: 1, target: 'bea' };
  await assertSucceeds(setDoc(doc(as('ana'), 'rooms', CODE, 'votes', '1_ana'), v));
  await assertFails(setDoc(doc(as('ana'), 'rooms', CODE, 'votes', '1_ana'), { ...v, target: 'host' }));
  await assertFails(getDoc(doc(as('bea'), 'rooms', CODE, 'votes', '1_ana')));   // voto secreto
  await assertSucceeds(getDoc(doc(as('host'), 'rooms', CODE, 'votes', '1_ana')));
  await assertFails(setDoc(doc(as('bea'), 'rooms', CODE, 'votes', '2_bea'), { uid: 'bea', seq: 2, target: 'ana' }));
});

test('relevo de anfitrión: sólo si lleva más de 45 s sin latir', async () => {
  const ref = doc(as('ana'), 'rooms', CODE);
  await assertFails(updateDoc(ref, { hostUid: 'ana', hostHeartbeat: serverTimestamp(), version: 2 }));
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'rooms', CODE), { hostHeartbeat: new Date(Date.now() - 120000) });
  });
  await assertSucceeds(updateDoc(ref, { hostUid: 'ana', hostHeartbeat: serverTimestamp(), version: 2 }));
  // El anfitrión anterior ya no puede escribir.
  await assertFails(updateDoc(doc(as('host'), 'rooms', CODE), { phase: 'roleReveal', version: 3 }));
});

test('la presencia sólo la escribe el propio miembro y sólo la lee el anfitrión', async () => {
  await assertSucceeds(setDoc(doc(as('ana'), 'rooms', CODE, 'presence', 'ana'), { ts: serverTimestamp() }));
  await assertFails(setDoc(doc(as('ana'), 'rooms', CODE, 'presence', 'bea'), { ts: serverTimestamp() }));
  await assertFails(getDoc(doc(as('bea'), 'rooms', CODE, 'presence', 'ana')));
  await assertSucceeds(getDoc(doc(as('host'), 'rooms', CODE, 'presence', 'ana')));
});

test('un jugador nuevo puede consultar su propio documento de miembro antes de unirse, pero no listar ni leer los ajenos', async () => {
  const db = as('nuevo');
  await assertSucceeds(getDoc(doc(db, 'rooms', CODE, 'members', 'nuevo')));   // reentrada (aún no existe)
  await assertFails(getDoc(doc(db, 'rooms', CODE, 'members', 'ana')));        // ajenos, no
  await assertFails(getDocs(collection(db, 'rooms', CODE, 'members')));       // listar, no
  await assertSucceeds(setDoc(doc(db, 'rooms', CODE, 'members', 'nuevo'), member('nuevo')));
  await assertSucceeds(getDocs(collection(db, 'rooms', CODE, 'members')));    // ya miembro: sí
});

const chatMsg = (uid, name, text = 'hola') => ({ uid, name, text, ts: serverTimestamp(), expireAt: new Date(Date.now() + 86400000) });

test('chat: los miembros escriben con su propio nombre y leen; los ajenos no', async () => {
  const col = (u) => collection(as(u), 'rooms', CODE, 'chat');
  await assertSucceeds(setDoc(doc(col('ana')), chatMsg('ana', 'ana')));                  // lobby
  await assertFails(setDoc(doc(col('ana')), chatMsg('ana', 'bea')));                      // suplantar nombre
  await assertFails(setDoc(doc(col('ana')), chatMsg('bea', 'bea')));                      // suplantar uid
  await assertFails(setDoc(doc(col('ana')), chatMsg('ana', 'ana', '')));                  // vacío
  await assertFails(setDoc(doc(col('ana')), chatMsg('ana', 'ana', 'x'.repeat(201))));     // demasiado largo
  await assertFails(setDoc(doc(collection(as('intruso'), 'rooms', CODE, 'chat')), chatMsg('intruso', 'intruso')));
  await assertSucceeds(getDocs(col('bea')));
  await assertFails(getDocs(collection(as('intruso'), 'rooms', CODE, 'chat')));
});

test('chat: cerrado de noche; los eliminados sólo hablan en lobby y al final', async () => {
  const send = (u) => setDoc(doc(collection(as(u), 'rooms', CODE, 'chat')), chatMsg(u, u));
  await setPhase('night', { round: 1, version: 2 });
  await assertFails(send('ana'));
  await setPhase('discussion', { version: 3 });
  await assertSucceeds(send('ana'));
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'rooms', CODE, 'members', 'bea'), { alive: false });
  });
  await assertFails(send('bea'));                       // eliminado en el debate
  await setPhase('finished', { version: 4 });
  await assertSucceeds(send('bea'));                    // al terminar sí
});
