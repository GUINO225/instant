import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> clientReservations(String uid) {
    return _db.collection('reservations').where('clientUid', isEqualTo: uid).orderBy('date').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> allReservations() {
    return _db.collection('reservations').orderBy('date', descending: true).snapshots();
  }

  Future<void> createReservation(Map<String, dynamic> data) async {
    final ref = _db.collection('reservations').doc();
    await ref.set({...data, 'id': ref.id});
  }

  Future<void> updateStatus({required String id, String? reservationStatus, String? paymentStatus}) {
    return _db.collection('reservations').doc(id).update({
      if (reservationStatus != null) 'statutReservation': reservationStatus,
      if (paymentStatus != null) 'statutPaiement': paymentStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
