import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bunny/models/split_cost.dart';

class SplitCostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference for split costs
  CollectionReference<Map<String, dynamic>> get _splitCostsCollection =>
      _firestore.collection('splitCosts');

  // Add a new split cost
  Future<void> addSplitCost(SplitCost splitCost) async {
    try {
      await _splitCostsCollection.doc(splitCost.id).set(splitCost.toJson());
    } catch (e) {
      print('Error adding split cost: $e');
      throw Exception('Failed to add split cost');
    }
  }

  // Get all split costs for a chat group
  Future<List<SplitCost>> getSplitCostsForGroup(String groupId) async {
    try {
      final QuerySnapshot snapshot = await _splitCostsCollection
          .where('groupId', isEqualTo: groupId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SplitCost.fromJson({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      print('Error getting split costs: $e');
      return [];
    }
  }

  // Mark a split cost as paid
  Future<void> markAsPaid(String splitCostId) async {
    try {
      await _splitCostsCollection.doc(splitCostId).update({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking split cost as paid: $e');
      throw Exception('Failed to mark split cost as paid');
    }
  }

  // Delete a split cost
  Future<void> deleteSplitCost(String splitCostId) async {
    try {
      await _splitCostsCollection.doc(splitCostId).delete();
    } catch (e) {
      print('Error deleting split cost: $e');
      throw Exception('Failed to delete split cost');
    }
  }

  // Get split costs by status
  Future<List<SplitCost>> getSplitCostsByStatus(
      String groupId, String status) async {
    try {
      final QuerySnapshot snapshot = await _splitCostsCollection
          .where('groupId', isEqualTo: groupId)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SplitCost.fromJson({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      print('Error getting split costs by status: $e');
      return [];
    }
  }

  // Get total amount owed by a specific user
  Future<double> getTotalOwedByUser(String groupId, String userId) async {
    try {
      final QuerySnapshot snapshot = await _splitCostsCollection
          .where('groupId', isEqualTo: groupId)
          .where('owerId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['amount'] as num).toDouble();
      }
      return total;
    } catch (e) {
      print('Error getting total owed by user: $e');
      return 0.0;
    }
  }

  // Get total amount paid by a specific user
  Future<double> getTotalPaidByUser(String groupId, String userId) async {
    try {
      final QuerySnapshot snapshot = await _splitCostsCollection
          .where('groupId', isEqualTo: groupId)
          .where('payerId', isEqualTo: userId)
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['amount'] as num).toDouble();
      }
      return total;
    } catch (e) {
      print('Error getting total paid by user: $e');
      return 0.0;
    }
  }
}
