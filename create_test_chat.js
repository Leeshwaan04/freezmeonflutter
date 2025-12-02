#!/usr/bin/env node

/**
 * Script to create a test chat document in Firestore
 *
 * Usage:
 *   node create_test_chat.js <your-firebase-auth-uid>
 *
 * Example:
 *   node create_test_chat.js abc123xyz
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, 'backend/service-account-key.json');

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch (error) {
  console.error('❌ Error: Could not load service account key.');
  console.error('Please download it from Firebase Console:');
  console.error('  1. Go to Project Settings → Service Accounts');
  console.error('  2. Click "Generate new private key"');
  console.error('  3. Save as backend/service-account-key.json');
  process.exit(1);
}

const db = admin.firestore();

// Get user UID from command line or use default
const userUid = process.argv[2] || 'test_user_123';
const priyaUid = 'pYjTHhoKgLINSkabm6tw';

console.log(`\n🔧 Creating chat between:`);
console.log(`   You: ${userUid}`);
console.log(`   Priya: ${priyaUid}\n`);

async function createChat() {
  try {
    // Create chat document
    const chatRef = db.collection('chats').doc();
    const chatId = chatRef.id;

    const chatData = {
      members: [userUid, priyaUid],
      memberDisplay: {
        [userUid]: {
          name: 'You',
          photoUrl: 'https://ui-avatars.com/api/?name=You&background=6C63FF&color=fff'
        },
        [priyaUid]: {
          name: 'priya',
          photoUrl: 'https://images.unsplash.com/photo-1546961329-78bef0414d7c?w=400'
        }
      },
      lastMessage: {
        text: 'Hey! That was such a great vibe date! 💜',
        senderId: priyaUid,
        status: 'delivered',
        sentAt: admin.firestore.FieldValue.serverTimestamp()
      },
      unread: {
        [userUid]: 1,
        [priyaUid]: 0
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      isGroup: false
    };

    await chatRef.set(chatData);
    console.log(`✅ Chat document created: ${chatId}`);

    // Create some test messages
    const messagesRef = chatRef.collection('messages');

    const messages = [
      {
        chatId: chatId,
        senderId: priyaUid,
        text: 'Hey! That was such a great vibe date! 💜',
        sentAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3600000)), // 1 hour ago
        status: 'read'
      },
      {
        chatId: chatId,
        senderId: userUid,
        text: 'I know right! I loved our conversation about art 🎨',
        sentAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3500000)),
        status: 'read'
      },
      {
        chatId: chatId,
        senderId: priyaUid,
        text: 'Same! We should definitely check out that gallery together',
        sentAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3000000)),
        status: 'read'
      },
      {
        chatId: chatId,
        senderId: userUid,
        text: 'Absolutely! How about this weekend?',
        sentAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2500000)),
        status: 'delivered'
      }
    ];

    for (let i = 0; i < messages.length; i++) {
      await messagesRef.add(messages[i]);
      console.log(`✅ Message ${i + 1}/${messages.length} created`);
    }

    console.log('\n🎉 Success! Chat created with 4 test messages.');
    console.log(`\n📱 Open your app and check the Matches tab to see the chat!`);
    console.log(`\n💡 Tip: The chat ID is: ${chatId}`);

  } catch (error) {
    console.error('\n❌ Error creating chat:', error.message);
    process.exit(1);
  }

  process.exit(0);
}

createChat();
