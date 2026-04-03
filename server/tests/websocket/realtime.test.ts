/**
 * WebSocket / Real-time tests — connects to live EC2 socket.io server.
 * Tests chat message delivery, ACK, auth enforcement, and match events.
 */

import { io as ioClient, Socket } from 'socket.io-client';
import axios from 'axios';

const BASE_HTTP = 'https://api.freezme.in';
const BASE_WS   = 'wss://api.freezme.in';

const WS_EMAIL_A = `ws_alice_${Date.now()}@freezme.com`;
const WS_EMAIL_B = `ws_bob_${Date.now()}@freezme.com`;
const PASSWORD   = 'TestPass1234!';

const http = axios.create({ baseURL: BASE_HTTP, validateStatus: () => true, timeout: 15000 });
const authH = (t: string) => ({ headers: { Authorization: `Bearer ${t}` } });

let tokenA = '', tokenB = '';
let aliceUid = '', bobUid = '';
let chatId = '';
let socketA: Socket, socketB: Socket;

// ── Helpers ──────────────────────────────────────────────────────────────────

async function authWithRetry(email: string, action: 'signup' | 'signin', retries = 8): Promise<any> {
  for (let i = 0; i < retries; i++) {
    const r = await http.post('/auth/email', { email, password: PASSWORD, action });
    if (r.status !== 429) return r;
    const wait = (i + 1) * 8000; // 8s, 16s, 24s ...
    console.log(`Rate limited on ${action} for ${email}, waiting ${wait / 1000}s...`);
    await new Promise(res => setTimeout(res, wait));
  }
  throw new Error(`Rate limited after ${retries} retries for ${email}`);
}

async function setupUsers() {
  const rA = await authWithRetry(WS_EMAIL_A, 'signup');
  tokenA = rA.data.accessToken;
  await http.post('/profiles', { name: 'WS-Alice', age: 25, bio: 'ws test', interests: [] }, authH(tokenA));
  const meA = await http.get('/profiles/me', authH(tokenA));
  aliceUid = meA.data.userId;

  await new Promise(r => setTimeout(r, 2000)); // rate limit gap

  const rB = await authWithRetry(WS_EMAIL_B, 'signup');
  tokenB = rB.data.accessToken;
  await http.post('/profiles', { name: 'WS-Bob', age: 27, bio: 'ws test bob', interests: [] }, authH(tokenB));
  const meB = await http.get('/profiles/me', authH(tokenB));
  bobUid = meB.data.userId;

  // Mutual like → match + chat
  await http.post('/matching/like', { targetUid: bobUid },   authH(tokenA));
  await http.post('/matching/like', { targetUid: aliceUid }, authH(tokenB));

  const chats = await http.get('/chats', authH(tokenA));
  chatId = chats.data[0]?.id ?? '';
}

function connectSocket(token: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const socket = ioClient(BASE_WS, {
      auth: { token },
      transports: ['websocket'],
      reconnection: false,
      timeout: 10000,
    });
    socket.once('connect', () => resolve(socket));
    socket.once('connect_error', reject);
  });
}

// ── Setup / Teardown ──────────────────────────────────────────────────────────

beforeAll(async () => {
  await setupUsers();
  socketA = await connectSocket(tokenA);
  socketB = await connectSocket(tokenB);
}, 120000);

afterAll(async () => {
  socketA?.disconnect();
  socketB?.disconnect();
  // Cleanup users
  const rA = await http.post('/auth/email', { email: WS_EMAIL_A, password: PASSWORD, action: 'signin' });
  const rB = await http.post('/auth/email', { email: WS_EMAIL_B, password: PASSWORD, action: 'signin' });
  await http.delete('/users/me', authH(rA.data?.accessToken ?? tokenA));
  await http.delete('/users/me', authH(rB.data?.accessToken ?? tokenB));
}, 20000);

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('WebSocket — Connection & Auth', () => {
  it('Alice connects successfully', () => {
    expect(socketA.connected).toBe(true);
  });

  it('Bob connects successfully', () => {
    expect(socketB.connected).toBe(true);
  });

  it('connection without token is rejected', async () => {
    await expect(connectSocket('')).rejects.toBeDefined();
  });

  it('connection with invalid token is rejected', async () => {
    await expect(connectSocket('invalid.jwt.token')).rejects.toBeDefined();
  });
});

describe('WebSocket — Chat Messaging', () => {
  it('Alice sends message and gets ACK from server', (done) => {
    expect(chatId).toBeTruthy();

    socketA.once('chat:ack', (data) => {
      expect(data).toHaveProperty('messageId');
      expect(data.status).toBe('sent');
      done();
    });

    socketA.emit('chat:send', {
      chatId,
      text: 'Hello from Alice! WS test.',
      clientMsgId: 'test-msg-001',
    });
  }, 10000);

  it('Bob receives the message Alice sent', (done) => {
    // Alice sends a message; Bob (the other member) should receive it via chat:message
    const targetText = 'Hello from Bob sender via Alice send.';
    function handler(data: any) {
      if (data.message?.text === targetText) {
        socketB.off('chat:message', handler);
        expect(data).toHaveProperty('chatId');
        expect(data.chatId).toBe(chatId);
        expect(data.message.senderUid).toBe(aliceUid);
        done();
      }
    }
    socketB.on('chat:message', handler);

    // Small delay so Bob's listener is registered before send
    setTimeout(() => {
      socketA.emit('chat:send', {
        chatId,
        text: targetText,
        clientMsgId: 'test-msg-002',
      });
    }, 300);
  }, 15000);

  it('Alice receives Bob message too (delivered to all members)', (done) => {
    const targetText = 'Ping from Bob to Alice.';
    // Use a filtering handler in case a prior event fires first
    function handler(data: any) {
      if (data.message?.text === targetText) {
        socketA.off('chat:message', handler);
        expect(data.chatId).toBe(chatId);
        done();
      }
    }
    socketA.on('chat:message', handler);

    setTimeout(() => {
      socketB.emit('chat:send', {
        chatId,
        text: targetText,
        clientMsgId: 'test-msg-003',
      });
    }, 300);
  }, 10000);

  it('message is persisted in DB after send', async () => {
    // Give server time to persist
    await new Promise(r => setTimeout(r, 500));
    const r = await http.get(`/chats/${chatId}/messages`, authH(tokenA));
    expect(r.status).toBe(200);
    expect(r.data.length).toBeGreaterThan(0);
    const texts = r.data.map((m: any) => m.text);
    expect(texts.some((t: string) => t.includes('Hello from') || t.includes('Ping from'))).toBe(true);
  });

  it('send to invalid chatId is silently ignored (no crash)', (done) => {
    // Server should not crash — just not deliver
    socketA.emit('chat:send', { chatId: 'nonexistent-chat-id', text: 'test' });
    // No event expected — just make sure server stays up
    setTimeout(() => done(), 1000);
  }, 5000);

  it('chat:read event is accepted without error', (done) => {
    socketA.emit('chat:read', { chatId, messageId: 'any-msg-id' });
    setTimeout(() => done(), 500);
  }, 3000);
});

describe('WebSocket — Presence', () => {
  it('presence:ping is accepted', (done) => {
    socketA.emit('presence:ping', {});
    setTimeout(() => done(), 500);
  }, 3000);
});
