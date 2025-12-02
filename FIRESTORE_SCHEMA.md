# Firestore Schema Reference for Freezme

This document describes the exact Firestore structure needed for the chat functionality to work properly.

## Collections Overview

```
/chats/{chatId}                    # Chat documents
  /messages/{messageId}             # Messages subcollection
/profiles/{userId}                  # User profiles
/presence/{userId}                  # Online status
```

---

## 1. `chats` Collection

**Collection Path:** `/chats/{chatId}`
**Document ID:** UUID or auto-generated

### Fields:

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `members` | `array<string>` | ✅ | Array of user IDs in this chat | `["user1Uid", "user2Uid"]` |
| `memberDisplay` | `map` | ✅ | Display info for each member | See below |
| `lastMessage` | `map` | ✅ | Most recent message preview | See below |
| `unread` | `map` | ✅ | Unread count per member | `{"user1Uid": 0, "user2Uid": 1}` |
| `updatedAt` | `timestamp` | ✅ | Last activity timestamp | `Timestamp.now()` |
| `isGroup` | `boolean` | ✅ | Whether this is a group chat | `false` |

### `memberDisplay` Map Structure:

```json
{
  "user1Uid": {
    "name": "John Doe",
    "photoUrl": "https://..."
  },
  "user2Uid": {
    "name": "Priya",
    "photoUrl": "https://..."
  }
}
```

### `lastMessage` Map Structure:

```json
{
  "text": "Hey! That was such a great vibe date!",
  "senderId": "user2Uid",
  "status": "delivered",
  "sentAt": Timestamp
}
```

---

## 2. `chats/{chatId}/messages` Subcollection

**Collection Path:** `/chats/{chatId}/messages/{messageId}`
**Document ID:** Auto-generated

### Fields:

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `chatId` | `string` | ✅ | Parent chat ID | `"abc123"` |
| `senderId` | `string` | ✅ | UID of message sender | `"user1Uid"` |
| `text` | `string` | ✅ | Message content | `"Hi there!"` |
| `sentAt` | `timestamp` | ✅ | When message was sent | `Timestamp.now()` |
| `status` | `string` | ✅ | Delivery status | `"sent"`, `"delivered"`, or `"read"` |

---

## Example Firestore Data

### Example Chat Document

**Path:** `/chats/chat_abc123`

```json
{
  "members": ["alice_uid", "bob_uid"],
  "memberDisplay": {
    "alice_uid": {
      "name": "Alice",
      "photoUrl": "https://example.com/alice.jpg"
    },
    "bob_uid": {
      "name": "Bob",
      "photoUrl": "https://example.com/bob.jpg"
    }
  },
  "lastMessage": {
    "text": "Hey! That was such a great vibe date!",
    "senderId": "bob_uid",
    "status": "delivered",
    "sentAt": Timestamp(2024-12-02 10:30:00)
  },
  "unread": {
    "alice_uid": 1,
    "bob_uid": 0
  },
  "updatedAt": Timestamp(2024-12-02 10:30:00),
  "isGroup": false
}
```

### Example Message Document

**Path:** `/chats/chat_abc123/messages/msg_xyz789`

```json
{
  "chatId": "chat_abc123",
  "senderId": "bob_uid",
  "text": "Hey! That was such a great vibe date!",
  "sentAt": Timestamp(2024-12-02 10:30:00),
  "status": "delivered"
}
```

---

## Firestore Indexes

### Required Composite Index

**Collection:** `chats`
**Fields to index:**
1. `members` (array-contains)
2. `updatedAt` (descending)

**Why:** This index allows fast queries like:
```dart
chats
  .where('members', arrayContains: currentUserId)
  .orderBy('updatedAt', descending: true)
```

### How to Create:

1. Go to Firebase Console → Firestore → Indexes
2. Click "Create Index"
3. Collection: `chats`
4. Add field: `members` → Array-contains
5. Add field: `updatedAt` → Descending
6. Click "Create"

Alternatively, the index will be auto-created when you run the query for the first time (Firebase will show an error with a link to create it).

---

## Query Examples

### Fetch user's chats (matches):

```dart
final snapshot = await FirebaseFirestore.instance
  .collection('chats')
  .where('members', arrayContains: currentUserId)
  .orderBy('updatedAt', descending: true)
  .limit(50)
  .get();
```

### Fetch messages for a chat:

```dart
final stream = FirebaseFirestore.instance
  .collection('chats')
  .doc(chatId)
  .collection('messages')
  .orderBy('sentAt', descending: true)
  .limit(50)
  .snapshots();
```

### Send a message and update chat:

```dart
final batch = FirebaseFirestore.instance.batch();

// 1. Add message to subcollection
final messageRef = FirebaseFirestore.instance
  .collection('chats')
  .doc(chatId)
  .collection('messages')
  .doc();

batch.set(messageRef, {
  'chatId': chatId,
  'senderId': currentUserId,
  'text': messageText,
  'sentAt': FieldValue.serverTimestamp(),
  'status': 'sent',
});

// 2. Update chat document
final chatRef = FirebaseFirestore.instance
  .collection('chats')
  .doc(chatId);

batch.update(chatRef, {
  'lastMessage': {
    'text': messageText,
    'senderId': currentUserId,
    'status': 'sent',
    'sentAt': FieldValue.serverTimestamp(),
  },
  'updatedAt': FieldValue.serverTimestamp(),
  'unread.${otherUserId}': FieldValue.increment(1),
});

await batch.commit();
```

---

## Security Rules

Example Firestore rules for chats:

```javascript
match /chats/{chatId} {
  allow read: if request.auth != null &&
    request.auth.uid in resource.data.members;

  allow create: if request.auth != null &&
    request.auth.uid in request.resource.data.members;

  allow update: if request.auth != null &&
    request.auth.uid in resource.data.members;

  match /messages/{messageId} {
    allow read: if request.auth != null &&
      request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.members;

    allow create: if request.auth != null &&
      request.auth.uid == request.resource.data.senderId &&
      request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.members;
  }
}
```

---

## Steps to Set Up in Firebase Console

1. **Create a test chat document:**
   - Go to Firestore Database
   - Click "Start collection"
   - Collection ID: `chats`
   - Document ID: (auto-generate or use a UUID)
   - Add fields as shown in the example above

2. **Create a test message:**
   - In the chat document, add a subcollection: `messages`
   - Add a message document with fields from the example

3. **Create the composite index:**
   - Either create manually (Indexes tab) or wait for the error link when running the query

4. **Test the queries:**
   - Run the app and check if chats appear in the Matches tab

---

## Next Steps

Once you create the data in Firestore Console:

1. Share one `chats` document (JSON export)
2. Share one `messages` document (JSON export)
3. I'll verify the code mapping matches exactly
4. Update repository if any adjustments are needed
