# ImmoGestion

Leasing automation engine for Quebec landlords. Flutter mobile app.

## 🏗️ Architecture

- **Flutter app** (`lib/`) - Mobile-first property management UI
- **Dart service layer** (`lib/services/`) - Service classes consuming REST APIs
- **Mock data** (`lib/data/`) - Demo data for development

## 🚀 Quick Start

```bash
# Install dependencies
flutter pub get

# Run on mobile device
flutter run -d android
flutter run -d ios

# Run on web
flutter run -d chrome

# Build for production
flutter build apk --release
flutter build ios --release
```

## 📱 Features

### Core Modules
- **Dashboard** - Revenue tracking, occupancy rates, performance metrics
- **Pipeline** - Lead management through leasing stages
- **Visits** - Schedule and manage property viewings
- **Buildings** - Multi-property portfolio management
- **Calendar** - Visit scheduling and reminders
- **Documents** - Lease management and storage

### Automation Features
- **SMS/Email** - Automated communication with prospects
- **Facebook Messenger** - Chat-based lead generation
- **Analytics** - Real-time performance tracking
- **Notifications** - Automated alerts and reminders

## 📁 Project Structure

```
ImmoGestion/
├── lib/                      # Flutter app
│   ├── screens/             # App screens (dashboard, pipeline, buildings, visits, etc.)
│   ├── services/            # Dart service classes (API, auth, leads, buildings, etc.)
│   ├── data/                # Mock data
│   ├── models.dart          # Data models
│   └── main.dart            # Entry point
├── assets/                   # Static assets
├── test/                     # Unit and integration tests
├── analysis_options.yaml     # Dart linter config
└── pubspec.yaml              # Dependencies
```

## 🎯 Target Market

- **Quebec landlords** with multi-property portfolios
- **Property managers** needing automation tools
- **Real estate investors** requiring analytics
- **Small agencies** managing 5-50 properties

## 🔄 Development Status

### ✅ Completed
- Flutter app UI with Quebec localization
- Dart service layer (API, auth, leads, buildings, visits, analytics)
- Mock data for demo purposes
- Basic navigation and layouts
- Responsive design for mobile/tablet

### 🚧 In Progress
- Real API integration (replace mock data)
- Authentication flow
- SMS integration

### 📋 Next Steps
- Real API integration (replace mock data)
- Mobile app builds (Android/iOS)
- Production deployment
- Analytics dashboard

## 📧 Contact

- **Email**: simon@immogestion.ca
- **Demo**: Available for Quebec landlords
- **Focus**: Streamlined leasing automation for local market