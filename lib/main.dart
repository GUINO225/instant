import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/constants.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/reservation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BookingApp());
}

class BookingApp extends StatelessWidget {
  const BookingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, title: 'Instant Beauty Booking', home: const AppRoot());
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final _auth = AuthService();
  String? _lastUid;
  Future<String>? _roleFuture;

  Future<String> _loadRole(String uid) async {
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return (snap.data()?['role'] ?? 'client').toString();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final user = authSnap.data;
        if (user == null) {
          _lastUid = null;
          _roleFuture = null;
          return const LandingPage();
        }
        if (_lastUid != user.uid || _roleFuture == null) {
          _lastUid = user.uid;
          _roleFuture = _loadRole(user.uid);
        }
        return FutureBuilder<String>(
          future: _roleFuture,
          builder: (context, userSnap) {
            if (!userSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            return userSnap.data == 'admin' ? const AdminDashboardPage() : const ClientDashboardPage();
          },
        );
      },
    );
  }
}

class LandingPage extends StatelessWidget { const LandingPage({super.key}); @override Widget build(BuildContext context) => Scaffold(body: Center(child: FilledButton(onPressed: AuthService().signInWithGoogleWeb, child: const Text('Connexion Google')))); }

class ClientDashboardPage extends StatelessWidget {
  const ClientDashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(length: 5, child: Scaffold(appBar: AppBar(title: const Text('Dashboard cliente'), bottom: const TabBar(isScrollable: true, tabs: [Tab(text: 'Nouvelle'), Tab(text: 'Mes réservations'), Tab(text: 'À venir'), Tab(text: 'Historique'), Tab(text: 'Profil')]), actions: [TextButton(onPressed: AuthService().signOut, child: const Text('Déconnexion'))]), body: const TabBarView(children: [ReservationPage(), ClientReservationsView(filter: 'all'), ClientReservationsView(filter: 'future'), ClientReservationsView(filter: 'history'), ClientProfileView()])));
  }
}

class ClientReservationsView extends StatelessWidget {
  const ClientReservationsView({super.key, required this.filter});
  final String filter;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ReservationService().clientReservations(uid),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}'));
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data?.docs ?? [];
        final now = DateTime.now();
        final rows = docs.where((d) {
          final date = ((d.data()['date'] as Timestamp?)?.toDate()) ?? DateTime(1900);
          if (filter == 'future') return date.isAfter(now);
          if (filter == 'history') return !date.isAfter(now);
          return true;
        }).toList();
        if (rows.isEmpty) return const Center(child: Text('Aucune réservation.'));
        return ListView.builder(itemCount: rows.length, itemBuilder: (_, i) {
          final r = rows[i].data();
          final prestations = (r['prestations'] as List? ?? []).map((e) => '${e['nom']} x ${e['quantite']} ${e['typeQuantite']}').join(', ');
          return Card(margin: const EdgeInsets.all(10), child: ListTile(title: Text('${DateFormat('dd/MM/yyyy').format((r['date'] as Timestamp).toDate())} • ${r['heure']}'), subtitle: Text('$prestations\nTotal: ${r['total']} FCFA\n${r['statutReservation']} | ${r['statutPaiement']}')));
        });
      },
    );
  }
}

class ClientProfileView extends StatelessWidget { const ClientProfileView({super.key}); @override Widget build(BuildContext context) { final user = FirebaseAuth.instance.currentUser; return ListView(children: [ListTile(title: const Text('Nom'), subtitle: Text(user?.displayName ?? '')), ListTile(title: const Text('Email'), subtitle: Text(user?.email ?? ''))]); } }

class ReservationPage extends StatefulWidget { const ReservationPage({super.key}); @override State<ReservationPage> createState() => _ReservationPageState(); }

class _ReservationPageState extends State<ReservationPage> {
  final selected = <String, Map<String, dynamic>>{};
  String lieu = 'Studio';
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final note = TextEditingController();
  DateTime? date;
  TimeOfDay? time;

  int _lineTotal(Map<String, dynamic> item) => (item['prixUnitaire'] as int) * (item['quantite'] as int);
  int get total => selected.values.fold(0, (sum, s) => sum + _lineTotal(s)) + (lieu == 'Déplacement' ? kTravelFee : 0);

  void _toggle(Map<String, dynamic> base, bool checked) {
    final nom = base['nom'] as String;
    setState(() {
      if (checked) {
        selected[nom] = {'nom': nom, 'prixUnitaire': base['prixUnitaire'], 'quantite': 1, 'typeQuantite': base['typeQuantite'], 'total': base['prixUnitaire']};
      } else {
        selected.remove(nom);
      }
    });
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser!;
    final prestations = selected.values.map((e) => {...e, 'total': _lineTotal(e)}).toList();
    await ReservationService().createReservation({'clientUid': user.uid, 'clientName': name.text.trim(), 'clientEmail': user.email ?? '', 'clientPhone': phone.text.trim(), 'prestations': prestations, 'lieu': lieu, 'fraisDeplacement': lieu == 'Déplacement' ? kTravelFee : 0, 'adresse': lieu == 'Déplacement' ? address.text.trim() : '', 'date': Timestamp.fromDate(date!), 'heure': time!.format(context), 'total': total, 'statutReservation': 'En attente', 'statutPaiement': 'Non soldé', 'message': note.text.trim(), 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    final lines = prestations.map((e) => '- ${e['nom']} : ${e['prixUnitaire']} FCFA x ${e['quantite']} ${e['typeQuantite']} = ${e['total']} FCFA').toList();
    if (lieu == 'Déplacement') lines.add('- Déplacement : $kTravelFee FCFA');
    final txt = 'Bonjour, je souhaite faire une réservation beauté.\n\nNom : ${name.text}\nTéléphone : ${phone.text}\nEmail : ${user.email}\n\nPrestations :\n${lines.join('\n')}\n\nDate souhaitée : ${DateFormat('dd/MM/yyyy').format(date!)}\nHeure souhaitée : ${time!.format(context)}\nAdresse : ${lieu == 'Déplacement' ? address.text : 'Studio'}\n\nTotal : $total FCFA\nStatut réservation : En attente\nStatut paiement : Non soldé\n\nMerci de me confirmer la disponibilité.';
    await launchUrl(Uri.parse('https://wa.me/$kAdminWhatsApp?text=${Uri.encodeComponent(txt)}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réservation enregistrée')));
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = selected.isNotEmpty && name.text.isNotEmpty && phone.text.isNotEmpty && date != null && time != null && (lieu == 'Studio' || address.text.isNotEmpty);
    return ListView(padding: const EdgeInsets.all(16), children: [
      ...defaultServices.map((s) {
        final nom = s['nom'] as String;
        final row = selected[nom];
        return Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CheckboxListTile(value: row != null, onChanged: (v) => _toggle(s, v ?? false), title: Text(nom), subtitle: Text('${s['prixUnitaire']} FCFA / ${s['typeQuantite']}')),
          if (row != null && s['typeQuantite'] != 'session') Row(children: [Text(s['quantityLabel'] as String), IconButton(onPressed: () => setState(() { final q = (row['quantite'] as int); row['quantite'] = q > 1 ? q - 1 : 1; row['total'] = _lineTotal(row); }), icon: const Icon(Icons.remove_circle_outline)), Text('${row['quantite']}'), IconButton(onPressed: () => setState(() { row['quantite'] = (row['quantite'] as int) + 1; row['total'] = _lineTotal(row); }), icon: const Icon(Icons.add_circle_outline))]),
          if (row != null) Padding(padding: const EdgeInsets.only(left: 16, bottom: 8), child: Text('Sous-total: ${_lineTotal(row)} FCFA')),
        ])));
      }),
      DropdownButtonFormField<String>(value: lieu, items: const [DropdownMenuItem(value: 'Studio', child: Text('Studio')), DropdownMenuItem(value: 'Déplacement', child: Text('Déplacement (+10 000 FCFA)'))], onChanged: (v) => setState(() => lieu = v!)),
      TextField(controller: name, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Nom complet')),
      TextField(controller: phone, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Téléphone WhatsApp')),
      if (lieu == 'Déplacement') TextField(controller: address, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Adresse')),
      TextField(controller: note, decoration: const InputDecoration(labelText: 'Message facultatif')),
      ListTile(title: Text(date == null ? 'Date souhaitée' : DateFormat('dd/MM/yyyy').format(date!)), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2031), initialDate: DateTime.now()); if (d != null) setState(() => date = d); }),
      ListTile(title: Text(time == null ? 'Heure souhaitée' : time!.format(context)), onTap: () async { final t = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (t != null) setState(() => time = t); }),
      Text('Total: $total FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
      FilledButton(onPressed: canSubmit ? _submit : null, child: const Text('Valider réservation')),
    ]);
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(length: 9, child: Scaffold(appBar: AppBar(title: const Text('Dashboard propriétaire'), bottom: const TabBar(isScrollable: true, tabs: [Tab(text: 'Vue'), Tab(text: 'Calendrier'), Tab(text: 'À confirmer'), Tab(text: 'Confirmées'), Tab(text: 'Accomplies'), Tab(text: 'Historique'), Tab(text: 'Clientes'), Tab(text: 'Gains'), Tab(text: 'Paramètres')]), actions: [TextButton(onPressed: AuthService().signOut, child: const Text('Déconnexion'))]), body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: ReservationService().allReservations(), builder: (context, snap) {
      if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}'));
      if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snap.data?.docs.map((e) => e.data()).toList() ?? [];
      Widget statusList(String status) => ListView(children: rows.where((r) => r['statutReservation'] == status).map((r) => _AdminReservationTile(r: r)).toList());
      return TabBarView(children: [_Overview(rows: rows), ListView(children: const [ListTile(title: Text('Vue calendrier'))]), statusList('En attente'), statusList('Confirmée'), statusList('Accomplie'), ListView(children: rows.map((r) => _AdminReservationTile(r: r)).toList()), _ClientsPage(rows: rows), _EarningsPage(rows: rows), const ListTile(title: Text('Paramètres Firestore: settings/booking'))]);
    })));
  }
}

class _AdminReservationTile extends StatelessWidget { const _AdminReservationTile({required this.r}); final Map<String, dynamic> r; @override Widget build(BuildContext context) { final prestations = (r['prestations'] as List? ?? []).map((e) => '${e['nom']} • ${e['prixUnitaire']} x ${e['quantite']} ${e['typeQuantite']} = ${e['total']} FCFA').join('\n'); return Card(child: ListTile(title: Text('${r['clientName']} • ${r['total']} FCFA'), subtitle: Text('${r['clientPhone']} | ${r['clientEmail']}\n$prestations\n${r['lieu']} ${r['adresse'] ?? ''}\n${r['statutReservation']} | ${r['statutPaiement']}'), trailing: PopupMenuButton<String>(onSelected: (v) => ReservationService().updateStatus(id: r['id'], reservationStatus: v.startsWith('PAY_') ? null : v, paymentStatus: v.startsWith('PAY_') ? v.replaceFirst('PAY_', '') : null), itemBuilder: (_) => const [PopupMenuItem(value: 'Confirmée', child: Text('Confirmer')), PopupMenuItem(value: 'Annulée', child: Text('Annuler')), PopupMenuItem(value: 'Reportée', child: Text('Reporter')), PopupMenuItem(value: 'Accomplie', child: Text('Accomplie')), PopupMenuItem(value: 'PAY_Acompte payé', child: Text('Acompte payé')), PopupMenuItem(value: 'PAY_Soldé', child: Text('Soldé'))]))); } }

class _Overview extends StatelessWidget { const _Overview({required this.rows}); final List<Map<String, dynamic>> rows; @override Widget build(BuildContext context) { int sumBy(bool Function(Map<String, dynamic>) f) => rows.where(f).fold(0, (s, r) => s + ((r['total'] ?? 0) as int)); return ListView(children: [ListTile(title: const Text('Réservations en attente'), trailing: Text('${rows.where((r) => r['statutReservation'] == 'En attente').length}')), ListTile(title: const Text('Réservations confirmées'), trailing: Text('${rows.where((r) => r['statutReservation'] == 'Confirmée').length}')), ListTile(title: const Text('Prestations accomplies'), trailing: Text('${rows.where((r) => r['statutReservation'] == 'Accomplie').length}')), ListTile(title: const Text('Gains estimés'), trailing: Text('${sumBy((r) => r['statutReservation'] == 'En attente' || r['statutReservation'] == 'Confirmée')} FCFA'))]); } }
class _ClientsPage extends StatelessWidget { const _ClientsPage({required this.rows}); final List<Map<String, dynamic>> rows; @override Widget build(BuildContext context) { final byClient = <String, List<Map<String, dynamic>>>{}; for (final r in rows) { final key = (r['clientEmail'] ?? '').toString(); byClient.putIfAbsent(key, () => []).add(r);} return ListView(children: byClient.entries.map((e) => ListTile(title: Text(e.value.first['clientName']), subtitle: Text('${e.key} • ${e.value.length} réservations'))).toList()); } }
class _EarningsPage extends StatelessWidget { const _EarningsPage({required this.rows}); final List<Map<String, dynamic>> rows; @override Widget build(BuildContext context) { final nonSolde = rows.where((r) => r['statutPaiement'] != 'Soldé').fold(0, (s, r) => s + ((r['total'] ?? 0) as int)); final qtyByService = <String, int>{}; for (final r in rows) { for (final p in (r['prestations'] as List? ?? [])) { qtyByService[p['nom'].toString()] = (qtyByService[p['nom'].toString()] ?? 0) + ((p['quantite'] ?? 1) as int); } } return ListView(children: [ListTile(title: const Text('Montant non soldé'), trailing: Text('$nonSolde FCFA')), ...qtyByService.entries.map((e) => ListTile(title: Text(e.key), trailing: Text('${e.value} unités')))]); } }
