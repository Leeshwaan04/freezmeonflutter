import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { io } from '../index';
import { enqueuePush } from '../jobs/queues';
import { logger } from '../services/logger';

const router = Router();
router.use(requireAuth);

// Prompt bank — 3 types, drawn in rotation
export const PROMPTS = {
  reflective: [
    'The best decision you ever made — describe it in one sentence.',
    'Something you changed your mind about completely in the last year.',
    'A moment you felt most like yourself.',
    'The thing you wish you had done sooner.',
  ],
  playful: [
    'You\'re planning the perfect Sunday for two strangers. What happens?',
    'The most chaotic thing you\'ve done that turned out perfectly.',
    'Describe your ideal morning using only three words.',
    'The last thing that made you laugh until it hurt.',
  ],
  values: [
    'The one thing you\'d never compromise on.',
    'What does a good day look like to you?',
    'Something you believe that most people around you don\'t.',
    'What you\'re most proud of that nobody gave you an award for.',
  ],
};

function pickPrompt(type: 'reflective' | 'playful' | 'values'): string {
  const list = PROMPTS[type];
  return list[Math.floor(Math.random() * list.length)];
}

function pickPromptType(): 'reflective' | 'playful' | 'values' {
  const types: Array<'reflective' | 'playful' | 'values'> = ['reflective', 'playful', 'values'];
  return types[Math.floor(Date.now() / (2 * 60 * 60 * 1000)) % 3];
}

// GET /freeze-room/current — get currently open room (or null)
router.get('/current', async (req: Request, res: Response) => {
  try {
    const now = new Date();

    // Find open room where user hasn't joined yet, or already joined
    let room = await prisma.freezeRoom.findFirst({
      where: { status: 'open', closesAt: { gt: now } },
      include: {
        participants: { where: { uid: req.uid } },
      },
      orderBy: { openedAt: 'desc' },
    });

    if (!room) {
      res.json({ room: null });
      return;
    }

    // How many participants (don't expose who)
    const participantCount = await prisma.freezeRoomParticipant.count({
      where: { roomId: room.id },
    });

    // Has user already answered?
    const myParticipation = room.participants[0] ?? null;

    res.json({
      room: {
        id: room.id,
        promptType: room.promptType,
        prompt: room.prompt,
        closesAt: room.closesAt,
        participantCount,
        myAnswer: myParticipation?.answer ?? null,
        myReveals: myParticipation?.reveals ?? [],
      },
    });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch room' });
  }
});

// POST /freeze-room/join — join current room and submit answer
router.post('/join', async (req: Request, res: Response) => {
  try {
    const { answer } = req.body;
    if (!answer || typeof answer !== 'string' || answer.trim().length < 3) {
      res.status(400).json({ error: 'answer required (min 3 chars)' }); return;
    }

    const now = new Date();
    const room = await prisma.freezeRoom.findFirst({
      where: { status: 'open', closesAt: { gt: now } },
      orderBy: { openedAt: 'desc' },
    });

    if (!room) {
      res.status(404).json({ error: 'No open room right now' }); return;
    }

    // Upsert participation
    await prisma.freezeRoomParticipant.upsert({
      where: { roomId_uid: { roomId: room.id, uid: req.uid } },
      update: { answer: answer.trim() },
      create: { roomId: room.id, uid: req.uid, answer: answer.trim() },
    });

    // Log presence event
    await prisma.presenceEvent.create({
      data: { uid: req.uid, eventType: 'room_joined' },
    });

    // Notify other participants in this room (anonymously — just "someone answered")
    io.to(`freeze_room:${room.id}`).emit('freeze_room:answer_in', {
      roomId: room.id,
      total: await prisma.freezeRoomParticipant.count({
        where: { roomId: room.id, answer: { not: null } },
      }),
    });

    // Join the socket room for real-time events
    // (socket joins happen client-side on connection — this is just the REST ack)
    res.json({ success: true, roomId: room.id });
  } catch (err) {
    logger.error({ msg: 'freeze_room_join_error', err });
    res.status(500).json({ error: 'Failed to join room' });
  }
});

// POST /freeze-room/reveal — reveal yourself to another participant (max 3)
router.post('/reveal', async (req: Request, res: Response) => {
  try {
    const { roomId, targetUid } = req.body;
    if (!roomId || !targetUid) {
      res.status(400).json({ error: 'roomId and targetUid required' }); return;
    }

    const myPart = await prisma.freezeRoomParticipant.findUnique({
      where: { roomId_uid: { roomId, uid: req.uid } },
    });
    if (!myPart) { res.status(403).json({ error: 'Not in this room' }); return; }
    if (!myPart.answer) { res.status(400).json({ error: 'Must answer before revealing' }); return; }

    // Max 3 reveals per session
    if (myPart.reveals.length >= 3) {
      res.status(429).json({ error: 'Maximum 3 reveals per room session' }); return;
    }
    if (myPart.reveals.includes(targetUid)) {
      res.status(400).json({ error: 'Already revealed to this person' }); return;
    }

    // Update reveals list
    const updatedReveals = [...myPart.reveals, targetUid];
    await prisma.freezeRoomParticipant.update({
      where: { roomId_uid: { roomId, uid: req.uid } },
      data: { reveals: updatedReveals },
    });

    // Check if target also revealed to me → mutual match!
    const theirPart = await prisma.freezeRoomParticipant.findUnique({
      where: { roomId_uid: { roomId, uid: targetUid } },
    });

    if (theirPart?.reveals.includes(req.uid)) {
      // Mutual reveal — create FreezeMatch + regular Match + Chat
      const [userA, userB] = [req.uid, targetUid].sort();

      const existing = await prisma.freezeMatch.findUnique({
        where: { userA_userB: { userA, userB } },
      });

      if (!existing) {
        await prisma.freezeMatch.create({ data: { roomId, userA, userB } });

        // Create a real match + chat so they can message
        const match = await prisma.match.create({
          data: { members: [userA, userB], status: 'active' },
        });
        await prisma.chat.create({
          data: { members: [userA, userB], matchId: match.id },
        });

        // Fetch profiles for notification
        const [profileA, profileB] = await Promise.all([
          prisma.profile.findUnique({ where: { userId: userA } }),
          prisma.profile.findUnique({ where: { userId: userB } }),
        ]);

        // Notify both via socket
        io.to(`user:${userA}`).emit('freeze_room:match', {
          matchId: match.id,
          otherUid: userB,
          otherName: profileB?.name ?? 'Someone',
          otherImageUrl: profileB?.imageUrl ?? null,
          fromRoom: roomId,
        });
        io.to(`user:${userB}`).emit('freeze_room:match', {
          matchId: match.id,
          otherUid: userA,
          otherName: profileA?.name ?? 'Someone',
          otherImageUrl: profileA?.imageUrl ?? null,
          fromRoom: roomId,
        });

        // Push notifications
        const [userARecord, userBRecord] = await Promise.all([
          prisma.user.findUnique({ where: { id: userA } }),
          prisma.user.findUnique({ where: { id: userB } }),
        ]);
        if (userARecord?.fcmToken) {
          await enqueuePush(userARecord.fcmToken, '❄️ It\'s a Freeze Match!',
            `You and ${profileB?.name ?? 'someone'} revealed to each other`, { type: 'freeze_match', matchId: match.id });
        }
        if (userBRecord?.fcmToken) {
          await enqueuePush(userBRecord.fcmToken, '❄️ It\'s a Freeze Match!',
            `You and ${profileA?.name ?? 'someone'} revealed to each other`, { type: 'freeze_match', matchId: match.id });
        }

        res.json({ mutual: true, matchId: match.id });
        return;
      }
      // Match already existed between these users
      res.json({ mutual: true, matchId: existing.id });
      return;
    }

    // Not mutual yet — notify target that someone revealed (anonymously)
    io.to(`user:${targetUid}`).emit('freeze_room:reveal_received', {
      roomId,
      // Don't reveal who yet — just that someone revealed
    });

    res.json({ mutual: false });
  } catch (err) {
    logger.error({ msg: 'freeze_room_reveal_error', err });
    res.status(500).json({ error: 'Failed to process reveal' });
  }
});

// GET /freeze-room/participants — get anonymised answers in current room
// (shown after user has answered — no names/photos until mutual reveal)
router.get('/participants', async (req: Request, res: Response) => {
  try {
    const now = new Date();
    const room = await prisma.freezeRoom.findFirst({
      where: { status: 'open', closesAt: { gt: now } },
      orderBy: { openedAt: 'desc' },
    });
    if (!room) { res.json({ participants: [] }); return; }

    // Only show if the requester has answered
    const myPart = await prisma.freezeRoomParticipant.findUnique({
      where: { roomId_uid: { roomId: room.id, uid: req.uid } },
    });
    if (!myPart?.answer) {
      res.status(403).json({ error: 'Answer first to see others' }); return;
    }

    const participants = await prisma.freezeRoomParticipant.findMany({
      where: { roomId: room.id, answer: { not: null }, uid: { not: req.uid } },
    });

    // Check who I already revealed to
    const alreadyRevealed = new Set(myPart.reveals);

    // Return anonymised — uid (for reveal action) + answer + whether they revealed to me
    const result = participants.map(p => ({
      participantId: p.uid,  // needed for reveal endpoint
      answer: p.answer,
      theyRevealedToMe: p.reveals.includes(req.uid),
      iRevealed: alreadyRevealed.has(p.uid),
    }));

    res.json({ participants: result, myRevealsLeft: 3 - myPart.reveals.length });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch participants' });
  }
});

export default router;
