#!/bin/bash

# Build and run the web admin panel
echo "Building web admin panel..."

# Build for web
flutter build web --target=web_admin_main.dart --web-renderer html --release

# Copy the built files to web_admin directory
echo "Copying built files..."
cp -r build/web/* web_admin/

# Start a simple HTTP server
echo "Starting web server..."
echo "Admin panel will be available at: http://localhost:8080"
echo "Press Ctrl+C to stop the server"

# Use Python's built-in HTTP server
cd web_admin && python3 -m http.server 8080
