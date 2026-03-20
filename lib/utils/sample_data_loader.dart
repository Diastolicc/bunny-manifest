import 'package:bunny/services/club_service.dart';
import 'package:bunny/services/party_service.dart';

class SampleDataLoader {
  static Future<void> loadAllSampleData() async {
    try {
      print('🔄 Loading sample data...');

      // Load sample clubs
      await _loadSampleClubs();

      // Load sample parties
      await _loadSampleParties();

      print('✅ Sample data loaded successfully!');
    } catch (e) {
      print('❌ Error loading sample data: $e');
    }
  }

  static Future<void> _loadSampleClubs() async {
    try {
      final ClubService clubService = ClubService();
      await clubService.addSampleData();
      print('✅ Sample clubs loaded');
    } catch (e) {
      print('❌ Error loading sample clubs: $e');
    }
  }

  static Future<void> _loadSampleParties() async {
    try {
      final PartyService partyService = PartyService();
      await partyService.addSampleData();
      print('✅ Sample parties loaded');
    } catch (e) {
      print('❌ Error loading sample parties: $e');
    }
  }

  static Future<void> clearAllData() async {
    try {
      print('🗑️ Clearing all data...');

      // Note: This would require admin privileges in production
      // For development, you can manually clear collections in Firebase Console

      print('⚠️ Data clearing requires manual action in Firebase Console');
      print('📋 Go to: Firebase Console > Firestore Database > Data tab');
      print('🗑️ Delete collections: clubs, parties, users, reservations');
    } catch (e) {
      print('❌ Error clearing data: $e');
    }
  }
}
