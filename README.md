# MiniHabitTracker

A native iOS habit-tracking app built with SwiftUI. MiniHabitTracker helps users create routines, record daily progress, and review consistency over time. The project also includes a WidgetKit extension for at-a-glance progress on the Home Screen.

## Highlights

- Create, edit, reorder, archive, and search habits
- Track daily, weekly, and monthly habits with optional target goals
- View streaks, weekly progress, statistics, and achievements
- Set per-habit reminders and choose from light, dark, or system appearance
- Use Home Screen widgets to view today’s progress and habit activity
- Persist data locally with `UserDefaults` and shared app-group storage for widgets

## Tech Stack

- SwiftUI and Swift
- WidgetKit and App Intents
- UserNotifications for reminders
- StoreKit / RevenueCat for the optional premium store flow
- iOS 18+ (Xcode 16+)

## Project Structure

```text
MiniHabitTracker/
├── MiniHabitTracker/          # Main iOS application
│   ├── Models/                # Habit data, persistence, reminders, achievements
│   ├── Views/                 # Screens and reusable SwiftUI components
│   └── Utils/                 # Date and heat-map helpers
├── WidgetsExtension/          # WidgetKit extension and shared models
└── MiniHabitTracker.xcodeproj
```

## Notes

- Habit data remains on-device; no account or server is required.
- The Store flow uses RevenueCat configuration that must be supplied for production purchases.

## License

Copyright © 2026 Maicol Cabreja. All rights reserved. See [LICENSE](LICENSE) for details.
