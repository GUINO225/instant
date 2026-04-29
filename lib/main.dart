import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/constants.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/reservation_service.dart';
import 'services/service_catalog_service.dart';

const _black = Color(0xFF0B0B0B);
const _white = Color(0xFFFFFFFF);
const _lightGray = Color(0xFFF5F5F5);
const _midGray = Color(0xFFCFCFCF);
const _darkGray = Color(0xFF6E6E6E);

Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); runApp(const BookingApp()); }

class BookingApp extends StatelessWidget { const BookingApp({super.key}); @override Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, title: 'Instant Maquillage', theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: _white, textTheme: GoogleFonts.interTextTheme(), appBarTheme: const AppBarTheme(backgroundColor: _white), cardTheme: CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _lightGray))),), home: const AppRoot()); }

class AppRoot extends StatefulWidget { const AppRoot({super.key}); @override State<AppRoot> createState() => _AppRootState(); }
class _AppRootState extends State<AppRoot> {
  final _auth = AuthService();
  Future<String> _loadRole(String uid) async => (await FirebaseFirestore.instance.collection('users').doc(uid).get()).data()?['role']?.toString() ?? 'client';
  @override Widget build(BuildContext context) => SplashGate(child: StreamBuilder<User?>(stream: _auth.authStateChanges(), builder: (_, auth) { if (!auth.hasData) return const LandingPage(); return FutureBuilder<String>(future: _loadRole(auth.data!.uid), builder: (_, role) => !role.hasData ? const Center(child: CircularProgressIndicator()) : role.data == 'admin' ? const AdminDashboardPage() : const ClientDashboardPage()); }));
}

class SplashGate extends StatefulWidget { const SplashGate({super.key, required this.child}); final Widget child; @override State<SplashGate> createState() => _SplashGateState(); }
class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin { late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200)); bool done = false; @override void initState() { super.initState(); c.forward(); Timer(const Duration(seconds: 2), () => mounted ? setState(() => done = true) : null); } @override void dispose() { c.dispose(); super.dispose(); } @override Widget build(BuildContext context) => done ? widget.child : Scaffold(backgroundColor: _black, body: Center(child: FadeTransition(opacity: c, child: Text('Instant Maquillage', style: GoogleFonts.playfairDisplay(color: _white, fontSize: 38, fontWeight: FontWeight.w600))))); }

class LandingPage extends StatelessWidget { const LandingPage({super.key}); @override Widget build(BuildContext context) => Scaffold(body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Instant Maquillage', style: GoogleFonts.playfairDisplay(fontSize: 40)), const Spacer(), FilledButton(onPressed: AuthService().signInWithGoogleWeb, style: FilledButton.styleFrom(backgroundColor: _black), child: const Text('Connexion Google')),]))); }

class ClientDashboardPage extends StatelessWidget { const ClientDashboardPage({super.key}); @override Widget build(BuildContext context) => DefaultTabController(length: 3, child: Scaffold(appBar: AppBar(title: const Text('Dashboard cliente'), bottom: const TabBar(tabs: [Tab(text: 'Réserver'), Tab(text: 'Réservations'), Tab(text: 'Profil')]), actions: [TextButton(onPressed: AuthService().signOut, child: const Text('Déconnexion'))]), body: const TabBarView(children: [ReservationPage(), ClientReservationsView(), Center(child: Text('Profil'))]))); }

class ReservationPage extends StatefulWidget { const ReservationPage({super.key}); @override State<ReservationPage> createState() => _ReservationPageState(); }
class _ReservationPageState extends State<ReservationPage> {
  final _catalog = ServiceCatalogService();
  final selected = <String, Map<String, dynamic>>{};
  final name = TextEditingController(); final phone = TextEditingController(); DateTime? date; TimeOfDay? time;
  int _line(Map<String, dynamic> e) => (e['price'] as int) * (e['quantity'] as int);
  int get subtotal => selected.values.fold(0, (s, e) => s + _line(e));

  List<Map<String, dynamic>> _fallbackActiveServices() {
    return ServiceCatalogService.defaultServices
        .where((e) => e['isActive'] == true)
        .map((e) => {
              'id': e['name'],
              ...e,
              'price': (e['price'] as num).toInt(),
            })
        .toList();
  }
  void _toggle(Map<String, dynamic> s, bool v) { setState(() { if (!v) { selected.remove(s['id']); return; } selected[s['id']] = {'serviceId': s['id'], 'name': s['name'], 'price': s['price'], 'quantityType': s['quantityType'], 'quantity': (s['quantityType'] == 'personne' || s['quantityType'] == 'photo') ? 1 : 1}; }); }
  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser!;
    final prestations = selected.values.map((e) => {...e, 'lineTotal': _line(e)}).toList();
    await ReservationService().createReservation({'clientUid': user.uid, 'clientName': name.text, 'clientEmail': user.email ?? '', 'clientPhone': phone.text, 'prestations': prestations, 'date': Timestamp.fromDate(date!), 'heure': time!.format(context), 'subtotal': subtotal, 'totalAfterDiscount': subtotal, 'statutReservation': 'En attente', 'statutPaiement': 'Non soldé', 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    final lines = prestations.map((e) => '- ${e['name']} : ${e['price']} FCFA x ${e['quantity']} ${e['quantityType']} = ${e['lineTotal']} FCFA').join('\n');
    final message = 'Bonjour, je souhaite faire une réservation Instant Maquillage.\n\nNom : ${name.text}\nTéléphone : ${phone.text}\nEmail : ${user.email}\n\nPrestations :\n$lines\n\nSous-total : $subtotal FCFA\nRéduction : 0 FCFA\nTotal final : $subtotal FCFA\n\nDate : ${DateFormat('dd/MM/yyyy').format(date!)}\nHeure : ${time!.format(context)}\nStatut : En attente\nPaiement : Non soldé\n\nMerci de me confirmer la disponibilité.';
    await launchUrl(Uri.parse('https://wa.me/$kAdminWhatsApp?text=${Uri.encodeComponent(message)}'));
  }
  @override Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: _catalog.watchServices(), builder: (_, snap) {
    List<Map<String, dynamic>> services;
    if (snap.hasError) {
      services = _fallbackActiveServices();
    } else if (!snap.hasData) {
      services = _fallbackActiveServices();
    } else {
      final firestoreServices = snap.data!.docs.map((d) {
        final data = d.data();
        return {
          'id': data['id'] ?? d.id,
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
          'price': (data['price'] as num?)?.toInt() ?? 0,
          'quantityType': data['quantityType'] ?? 'fixe',
          'isActive': data['isActive'] ?? true,
        };
      }).where((e) => e['isActive'] == true).toList();
      services = firestoreServices.isNotEmpty ? firestoreServices : _fallbackActiveServices();
    }

    return ListView(padding: const EdgeInsets.all(16), children: [for (final s in services) Card(child: CheckboxListTile(value: selected.containsKey(s['id']), onChanged: (v) => _toggle(s, v ?? false), title: Text('${s['name']} • ${s['price']} FCFA (${serviceTypeLabels[s['quantityType']]})'), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if ((s['description'] ?? '').toString().isNotEmpty) Text(s['description']), if (selected.containsKey(s['id']) && (s['quantityType'] == 'personne' || s['quantityType'] == 'photo')) Row(children: [IconButton(onPressed: () => setState(() => selected[s['id']]!['quantity'] = (selected[s['id']]!['quantity'] as int) > 1 ? (selected[s['id']]!['quantity'] as int) - 1 : 1), icon: const Icon(Icons.remove)), Text('${selected[s['id']]!['quantity']}'), IconButton(onPressed: () => setState(() => selected[s['id']]!['quantity'] = (selected[s['id']]!['quantity'] as int) + 1), icon: const Icon(Icons.add))])]))), const SizedBox(height: 8), TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')), const SizedBox(height: 8), TextField(controller: phone, decoration: const InputDecoration(labelText: 'Téléphone')), ListTile(title: Text(date == null ? 'Date' : DateFormat('dd/MM/yyyy').format(date!)), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2032), initialDate: DateTime.now()); if (d != null) setState(() => date = d); }), ListTile(title: Text(time == null ? 'Heure' : time!.format(context)), onTap: () async { final t = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (t != null) setState(() => time = t); }), Text('Sous-total: $subtotal FCFA'), FilledButton(onPressed: selected.isNotEmpty && date != null && time != null ? _submit : null, style: FilledButton.styleFrom(backgroundColor: _black), child: const Text('Valider'))]); });
}

class ClientReservationsView extends StatelessWidget { const ClientReservationsView({super.key}); @override Widget build(BuildContext context) { final uid = FirebaseAuth.instance.currentUser!.uid; return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: ReservationService().clientReservations(uid), builder: (_, snap) { final docs = snap.data?.docs ?? []; return ListView(children: docs.map((d) { final r = d.data(); final subtotal = r['subtotal'] ?? 0; final discountAmount = r['discountAmount'] ?? 0; final total = r['totalAfterDiscount'] ?? subtotal; return Card(child: ListTile(title: Text('${r['clientName']} - ${r['heure']}'), subtitle: Text('Sous-total: $subtotal FCFA\nRéduction: $discountAmount FCFA\nTotal final: $total FCFA\n${r['statutReservation']} · ${r['statutPaiement']}'))); }).toList()); }); } }

class AdminDashboardPage extends StatefulWidget { const AdminDashboardPage({super.key}); @override State<AdminDashboardPage> createState() => _AdminDashboardPageState(); }
class _AdminDashboardPageState extends State<AdminDashboardPage> { int selectedIndex = 0; final pages = const [AdminOverviewPage(), AdminCalendarPage(), AdminStatusPage('En attente'), AdminStatusPage('Confirmée'), AdminStatusPage('Accomplie'), AdminHistoryPage(), AdminClientsPage(), AdminEarningsPage(), AdminServicesPage(), Center(child: Text('Paramètres'))]; @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Dashboard admin'), actions: [TextButton(onPressed: AuthService().signOut, child: const Text('Déconnexion'))]), body: Row(children: [NavigationRail(selectedIndex: selectedIndex, onDestinationSelected: (i) => setState(() => selectedIndex = i), labelType: NavigationRailLabelType.all, destinations: const [NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')), NavigationRailDestination(icon: Icon(Icons.calendar_month), label: Text('Calendrier')), NavigationRailDestination(icon: Icon(Icons.pending), label: Text('À confirmer')), NavigationRailDestination(icon: Icon(Icons.check_circle), label: Text('Confirmées')), NavigationRailDestination(icon: Icon(Icons.task_alt), label: Text('Accomplies')), NavigationRailDestination(icon: Icon(Icons.history), label: Text('Historique')), NavigationRailDestination(icon: Icon(Icons.people), label: Text('Clientes')), NavigationRailDestination(icon: Icon(Icons.payments), label: Text('Gains')), NavigationRailDestination(icon: Icon(Icons.design_services), label: Text('Prestations')), NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Paramètres')), ]), const VerticalDivider(width: 1), Expanded(child: pages[selectedIndex]) ])); }

class AdminOverviewPage extends StatelessWidget { const AdminOverviewPage({super.key}); @override Widget build(BuildContext context) => const _AdminReservationsBuilder(builder: _overview); static Widget _overview(List<Map<String, dynamic>> rows) { final total = rows.fold<int>(0, (s, r) => s + ((r['totalAfterDiscount'] ?? r['subtotal'] ?? 0) as int)); return ListView(children: [ListTile(title: const Text('Total gains (net)'), trailing: Text('$total FCFA'))]); }}
class AdminStatusPage extends StatelessWidget { const AdminStatusPage(this.status, {super.key}); final String status; @override Widget build(BuildContext context) => _AdminReservationsBuilder(builder: (rows) => ListView(children: rows.where((r) => r['statutReservation'] == status).map((r) => AdminReservationTile(r: r)).toList())); }
class AdminHistoryPage extends StatelessWidget { const AdminHistoryPage({super.key}); @override Widget build(BuildContext context) => const _AdminReservationsBuilder(builder: _all); static Widget _all(List<Map<String, dynamic>> rows) => ListView(children: rows.map((r) => AdminReservationTile(r: r)).toList()); }
class AdminClientsPage extends StatelessWidget { const AdminClientsPage({super.key}); @override Widget build(BuildContext context) => const _AdminReservationsBuilder(builder: _clients); static Widget _clients(List<Map<String, dynamic>> rows) { final map = <String,int>{}; for (final r in rows) { map[r['clientEmail'] ?? ''] = (map[r['clientEmail'] ?? ''] ?? 0)+1;} return ListView(children: map.entries.map((e) => ListTile(title: Text(e.key), trailing: Text('${e.value}'))).toList()); }}
class AdminEarningsPage extends StatelessWidget { const AdminEarningsPage({super.key}); @override Widget build(BuildContext context) => const _AdminReservationsBuilder(builder: _earn); static Widget _earn(List<Map<String, dynamic>> rows) { final net = rows.fold<int>(0, (s, r) => s + ((r['totalAfterDiscount'] ?? 0) as int)); return ListTile(title: const Text('Gains basés sur totalAfterDiscount'), trailing: Text('$net FCFA')); }}

class _AdminReservationsBuilder extends StatelessWidget { const _AdminReservationsBuilder({required this.builder}); final Widget Function(List<Map<String, dynamic>>) builder; @override Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: ReservationService().allReservations(), builder: (_, snap) => !snap.hasData ? const Center(child: CircularProgressIndicator()) : builder(snap.data!.docs.map((e) => e.data()).toList())); }

class AdminReservationTile extends StatefulWidget { const AdminReservationTile({super.key, required this.r}); final Map<String, dynamic> r; @override State<AdminReservationTile> createState() => _AdminReservationTileState(); }
class _AdminReservationTileState extends State<AdminReservationTile> { String discountType = 'none'; final c = TextEditingController(text: '0'); @override void initState() { super.initState(); discountType = widget.r['discountType'] ?? 'none'; c.text = '${widget.r['discountValue'] ?? 0}'; } @override Widget build(BuildContext context) { final r = widget.r; final subtotal = r['subtotal'] ?? 0; final total = r['totalAfterDiscount'] ?? subtotal; return Card(child: ExpansionTile(title: Text('${r['clientName']} • $total FCFA'), subtitle: Text('${r['statutReservation']} · ${r['statutPaiement']}'), children: [for (final p in (r['prestations'] as List? ?? [])) ListTile(title: Text('${p['name']}'), subtitle: Text('${p['price']} x ${p['quantity']} ${p['quantityType']} = ${p['lineTotal']}')), ListTile(title: const Text('Réduction')), Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: DropdownButtonFormField<String>(value: discountType, items: const [DropdownMenuItem(value: 'none', child: Text('Aucune réduction')), DropdownMenuItem(value: 'amount', child: Text('Montant fixe')), DropdownMenuItem(value: 'percent', child: Text('Pourcentage'))], onChanged: (v) => setState(() => discountType = v!))), const SizedBox(width: 10), SizedBox(width: 100, child: TextField(controller: c, keyboardType: TextInputType.number)), const SizedBox(width: 10), FilledButton(onPressed: () => ReservationService().applyDiscount(id: r['id'], subtotal: subtotal, discountType: discountType, discountValue: int.tryParse(c.text) ?? 0), child: const Text('Appliquer'))])), ])); }}

class AdminCalendarPage extends StatelessWidget { const AdminCalendarPage({super.key}); @override Widget build(BuildContext context) => const _AdminReservationsBuilder(builder: _calendar); static Widget _calendar(List<Map<String, dynamic>> rows) { final byDay = <String, List<Map<String, dynamic>>>{}; for (final r in rows.where((r) => r['statutReservation'] != 'Annulée')) { final d = (r['date'] as Timestamp).toDate(); final k = DateFormat('yyyy-MM-dd').format(d); byDay.putIfAbsent(k, () => []).add(r);} final now = DateTime.now(); final first = DateTime(now.year, now.month, 1); return GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7), itemCount: DateUtils.getDaysInMonth(now.year, now.month), itemBuilder: (c, i) { final day = first.add(Duration(days: i)); final k = DateFormat('yyyy-MM-dd').format(day); final count = byDay[k]?.length ?? 0; return InkWell(onTap: count == 0 ? null : () => showModalBottomSheet(context: c, builder: (_) => ListView(children: byDay[k]!.map((r) => ListTile(title: Text('${r['heure']} • ${r['clientName']}'), subtitle: Text('${r['clientPhone']}\nTotal: ${r['totalAfterDiscount'] ?? r['subtotal']}'), trailing: IconButton(onPressed: () => launchUrl(Uri.parse('https://wa.me/${r['clientPhone']}')), icon: const Icon(Icons.message)))).toList())), child: Card(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${day.day}'), if (count > 0) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)), if (count > 1) Text('$count', style: const TextStyle(fontSize: 10))]))); }); }}

class AdminServicesPage extends StatefulWidget { const AdminServicesPage({super.key}); @override State<AdminServicesPage> createState() => _AdminServicesPageState(); }

class _AdminServicesPageState extends State<AdminServicesPage> {
  final _catalog = ServiceCatalogService(); @override Widget build(BuildContext context) => Scaffold(body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: _catalog.watchServices(), builder: (_, snap) { final rows = snap.data?.docs.map((e) => {'id': e.data()['id'] ?? e.id, ...e.data(), 'price': (e.data()['price'] as num?)?.toInt() ?? 0, 'isActive': e.data()['isActive'] ?? true}).toList() ?? []; return ListView(padding: const EdgeInsets.all(12), children: [Row(children: [Expanded(child: FilledButton(onPressed: () => _serviceDialog(context), child: const Text('Ajouter prestation'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(onPressed: () async { final count = await _catalog.initializeDefaultServicesIfEmpty(); if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(count == 0 ? 'Des prestations existent déjà.' : '$count prestations initialisées.'))); }, child: const Text('Initialiser les prestations par défaut')))]), ...rows.map((s) => Card(child: ListTile(title: Text('${s['name']} • ${s['price']} FCFA'), subtitle: Text('${s['quantityType']} • ${s['isActive'] ? 'Actif' : 'Inactif'}'), trailing: Wrap(spacing: 8, children: [IconButton(onPressed: () => _serviceDialog(context, data: s), icon: const Icon(Icons.edit)), IconButton(onPressed: () => _catalog.updateService(s['id'], {'isActive': !(s['isActive'] as bool)}), icon: const Icon(Icons.block)), IconButton(onPressed: () async { final used = await _catalog.isServiceUsedInReservations(s['id']); if (used) { await _catalog.updateService(s['id'], {'isActive': false}); if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prestation utilisée: désactivée au lieu de suppression.'))); } else { await _catalog.deleteService(s['id']); } }, icon: const Icon(Icons.delete_outline))]))))]); }));
  Future<void> _serviceDialog(BuildContext context, {Map<String, dynamic>? data}) async { final name = TextEditingController(text: data?['name'] ?? ''); final desc = TextEditingController(text: data?['description'] ?? ''); final price = TextEditingController(text: '${data?['price'] ?? 0}'); String qty = data?['quantityType'] ?? 'personne'; bool active = data?['isActive'] ?? true; await showDialog(context: context, builder: (_) => AlertDialog(title: Text(data == null ? 'Nouvelle prestation' : 'Modifier prestation'), content: StatefulBuilder(builder: (context, set) => Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')), TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')), TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix')), DropdownButtonFormField(value: qty, items: const [DropdownMenuItem(value: 'personne', child: Text('personne')), DropdownMenuItem(value: 'photo', child: Text('photo')), DropdownMenuItem(value: 'session', child: Text('session')), DropdownMenuItem(value: 'fixe', child: Text('fixe'))], onChanged: (v) => set(() => qty = v!)), SwitchListTile(value: active, onChanged: (v) => set(() => active = v), title: const Text('Actif'))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty || (int.tryParse(price.text) ?? -1) < 0) return; if (data == null) { await ServiceCatalogService().createService(name: name.text.trim(), description: desc.text.trim(), price: int.parse(price.text), quantityType: qty, isActive: active); } else { await ServiceCatalogService().updateService(data['id'], {'name': name.text.trim(), 'description': desc.text.trim(), 'price': int.parse(price.text), 'quantityType': qty, 'isActive': active}); } if (context.mounted) Navigator.pop(context); }, child: const Text('Enregistrer'))])); }
}
