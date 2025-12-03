# Profile & Settings - Comprehensive Enhancement Plan

## 📋 Current State Analysis

### 🔴 Critical Issues Identified

#### 1. ProfileSettingsPage Issues
- **Dead-end menu items**: "Preferences", "Safety & Privacy", and "Help & Support" have empty actions
- **Missing bottom navigation**: Inconsistent with other main pages (Chats, Feed, etc.)
- **Hardcoded checklist**: Profile completion checklist has hardcoded `done: false` values
- **No refresh mechanism**: Profile data doesn't update when returning from edit pages

#### 2. ProfilePreviewPage Issues
- **Misleading functionality**: Named "Edit Profile" but only shows a preview
- **No editing capability**: Displays profile data but provides no text fields to edit
- **Hardcoded interests**: Shows static chips (Music, Travel, Art, etc.) not real user data
- **Confusing navigation**: "Edit photos" calls `startOnboarding()` which is unintuitive
- **No bio editing**: Placeholder text but no TextField for bio input
- **Circular navigation**: "Edit details" button loops back to ProfileSettings

#### 3. Missing Pages
- **PreferencesPage**: Age range, distance, interests settings
- **SafetyPrivacyPage**: Block list, data settings, account privacy
- **HelpSupportPage**: FAQs, contact support, report issues
- **EditProfilePage**: Actual editable form for bio, name, interests, etc.

#### 4. User Flow Issues
```
Current Flow (Broken):
ProfileSettings → "Edit Profile" → ProfilePreview → "Edit details" → ProfileSettings
                                  ↓
                            "Edit photos" → Onboarding (confusing!)

Missing Flows:
- ProfileSettings → Preferences (doesn't exist)
- ProfileSettings → Safety & Privacy (doesn't exist)
- ProfileSettings → Help & Support (doesn't exist)
- ProfileSettings → Edit Profile → Save changes → ProfileSettings (with refresh)
```

---

## 🎯 Enhancement Goals

### Primary Goals
1. ✅ Create functional profile editing with form validation
2. ✅ Add missing settings pages (Preferences, Safety, Help)
3. ✅ Fix circular navigation and create clear user flows
4. ✅ Add bottom navigation for consistency
5. ✅ Implement proper save/cancel mechanisms
6. ✅ Add loading states and success feedback

### Secondary Goals
7. ✅ Dynamic profile completion checklist
8. ✅ Add interest selection UI
9. ✅ Add photo management from profile page
10. ✅ Improve visual consistency with modern design

---

## 🎨 PART 1: PROFILE EDITING ENHANCEMENTS

### 1.1 New EditProfilePage (Full Form)

**Purpose**: Replace ProfilePreviewPage for actual editing

**Features**:
- ✅ Editable text fields: Name, Bio, Age, Location
- ✅ Interest selection with chips (tap to add/remove)
- ✅ Photo grid with add/remove functionality
- ✅ Form validation (name required, bio max 500 chars, age 18+)
- ✅ Save/Cancel buttons with loading states
- ✅ Confirmation dialog if unsaved changes

**UI Components**:
```dart
- AppBar with "Save" action button
- Profile photo section (scrollable grid)
- TextField for name (required)
- TextField for bio (multiline, max 500 chars)
- Age selector (dropdown or number field, 18-99)
- Location field (text or map picker)
- Interest chips (selectable, max 10)
- Save button (fixed at bottom)
```

**Validation Rules**:
- Name: 2-50 characters, required
- Bio: Max 500 characters, optional
- Age: 18-99, required
- Location: Optional
- Interests: 1-10 selections, at least 1 required
- Photos: At least 1 required, max 6

### 1.2 Enhanced ProfilePreviewPage (Read-Only)

**Purpose**: Show how profile looks to others

**Changes**:
- ✅ Remove "Edit details" button (confusing)
- ✅ Keep "Edit photos" but rename to "Manage Photos"
- ✅ Add "Edit Profile" button that goes to EditProfilePage
- ✅ Show actual user interests (not hardcoded)
- ✅ Display bio from user data
- ✅ Show age, location if set
- ✅ Better photo gallery layout

### 1.3 Photo Management Flow

**Current Issue**: "Edit photos" calls `startOnboarding()` which is confusing

**Solution**: Create dedicated photo picker within EditProfilePage

**Features**:
- ✅ In-app photo picker (using image_picker package)
- ✅ Reorder photos by drag-and-drop
- ✅ Delete photos with confirmation
- ✅ Add photos up to max limit (6)
- ✅ Primary photo indicator
- ✅ Upload progress indicators
- ✅ Photo compression before upload

---

## 🔧 PART 2: NEW SETTINGS PAGES

### 2.1 PreferencesPage

**Navigation**: ProfileSettings → "Preferences"

**Features**:
- ✅ Age range slider (18-99)
- ✅ Distance slider (1-100 km)
- ✅ Intent selection (Friends, Dates, Networking, etc.)
- ✅ Show me preferences (Men, Women, Everyone)
- ✅ Advanced filters (toggle):
  - ✅ Height range
  - ✅ Education level
  - ✅ Smoking/Drinking preferences
- ✅ Save button with loading state

**UI Layout**:
```dart
AppBar("Preferences")
ScrollView:
  - Section: "Discovery Settings"
    - Age Range Slider (18-99)
    - Distance Slider (1-100 km)
  - Section: "Looking For"
    - Intent chips (Friends, Dates, Networking)
  - Section: "Show Me"
    - Gender preference chips
  - Section: "Advanced Filters" (optional)
    - Height, Education, Lifestyle toggles
  - Save button (fixed at bottom)
```

### 2.2 SafetyPrivacyPage

**Navigation**: ProfileSettings → "Safety & Privacy"

**Features**:
- ✅ Block list management
- ✅ Privacy settings:
  - ✅ Hide online status
  - ✅ Hide last seen
  - ✅ Hide read receipts
  - ✅ Incognito mode
- ✅ Data settings:
  - ✅ Download my data
  - ✅ Delete account (with confirmation)
- ✅ Report & block:
  - ✅ View blocked users
  - ✅ Unblock users
- ✅ Two-factor authentication (future)

**UI Layout**:
```dart
AppBar("Safety & Privacy")
ScrollView:
  - Section: "Privacy"
    - Toggle: Hide online status
    - Toggle: Hide last seen
    - Toggle: Hide read receipts
    - Toggle: Incognito mode
  - Section: "Blocked Users"
    - List of blocked users with Unblock button
    - Empty state if none
  - Section: "Data & Account"
    - Button: Download my data
    - Button: Delete account (red, with warning)
```

### 2.3 HelpSupportPage

**Navigation**: ProfileSettings → "Help & Support"

**Features**:
- ✅ FAQ accordion (expandable sections)
- ✅ Contact support form
- ✅ Report a problem
- ✅ Community guidelines link
- ✅ Terms of service link
- ✅ Privacy policy link
- ✅ App version info

**UI Layout**:
```dart
AppBar("Help & Support")
ScrollView:
  - Section: "Frequently Asked Questions"
    - ExpansionTile: How do I match?
    - ExpansionTile: How do I unmatch?
    - ExpansionTile: What are Paths?
    - ExpansionTile: What are Blinds?
  - Section: "Get Help"
    - ListTile: Contact Support → ContactSupportPage
    - ListTile: Report a Problem → ReportProblemPage
  - Section: "Legal"
    - ListTile: Community Guidelines (web view)
    - ListTile: Terms of Service (web view)
    - ListTile: Privacy Policy (web view)
  - Section: "About"
    - App version, build number
```

---

## 💾 PART 3: BACKEND & DATABASE ENHANCEMENTS

### 3.1 Enhanced User Profile Schema

**Current**: Basic fields in `VibeProfile`

**Enhanced** (`/users/{uid}`):
```javascript
{
  // Basic Info
  uid: string,
  displayName: string,
  email: string,
  photoURL: string,

  // Profile Details (NEW)
  bio: string | null,  // max 500 chars
  age: number | null,  // 18-99
  location: {
    city: string | null,
    state: string | null,
    country: string | null,
    lat: number | null,
    lng: number | null,
  },
  gender: 'male' | 'female' | 'non-binary' | 'other' | null,

  // Interests (NEW)
  interests: [string],  // max 10
  interestCategories: {
    hobbies: [string],
    music: [string],
    sports: [string],
  },

  // Photos (ENHANCED)
  photos: [
    {
      url: string,
      thumbnailUrl: string,
      order: number,
      isPrimary: boolean,
      uploadedAt: timestamp,
    }
  ],

  // Preferences (NEW)
  preferences: {
    ageRange: { min: number, max: number },
    distanceKm: number,
    intents: ['Friends' | 'Dates' | 'Networking'],
    showMe: ['men' | 'women' | 'everyone'],
    advancedFilters: {
      heightRange: { min: number, max: number } | null,
      education: [string] | null,
      lifestyle: {
        smoking: 'yes' | 'no' | 'sometimes' | null,
        drinking: 'yes' | 'no' | 'sometimes' | null,
      },
    },
  },

  // Privacy Settings (NEW)
  privacy: {
    hideOnlineStatus: boolean,
    hideLastSeen: boolean,
    hideReadReceipts: boolean,
    incognitoMode: boolean,
  },

  // Account Settings
  settings: {
    notificationsEnabled: boolean,
    emailNotifications: boolean,
    pushNotifications: boolean,
  },

  // Blocked Users (NEW)
  blockedUsers: [uid],

  // Profile Completion
  profileCompletion: {
    hasPhotos: boolean,
    hasBio: boolean,
    hasInterests: boolean,
    hasPreferences: boolean,
    percentage: number,  // 0-100
  },

  // Metadata
  createdAt: timestamp,
  updatedAt: timestamp,
  lastActiveAt: timestamp,
}
```

### 3.2 New Repository Methods

**Add to FreezmeRepository interface**:
```dart
// Profile editing
Future<void> updateProfile({
  required String uid,
  String? displayName,
  String? bio,
  int? age,
  Map<String, dynamic>? location,
  String? gender,
});

// Interest management
Future<void> updateInterests(String uid, List<String> interests);

// Preferences
Future<void> updatePreferences(String uid, Map<String, dynamic> preferences);

// Privacy settings
Future<void> updatePrivacySettings(String uid, Map<String, dynamic> privacy);

// Block management
Future<void> blockUser(String blockerUid, String blockedUid);
Future<void> unblockUser(String blockerUid, String blockedUid);
Future<List<String>> getBlockedUsers(String uid);

// Photo management
Future<void> uploadProfilePhoto(String uid, File photo, {bool isPrimary = false});
Future<void> deleteProfilePhoto(String uid, String photoUrl);
Future<void> reorderPhotos(String uid, List<String> photoUrls);

// Account actions
Future<void> downloadUserData(String uid);
Future<void> deleteAccount(String uid);
```

### 3.3 Firestore Security Rules Updates

```javascript
match /users/{uid} {
  // Read: user can read own profile, or if not blocked
  allow read: if isSignedIn()
    && (request.auth.uid == uid
        || !(request.auth.uid in resource.data.get('blockedUsers', [])));

  // Update: only owner can update
  allow update: if isSignedIn() && request.auth.uid == uid;

  // Can't modify blockedUsers of other users
  allow update: if isSignedIn()
    && request.auth.uid == uid
    && (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['blockedUsers']));
}

// Block list (separate collection for better queries)
match /blocks/{blockId} {
  allow read, write: if isSignedIn()
    && request.auth.uid == resource.data.blockerUid;
}
```

---

## 🎨 PART 4: UI/UX IMPROVEMENTS

### 4.1 Bottom Navigation Addition

**Add to ProfileSettingsPage** (consistent with ChatListPage):
```dart
bottomNavigationBar: SafeArea(
  child: Container(
    decoration: BoxDecoration(/* shadows */),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNavItem(context, icon: Icons.chat_bubble_outline, label: 'Chats', onTap: () => flow.openChats()),
        _buildNavItem(context, icon: Icons.favorite_border, label: 'Feed', onTap: () => flow.openFeed()),
        _buildNavItem(context, icon: Icons.route_outlined, label: 'Paths', onTap: () => flow.openPaths()),
        _buildNavItem(context, icon: Icons.bolt_outlined, label: 'Blinds', onTap: () => flow.openBlinds()),
        _buildNavItem(context, icon: Icons.person_outline, label: 'Profile', active: true, onTap: () {}),
      ],
    ),
  ),
)
```

### 4.2 Dynamic Profile Checklist

**Current**: Hardcoded `done: false`

**Enhanced**: Calculate completion based on actual data
```dart
Widget _buildChecklist(AppFlowController flow) {
  final hasMinPhotos = flow.photoSlots.where((p) => p.status == PhotoSlotStatus.uploaded).length >= 3;
  final hasBio = flow.profileBio != null && flow.profileBio!.length >= 50;
  final hasInterests = flow.profileInterests != null && flow.profileInterests!.length >= 3;
  final hasPreferences = flow.preferences != null && flow.preferences!['ageRange'] != null;
  final completion = _calculateCompletion(hasMinPhotos, hasBio, hasInterests, hasPreferences);

  return _ProfileChecklist(
    items: [
      ChecklistItem(
        label: 'Add at least 3 photos',
        done: hasMinPhotos,
        status: hasMinPhotos ? 'Done' : '${uploadedPhotos}/3 added',
      ),
      ChecklistItem(
        label: 'Write a bio (50+ chars)',
        done: hasBio,
        status: hasBio ? 'Done' : 'Add your story',
      ),
      ChecklistItem(
        label: 'Select 3+ interests',
        done: hasInterests,
        status: hasInterests ? 'Done' : 'Choose interests',
      ),
      ChecklistItem(
        label: 'Set your preferences',
        done: hasPreferences,
        status: hasPreferences ? 'Done' : 'Age, distance, etc.',
      ),
    ],
    completion: completion,
  );
}
```

### 4.3 Loading States & Feedback

**Add to all save actions**:
```dart
bool _saving = false;

Future<void> _saveProfile() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _saving = true);
  try {
    await flow.updateProfile(/* data */);
    if (!mounted) return;

    // Show success
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Profile updated successfully'),
          ],
        ),
        backgroundColor: FreezmeColors.success,
      ),
    );

    // Navigate back
    flow.pop();
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}
```

### 4.4 Interest Selection UI

**Component**: `InterestSelectorWidget`

```dart
class InterestSelectorWidget extends StatefulWidget {
  final List<String> selectedInterests;
  final ValueChanged<List<String>> onChanged;
  final int maxSelections;

  // Shows grid of available interests
  // Tap to toggle selection
  // Show selected count
  // Disable selection when max reached
}
```

**Available Interests** (categorized):
```dart
final Map<String, List<String>> availableInterests = {
  'Hobbies': ['Music', 'Travel', 'Art', 'Photography', 'Reading', 'Gaming', 'Cooking'],
  'Sports': ['Yoga', 'Running', 'Gym', 'Cycling', 'Swimming', 'Dancing', 'Hiking'],
  'Lifestyle': ['Coffee', 'Wine', 'Foodie', 'Nightlife', 'Movies', 'Netflix'],
  'Values': ['Environmentalism', 'Volunteering', 'Spirituality', 'Activism'],
};
```

---

## 🧪 PART 5: FORM VALIDATION

### 5.1 Validation Rules

```dart
// Name validator
String? _validateName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Name is required';
  }
  if (value.trim().length < 2) {
    return 'Name must be at least 2 characters';
  }
  if (value.trim().length > 50) {
    return 'Name must be less than 50 characters';
  }
  return null;
}

// Bio validator
String? _validateBio(String? value) {
  if (value != null && value.length > 500) {
    return 'Bio must be less than 500 characters';
  }
  return null;
}

// Age validator
String? _validateAge(String? value) {
  if (value == null || value.isEmpty) {
    return 'Age is required';
  }
  final age = int.tryParse(value);
  if (age == null) {
    return 'Please enter a valid number';
  }
  if (age < 18) {
    return 'You must be at least 18 years old';
  }
  if (age > 99) {
    return 'Please enter a valid age';
  }
  return null;
}
```

### 5.2 Unsaved Changes Detection

```dart
class EditProfilePage extends StatefulWidget {
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool _hasUnsavedChanges = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_hasUnsavedChanges) return true;

        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unsaved Changes'),
            content: const Text('You have unsaved changes. Discard them?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );

        return shouldPop ?? false;
      },
      child: Scaffold(/* ... */),
    );
  }
}
```

---

## 🚀 PART 6: IMPLEMENTATION ROADMAP

### Phase 1: Core Profile Editing (Priority: HIGH)
**Timeline**: Week 1

1. ✅ Create EditProfilePage with form fields
2. ✅ Add form validation
3. ✅ Implement save/cancel with loading states
4. ✅ Add unsaved changes detection
5. ✅ Update ProfileSettingsPage to navigate to EditProfilePage
6. ✅ Fix ProfilePreviewPage to be read-only
7. ✅ Add backend methods: updateProfile, updateInterests

**Deliverables**:
- Functional profile editing
- Form validation working
- Save changes persisted to Firestore

### Phase 2: New Settings Pages (Priority: HIGH)
**Timeline**: Week 2

8. ✅ Create PreferencesPage
9. ✅ Create SafetyPrivacyPage
10. ✅ Create HelpSupportPage
11. ✅ Wire up navigation from ProfileSettings
12. ✅ Add backend methods: updatePreferences, updatePrivacySettings

**Deliverables**:
- All three new pages functional
- Preferences saved to Firestore
- Privacy settings working

### Phase 3: Advanced Features (Priority: MEDIUM)
**Timeline**: Week 3

13. ✅ Add InterestSelectorWidget
14. ✅ Add photo management (upload, delete, reorder)
15. ✅ Add block/unblock functionality
16. ✅ Add download user data feature
17. ✅ Add delete account with confirmation

**Deliverables**:
- Interest selection UI
- Photo upload/management
- Block management
- Data export

### Phase 4: UI Polish (Priority: MEDIUM)
**Timeline**: Week 4

18. ✅ Add bottom navigation to ProfileSettingsPage
19. ✅ Make profile checklist dynamic
20. ✅ Add skeleton loading states
21. ✅ Add success animations
22. ✅ Improve visual consistency

**Deliverables**:
- Bottom navigation added
- Dynamic checklist
- Loading states
- Polished UI

### Phase 5: Testing & Bug Fixes (Priority: HIGH)
**Timeline**: Week 5

23. ✅ Write unit tests for validators
24. ✅ Write widget tests for new pages
25. ✅ Integration tests for profile editing flow
26. ✅ Fix any bugs found
27. ✅ Performance testing

**Deliverables**:
- All tests passing
- No critical bugs
- Performance optimized

---

## 📊 SUCCESS METRICS

### Before Enhancement:
- ❌ Profile editing: Not functional (only preview)
- ❌ Settings pages: 3/5 missing (Preferences, Safety, Help)
- ❌ User flow: Circular navigation, dead ends
- ❌ Form validation: None
- ❌ Photo management: Confusing (redirects to onboarding)
- ❌ Interests: Hardcoded, not editable
- ❌ Bottom nav: Missing

### After Enhancement:
- ✅ Profile editing: Fully functional with validation
- ✅ Settings pages: 5/5 complete
- ✅ User flow: Clear, intuitive navigation
- ✅ Form validation: All fields validated
- ✅ Photo management: In-app picker, reorder, delete
- ✅ Interests: Selectable, categorized, max 10
- ✅ Bottom nav: Consistent across all pages
- ✅ Loading states: All async operations
- ✅ Success feedback: Snackbars, animations
- ✅ Unsaved changes: Detection and confirmation

---

## 🔐 SECURITY CONSIDERATIONS

### Profile Privacy
- ✅ Users can only edit their own profiles
- ✅ Blocked users can't see each other's profiles
- ✅ Privacy settings respected in queries
- ✅ Data export only for own account

### Data Validation
- ✅ Server-side validation in Cloud Functions
- ✅ Client-side validation for UX
- ✅ Sanitize user input (bio, name)
- ✅ Image upload size limits

### Account Deletion
- ✅ Confirmation dialog with password
- ✅ 30-day grace period
- ✅ Data cleanup: messages, matches, photos
- ✅ GDPR compliance

---

## 💰 COST IMPACT

### Firestore Reads/Writes
- **Profile updates**: +1 write per save
- **Preferences updates**: +1 write per save
- **Photo uploads**: +1 write + storage cost per photo
- **Block operations**: +2 writes (blocker + blocked)

**Estimated Monthly Cost** (1000 users):
- Profile edits: ~2 edits/user/month = 2000 writes = ₹0.37
- Photo uploads: ~1 upload/user/month = 1000 writes + storage = ₹2-3
- Preferences: ~1 update/user/month = 1000 writes = ₹0.18
**Total**: ~₹3-4/month for 1000 users (negligible)

### Storage
- Photos: 10MB avg × 6 photos × 1000 users = 60GB
- Storage cost: ₹1.80/GB × 60 = ₹108/month
- **Optimization**: Compress to 2MB avg = 12GB = ₹21.60/month

---

## ✅ IMPLEMENTATION CHECKLIST

### Backend
- [ ] Add profile update methods to repository
- [ ] Add preferences update methods
- [ ] Add privacy settings methods
- [ ] Add block/unblock methods
- [ ] Add photo upload methods
- [ ] Update Firestore security rules
- [ ] Add server-side validation

### Frontend
- [ ] Create EditProfilePage
- [ ] Create PreferencesPage
- [ ] Create SafetyPrivacyPage
- [ ] Create HelpSupportPage
- [ ] Create InterestSelectorWidget
- [ ] Add form validation
- [ ] Add unsaved changes detection
- [ ] Add loading states
- [ ] Add bottom navigation
- [ ] Fix ProfilePreviewPage
- [ ] Make profile checklist dynamic

### Testing
- [ ] Unit tests for validators
- [ ] Widget tests for new pages
- [ ] Integration tests for flows
- [ ] Manual QA testing

### Documentation
- [ ] Update README with new features
- [ ] Add inline code comments
- [ ] Update user guide

---

## 🎯 READY TO IMPLEMENT

This comprehensive plan addresses all identified issues in the Profile & Settings flow. Implementation will proceed in 5 phases over 5 weeks, prioritizing core functionality first (profile editing, new pages) followed by advanced features and UI polish.

**Next Step**: Begin Phase 1 - Create EditProfilePage with form validation.
