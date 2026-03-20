#!/bin/bash

echo "🔨 Building Club Reservation Admin Panel..."

# Build the web admin
flutter build web --target=web_admin_main.dart

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Copy built files
    cp -r build/web/* web_admin/
    
    # Fix the branding in HTML and manifest files
    echo "🎨 Fixing branding..."
    
    # Update index.html
    sed -i '' 's/A new Flutter project\./Club Reservation Admin Panel/g' web_admin/index.html
    sed -i '' 's/club_reservation/Club Admin/g' web_admin/index.html
    sed -i '' 's/<title>Club Admin<\/title>/<title>Club Reservation Admin Panel<\/title>/g' web_admin/index.html
    
    # Update manifest.json
    sed -i '' 's/"name": "club_reservation"/"name": "Club Reservation Admin Panel"/g' web_admin/manifest.json
    sed -i '' 's/"short_name": "club_reservation"/"short_name": "Club Admin"/g' web_admin/manifest.json
    sed -i '' 's/"description": "A new Flutter project\."/"description": "Admin panel for Club Reservation System"/g' web_admin/manifest.json
    
    echo "🎉 Web admin panel built and deployed successfully!"
    echo "🌐 Access at: http://localhost:8080"
    echo "🔐 Login with: carlmichaelbaylon@outlook.com"
else
    echo "❌ Build failed!"
    exit 1
fi
