import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceCatalogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<Map<String, dynamic>> defaultServices = [
    {
      'name': 'Maquillage événement / maquillage simple',
      'description': 'Maquillage simple ou événementiel',
      'price': 25000,
      'quantityType': 'personne',
      'isActive': true,
    },
    {
      'name': 'Maquillage mariée',
      'description': 'Maquillage spécial mariée',
      'price': 35000,
      'quantityType': 'personne',
      'isActive': true,
    },
    {
      'name': 'Cours d’auto-maquillage',
      'description': 'Session d’apprentissage maquillage',
      'price': 50000,
      'quantityType': 'session',
      'isActive': true,
    },
    {
      'name': 'Conseils beauté coiffure',
      'description': 'Conseils personnalisés beauté et coiffure',
      'price': 60000,
      'quantityType': 'personne',
      'isActive': true,
    },
    {
      'name': 'Shooting photo',
      'description': 'Maquillage pour shooting photo',
      'price': 100000,
      'quantityType': 'photo',
      'isActive': true,
    },
    {
      'name': 'Déplacement',
      'description': 'Frais de déplacement',
      'price': 10000,
      'quantityType': 'fixe',
      'isActive': true,
    },
  ];

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

  Future<void> deleteService(String id) => _db.collection('services').doc(id).delete();

  Future<bool> isServiceUsedInReservations(String id) async {
    final allReservations = await _db.collection('reservations').get();
    for (final doc in allReservations.docs) {
      final prestations = (doc.data()['prestations'] as List? ?? []).cast<dynamic>();
      if (prestations.any((p) => p is Map && p['serviceId'] == id)) return true;
    }
    return false;
  }

  Future<int> initializeDefaultServicesIfEmpty() async {
    final collection = _db.collection('services');
    final existing = await collection.limit(1).get();
    if (existing.docs.isNotEmpty) return 0;

    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();
    for (final service in defaultServices) {
      final ref = collection.doc();
      batch.set(ref, {
        'id': ref.id,
        ...service,
        'createdAt': now,
        'updatedAt': now,
      });
    }
    await batch.commit();
    return defaultServices.length;
  }
}
