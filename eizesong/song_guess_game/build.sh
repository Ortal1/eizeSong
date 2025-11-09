#!/bin/bash

# Build script for Netlify deployment

echo "🚀 Starting Flutter Web build for Netlify..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null
then
    echo "❌ Flutter is not installed. Installing Flutter..."
    # You might need to install Flutter in Netlify build environment
    # For now, we assume it's available
    exit 1
fi

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Build web app
echo "🔨 Building Flutter web app..."
flutter build web --release

# Copy _redirects file to build output
echo "📋 Copying redirects file..."
if [ -f "web/_redirects" ]; then
    cp web/_redirects build/web/_redirects
fi

echo "✅ Build completed successfully!"
echo "📁 Output directory: build/web"
