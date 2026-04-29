import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';

const String kAdminWhatsApp = '2250749931142';
const int kTravelFee = 10000;

const List<ServiceItem> kServices = [
  ServiceItem('Maquillage événement / maquillage simple', 25000),
  ServiceItem('Maquillage mariée', 35000),
  ServiceItem('Cours d’auto-maquillage', 50000),
  ServiceItem('Conseils beauté coiffure', 60000),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BookingApp());
}

class ServiceItem {
  const ServiceItem(this.name, this.price);
  final String name;
  final int price;

  Map<String, dynamic> toMap() => {'nom': name, 'prix': price};
}

class BookingApp extends StatelessWidget {
  const BookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Instant Beauty Booking',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(primary: Colors.black),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;
        if (user == null) return const LandingPage();
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userDocSnap) {
            if (!userDocSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final role = (userDocSnap.data!.data()?['role'] ?? 'client').toString();
            return role == 'admin' ? const AdminDashboardPage() : const ClientDashboardPage();
          },
        );
      },
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  Future<void> _signInGoogle() async {
    final provider = GoogleAuthProvider();
    final credential = await FirebaseAuth.instance.signInWithPopup(provider);
    final user = credential.user;
    if (user == null) return;

    final users = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();
    final existing = await users.get();
    final existingData = existing.data();

    await users.set({
      'uid': user.uid,
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'phone': existingData?['phone'] ?? user.phoneNumber ?? '',
      'role': existingData?['role'] ?? 'client',
      'createdAt': existingData?['createdAt'] ?? now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.black12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Réservation Beauté', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300)),
                const SizedBox(height: 10),
                const Text('Connectez-vous avec Google pour réserver et suivre vos prestations.'),
                const SizedBox(height: 20),
                FilledButton(onPressed: _signInGoogle, child: const Text('Connexion Google/Gmail')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class ClientDashboardPage extends StatefulWidget {
  const ClientDashboardPage({super.key});

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace cliente'),
        actions: [TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Déconnexion'))],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('reservations').where('clientUid', isEqualTo: uid).orderBy('date').snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final data = docs.map((e) => e.data()).toList();
          final now = DateTime.now();

          List<Map<String, dynamic>> filtered = data;
          if (tab == 1) filtered = data.where((r) => (r['date'] as Timestamp).toDate().isAfter(now)).toList();
          if (tab == 2) filtered = data.where((r) => r['statutReservation'] == 'En attente').toList();
          if (tab == 3) filtered = data.where((r) => r['statutReservation'] == 'Confirmée').toList();
          if (tab == 4) filtered = data.where((r) => r['statutReservation'] == 'Accomplie').toList();

          return Column(children: [
            Wrap(spacing: 8, children: [
              for (final e in ['Mes réservations', 'À venir', 'En attente', 'Confirmées', 'Accomplies'])
                ChoiceChip(label: Text(e), selected: ['Mes réservations', 'À venir', 'En attente', 'Confirmées', 'Accomplies'].indexOf(e) == tab, onSelected: (_) => setState(() => tab = ['Mes réservations', 'À venir', 'En attente', 'Confirmées', 'Accomplies'].indexOf(e))),
            ]),
            Expanded(
              child: ListView(
                children: filtered
                    .map(
                      (r) => Card(
                        child: ListTile(
                          title: Text('${r['clientName']} • ${r['total']} FCFA'),
                          subtitle: Text('${r['statutReservation']} | ${r['statutPaiement']}\n${DateFormat('dd/MM/yyyy').format((r['date'] as Timestamp).toDate())} ${r['heure']}'),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReservationPage())), child: const Text('Nouvelle réservation')),
            )
          ]);
        },
      ),
    );
  }
}

class ReservationPage extends StatefulWidget {
  const ReservationPage({super.key});

  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  final selected = <ServiceItem>{};
  String lieu = 'Studio';
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final note = TextEditingController();
  DateTime? date;
  TimeOfDay? time;

  int get total => selected.fold(0, (sum, s) => sum + s.price) + (lieu == 'Déplacement' ? kTravelFee : 0);

  Future<void> _saveReservation() async {
    final user = FirebaseAuth.instance.currentUser!;
    final ref = FirebaseFirestore.instance.collection('reservations').doc();
    final reservationData = {
      'id': ref.id,
      'clientUid': user.uid,
      'clientName': name.text.trim(),
      'clientEmail': user.email ?? '',
      'clientPhone': phone.text.trim(),
      'prestations': selected.map((s) => s.toMap()).toList(),
      'lieu': lieu,
      'fraisDeplacement': lieu == 'Déplacement' ? kTravelFee : 0,
      'adresse': lieu == 'Déplacement' ? address.text.trim() : '',
      'date': Timestamp.fromDate(date!),
      'heure': time!.format(context),
      'total': total,
      'statutReservation': 'En attente',
      'statutPaiement': 'Non soldé',
      'message': note.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await ref.set(reservationData);

    final txt = '''Nouvelle réservation beauté\nNom: ${name.text.trim()}\nTéléphone: ${phone.text.trim()}\nEmail: ${user.email ?? ''}\nPrestations: ${selected.map((e) => e.name).join(', ')}\nLieu: $lieu\nAdresse: ${lieu == 'Déplacement' ? address.text.trim() : 'Studio'}\nDate: ${DateFormat('dd/MM/yyyy').format(date!)}\nHeure: ${time!.format(context)}\nTotal: $total FCFA\nStatut réservation: En attente\nStatut paiement: Non soldé''';
    final uri = Uri.parse('https://wa.me/$kAdminWhatsApp?text=${Uri.encodeComponent(txt)}');
    await launchUrl(uri, mode: LaunchMode.platformDefault);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réservation enregistrée. Retour accueil...')));
    unawaited(Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pop();
    }));
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = selected.isNotEmpty && name.text.isNotEmpty && phone.text.isNotEmpty && date != null && time != null && (lieu == 'Studio' || address.text.isNotEmpty);
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle réservation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...kServices.map((s) => CheckboxListTile(value: selected.contains(s), onChanged: (v) => setState(() => v == true ? selected.add(s) : selected.remove(s)), title: Text(s.name), subtitle: Text('${s.price} FCFA'))),
          DropdownButtonFormField<String>(value: lieu, items: const [DropdownMenuItem(value: 'Studio', child: Text('Studio')), DropdownMenuItem(value: 'Déplacement', child: Text('Déplacement (+10 000 FCFA)'))], onChanged: (v) => setState(() => lieu = v!), decoration: const InputDecoration(labelText: 'Lieu')),
          TextField(controller: name, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Nom complet')),
          TextField(controller: phone, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Téléphone WhatsApp')),
          if (lieu == 'Déplacement') TextField(controller: address, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Adresse')),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Message facultatif')),
          ListTile(title: Text(date == null ? 'Date souhaitée' : DateFormat('dd/MM/yyyy').format(date!)), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2031), initialDate: DateTime.now()); if (d != null) setState(() => date = d); }),
          ListTile(title: Text(time == null ? 'Heure souhaitée' : time!.format(context)), onTap: () async { final t = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (t != null) setState(() => time = t); }),
          const SizedBox(height: 8),
          Text('Total: $total FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          FilledButton(onPressed: canSubmit ? _saveReservation : null, child: const Text('Valider réservation')),
        ],
      ),
    );
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard propriétaire'), actions: [TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Déconnexion'))]),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('reservations').snapshots(),
        builder: (context, snap) {
          final rows = snap.data?.docs ?? [];
          int sumWhere(bool Function(Map<String, dynamic>) f) => rows.where((d) => f(d.data())).fold(0, (p, d) => p + ((d.data()['total'] ?? 0) as int));
          return DefaultTabController(
            length: 4,
            child: Column(children: [
              const TabBar(tabs: [Tab(text: 'Vue'), Tab(text: 'Actions'), Tab(text: 'Historique'), Tab(text: 'Clientes')]),
              Expanded(
                child: TabBarView(children: [
                  ListView(children: [
                    ListTile(title: const Text('Total réservations'), trailing: Text('${rows.length}')),
                    ListTile(title: const Text('En attente'), trailing: Text('${rows.where((e) => e.data()['statutReservation'] == 'En attente').length}')),
                    ListTile(title: const Text('Confirmées'), trailing: Text('${rows.where((e) => e.data()['statutReservation'] == 'Confirmée').length}')),
                    ListTile(title: const Text('Accomplies'), trailing: Text('${rows.where((e) => e.data()['statutReservation'] == 'Accomplie').length}')),
                    ListTile(title: const Text('Gains estimés'), trailing: Text('${sumWhere((r) => r['statutReservation'] == 'En attente' || r['statutReservation'] == 'Confirmée')} FCFA')),
                    ListTile(title: const Text('Gains confirmés'), trailing: Text('${sumWhere((r) => r['statutReservation'] == 'Confirmée')} FCFA')),
                    ListTile(title: const Text('Gains réalisés'), trailing: Text('${sumWhere((r) => r['statutReservation'] == 'Accomplie')} FCFA')),
                  ]),
                  ListView(
                    children: rows
                        .map((d) => d.data())
                        .map((r) => Card(
                              child: ListTile(
                                title: Text('${r['clientName']} • ${r['total']} FCFA'),
                                subtitle: Text('${r['statutReservation']} | ${r['statutPaiement']}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) => FirebaseFirestore.instance.collection('reservations').doc(r['id']).update({
                                    if (v.startsWith('PAY_')) 'statutPaiement': v.replaceFirst('PAY_', ''),
                                    if (!v.startsWith('PAY_')) 'statutReservation': v,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'Confirmée', child: Text('Confirmer')),
                                    PopupMenuItem(value: 'Annulée', child: Text('Annuler')),
                                    PopupMenuItem(value: 'Reportée', child: Text('Reporter')),
                                    PopupMenuItem(value: 'Accomplie', child: Text('Accomplie')),
                                    PopupMenuItem(value: 'PAY_Acompte payé', child: Text('Acompte payé')),
                                    PopupMenuItem(value: 'PAY_Soldé', child: Text('Soldé')),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  ListView(children: rows.map((r) => ListTile(title: Text('${r.data()['clientName']}'), subtitle: Text('${r.data()['statutReservation']} | ${r.data()['statutPaiement']}'))).toList()),
                  FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance.collection('users').get(),
                    builder: (context, usersSnap) {
                      final users = usersSnap.data?.docs ?? [];
                      return ListView(children: users.map((u) => ListTile(title: Text(u.data()['displayName'] ?? ''), subtitle: Text('${u.data()['email']} | role: ${u.data()['role']}'))).toList());
                    },
                  ),
                ]),
              )
            ]),
          );
        },
      ),
    );
  }
}
