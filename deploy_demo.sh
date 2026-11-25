#!/usr/bin/env bash
set -e
flutter pub get
flutter build web --release --dart-define=DEMO_MODE=true
firebase hosting:channel:deploy demo --expires 30d
