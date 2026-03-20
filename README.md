# Bunny 

A comprehensive Flutter application for managing club reservations with both mobile and web admin interfaces. Built with Firebase backend integration and modern Flutter architecture.

**Version:** 1.0.0+1

_This README was updated to include the current app version from `pubspec.yaml`._

## 🚀 Features

- **Mobile App**: User-friendly interface for making and managing reservations
- **Web Admin Panel**: Comprehensive admin interface for managing reservations, users, and settings
- **Firebase Integration**: Real-time data synchronization with Firestore
- **Authentication**: Secure user authentication with Firebase Auth
- **Cross-Platform**: Supports iOS, Android, and Web platforms
- **Modern UI**: Beautiful, responsive design with Material 3

## 📱 Screenshots

*Add screenshots of your app here*

## 🛠️ Tech Stack

- **Frontend**: Flutter 3.5+
- **Backend**: Firebase (Firestore, Auth, Storage, Analytics)
- **State Management**: Provider
- **Routing**: GoRouter
- **UI Framework**: Material 3
- **Fonts**: Google Fonts (Poppins)
- **Code Generation**: Freezed, JSON Serializable

## 📋 Prerequisites

- Flutter SDK (3.5.0 or higher)
- Dart SDK (3.5.0 or higher)
- Firebase CLI
- Android Studio / Xcode (for mobile development)
- Git

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/club_reservation.git
cd club_reservation
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication, Firestore, Storage, and Analytics
3. Download the configuration files:
   - `google-services.json` for Android (place in `android/app/`)
   - `GoogleService-Info.plist` for iOS (place in `ios/Runner/`)
4. Update `lib/firebase_options.dart` with your Firebase configuration

### 4. Run the App

#### Mobile App
```bash
# For Android
flutter run

# For iOS
flutter run -d ios

# For specific device
flutter devices
flutter run -d <device-id>
```

#### Web Admin Panel
```bash
# Build and run web admin
flutter build web --target lib/web_admin_main.dart --web-renderer canvaskit
cd web_admin
python -m http.server 8000
```

Or use the provided scripts:
```bash
# Build web admin
./build_web_admin.sh

# Run web admin
./run_web_admin.sh
```

## 📁 Project Structure

```
lib/
├── admin/                 # Admin-specific screens and widgets
├── config/               # App configuration files
├── models/               # Data models and entities
├── providers/            # State management providers
├── router/               # App routing configuration
├── screens/              # Main app screens
├── services/             # Business logic and API services
├── theme/                # App theming and styling
├── utils/                # Utility functions and helpers
├── web_admin/            # Web admin specific code
└── widgets/              # Reusable UI components
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_API_KEY=your-api-key
```

### Firebase Rules

Update your Firestore security rules based on your requirements:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Add your security rules here
  }
}
```

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run tests with coverage
flutter test --coverage
```

## 📦 Building for Production

### Android
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## 🚀 Deployment

### Firebase Hosting (Web Admin)
```bash
firebase deploy --only hosting
```

### Google Play Store
1. Build the app bundle: `flutter build appbundle --release`
2. Upload to Google Play Console

### Apple App Store
1. Build for iOS: `flutter build ios --release`
2. Archive and upload via Xcode

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/yourusername/club_reservation/issues) page
2. Create a new issue with detailed information
3. Contact the maintainers

## 🗺️ Roadmap

- [ ] Push notifications
- [ ] Offline support
- [ ] Advanced analytics
- [ ] Multi-language support
- [ ] Dark mode
- [ ] Advanced reporting features

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase team for the backend services
- All contributors who help improve this project

---

Made with ❤️ using Flutter
