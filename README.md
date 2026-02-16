# Roomix

Roomix is a Flutter app for campus housing and student community workflows: PG/room discovery, mess listings, roommate matching, buy/sell marketplace, lost and found, utilities, map views, bookmarks, and messaging.

This README is the technical handoff for new developers joining the project.

## 1) Project Snapshot

- App type: Multi-module campus community app
- Frontend: Flutter (Dart)
- State management: Provider
- Backend: Firebase (Auth, Firestore, Storage, Messaging)
- Maps: MapMyIndia static map integration with runtime API key fallback
- Platforms configured: Android, iOS, Web, Windows, macOS
- Package id (Android): `com.company.roomix`

## 2) Tech Stack

### Core
- Flutter SDK: `>=3.8.1`
- Dart SDK: `^3.8.1`
- Provider: `^6.1.2`

### Firebase
- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`
- `firebase_messaging`
- `flutter_local_notifications`
- `google_sign_in`

### UI + utilities
- `cached_network_image`
- `image_picker`
- `intl`
- `url_launcher`
- `webview_flutter`
- `geolocator`
- `geocoding`
- `flutter_secure_storage`
- `shared_preferences`

## 3) Feature Modules

- Auth and onboarding
  - Email/password login and registration
  - Google Sign-In
  - Admin OTP-style flow via local `OtpService`
  - University selection + onboarding profile capture

- Housing and mess
  - Room/PG listing browse and filters
  - Mess listing browse and filters
  - Owner listing creation/edit/delete (room and mess)

- Roommate matching
  - Roommate profile create/update
  - Basic compatibility scoring based on shared interests
  - In-app chat backed by Firestore `chatmessages`

- Marketplace
  - Create and browse student buy/sell items
  - Search/category/condition/price filters
  - Mark item as sold

- Lost and found
  - Report lost/found item
  - Filter by type and search
  - Resolve/delete reported items

- Utilities and map
  - Nearby utility directory
  - Utility moderation flow for admins
  - Campus map with markers and category filters
  - Runtime map key settings screen

- Messaging and bookmarks
  - Saved items via bookmark collection
  - Conversation UI backed by Firestore streams

## 4) Directory Map

```text
roomix/
|-- lib/
|   |-- constants/      # Theme colors and static UI constants
|   |-- models/         # Data models (Firestore and compatibility JSON)
|   |-- providers/      # ChangeNotifier state modules
|   |-- screens/        # UI screens grouped by feature
|   |-- services/       # Firebase, map, notification, auth, API compatibility
|   |-- utils/          # Storage + navigation helpers
|   |-- widgets/        # Reusable UI widgets
|   |-- firebase_options.dart
|   `-- main.dart
|-- android/
|-- ios/
|-- web/
|-- windows/
|-- macos/
|-- linux/
|-- assets/
|-- stitch_new_app_desing/  # Design references
|-- fr_db/                  # DB screenshot references
|-- pubspec.yaml
`-- README.md
```

### `lib/screens` submodules
- `admin`, `auth`, `bookmarks`, `events`, `home`, `lost_found`, `map`, `market`, `mess`, `messages`, `onboarding`, `owner`, `profile`, `roommate_finder`, `rooms`, `settings`, `utilities`

## 5) Key Services and Functions

### `lib/services/firebase_service.dart`
Primary Firestore service with CRUD and streams.

Important methods:
- Universities: `getUniversities`, `createUniversity`, `getUniversityById`
- Users: `createUser`, `getUser`, `updateUser`
- Rooms: `getRooms`, `getRoomsByUniversity`, `getRoomsByOwner`, `createRoom`, `updateRoom`, `deleteRoom`
- Mess: `getMessListings`, `getMessByOwner`, `createMess`, `updateMess`, `deleteMess`
- Roommates: `getRoommateProfiles`, `getRoommateProfileByUserId`, `createRoommateProfile`, `updateRoommateProfile`, `deleteRoommateProfile`
- Bookmarks: `getBookmarks`, `addBookmark`, `removeBookmark`, `removeBookmarkByItemId`, `isBookmarked`
- Chat: `getChatMessages`, `getConversations`, `sendMessage`, `markConversationAsRead`, `getUnreadCount`
- Marketplace: `getMarketItems`, `createMarketItem`, `updateMarketItem`, `deleteMarketItem`
- Lost/Found: `getLostItems`, `createLostItem`, `updateLostItem`, `deleteLostItem`
- Utilities: `getUtilities`, `createUtility`, `updateUtility`, `deleteUtility`
- Notifications: `getNotifications`, `createNotification`, `markNotificationAsRead`, `getUnreadNotificationCount`

### `lib/services/firebase_auth_service.dart`
Auth wrapper over Firebase Auth + Google Sign-In.

Important methods:
- `signInWithEmail`
- `registerWithEmail`
- `sendPasswordResetEmail`
- `signInWithGoogle`
- `requestAdminOtp`, `verifyAdminOtpAndLogin`, `adminLoginWithPassword`
- `signInAnonymously`
- `signOut`, `updatePassword`, `reauthenticate`, `deleteAccount`

### `lib/services/api_service.dart`
Compatibility layer used by older screens. Most calls are currently mapped to Firestore reads/writes.

### `lib/services/map_service.dart`
- Loads API key from `lib/maps_keys/*.conf` or runtime setting
- `generateStaticMapUrl`, `generatePreviewUrl`
- `calculateDistanceKm`, `clusterMarkers`

### `lib/providers/*`
Core state modules:
- `AuthProvider`
- `OwnerListingsProvider`
- `RoommateProvider`
- `BookmarksProvider`
- `MarketProvider`
- `LostFoundProvider`
- `UtilityProvider`
- `MapProvider`
- `NotificationProvider`
- `UserPreferencesProvider`

## 6) Database (Firestore) - Collections and Fields

Roomix uses Cloud Firestore (NoSQL). Treat each collection below as a logical table.

## Canonical collections used by `FirebaseService`

| Collection | Core fields used in code |
|---|---|
| `users` | `email`, `name`, `role`, `phone`, `university`, `createdat`, optional `fcmToken`, `lastTokenUpdate`, profile fields from onboarding |
| `rooms` | `title`, `location`, `price`, `type`, `imageurl`, `contact`, `amenities[]`, `university`, `ownerid`, `ceratedat` |
| `mess` | `name`, `location`, `pricepermonth`, `foodtype`, `contact`, `menu[]`, `imageurl`, `timings`, `university`, `ownerid`, `createdat` |
| `roommateprofiles` | `userid`, `username`, `bio`, `college`, `courseYear`, `gender`, `interests[]`, `preferences{}`, `createdat` |
| `bookmarks` | `userid`, `itemid`, `itemtype`, `ceratedat` |
| `chatmessages` | `senderid`, `receiverid`, `message`, `read`, `timestamp` |
| `universities` | free-form seed data + `createdAt`; model expects `name`, `location`, `campusBounds`, `address`, `city`, `state`, `isActive`, `createdAt`, `updatedAt` |
| `marketItems` | `title`, `description`, `price`, `condition`, `category`, `image`, `sellerId`, `sellerName`, `sellerContact`, `sold`, `createdAt`, `updatedAt` |
| `lostItems` | `title`, `description`, `status`, `date`, `location`, `contact`, `image`, `userId`, `claimStatus`, `createdAt`, `updatedAt` |
| `utilities` | `name`, `category`, `address`, `contact{phone}`, `description`, `image`, `location{coordinates,address}`, `verified`, `rating`, `reviews[]`, `isActive`, `createdAt`, `updatedAt` |
| `notifications` | `userId`, `title`, `message`, `type`, `relatedId`, `read`, `createdAt` |

## Additional collections referenced by compatibility screens

| Collection | Notes |
|---|---|
| `events` | Queried by `ApiService.getEvents`; current code sorts by `date` while `EventModel` expects `eventDate` |
| `utilities/{id}/reviews` | Written by `ApiService.addReviewToUtility` as a subcollection |

## Important naming note
- Some field names are intentionally misspelled in current production code and must be preserved unless migrated:
  - `ceratedat` (rooms, bookmarks)
  - `createdat` vs `createdAt` is mixed across modules

## 7) Firebase Storage Paths

Used by `FirebaseStorageService`:
- `profile_pictures/`
- `room_images/`
- `mess_images/`
- `roommate_images/`
- `utility_images/`

## 8) Local Storage Keys

From `StorageUtil`:
- `selected_university`
- `onboarding_complete`
- `campus_latitude`, `campus_longitude`, `campus_address`
- `student_course`, `student_year`, `student_college`, `student_contact`
- `user_token`, `user_info`

## 9) Setup and Run

### Prerequisites
- Flutter SDK 3.8+
- Dart SDK matching Flutter
- Firebase project configured
- Android Studio / Xcode (for mobile)

### Install
```bash
flutter pub get
```

### Firebase files expected
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`
- FlutterFire options: `lib/firebase_options.dart`

### Environment variables
From `.env.example` and build scripts:
- `MAPMYINDIA_API_KEY`
- `FLUTTER_BACKEND_URL`
- `FIREBASE_API_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_APP_ID`

### Android map key injection
`android/app/build.gradle.kts` injects `MAPMYINDIA_API_KEY` into manifest placeholders and release build checks.

### Run commands
```bash
flutter run
flutter run --dart-define=MAPMYINDIA_API_KEY=your_key
flutter build apk --release --dart-define=MAPMYINDIA_API_KEY=your_key
flutter build appbundle --release --dart-define=MAPMYINDIA_API_KEY=your_key
flutter build web --release --dart-define=MAPMYINDIA_API_KEY=your_key
```

## 10) Roles and Access Scope

- `student`
  - browse listings, search, bookmarks, roommate, market, lost/found
- `owner`
  - all student actions + create/manage room/mess listings
- `admin`
  - utility moderation and admin dashboards (some areas are partially legacy)

Admin email hardcoded in auth/OTP services:
- `rajatsinghrawat182@gmail.com`

## 11) Known Gaps / Technical Debt (Important Before Development)

- The codebase is mixed between:
  - direct Firebase services (`FirebaseService`)
  - older compatibility flows (`ApiService`)

- Data contract mismatches exist in some screens (example: expected response keys like `events`/`mess` vs service returning `data`).

- Field naming is inconsistent (`createdat`, `createdAt`, `ceratedat`).

- Some legacy screens reference methods/packages not aligned with current dependencies (for example, old admin/API paths and Cloudinary usage).

- iOS `Info.plist` contains `TomTomOnlineKey` while map implementation is MapMyIndia.

If you add new features, prefer `FirebaseService` + provider pattern and avoid expanding legacy REST-style compatibility code.

## 12) Recommended Development Conventions

- Use Provider modules for state updates.
- Add Firestore writes through `FirebaseService` first.
- Keep Firestore field names backward-compatible unless you run a migration.
- Add null-safe parsing in models for mixed timestamp formats.
- For new map features, route through `MapProvider`/`MapService`.

## 13) Quick Start for New Contributors

1. Run `flutter pub get`.
2. Verify Firebase config files are present.
3. Set `MAPMYINDIA_API_KEY` and run app.
4. Check authentication and university onboarding flow.
5. Validate Firestore has core collections listed above.
6. Build any new feature in this order:
   - model
   - service method
   - provider state method
   - screen UI wiring

## 14) License

MIT License (`LICENSE`).
