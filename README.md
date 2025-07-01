# WasherLord - Smart Washing Machine Monitor Assistant

[中文版本](./README_CN.md)

## Project Overview

WasherLord is a smart washing machine monitoring application developed with the Flutter framework, designed to help you monitor washing machine status in real-time in dormitory laundry scenarios, automatically claim available machines, and simplify the laundry process.

## Core Features

### 🚀 Real-time Washing Machine Monitoring

- Display all washing machine statuses (Available, Rinsing, Washing, Occupied)
- Intuitive display of remaining time for each machine
- Support start/stop monitoring operations

### ⚡ Smart Claiming System

- Automatic detection of available washing machines
- One-click laundry order creation
- Real-time order tracking (Order number, Payment status)

### ⧉ Personalized Configuration Center

- **Machine Exclusion**: Customize ignored machines
- **Preset Washing Modes**:
  - Quick Wash (23min) ¥3.5
  - Regular Wash (40min) ¥3.7
  - Extended Wash (45min) ¥4.2
  - Spin Only (6min) ¥1.0
- **Payment Configuration**: Enable auto-payment feature

### 👤 User Account Management

- Multi-account switching support
- User configuration import/export

## Interface Preview

| Login Screen                                    | Monitoring Screen                                       | Order Screen                                  |
| ----------------------------------------------- | ------------------------------------------------------- | --------------------------------------------- |
| ![Login Screen](./screenshots/login_screen.png) | ![Monitoring Screen](./screenshots/get_washer_info.png) | ![Order Screen](./screenshots/got_washer.png) |

| Configuration Center                                | My Orders                                |
| --------------------------------------------------- | ---------------------------------------- |
| ![Configuration Center](./screenshots/settings.png) | ![My Orders](./screenshots/my_order.png) |

## Technical Architecture

- **Framework**: Flutter (Cross-platform support for iOS/Android)
- **Local Storage**: SharedPreferences

## User Guide

1. **Login**: Enter your phone number to use current account
2. **Configure Preferences**:
   - Set machines to exclude
   - Select preferred washing mode
   - Enable auto-payment function
3. **Start Monitoring**: Click "Start Monitoring" button
4. **Claim Machine**: Automatically creates order when available machine detected
5. **Complete Payment**: Pay promptly to start laundry

## Building Instructions

```bash
# Install dependencies
flutter pub get

# Run development version
flutter run

# Build APK
flutter build apk --release
```

## Disclaimer

```bash
This software is provided solely for learning and exchange purposes. The developer assumes no responsibility for user actions or consequences. Users shall comply with relevant platform usage agreements and bear all usage risks independently.

The software does not collect any sensitive user information. All data processing occurs locally on the device.

Before using, please replace "WEBSITE_PEOPLE_KNOW" in the source code with a valid domain address.
```

## License

This project is licensed under the GPL 3.0 License - see the LICENSE file for details.