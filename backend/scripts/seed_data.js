const admin = require('firebase-admin');

// Point to the emulators
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8085';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';

admin.initializeApp({
  projectId: 'freezme-844cc'
});

const db = admin.firestore();
const auth = admin.auth();

async function seed() {
  console.log('🌱 Seeding data to emulators...');

  // 1. Create Test Users in Auth
  const users = [
    { uid: 'test_user_alice', email: 'alice@example.com', displayName: 'Alice' },
    { uid: 'test_user_bob', email: 'bob@example.com', displayName: 'Bob' },
  ];

  for (const u of users) {
    try {
      await auth.createUser(u);
      console.log(`✅ Created user: ${u.displayName}`);
    } catch (e) {
      console.log(`ℹ️ User ${u.displayName} might already exist.`);
    }
  }

  // 2. Create Profiles
  const profiles = [
    {
      uid: 'test_user_alice',
      name: 'Alice',
      age: 24,
      bio: 'Loves hiking and coffee! ☕🏔️',
      interests: ['Hiking', 'Coffee', 'Music'],
      photoUrls: ['https://images.unsplash.com/photo-1494790108377-be9c29b29330'],
      location: 'New York',
      distance: '2 km away',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      uid: 'test_user_bob',
      name: 'Bob',
      age: 28,
      bio: 'Software engineer by day, foodie by night. 🍕💻',
      interests: ['Coding', 'Pizza', 'Travel'],
      photoUrls: ['https://images.unsplash.com/photo-1500648767791-00dcc994a43e'],
      location: 'New York',
      distance: '3 km away',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }
  ];

  for (const p of profiles) {
    await db.collection('profiles').doc(p.uid).set(p);
    console.log(`✅ Seeded profile: ${p.name}`);
  }

  // 3. Create a Match/Chat
  const chatId = 'alice_bob_chat';
  await db.collection('chats').doc(chatId).set({
    members: ['test_user_alice', 'test_user_bob'],
    memberDisplay: {
      'test_user_alice': { name: 'Alice', photoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330' },
      'test_user_bob': { name: 'Bob', photoUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e' }
    },
    lastMessage: {
      text: 'Hey Bob! Nice code matching you! 😉',
      senderId: 'test_user_alice',
      status: 'delivered',
      sentAt: admin.firestore.FieldValue.serverTimestamp()
    },
    unread: { 'test_user_alice': 0, 'test_user_bob': 1 },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    isGroup: false
  });
  console.log('✅ Seeded demo chat between Alice and Bob');

  console.log('✨ Seeding complete!');
  process.exit(0);
}

seed().catch(err => {
  console.error('❌ Seeding failed:', err);
  process.exit(1);
});
