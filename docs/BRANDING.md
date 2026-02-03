# Branding Guide - CloudToLocalLLM (Zoidbot Edition)

## Overview

CloudToLocalLLM is now branded with the Zoidbot theme — a lobster-inspired design that reflects privacy, security, and local AI power.

## Brand Assets

### Logo

- **Primary Logo:** Lobster avatar (🦞)
- **Assets:**
  - `assets/images/lobster_avatar.png` - Standard size
  - `assets/images/lobster_avatar_64.png` - Small icons
  - `assets/images/lobster_avatar_128.png` - Large displays

### Colors

The Zoidbot theme uses a warm color palette:

- **Primary:** Red-orange (#D32F2F) — Passion and energy
- **Secondary:** Deep orange (#FF6F00) — Warmth and approachability
- **Background:** Dark (#181a20) — Privacy and security
- **Success:** Green (#4caf50) — Healthy systems
- **Warning:** Orange (#ffa726) — Attention needed
- **Error:** Red (#ff5252) — Critical issues

### Typography

- **Font:** System default (clean, modern)
- **Style:** Clean, readable, privacy-focused
- **Headings:** Bold, prominent
- **Body:** Regular, comfortable for long reading sessions

## Theme System

### Flutter Theme Configuration

Located in `lib/config/theme.dart`:

```dart
// Primary colors (lobster-themed)
static const Color primaryColor = Color(0xFFD32F2F);   // Red
static const Color secondaryColor = Color(0xFFFF6F00); // Orange
static const Color backgroundMain = Color(0xFF181a20); // Dark background
```

### Custom Components

#### AppLogo

The `AppLogo` widget uses lobster imagery instead of text:

```dart
AppLogo.large()    // 70px for headers
AppLogo.medium()   // 48px for navigation
AppLogo.small()    // 32px for compact spaces
AppLogo.favicon()  // 16px for favicons
```

#### Gradient AppLogo

For prominent displays with gradient background:

```dart
GradientAppLogo(size: 70.0)
```

## Integration Points

### Agent Status Dashboard

Real-time monitoring of OpenClaw agent sessions:

**Service:** `lib/services/agent_status_service.dart`
- Polls `http://localhost:3000/status.json` every 2 seconds
- Streams agent status updates
- Provides cached synchronous access

**Widget:** `lib/components/agent_status_widget.dart`
- Displays agent status cards
- Shows activity, last update, status emoji
- Empty state with lobster branding

**Usage:**

```dart
final service = AgentStatusService();
service.startPolling();

// In widget tree:
AgentStatusWidget(
  service: service,
  showDetails: true,
  width: 400,
  height: 300,
)
```

## Design Principles

1. **Privacy First** — Dark colors, secure feel, data stays local
2. **Approachable** — Warm lobster theme, friendly, not corporate
3. **Real-Time** — Live status updates, responsive feedback
4. **Transparent** — Clear indicators, open about what's happening

## Icon Guidelines

When creating new icons or graphics:

- Use lobster imagery where appropriate
- Maintain the red/orange color scheme
- Keep designs clean and modern
- Ensure accessibility (contrast ratios)
- Consider both light and dark themes

## Splash Screen

The splash screen uses:

- **Background:** Dark (#181a20)
- **Logo:** Lobster avatar (lobster_avatar.png)
- **Text:** White, clean sans-serif

## Documentation Updates

When updating documentation:

1. Update README.md with new branding
2. Add screenshots with lobster theme
3. Update any screenshots in docs/user-guide/
4. Keep tech stack descriptions accurate
5. Add Zoidbot to acknowledgments if appropriate

## Future Enhancements

Planned branding improvements:

- [ ] Animated lobster logo (waving claws)
- [ ] Themed loading animations
- [ ] Custom error screens with lobster branding
- [ ] System tray icons with lobster variants
- [ ] App icon generation for all platforms

## Contributing

When contributing:

1. Use lobster colors in new UI components
2. Test in both dark and light themes
3. Ensure accessibility standards
4. Update screenshots if UI changes
5. Document new branding components

---

**Zoidbot 🦞** — Privacy-first local AI, with claws.
