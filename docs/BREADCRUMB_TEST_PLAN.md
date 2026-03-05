# Breadcrumb Navigation Test Plan

**Purpose**: Verify breadcrumb navigation works correctly across all settings screens.

## Test Instructions

1. **Navigate to Settings**
   - Click on Settings in the sidebar
   - **Expected**: Breadcrumb shows "Home ▸ Settings"
   - **Expected**: "Settings" is highlighted (current page)

2. **Navigate to General Settings**
   - From Settings, the app automatically redirects to General Settings
   - **Expected**: Breadcrumb shows "Home ▸ Settings ▸ General"
   - **Expected**: "General" is highlighted
   - **Test**: Click "Settings" breadcrumb
   - **Expected**: Navigates to /settings (shows category list or redirects to general)

3. **Navigate to Appearance Settings**
   - Click Settings → Appearance
   - **Expected**: Breadcrumb shows "Home ▸ Settings ▸ Appearance"
   - **Test**: Click "Home" breadcrumb
   - **Expected**: Navigates to home screen

4. **Navigate to Connection Settings → Daemon Settings**
   - Click Settings → Connection
   - **Expected**: Breadcrumb shows "Home ▸ Settings ▸ Connection"
   - Click "Daemon Settings" card
   - **Expected**: Breadcrumb shows "Home ▸ Settings ▸ Connection ▸ Daemon Settings"
   - **Test**: Click "Connection" breadcrumb
   - **Expected**: Returns to Connection Settings screen

5. **Navigate to Avatar Settings → Customization**
   - Click Settings → Avatar
   - **Expected**: Breadcrumb shows "Home ▸ Settings ▸ Avatar"
   - Click "Avatar Customization" card
   - **Expected**: Breadcrumb shows "Home ▸ Settings ▸ Avatar ▸ Customization"
   - **Test**: Click "Settings" breadcrumb
   - **Expected**: Returns to Settings category screen

6. **Navigate to Desktop Settings → File Operations**
   - Click Settings → Desktop
   - **Expected**: Breadcrumb shows "Home ▸ Settings ▸ Desktop"
   - Click "File Operations" card
   - **Expected**: Breadcrumb shows "Home ▸ Settings ▸ Desktop ▸ File Operations"
   - **Test**: Click "Desktop" breadcrumb
   - **Expected**: Returns to Desktop Settings screen

7. **Navigate to About Settings → Upgrade**
   - Click Settings → About
   - **Expected**: Breadcrumb shows "Home ▸ Settings ▸ About"
   - Click "Upgrade to Pro" card
   - **Expected**: Breadcrumb shows "Home ▸ Settings ▸ About ▸ Upgrade"
   - **Test**: Click "About" breadcrumb
   - **Expected**: Returns to About Settings screen

## Visual Verification

For each breadcrumb level, verify:
- ✅ Folder icon appears on all but last item
- ✅ Open folder icon on current page (last item)
- ✅ Chevron separators (▸) between items
- ✅ Current page highlighted with primary color
- ✅ Hover effect on clickable breadcrumbs
- ✅ Correct indentation/spacing

## Known Routes with Breadcrumbs

| Route | Expected Breadcrumb |
|-------|-------------------|
| `/` | Home |
| `/settings` | Home ▸ Settings |
| `/settings/general` | Home ▸ Settings ▸ General |
| `/settings/appearance` | Home ▸ Settings ▸ Appearance |
| `/settings/connection` | Home ▸ Settings ▸ Connection |
| `/settings/avatar` | Home ▸ Settings ▸ Avatar |
| `/settings/desktop` | Home ▸ Settings ▸ Desktop |
| `/settings/about` | Home ▸ Settings ▸ About |
| `/settings/daemon` | Home ▸ Settings ▸ Connection ▸ Daemon Settings |
| `/settings/connection-status` | Home ▸ Settings ▸ Connection ▸ Connection Status |
| `/settings/avatar/customization` | Home ▸ Settings ▸ Avatar ▸ Customization |
| `/settings/desktop/files` | Home ▸ Settings ▸ Desktop ▸ File Operations |
| `/upgrade` | Home ▸ Settings ▸ About ▸ Upgrade |

## Success Criteria

- All breadcrumbs display correctly
- All breadcrumb links navigate to correct routes
- Visual styling is consistent across all screens
- No console errors related to breadcrumbs
- Back button still works independently of breadcrumbs
