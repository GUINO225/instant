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
    final subtotal = (data['subtotal'] ?? data['total'] ?? 0) as int;
    await ref.set({
      ...data,
      'id': ref.id,
      'discountType': data['discountType'] ?? 'none',
      'discountValue': data['discountValue'] ?? 0,
      'discountAmount': data['discountAmount'] ?? 0,
      'totalAfterDiscount': data['totalAfterDiscount'] ?? subtotal,
    });
  }

  Future<void> updateStatus({required String id, String? reservationStatus, String? paymentStatus}) {
    return _db.collection('reservations').doc(id).update({
      if (reservationStatus != null) 'statutReservation': reservationStatus,
      if (paymentStatus != null) 'statutPaiement': paymentStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> applyDiscount({required String id, required int subtotal, required String discountType, required int discountValue}) {
    var discountAmount = 0;
    if (discountType == 'amount') {
      discountAmount = discountValue;
    } else if (discountType == 'percent') {
      discountAmount = ((subtotal * discountValue) / 100).round();
    }
    if (discountAmount > subtotal) discountAmount = subtotal;
    return _db.collection('reservations').doc(id).update({
      'subtotal': subtotal,
      'discountType': discountType,
      'discountValue': discountValue,
      'discountAmount': discountAmount,
      'totalAfterDiscount': subtotal - discountAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
