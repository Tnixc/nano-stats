# nano-stats Features

## Menu Bar Only App

The app runs exclusively in the menu bar with no Dock icon. This provides a clean, unobtrusive experience focused on system monitoring.

### Configuration

The app is configured with `LSUIElement = YES` in the Info.plist, which:
- Hides the app from the Dock
- Prevents it from appearing in Cmd+Tab app switcher
- Keeps it visible only in the menu bar

## Launch at Login

Users can configure the app to automatically start when they log in to macOS.

### How to Enable

1. Click the menu bar icon to open the stats panel
2. Click the gear (⚙️) icon at the bottom
3. Toggle "Launch at Login" to ON

### Technical Implementation

- Uses macOS 13+ `ServiceManagement` framework with `SMAppService`
- Registers the app as a login item through the system
- Users can also manage this through System Settings > General > Login Items

### Requirements

- macOS 13.0 (Ventura) or later for launch at login functionality
- On older versions, the toggle will appear but won't function

## Menu Bar Features

- **CPU Graph**: Real-time CPU usage visualization with percentage
- **System Stats**: Detailed CPU, Memory, and Battery information
- **Quick Actions**: 
  - Refresh stats manually
  - Settings (launch at login)
  - Quit application
- **No Focus Ring**: Tab key navigation disabled for clean appearance

## Privacy & Permissions

The app requires no special permissions beyond reading system statistics. All data is local and never transmitted.