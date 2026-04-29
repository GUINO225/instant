import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> clientReservations(String uid) => _db.collection('reservations').where('clientUid', isEqualTo: uid).orderBy('date', descending: true).snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> allReservations() => _db.collection('reservations').orderBy('date', descending: true).snapshots();

  Future<void> createReservation(Map<String, dynamic> data) async {
    final ref = _db.collection('reservations').doc();
    await ref.set({...data, 'id': ref.id, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> updateWorkflow({required String id, String? availabilityStatus, String? bookingStatus, String? paymentStatus, String? cancelledBy, Map<String, dynamic>? extra}) {
    return _db.collection('reservations').doc(id).update({
      if (availabilityStatus != null) 'availabilityStatus': availabilityStatus,
      if (bookingStatus != null) 'bookingStatus': bookingStatus,
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
      if (cancelledBy != null) 'cancelledBy': cancelledBy,
      ...?extra,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recordDeposit({required String id, required int total, required int paidNow}) {
    final paid = paidNow.clamp(0, total);
    final remaining = total - paid;
    return _db.collection('reservations').doc(id).update({'paidDepositAmount': paid, 'paidTotalAmount': paid, 'remainingAmount': remaining, 'paymentStatus': remaining == 0 ? 'paid' : 'deposit_paid', 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> markPaid({required String id, required int total}) => _db.collection('reservations').doc(id).update({'paidTotalAmount': total, 'remainingAmount': 0, 'paymentStatus': 'paid', 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> acceptReschedule({required String id, required Timestamp? date, required String? time}) => _db.collection('reservations').doc(id).update({'date': date, 'heure': time, 'bookingStatus': 'confirmed', 'requestedRescheduleDate': null, 'requestedRescheduleTime': null, 'updatedAt': FieldValue.serverTimestamp()});
}
