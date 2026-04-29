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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Instant Beauty Booking',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(primary: Colors.black),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white)),
        cardTheme: CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.black12))),
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;
        if (user == null) return const LandingPage();
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            final role = (userSnap.data?.data()?['role'] ?? 'client').toString();
            return role == 'admin' ? const AdminDashboardPage() : const ClientDashboardPage();
          },
        );
      },
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Instant Beauty Booking', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
                const SizedBox(height: 12),
                const Text('Connexion Google obligatoire pour réserver vos prestations beauté.'),
                const SizedBox(height: 18),
                FilledButton(onPressed: auth.signInWithGoogleWeb, child: const Text('Connexion Google')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class ClientDashboardPage extends StatelessWidget {
  const ClientDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard cliente'),
          bottom: const TabBar(isScrollable: true, tabs: [Tab(text: 'Nouvelle'), Tab(text: 'Mes réservations'), Tab(text: 'À venir'), Tab(text: 'Historique'), Tab(text: 'Profil')]),
          actions: [TextButton(onPressed: () => AuthService().signOut(), child: const Text('Déconnexion'))],
        ),
        body: const TabBarView(
          children: [ReservationPage(), ClientReservationsView(filter: 'all'), ClientReservationsView(filter: 'future'), ClientReservationsView(filter: 'history'), ClientProfileView()],
        ),
      ),
    );
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
        final docs = snap.data?.docs ?? [];
        final now = DateTime.now();
        final rows = docs.where((d) {
          final r = d.data();
          final date = (r['date'] as Timestamp).toDate();
          if (filter == 'future') return date.isAfter(now);
          if (filter == 'history') return !date.isAfter(now);
          return true;
        }).toList();

        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final r = rows[i].data();
            final prestations = (r['prestations'] as List).map((e) => e['nom']).join(', ');
            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text('${DateFormat('dd/MM/yyyy').format((r['date'] as Timestamp).toDate())} • ${r['heure']}'),
                subtitle: Text('$prestations\n${r['lieu']} ${r['lieu'] == 'Déplacement' ? '• ${r['adresse']}' : ''}\n${r['statutReservation']} | ${r['statutPaiement']}\n${r['total']} FCFA'),
              ),
            );
          },
        );
      },
    );
  }
}

class ClientProfileView extends StatelessWidget {
  const ClientProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ListView(children: [ListTile(title: const Text('Nom'), subtitle: Text(user?.displayName ?? '')), ListTile(title: const Text('Email'), subtitle: Text(user?.email ?? ''))]);
  }
}

class ReservationPage extends StatefulWidget {
  const ReservationPage({super.key});
  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  final selected = <Map<String, dynamic>>[];
  String lieu = 'Studio';
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final note = TextEditingController();
  DateTime? date;
  TimeOfDay? time;

  int get total => selected.fold(0, (sum, s) => sum + (s['prix'] as int)) + (lieu == 'Déplacement' ? kTravelFee : 0);

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser!;
    await ReservationService().createReservation({
      'clientUid': user.uid,
      'clientName': name.text.trim(),
      'clientEmail': user.email ?? '',
      'clientPhone': phone.text.trim(),
      'prestations': selected,
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
    });

    final txt = 'Nom: ${name.text}\nTéléphone: ${phone.text}\nEmail: ${user.email}\nPrestations: ${selected.map((e) => e['nom']).join(', ')}\nLieu: $lieu\nAdresse: ${lieu == 'Déplacement' ? address.text : 'Studio'}\nDate: ${DateFormat('dd/MM/yyyy').format(date!)}\nHeure: ${time!.format(context)}\nTotal: $total FCFA\nStatut réservation: En attente\nStatut paiement: Non soldé';
    await launchUrl(Uri.parse('https://wa.me/$kAdminWhatsApp?text=${Uri.encodeComponent(txt)}'));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réservation enregistrée')));
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = selected.isNotEmpty && name.text.isNotEmpty && phone.text.isNotEmpty && date != null && time != null && (lieu == 'Studio' || address.text.isNotEmpty);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...defaultServices.map((s) => CheckboxListTile(value: selected.contains(s), onChanged: (v) => setState(() => v == true ? selected.add(s) : selected.remove(s)), title: Text(s['nom']), subtitle: Text('${s['prix']} FCFA'))),
        DropdownButtonFormField<String>(value: lieu, items: const [DropdownMenuItem(value: 'Studio', child: Text('Studio')), DropdownMenuItem(value: 'Déplacement', child: Text('Déplacement (+10 000 FCFA)'))], onChanged: (v) => setState(() => lieu = v!)),
        TextField(controller: name, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Nom complet')),
        TextField(controller: phone, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Téléphone WhatsApp')),
        if (lieu == 'Déplacement') TextField(controller: address, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Adresse')),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Message facultatif')),
        ListTile(title: Text(date == null ? 'Date souhaitée' : DateFormat('dd/MM/yyyy').format(date!)), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2031), initialDate: DateTime.now()); if (d != null) setState(() => date = d); }),
        ListTile(title: Text(time == null ? 'Heure souhaitée' : time!.format(context)), onTap: () async { final t = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (t != null) setState(() => time = t); }),
        Text('Total: $total FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FilledButton(onPressed: canSubmit ? _submit : null, child: const Text('Valider réservation')),
      ],
    );
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 9,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard propriétaire'),
          bottom: const TabBar(isScrollable: true, tabs: [Tab(text: 'Vue'), Tab(text: 'Calendrier'), Tab(text: 'À confirmer'), Tab(text: 'Confirmées'), Tab(text: 'Accomplies'), Tab(text: 'Historique'), Tab(text: 'Clientes'), Tab(text: 'Gains'), Tab(text: 'Paramètres')]),
          actions: [TextButton(onPressed: () => AuthService().signOut(), child: const Text('Déconnexion'))],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ReservationService().allReservations(),
          builder: (context, snap) {
            final rows = snap.data?.docs.map((e) => e.data()).toList() ?? [];
            Widget statusList(String status) => ListView(children: rows.where((r) => r['statutReservation'] == status).map((r) => _AdminReservationTile(r: r)).toList());
            return TabBarView(children: [
              _Overview(rows: rows),
              ListView(children: const [ListTile(title: Text('Vue jour/semaine/mois à brancher avec un package calendrier'))]),
              statusList('En attente'),
              statusList('Confirmée'),
              statusList('Accomplie'),
              ListView(children: rows.map((r) => _AdminReservationTile(r: r)).toList()),
              _ClientsPage(rows: rows),
              _EarningsPage(rows: rows),
              const ListTile(title: Text('Paramètres Firestore: settings/booking')),
            ]);
          },
        ),
      ),
    );
  }
}

class _AdminReservationTile extends StatelessWidget {
  const _AdminReservationTile({required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${r['clientName']} • ${r['total']} FCFA'),
        subtitle: Text('${r['statutReservation']} | ${r['statutPaiement']}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => ReservationService().updateStatus(id: r['id'], reservationStatus: v.startsWith('PAY_') ? null : v, paymentStatus: v.startsWith('PAY_') ? v.replaceFirst('PAY_', '') : null),
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
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    int sumBy(bool Function(Map<String, dynamic>) f) => rows.where(f).fold(0, (s, r) => s + ((r['total'] ?? 0) as int));
    return ListView(children: [
      ListTile(title: const Text('Réservations en attente'), trailing: Text('${rows.where((r) => r['statutReservation'] == 'En attente').length}')),
      ListTile(title: const Text('Réservations confirmées'), trailing: Text('${rows.where((r) => r['statutReservation'] == 'Confirmée').length}')),
      ListTile(title: const Text('Prestations accomplies'), trailing: Text('${rows.where((r) => r['statutReservation'] == 'Accomplie').length}')),
      ListTile(title: const Text('Gains estimés'), trailing: Text('${sumBy((r) => r['statutReservation'] == 'En attente' || r['statutReservation'] == 'Confirmée')} FCFA')),
      ListTile(title: const Text('Gains confirmés'), trailing: Text('${sumBy((r) => r['statutReservation'] == 'Confirmée')} FCFA')),
      ListTile(title: const Text('Gains réalisés'), trailing: Text('${sumBy((r) => r['statutReservation'] == 'Accomplie')} FCFA')),
    ]);
  }
}

class _ClientsPage extends StatelessWidget {
  const _ClientsPage({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final byClient = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final key = (r['clientEmail'] ?? '').toString();
      byClient.putIfAbsent(key, () => []).add(r);
    }
    return ListView(children: byClient.entries.map((e) => ListTile(title: Text(e.value.first['clientName']), subtitle: Text('${e.key} • ${e.value.length} réservations'))).toList());
  }
}

class _EarningsPage extends StatelessWidget {
  const _EarningsPage({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final nonSolde = rows.where((r) => r['statutPaiement'] != 'Soldé').fold(0, (s, r) => s + ((r['total'] ?? 0) as int));
    final deplacements = rows.where((r) => r['lieu'] == 'Déplacement');
    final fraisDepl = deplacements.fold(0, (s, r) => s + ((r['fraisDeplacement'] ?? 0) as int));
    return ListView(children: [
      ListTile(title: const Text('Montant non soldé'), trailing: Text('$nonSolde FCFA')),
      ListTile(title: const Text('Nombre de déplacements'), trailing: Text('${deplacements.length}')),
      ListTile(title: const Text('Total frais déplacement'), trailing: Text('$fraisDepl FCFA')),
    ]);
  }
}
