import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a reminder to the database
  Future<String?> addReminder({
    required String groupId,
    required String text,
    required String time,
    required String createdBy,
  }) async {
    try {
      final reminderData = {
        'groupId': groupId,
        'text': text,
        'time': time,
        'createdBy': createdBy,
        'createdAt': Timestamp.now(),
        'isActive': true,
      };

      final docRef = await _firestore.collection('reminders').add(reminderData);

      print('Reminder added with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error adding reminder: $e');
      return null;
    }
  }

  // Get all reminders for a group
  Future<List<Map<String, dynamic>>> getRemindersForGroup(
      String groupId) async {
    try {
      final snapshot = await _firestore
          .collection('reminders')
          .where('groupId', isEqualTo: groupId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt':
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      print('Error getting reminders for group: $e');
      return [];
    }
  }

  // Delete a reminder
  Future<bool> deleteReminder(String reminderId) async {
    try {
      await _firestore
          .collection('reminders')
          .doc(reminderId)
          .update({'isActive': false});

      print('Reminder deleted: $reminderId');
      return true;
    } catch (e) {
      print('Error deleting reminder: $e');
      return false;
    }
  }

  // Update a reminder
  Future<bool> updateReminder({
    required String reminderId,
    required String text,
    required String time,
  }) async {
    try {
      await _firestore.collection('reminders').doc(reminderId).update({
        'text': text,
        'time': time,
        'updatedAt': Timestamp.now(),
      });

      print('Reminder updated: $reminderId');
      return true;
    } catch (e) {
      print('Error updating reminder: $e');
      return false;
    }
  }

  // Stream reminders for real-time updates
  Stream<List<Map<String, dynamic>>> streamRemindersForGroup(String groupId) {
    return _firestore
        .collection('reminders')
        .where('groupId', isEqualTo: groupId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt':
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    });
  }
}
