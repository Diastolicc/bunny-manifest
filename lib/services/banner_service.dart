import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/banner_config.dart';

class BannerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get active banner
  Future<BannerConfig?> getActiveBanner() async {
    try {
      print('BannerService: Fetching active banner...');
      final snapshot = await _firestore
          .collection('banners')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      print('BannerService: Found ${snapshot.docs.length} active banners');
      
      if (snapshot.docs.isEmpty) {
        return null;
      }

      final data = snapshot.docs.first.data();
      print('BannerService: Banner data: $data');
      
      final Map<String, dynamic> jsonData = {
        'id': snapshot.docs.first.id,
        'imageUrl': data['imageUrl'] ?? '',
        'isActive': data['isActive'] ?? true,
        'title': data['title'] ?? '',
        'description': data['description'] ?? '',
        'linkUrl': data['linkUrl'],
        'displayOrder': data['displayOrder'] ?? 0,
      };
      
      // Handle createdAt and updatedAt separately - don't include if null
      if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
        jsonData['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      if (data['updatedAt'] != null && data['updatedAt'] is Timestamp) {
        jsonData['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
      }
      
      print('BannerService: Returning banner with imageUrl: ${jsonData['imageUrl']}');
      return BannerConfig.fromJson(jsonData);
    } catch (e) {
      print('Error getting active banner: $e');
      return null;
    }
  }

  // Get all banners
  Future<List<BannerConfig>> getAllBanners() async {
    try {
      final snapshot = await _firestore
          .collection('banners')
          .orderBy('displayOrder')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final Map<String, dynamic> jsonData = {
          'id': doc.id,
          'imageUrl': data['imageUrl'] ?? '',
          'isActive': data['isActive'] ?? true,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'linkUrl': data['linkUrl'],
          'displayOrder': data['displayOrder'] ?? 0,
        };
        
        // Handle createdAt and updatedAt separately - don't include if null
        if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
          jsonData['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updatedAt'] != null && data['updatedAt'] is Timestamp) {
          jsonData['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
        }
        
        return BannerConfig.fromJson(jsonData);
      }).toList();
    } catch (e) {
      print('Error getting all banners: $e');
      return [];
    }
  }

  // Create banner
  Future<void> createBanner(BannerConfig banner) async {
    try {
      await _firestore.collection('banners').add({
        'imageUrl': banner.imageUrl,
        'isActive': banner.isActive,
        'title': banner.title,
        'description': banner.description,
        'linkUrl': banner.linkUrl,
        'displayOrder': banner.displayOrder,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating banner: $e');
      rethrow;
    }
  }

  // Update banner
  Future<void> updateBanner(String id, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('banners').doc(id).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating banner: $e');
      rethrow;
    }
  }

  // Delete banner
  Future<void> deleteBanner(String id) async {
    try {
      await _firestore.collection('banners').doc(id).delete();
    } catch (e) {
      print('Error deleting banner: $e');
      rethrow;
    }
  }

  // Set active banner (deactivates all others)
  Future<void> setActiveBanner(String id) async {
    try {
      final batch = _firestore.batch();

      // Deactivate all banners
      final allBanners = await _firestore.collection('banners').get();
      for (var doc in allBanners.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      // Activate the selected banner
      batch.update(
        _firestore.collection('banners').doc(id),
        {
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      print('Error setting active banner: $e');
      rethrow;
    }
  }
}
