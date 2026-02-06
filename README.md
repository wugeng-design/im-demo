# IM SDK Demo

A standalone Flutter demo application for testing the IM SDK.

## Features

- Connect to any XMPP server (ejabberd, OpenFire, Prosody)
- Send/receive messages
- View connection state changes
- Real-time logging

## Quick Start

### 1. Start XMPP Server

```bash
# Start ejabberd with Docker
docker run -d --name ejabberd -p 5222:5222 ejabberd/ecs

# Register test users
docker exec ejabberd ejabberdctl register admin localhost admin
docker exec ejabberd ejabberdctl register user1 localhost user1
```

### 2. Run the Demo

```bash
cd examples/im_sdk_demo

# Get dependencies
flutter pub get

# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android

# Run on macOS (desktop)
flutter run -d macos
```

### 3. Connect and Test

1. Launch the app
2. Default credentials are already filled (admin/admin)
3. Tap "Connect" to connect to localhost:5222
4. Enter a recipient JID (e.g., `user1@localhost`)
5. Type a message and tap "Send"

## Project Structure

```
im_sdk_demo/
├── lib/
│   ├── main.dart              # Demo app entry point
│   └── sdk/                   # IM SDK (standalone copy)
│       ├── im_sdk.dart        # SDK exports
│       ├── config/            # Configuration
│       ├── extensions/        # Extension interfaces
│       ├── models/            # Data models
│       └── services/          # Connection services
├── pubspec.yaml               # Dependencies
└── README.md
```

## Configuration

### Server Settings

| Field    | Default     | Description                    |
|----------|-------------|--------------------------------|
| Host     | localhost   | XMPP server hostname           |
| Port     | 5222        | XMPP server port               |
| Domain   | localhost   | XMPP domain                    |
| Username | admin       | User's local part (before @)   |
| Password | admin       | User's password                |

### For Remote Server

If connecting to a remote server:

1. Change Host to the server's IP or domain
2. Change Domain to match the server's XMPP domain
3. Use valid credentials registered on that server

## Dependencies

- `whixp`: XMPP protocol implementation
- `flutter_riverpod`: State management

## Troubleshooting

### Connection Timeout

- Ensure the XMPP server is running
- Check firewall allows port 5222
- Verify host/port are correct

### Authentication Failed

- Verify username and password
- Ensure user is registered on the server
- Check domain matches server configuration

### iOS/macOS Network Issues

Add to `ios/Runner/Info.plist` or `macos/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```
