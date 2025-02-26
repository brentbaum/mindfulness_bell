# Mindfulness Bell

A beautiful, minimalist mindfulness bell app for macOS that helps you stay present throughout your day with gentle reminders.

![Mindfulness Bell App](screenshots/app_screenshot.png)

## Features

- **Customizable Intervals**: Set specific intervals or use random timings between 5-30 minutes
- **Visual Reminders**: Gentle full-screen flash with smooth fade in/out animation
- **Meeting Mode**: Visual-only notifications for when you're in meetings
- **System Integration**: Works even when the app isn't in focus

## Installation

### Option 1: Download the pre-built app

1. Download the latest release from the [Releases](https://github.com/brentbaum/mindfulness_bell/releases) page
2. Unzip the file
3. Right-click (or Control+click) on `mindfulness_bell.app` and select "Open"
4. Click "Open" in the security dialog that appears

### Option 2: Build from source

```bash
# Clone the repository
git clone https://github.com/brentbaum/mindfulness_bell.git
cd mindfulness_bell

# Install dependencies and run
flutter pub get
flutter run -d macos
```

## Permissions

To enable the full-screen flash feature, you'll need to grant accessibility permissions:

1. Click the "Enable Full Screen Flash" button in the app
2. Follow the prompts to open System Preferences
3. In Security & Privacy > Privacy > Accessibility, add and enable mindfulness_bell.app

## How It Works

The app uses Flutter for the UI and native macOS integration to create system-wide visual notifications. The flash animation fades in over 1 second and fades out over 5 seconds for a gentle, non-disruptive reminder.

## Development

This project is built with Flutter and uses the following packages:
- `audioplayers` for sound
- `url_launcher` for opening system preferences
- Custom native channel integration for macOS accessibility features

## License

MIT License
