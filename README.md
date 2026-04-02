<p align="center">
  <img src="assets/images/app_icon.png" alt="Roomix Logo" width="120" height="120" style="border-radius: 24px;" />
</p>

<h1 align="center">Roomix</h1>

<p align="center">
  <strong>Find PGs, Mess & Roommates Near Your Campus</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.8+-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.8+-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Firebase-Backend-FFCA28?logo=firebase&logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/Provider-State_Mgmt-6C63FF" alt="Provider" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
</p>

<p align="center">
  A multi-module campus community app that helps students discover PG accommodations, mess/dining services, find compatible roommates, trade in the marketplace, and connect with campus utilities — all in one place.
</p>

---

## ✨ Features

### 🏠 Housing & PG Discovery
- Browse, search, and filter PG/room listings by price, location, amenities
- Detailed property views with image gallery, contact options, and directions
- Owner dashboard for creating, editing, and managing listings

### 🍽️ Mess & Dining
- Discover mess services with menu details, pricing, food type, and timings
- Filter by vegetarian/non-vegetarian, price range, and location
- Direct contact via phone call or Telegram

### 🤝 Roommate Matching
- Create a detailed roommate profile (interests, lifestyle, budget, preferences)
- AI-powered compatibility scoring with weighted multi-factor algorithm
  - Interests (30%) · Location (25%) · Lifestyle (20%) · College (15%) · Year (10%)
- In-app chat for matched roommates

### 🛒 Student Marketplace
- Post and browse buy/sell items within your campus community
- Category, condition, and price filters
- Mark items as sold

### 📦 Lost & Found
- Report and browse lost/found items
- Filter by type, search by keyword
- Claim and resolve reported items

### 🗺️ Interactive Campus Map
- MapMyIndia-powered campus map with categorized markers
- Nearby utility directory (ATMs, medical stores, cafes, etc.)
- Get directions to any location

### 💬 Messaging & Bookmarks
- Real-time chat backed by Firestore streams
- Save and organize bookmarked listings

### 🔐 Authentication
- Email/password login and registration
- Google Sign-In integration
- Admin OTP-based authentication
- University-based onboarding flow

---

## 🏗️ Architecture

```
lib/
├── constants/          # Theme colors and static UI constants
├── models/             # Dart data models (Firestore-backed)
├── providers/          # ChangeNotifier state management modules
├── screens/            # UI screens organized by feature module
│   ├── admin/          #   Admin dashboard and moderation
│   ├── auth/           #   Login, signup, role gate, password reset
│   ├── bookmarks/      #   Saved items
│   ├── events/         #   Campus events
│   ├── home/           #   Home dashboard
│   ├── lost_found/     #   Lost & found board
│   ├── map/            #   Interactive campus map
│   ├── market/         #   Student marketplace
│   ├── mess/           #   Mess and dining listings
│   ├── messages/       #   Chat and conversations
│   ├── notifications/  #   Notification center
│   ├── onboarding/     #   University selection and student profile
│   ├── owner/          #   Owner listing management
│   ├── profile/        #   User profile and account settings
│   ├── roommate_finder/#   Roommate matching and chat
│   ├── rooms/          #   PG/room listings
│   ├── settings/       #   App and map settings
│   └── utilities/      #   Campus utility directory
├── services/           # Firebase, map, notification, auth services
├── utils/              # Navigation helpers and local storage
├── widgets/            # Reusable UI components
├── firebase_options.dart
└── main.dart
```

### Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter (Dart) |
| **State Management** | Provider (`ChangeNotifier`) |
| **Backend** | Firebase (Auth, Firestore, Storage, Messaging) |
| **Maps** | MapMyIndia Static Map API |
| **Platforms** | Android, iOS, Web, Windows, macOS |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `≥ 3.8.1`
- [Android Studio](https://developer.android.com/studio) with Android SDK (for mobile builds)
- [Xcode](https://developer.apple.com/xcode/) (for iOS/macOS builds)
- A configured [Firebase project](https://console.firebase.google.com/)
- A [MapMyIndia API key](https://www.mapmyindia.com/)

### 1. Clone & Install

```bash
git clone https://github.com/your-username/roomix.git
cd roomix
flutter pub get
```

### 2. Firebase Configuration

Ensure these Firebase config files are in place:

| Platform | File | Location |
|----------|------|----------|
| Android | `google-services.json` | `android/app/` |
| iOS | `GoogleService-Info.plist` | `ios/Runner/` |
| All | `firebase_options.dart` | `lib/` (already included) |

> To regenerate Firebase options: `flutterfire configure`

### 3. Environment Setup

```bash
# Copy the template
cp .env.example .env

# For Android, also set the MapMyIndia key:
# Edit android/local.properties and add:
# mapmyindia.api.key=your_actual_key
```

### 4. Run the App

```bash
# Debug mode (connected device or emulator)
flutter run

# With MapMyIndia key via CLI
flutter run --dart-define=MAPMYINDIA_API_KEY=your_key

# Chrome (web)
flutter run -d chrome --dart-define=MAPMYINDIA_API_KEY=your_key
```

### 5. Build Release APK

```bash
# Standard release APK
flutter build apk --release --dart-define=MAPMYINDIA_API_KEY=your_key

# Split by architecture (smaller APK size — recommended)
flutter build apk --split-per-abi --release --dart-define=MAPMYINDIA_API_KEY=your_key

# App Bundle (for Play Store)
flutter build appbundle --release --dart-define=MAPMYINDIA_API_KEY=your_key
```

> **💡 Tip:** Use `--split-per-abi` for significantly smaller APK files. Most modern phones use `arm64-v8a`.

---

## 🗄️ Database Schema (Firestore)

| Collection | Purpose | Key Fields |
|-----------|---------|------------|
| `users` | User profiles | `email`, `name`, `role`, `phone`, `university`, `fcmToken` |
| `rooms` | PG/room listings | `title`, `location`, `price`, `type`, `amenities[]`, `ownerid` |
| `mess` | Mess listings | `name`, `pricepermonth`, `foodtype`, `menu[]`, `timings` |
| `roommateprofiles` | Roommate profiles | `userid`, `bio`, `interests[]`, `preferences{}`, `gender` |
| `bookmarks` | Saved items | `userid`, `itemid`, `itemtype` |
| `chatmessages` | Chat messages | `senderid`, `receiverid`, `message`, `read`, `timestamp` |
| `universities` | University data | `name`, `location`, `campusBounds`, `city`, `state` |
| `marketItems` | Marketplace items | `title`, `price`, `condition`, `category`, `sellerId`, `sold` |
| `lostItems` | Lost/found reports | `title`, `status`, `location`, `contact`, `claimStatus` |
| `utilities` | Campus utilities | `name`, `category`, `address`, `contact`, `rating`, `verified` |
| `notifications` | Push notifications | `userId`, `title`, `message`, `type`, `read` |

### Firebase Storage Paths

```
profile_pictures/    → User avatars
room_images/         → PG/room listing photos
mess_images/         → Mess listing photos
roommate_images/     → Roommate profile images
utility_images/      → Utility directory images
```

---

## 👥 User Roles

| Role | Access |
|------|--------|
| **Student** | Browse listings, search, bookmarks, roommate matching, marketplace, lost & found |
| **Owner** | All student features + create and manage room/mess listings |
| **Admin** | Utility moderation, admin dashboards, platform management |

---

## 🔧 Key Services

| Service | File | Responsibility |
|---------|------|---------------|
| `FirebaseService` | `firebase_service.dart` | Firestore CRUD operations and streams |
| `FirebaseAuthService` | `firebase_auth_service.dart` | Auth (email, Google, admin OTP) |
| `FirebaseStorageService` | `firebase_storage_service.dart` | Image upload/download/delete |
| `MapService` | `map_service.dart` | Static maps, distance calculation |
| `NotificationService` | `notification_service.dart` | FCM push notifications |
| `LocationService` | `loaction_service.dart` | GPS and geocoding |
| `ApiService` | `api_service.dart` | Compatibility layer (legacy screens) |
| `TelegramService` | `telegram_service.dart` | Telegram deep linking |
| `OtpService` | `otp_service.dart` | Admin OTP generation/verification |

---

## 📱 APK Size Optimization

The release build is optimized with:

- ✅ **R8/ProGuard** code shrinking (`isMinifyEnabled = true`)
- ✅ **Resource shrinking** (`isShrinkResources = true`)
- ✅ **Custom ProGuard rules** for Firebase, Google Sign-In, and all dependencies
- ✅ **Multidex** enabled for Firebase compatibility
- ✅ **Split APK by architecture** support (`--split-per-abi`)

---

## 🛠️ Development Guide

### Recommended Workflow for New Features

1. **Model** → Create/update data model in `lib/models/`
2. **Service** → Add Firestore CRUD method in `lib/services/firebase_service.dart`
3. **Provider** → Add state management in `lib/providers/`
4. **Screen** → Build the UI in `lib/screens/<feature>/`

### Conventions

- Use `Provider` + `ChangeNotifier` for all state updates
- Route all Firestore operations through `FirebaseService`
- Keep Firestore field names backward-compatible
- Add null-safe parsing in models for mixed timestamp formats
- For map features, use `MapProvider` / `MapService`

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Changes not reflecting | `flutter clean && flutter pub get && flutter run` |
| Gradle errors | Delete `build/` and `android/.gradle/`, then clean rebuild |
| Firebase config issues | Run `flutterfire configure` to regenerate |
| Map not loading | Verify `MAPMYINDIA_API_KEY` is set in env or `local.properties` |

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
