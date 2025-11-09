#!/bin/bash

# Install Flutter on Netlify
echo "Installing Flutter..."

# Set Flutter version
FLUTTER_VERSION="3.24.0"

# Download and install Flutter
cd /opt/buildhome
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:/opt/buildhome/flutter/bin"

# Run Flutter doctor
flutter doctor -v

# Enable web
flutter config --enable-web

# Get dependencies and build
cd $OLDPWD
flutter pub get
flutter build web --release

# Copy redirects
cp web/_redirects build/web/_redirects

echo "Build complete!"
