# ImmoGestion

Leasing automation engine for Quebec landlords. Flutter mobile app.

## 🏗️ Architecture

- **Flutter app** (`lib/`) - Mobile-first property management UI
- **API service layer** (`lib/services/`) - Dart-based service classes consuming REST APIs
- **Legacy Node.js backend** (`services/api-backend/`) - Archived Express.js API server (superseded)

## 🚀 Quick Start

### Flutter Development

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

### Node.js Backend

```bash
cd services/api-backend

# Install dependencies
npm install

# Start development server
npm run dev

# Run tests
npm test
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
api-backend/
├── lib/                      # Flutter app
│   ├── screens/             # App screens (dashboard, pipeline, buildings, visits, etc.)
│   ├── services/            # Dart service classes (API, auth, leads, buildings, etc.)
│   ├── models.dart          # Data models
│   └── main.dart            # Entry point
├── services/api-backend/     # Archived Node.js backend (superseded by Dart services)
├── assets/                   # Static assets
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
- Basic navigation and layouts
- Responsive design for mobile/tablet

### 🚧 In Progress
- Real API integration (replace mock data)
- Authentication flow
- SMS integration

### 📋 Next Steps
- Mobile app builds (Android/iOS)
- Production deployment
- Analytics dashboard

## 📧 Contact

- **Email**: simon@immogestion.ca
- **Demo**: Available for Quebec landlords
- **Focus**: Streamlined leasing automation for local market