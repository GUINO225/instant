import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceCatalogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchServices({bool activeOnly = false}) {
    var query = _db.collection('services').orderBy('createdAt');
    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }
    return query.snapshots();
  }

  Future<void> createService({
    required String name,
    required String description,
    required int price,
    required String quantityType,
    required bool isActive,
  }) async {
    final ref = _db.collection('services').doc();
    await ref.set({
      'id': ref.id,
      'name': name,
      'description': description,
      'price': price,
      'quantityType': quantityType,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateService(String id, Map<String, dynamic> payload) {
    return _db.collection('services').doc(id).update({...payload, 'updatedAt': FieldValue.serverTimestamp()});
  }
}
