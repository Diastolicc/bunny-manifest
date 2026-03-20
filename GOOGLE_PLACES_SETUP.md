# Google Places API Setup Guide

## 🚀 Phase 2: External API Integration - Google Places API

This guide will help you set up Google Places API integration for enhanced venue discovery and autocomplete functionality.

## 📋 Prerequisites

1. **Google Cloud Console Account** - Sign up at [console.cloud.google.com](https://console.cloud.google.com)
2. **Billing Account** - Google Places API requires billing to be enabled
3. **API Key** - You'll need to create and configure an API key

## 🔧 Setup Steps

### Step 1: Enable Required APIs

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select an existing one
3. Navigate to **APIs & Services** > **Library**
4. Enable the following APIs:
   - **Places API**
   - **Places API (New)**
   - **Geocoding API**
   - **Maps JavaScript API** (optional, for web support)

### Step 2: Create API Key

1. Go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **API Key**
3. Copy your API key
4. (Optional) Restrict the API key for security:
   - Click on your API key
   - Under **API restrictions**, select **Restrict key**
   - Choose the APIs you enabled above

### Step 3: Configure Your App

1. Open `lib/config/places_config.dart`
2. Replace `YOUR_GOOGLE_PLACES_API_KEY` with your actual API key:

```dart
class PlacesConfig {
  static const String apiKey = 'YOUR_ACTUAL_API_KEY_HERE';
  // ... rest of the config
}
```

### Step 4: Test the Integration

1. Run your Flutter app
2. Navigate to the **Create Party** screen
3. Try searching for venues in the search field
4. Verify that nearby venues are displayed with real data

## 🎯 Features Implemented

### ✅ Enhanced Venue Discovery
- **Google Places Integration** - Real-time venue data from Google's database
- **Autocomplete Search** - Smart venue search with suggestions
- **Photo Support** - Venue photos from Google Places
- **Real-time Data** - Live ratings, hours, and contact information

### ✅ Smart Venue Selection
- **Location-based Suggestions** - Venues sorted by distance
- **Search & Filter** - Find specific venues by name or type
- **Visual Selection** - Interactive venue cards with ratings and distance
- **Fallback Support** - Works even without Google Places API

### ✅ Enhanced User Experience
- **Seamless Integration** - Works with existing location detection
- **Smart Caching** - Combines local and Google Places data
- **Error Handling** - Graceful fallbacks when API is unavailable
- **Performance Optimized** - Efficient data loading and caching

## 🔒 Security Best Practices

### API Key Security
1. **Restrict API Key** - Limit to specific APIs and IP addresses
2. **Use Environment Variables** - Don't commit API keys to version control
3. **Monitor Usage** - Set up billing alerts and usage quotas
4. **Rotate Keys** - Regularly update your API keys

### Recommended Restrictions
- **API Restrictions**: Places API, Geocoding API only
- **Application Restrictions**: Android/iOS app restrictions
- **Usage Quotas**: Set daily/monthly limits

## 💰 Cost Considerations

### Google Places API Pricing (as of 2024)
- **Places API (New)**: $0.017 per request
- **Places Autocomplete**: $0.00283 per request
- **Places Details**: $0.017 per request
- **Places Photos**: $0.007 per request

### Cost Optimization Tips
1. **Cache Results** - Store venue data locally to reduce API calls
2. **Debounce Search** - Limit autocomplete requests
3. **Set Quotas** - Configure daily/monthly limits
4. **Use Efficient Queries** - Only request necessary data fields

## 🚨 Troubleshooting

### Common Issues

#### "API Key Invalid"
- Verify your API key is correct
- Check that billing is enabled
- Ensure the API is enabled in Google Cloud Console

#### "Quota Exceeded"
- Check your usage in Google Cloud Console
- Increase quota limits if needed
- Implement caching to reduce API calls

#### "No Results Found"
- Verify location permissions are granted
- Check that the search area has venues
- Try different search terms or expand the radius

### Debug Mode
Enable debug logging by adding this to your app:

```dart
// In your main.dart or debug configuration
import 'dart:developer' as developer;

// Add this to see API responses
developer.log('Places API Response: $response');
```

## 🔄 Next Steps

### Phase 3: Smart Recommendations
- **Machine Learning** - Personalized venue suggestions
- **User Preferences** - Learn from user behavior
- **Dynamic Ranking** - Smart venue ordering
- **Social Features** - Friend recommendations and reviews

### Advanced Features
- **Real-time Updates** - Live venue status and availability
- **Social Integration** - Share venues with friends
- **Analytics** - Track venue popularity and trends
- **Offline Support** - Cache venues for offline use

## 📞 Support

If you encounter issues:
1. Check the [Google Places API documentation](https://developers.google.com/maps/documentation/places/web-service)
2. Review your API key configuration
3. Verify billing and quotas in Google Cloud Console
4. Test with a simple API call first

---

**🎉 Congratulations!** You now have a fully integrated Google Places API system that provides real-time venue discovery, autocomplete search, and enhanced user experience for your club reservation app!
