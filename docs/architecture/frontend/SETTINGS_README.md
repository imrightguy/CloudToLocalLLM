# Settings Screens

This directory contains the settings-related screens for CloudToLocalLLM.

## Structure

- `connection_status_screen.dart` - Displays connection status to local LLM providers
- `daemon_settings_screen.dart` - Settings for the daemon/backend service
- `llm_provider_settings_screen.dart` - Configuration for local LLM providers

## New Settings Architecture

The unified settings screen is being implemented with the following components:

### Core Components

- **UnifiedSettingsScreen** - Main container that orchestrates the settings experience
- **SettingsSearchBar** - Real-time search across all settings
- **SettingsCategoryList** - Navigation between settings categories
- **SettingsContentPanel** - Displays content for the active category

### Settings Categories

- **General** - Theme, language, and general preferences
- **Local LLM Providers** - Configure local AI model providers
- **Account** - Account information and subscription
- **Privacy** - Privacy and data collection settings
- **Desktop** - Desktop application settings (Windows/Linux only)
- **Mobile** - Mobile application settings (iOS/Android only)
- **Premium Features** - Premium features and upgrades (Premium users only)
- **Admin Center** - Administration and user management (Admin users only)

### Models

- `SettingsUIState` - Manages the state of the settings UI
- `SettingsCategory` - Defines the structure for settings categories
- `SettingsCategoryIds` - Predefined category IDs
- `CategoryVisibilityRules` - Rules for category visibility based on platform and user role
- `SettingsCategoryMetadata` - Metadata for sorting and organizing categories

### Widgets

- `SettingsSectionWidget` - Base widget for a settings section
- `SettingsItemWidget` - Base widget for a single settings item
- `SettingsGroup` - Settings group container with dividers
- `SettingsForm` - Settings form container with save/cancel buttons
- `SettingsCategoryContentWidget` - Base widget for category content
- `SettingsCategoryListItem` - Category list item widget
- `SettingsSearchResultItem` - Search result item widget
- `SettingsValidationError` - Validation error display
- `SettingsSuccessMessage` - Success message display
- `SettingsTextInput` - Text input widget
- `SettingsToggle` - Toggle/switch widget
- `SettingsDropdown` - Dropdown widget
- `SettingsButton` - Button widget
- `SettingsSlider` - Slider widget

## Implementation Plan

See `.kiro/specs/platform-settings-screen/tasks.md` for the detailed implementation plan.
