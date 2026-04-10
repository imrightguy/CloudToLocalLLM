# ImmoGestion

Leasing automation engine for Quebec landlords. Flutter mobile app with Node.js backend.

## 🏗️ Architecture

**Similar to CloudToLocalLLM:**
- **Flutter frontend** (root directory) - Mobile-first property management UI
- **Node.js backend** - REST API for data management and automation
- **PostgreSQL + Drizzle ORM** - Database layer

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
ImmoGestion/
├── lib/                      # Flutter frontend
│   ├── screens/             # Main app screens
│   ├── models.dart          # Data models
│   ├── data/                # Mock data
│   └── main.dart
├── services/                 # Node.js backend services
│   └── api-backend/          # Express.js API server
├── database/                 # PostgreSQL + Drizzle
├── config/                  # Docker, deployment
└── pubspec.yaml
```

## 🎯 Target Market

- **Quebec landlords** with multi-property portfolios
- **Property managers** needing automation tools
- **Real estate investors** requiring analytics
- **Small agencies** managing 5-50 properties

## 🔄 Development Status

### ✅ Completed
- Flutter app UI with Quebec localization
- Mock data for demo purposes
- Basic navigation and layouts
- Responsive design for mobile/tablet

### 🚧 In Progress
- Node.js backend API development
- PostgreSQL database setup
- Authentication system
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