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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BookingApp());
}

class BookingApp extends StatelessWidget {
  const BookingApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(useMaterial3: true, textTheme: GoogleFonts.interTextTheme()), home: const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});
  Future<String> _loadRole(String uid) async => (await FirebaseFirestore.instance.collection('users').doc(uid).get()).data()?['role']?.toString() ?? 'client';
  @override
  Widget build(BuildContext context) => SplashGate(
        child: StreamBuilder<User?>(
          stream: AuthService().authStateChanges(),
          builder: (_, auth) {
            if (!auth.hasData) return const LandingPage();
            return FutureBuilder<String>(future: _loadRole(auth.data!.uid), builder: (_, role) => role.hasData ? (role.data == 'admin' ? const AdminDashboardPage() : const ClientDashboardPage()) : const Center(child: CircularProgressIndicator()));
          },
        ),
      );
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});
  final Widget child;
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool done = false;
  @override
  void initState() {
    super.initState();
    c.forward();
    Timer(const Duration(milliseconds: 1200), () => mounted ? setState(() => done = true) : null);
  }

  @override
  Widget build(BuildContext context) => done
      ? widget.child
      : Scaffold(
          backgroundColor: _black,
          body: Center(
            child: FadeTransition(
              opacity: c,
              child: Text(
                'Instant Maquillage',
                style: GoogleFonts.playfairDisplay(color: _white, fontSize: 36),
              ),
            ),
          ),
        );
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: FilledButton(onPressed: AuthService().signInWithGoogleWeb, style: FilledButton.styleFrom(backgroundColor: _black), child: const Text('Connexion Google'))));
}

String _f(int n) => '${NumberFormat('#,###', 'fr_FR').format(n).replaceAll(',', ' ')} FCFA';
Color _c(String s) => {
      'pending': Colors.orange,
      'available': Colors.green,
      'unavailable': Colors.red,
      'waiting_client_confirmation': Colors.blueGrey,
      'confirmed': Colors.green,
      'reschedule_requested': Colors.purple,
      'reschedule_refused': Colors.deepOrange,
      'completed': Colors.black,
      'deposit_unpaid': Colors.orange,
      'deposit_paid': Colors.teal,
      'paid': Colors.green,
      'cancelled_by_client': Colors.grey,
      'cancelled_by_admin': Colors.redAccent,
    }[s] ?? Colors.grey;

Widget _badge(String l, String k) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: _c(k).withOpacity(.12), borderRadius: BorderRadius.circular(99), border: Border.all(color: _c(k).withOpacity(.5))), child: Text(l, style: TextStyle(color: _c(k), fontWeight: FontWeight.w600, fontSize: 12)));

Map<String, dynamic> _normalize(Map<String, dynamic> r) {
  final total = (r['total'] ?? r['totalAfterDiscount'] ?? r['subtotal'] ?? 0) as num;
  final depositPercent = (r['depositPercent'] ?? 50) as num;
  final expected = (r['expectedDepositAmount'] ?? (total * (depositPercent / 100)).round()) as num;
  final paid = (r['paidTotalAmount'] ?? 0) as num;
  return {
    ...r,
    'total': total.toInt(),
    'availabilityStatus': r['availabilityStatus'] ?? (r['statutReservation'] == 'En attente' ? 'pending' : 'available'),
    'bookingStatus': r['bookingStatus'] ?? 'pending',
    'paymentStatus': r['paymentStatus'] ?? 'deposit_unpaid',
    'depositPercent': depositPercent.toInt(),
    'expectedDepositAmount': expected.toInt(),
    'paidDepositAmount': (r['paidDepositAmount'] ?? 0) as num,
    'paidTotalAmount': paid.toInt(),
    'remainingAmount': (r['remainingAmount'] ?? (total - paid)).toInt(),
  };
}

class ClientDashboardPage extends StatefulWidget { const ClientDashboardPage({super.key}); @override State<ClientDashboardPage> createState() => _ClientDashboardPageState(); }
class _ClientDashboardPageState extends State<ClientDashboardPage> { int i = 0; final tabs = const ['Accueil', 'Réserver', 'Mes réservations']; @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('Espace cliente'), actions: [TextButton(onPressed: AuthService().signOut, child: const Text('Déconnexion'))]), body: Column(children: [Wrap(children: [for (int x = 0; x < tabs.length; x++) Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: Text(tabs[x]), selected: i == x, onSelected: (_) => setState(() => i = x), selectedColor: _black, labelStyle: TextStyle(color: i == x ? _white : _black)))]), Expanded(child: IndexedStack(index: i, children: const [Center(child: Text('Bienvenue')), ReservationPage(), ClientReservationsView()]))])); }

class ReservationPage extends StatefulWidget { const ReservationPage({super.key}); @override State<ReservationPage> createState() => _ReservationPageState(); }
class _ReservationPageState extends State<ReservationPage> {
  final selected = <String, Map<String, dynamic>>{}; DateTime? date; TimeOfDay? time; final phone = TextEditingController();
  int get subtotal => selected.values.fold(0, (s, e) => s + ((e['price'] as int) * (e['quantity'] as int)));
  List<Map<String, dynamic>> _fallback() => ServiceCatalogService.defaultServices.where((e) => e['isActive'] == true).map((e) => {'id': e['name'], ...e}).toList();
  Future<void> _submit() async {
    final u = FirebaseAuth.instance.currentUser!;
    final total = subtotal;
    await ReservationService().createReservation({'clientUid': u.uid, 'clientName': u.displayName ?? '', 'clientEmail': u.email ?? '', 'clientPhone': phone.text, 'prestations': selected.values.toList(), 'date': Timestamp.fromDate(date!), 'heure': time!.format(context), 'total': total, 'depositPercent': 50, 'expectedDepositAmount': (total * .5).round(), 'paidDepositAmount': 0, 'paidTotalAmount': 0, 'remainingAmount': total, 'availabilityStatus': 'pending', 'bookingStatus': 'pending', 'paymentStatus': 'deposit_unpaid', 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: ServiceCatalogService().watchServices(activeOnly: true), builder: (_, s) {
        final rows = s.hasData && s.data!.docs.isNotEmpty ? s.data!.docs.map((d) => {'id': d.id, ...d.data(), 'price': (d.data()['price'] as num).toInt()}).toList() : _fallback();
        return ListView(padding: const EdgeInsets.all(12), children: [for (final r in rows) CheckboxListTile(value: selected.containsKey(r['id']), title: Text('${r['name']} • ${_f(r['price'])}'), onChanged: (v) => setState(() => v == true ? selected[r['id']] = {'serviceId': r['id'], 'name': r['name'], 'price': r['price'], 'quantity': 1} : selected.remove(r['id']))), TextField(controller: phone, decoration: const InputDecoration(labelText: 'Téléphone')), ListTile(title: Text(date == null ? 'Date' : DateFormat('dd/MM/yyyy').format(date!)), onTap: () async => setState(() async => date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2032), initialDate: DateTime.now()))), ListTile(title: Text(time == null ? 'Heure' : time!.format(context)), onTap: () async { final t = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (t != null) setState(() => time = t); }), FilledButton(onPressed: selected.isNotEmpty && date != null && time != null ? _submit : null, child: Text('Réserver • ${_f(subtotal)}'))]);
      });
}

class ClientReservationsView extends StatelessWidget { const ClientReservationsView({super.key}); @override Widget build(BuildContext context) { final uid = FirebaseAuth.instance.currentUser!.uid; return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: ReservationService().clientReservations(uid), builder: (_, s) { if (!s.hasData) return const Center(child: CircularProgressIndicator()); final docs = s.data!.docs; return ListView(padding: const EdgeInsets.all(12), children: docs.map((d) { final r = _normalize(d.data()); return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${DateFormat('dd/MM/yyyy').format((r['date'] as Timestamp).toDate())} • ${r['heure']}'), const SizedBox(height: 6), Wrap(spacing: 8, runSpacing: 8, children: [_badge(r['availabilityStatus'], r['availabilityStatus']), _badge(r['bookingStatus'], r['bookingStatus']), _badge(r['paymentStatus'], r['paymentStatus'])]), const SizedBox(height: 6), Text('Total: ${_f(r['total'])} | Acompte attendu: ${_f(r['expectedDepositAmount'])}\nPayé: ${_f(r['paidTotalAmount'])} | Reste: ${_f(r['remainingAmount'])}'), Wrap(children: [if (r['availabilityStatus'] == 'available' && r['bookingStatus'] == 'waiting_client_confirmation') TextButton(onPressed: () => ReservationService().updateWorkflow(id: d.id, bookingStatus: 'confirmed'), child: const Text('Confirmer ma réservation')), if (['waiting_client_confirmation', 'confirmed'].contains(r['bookingStatus'])) TextButton(onPressed: () => _reqReschedule(context, d.id), child: const Text('Repousser la date')), if (r['bookingStatus'] != 'completed') TextButton(onPressed: () => ReservationService().updateWorkflow(id: d.id, bookingStatus: 'cancelled_by_client', cancelledBy: 'client'), child: const Text('Annuler'))])]))); }).toList()); }); } }

Future<void> _reqReschedule(BuildContext context, String id) async { DateTime? d; TimeOfDay? t; final reason = TextEditingController(); await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Demande de report'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: reason, decoration: const InputDecoration(labelText: 'Motif')), TextButton(onPressed: () async => d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2032), initialDate: DateTime.now()), child: const Text('Nouvelle date')), TextButton(onPressed: () async => t = await showTimePicker(context: context, initialTime: TimeOfDay.now()), child: const Text('Nouvelle heure'))]), actions: [FilledButton(onPressed: () async { if (d != null && t != null) { await ReservationService().updateWorkflow(id: id, bookingStatus: 'reschedule_requested', extra: {'requestedRescheduleDate': Timestamp.fromDate(d!), 'requestedRescheduleTime': t!.format(context), 'rescheduleReason': reason.text}); } if (context.mounted) Navigator.pop(context); }, child: const Text('Envoyer'))])); }

class AdminDashboardPage extends StatefulWidget { const AdminDashboardPage({super.key}); @override State<AdminDashboardPage> createState() => _AdminDashboardPageState(); }
class _AdminDashboardPageState extends State<AdminDashboardPage> { int i = 0; final tabs = const ['Vue d’ensemble', 'Demandes en attente', 'Réservations confirmées', 'Demandes de report', 'Calendrier', 'Prestations', 'Clientes', 'Finances', 'Historique', 'Paramètres']; @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('Administration'), actions: [TextButton(onPressed: AuthService().signOut, child: const Text('Déconnexion'))]), body: Column(children: [SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (int x = 0; x < tabs.length; x++) Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: Text(tabs[x]), selected: i == x, onSelected: (_) => setState(() => i = x)))])), Expanded(child: IndexedStack(index: i, children: const [AdminOverviewPage(), AdminPendingPage(), AdminConfirmedPage(), AdminReschedulePage(), AdminCalendarPage(), AdminServicesPage(), AdminClientsPage(), AdminFinancePage(), AdminHistoryPage(), Center(child: Text('Paramètres'))]))])); }

class _ResStream extends StatelessWidget { const _ResStream({required this.child}); final Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>) child; @override Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: ReservationService().allReservations(), builder: (_, s) => !s.hasData ? const Center(child: CircularProgressIndicator()) : child(s.data!.docs)); }
class AdminOverviewPage extends StatelessWidget { const AdminOverviewPage({super.key}); @override Widget build(BuildContext context) => const Center(child: Text('Vue pro')); }
class AdminPendingPage extends StatelessWidget { const AdminPendingPage({super.key}); @override Widget build(BuildContext context) => _ResStream(child: (docs) => ListView(children: docs.where((d){final r=_normalize(d.data());return r['bookingStatus']=='pending'||r['availabilityStatus']=='pending';}).map((d)=>AdminReservationTile(doc:d,mode:'pending')).toList())); }
class AdminConfirmedPage extends StatelessWidget { const AdminConfirmedPage({super.key}); @override Widget build(BuildContext context) => _ResStream(child: (docs) => ListView(children: docs.where((d){final b=_normalize(d.data())['bookingStatus']; return b=='confirmed'||b=='waiting_client_confirmation';}).map((d)=>AdminReservationTile(doc:d,mode:'confirmed')).toList())); }
class AdminReschedulePage extends StatelessWidget { const AdminReschedulePage({super.key}); @override Widget build(BuildContext context) => _ResStream(child: (docs) => ListView(children: docs.where((d)=>_normalize(d.data())['bookingStatus']=='reschedule_requested').map((d)=>AdminReservationTile(doc:d,mode:'reschedule')).toList())); }
class AdminHistoryPage extends StatelessWidget { const AdminHistoryPage({super.key}); @override Widget build(BuildContext context) => _ResStream(child: (docs) => ListView(children: docs.where((d){final b=_normalize(d.data())['bookingStatus']; return b=='completed'||b.toString().startsWith('cancelled');}).map((d)=>AdminReservationTile(doc:d,mode:'history')).toList())); }

class AdminReservationTile extends StatelessWidget {
  const AdminReservationTile({super.key, required this.doc, required this.mode}); final QueryDocumentSnapshot<Map<String, dynamic>> doc; final String mode;
  @override Widget build(BuildContext context) { final r = _normalize(doc.data());
    return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['clientName']} • ${r['clientPhone']}'), Text('${DateFormat('dd/MM').format((r['date'] as Timestamp).toDate())} ${r['heure']} • ${_f(r['total'])}'), Wrap(spacing: 8, children: [_badge(r['availabilityStatus'], r['availabilityStatus']), _badge(r['bookingStatus'], r['bookingStatus']), _badge(r['paymentStatus'], r['paymentStatus'])]), Wrap(children: [if (mode == 'pending') TextButton(onPressed: () => ReservationService().updateWorkflow(id: doc.id, availabilityStatus: 'available', bookingStatus: 'waiting_client_confirmation'), child: const Text('Disponible')), if (mode == 'pending') TextButton(onPressed: () => ReservationService().updateWorkflow(id: doc.id, availabilityStatus: 'unavailable', bookingStatus: 'unavailable'), child: const Text('Non disponible')), if (mode == 'confirmed') TextButton(onPressed: () => _depositDialog(context, doc.id, r), child: const Text('Valider acompte')), if (mode == 'confirmed') TextButton(onPressed: () => ReservationService().markPaid(id: doc.id, total: r['total']), child: const Text('Marquer soldé')), if (mode == 'confirmed') TextButton(onPressed: () => ReservationService().updateWorkflow(id: doc.id, bookingStatus: 'completed'), child: const Text('Marquer accomplie')), if (mode == 'reschedule') TextButton(onPressed: () => ReservationService().acceptReschedule(id: doc.id, date: r['requestedRescheduleDate'], time: r['requestedRescheduleTime']), child: const Text('Accepter report')), if (mode == 'reschedule') TextButton(onPressed: () => ReservationService().updateWorkflow(id: doc.id, bookingStatus: 'reschedule_refused'), child: const Text('Refuser report')), TextButton(onPressed: () => launchUrl(Uri.parse('https://wa.me/$kAdminWhatsApp')), child: const Text('WhatsApp'))])])));
  }
}

Future<void> _depositDialog(BuildContext context, String id, Map<String, dynamic> r) async { final c = TextEditingController(text: '${r['expectedDepositAmount']}'); await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Valider acompte'), content: TextField(controller: c, keyboardType: TextInputType.number), actions: [FilledButton(onPressed: () async { final paid = int.tryParse(c.text) ?? 0; await ReservationService().recordDeposit(id: id, total: r['total'], paidNow: paid); if (context.mounted) Navigator.pop(context); }, child: const Text('Valider'))])); }

class AdminCalendarPage extends StatelessWidget { const AdminCalendarPage({super.key}); @override Widget build(BuildContext context) => _ResStream(child: (docs) { final by = <String, List<Map<String, dynamic>>>{}; for (final d in docs) { final r = _normalize(d.data()); final day = DateFormat('yyyy-MM-dd').format((r['date'] as Timestamp).toDate()); by.putIfAbsent(day, () => []).add(r); } final now = DateTime.now(); return GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7), itemCount: DateUtils.getDaysInMonth(now.year, now.month), itemBuilder: (_, i) { final day = DateTime(now.year, now.month, i + 1); final k = DateFormat('yyyy-MM-dd').format(day); final count = by[k]?.length ?? 0; return Card(child: InkWell(onTap: count == 0 ? null : () => showModalBottomSheet(context: context, builder: (_) => ListView(children: by[k]!.map((r) => ListTile(title: Text('${r['heure']} ${r['clientName']}'), subtitle: Text('${r['bookingStatus']} | ${r['paymentStatus']}'))).toList())), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${i + 1}'), if (count > 0) const Icon(Icons.circle, size: 8, color: Colors.red)])))); }); }); }

class AdminServicesPage extends StatefulWidget { const AdminServicesPage({super.key}); @override State<AdminServicesPage> createState()=>_AdminServicesPageState(); }
class _AdminServicesPageState extends State<AdminServicesPage>{ final c=ServiceCatalogService(); @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:c.watchServices(),builder:(_,s){ if(!s.hasData) return const Center(child:CircularProgressIndicator()); final rows=s.data!.docs; return ListView(padding: const EdgeInsets.all(12),children:[if(rows.isEmpty) FilledButton(onPressed:()=>c.initializeDefaultServicesIfEmpty(), child: const Text('Initialiser les prestations par défaut')),FilledButton(onPressed:()=>_serviceDialog(context), child: const Text('Ajouter prestation')),...rows.map((d){final r=d.data(); return Card(child:ListTile(title:Text('${r['name']} • ${_f((r['price']??0) as int)}'),subtitle:Text('${r['description']}\n${r['quantityType']} • ${(r['isActive']??true)?'Actif':'Inactif'}'),trailing:Wrap(children:[IconButton(onPressed:()=>_serviceDialog(context,data:{'id':d.id,...r}), icon: const Icon(Icons.edit)),IconButton(onPressed:()=>c.updateService(d.id, {'isActive': !(r['isActive']??true)}), icon: const Icon(Icons.toggle_on)),IconButton(onPressed:()=>c.deleteService(d.id), icon: const Icon(Icons.delete))])));})]);}); Future<void> _serviceDialog(BuildContext context,{Map<String,dynamic>? data}) async {final name=TextEditingController(text:data?['name']??''); final desc=TextEditingController(text:data?['description']??''); final price=TextEditingController(text:'${data?['price']??0}'); String qty=data?['quantityType']??'personne'; bool active=data?['isActive']??true; await showDialog(context: context, builder:(_)=>AlertDialog(content:Column(mainAxisSize: MainAxisSize.min,children:[TextField(controller:name),TextField(controller:desc),TextField(controller:price),DropdownButtonFormField(value:qty,items: const [DropdownMenuItem(value:'personne',child:Text('personne')),DropdownMenuItem(value:'session',child:Text('session')),DropdownMenuItem(value:'photo',child:Text('photo')),DropdownMenuItem(value:'fixe',child:Text('fixe'))],onChanged:(v)=>qty=v!),SwitchListTile(value:active,onChanged:(v)=>active=v,title: const Text('Actif'))]),actions:[FilledButton(onPressed:() async {if(data==null){await c.createService(name:name.text, description:desc.text, price:int.tryParse(price.text)??0, quantityType:qty, isActive:active);} else {await c.updateService(data['id'], {'name':name.text,'description':desc.text,'price':int.tryParse(price.text)??0,'quantityType':qty,'isActive':active});} if(context.mounted)Navigator.pop(context);}, child: const Text('Enregistrer'))])); }}
class AdminClientsPage extends StatelessWidget { const AdminClientsPage({super.key}); @override Widget build(BuildContext context)=>_ResStream(child:(docs){final map=<String,Map<String,dynamic>>{}; for(final d in docs){final r=_normalize(d.data()); final k=(r['clientUid']??r['clientEmail']).toString(); final m=map.putIfAbsent(k,()=>{'name':r['clientName'],'email':r['clientEmail'],'phone':r['clientPhone'],'count':0,'reserved':0,'paid':0,'remaining':0}); m['count']=m['count']+1; m['reserved']=m['reserved']+r['total']; m['paid']=m['paid']+r['paidTotalAmount']; m['remaining']=m['remaining']+r['remainingAmount'];} return ListView(children:map.values.map((c)=>ListTile(title:Text('${c['name']} (${c['count']})'),subtitle:Text('${c['email']} • ${c['phone']}\nRéservé: ${_f(c['reserved'])} | Payé: ${_f(c['paid'])} | Reste: ${_f(c['remaining'])}'))).toList());}); }
class AdminFinancePage extends StatelessWidget { const AdminFinancePage({super.key}); @override Widget build(BuildContext context)=>_ResStream(child:(docs){int enc=0,rest=0,pot=0,real=0,dep=0,conf=0,comp=0; final clients=<String>{}; for(final d in docs){final r=_normalize(d.data()); final b=r['bookingStatus']; final cancelled=b=='cancelled_by_client'||b=='cancelled_by_admin'; if(!cancelled) enc+=r['paidTotalAmount'] as int; if((b=='confirmed'||b=='completed') && (r['remainingAmount'] as int)>0) rest+=r['remainingAmount'] as int; if(['pending','waiting_client_confirmation','confirmed'].contains(b)) pot+=r['total'] as int; if(b=='completed'){real+=r['paidTotalAmount'] as int; comp++;} dep+=r['paidDepositAmount'] as int; if(b=='confirmed') conf++; clients.add((r['clientUid']??r['clientEmail']).toString()); } return ListView(padding: const EdgeInsets.all(12),children:[Card(child:ListTile(title: const Text('Argent encaissé'),trailing:Text(_f(enc)))),Card(child:ListTile(title: const Text('Reste à encaisser'),trailing:Text(_f(rest)))),Card(child:ListTile(title: const Text('CA potentiel'),trailing:Text(_f(pot)))),Card(child:ListTile(title: const Text('Revenus réalisés'),trailing:Text(_f(real)))),Card(child:ListTile(title: const Text('Acomptes reçus'),trailing:Text(_f(dep)))),Card(child:ListTile(title: const Text('Nombre de clientes'),trailing:Text('${clients.length}'))),Card(child:ListTile(title: const Text('Réservations confirmées'),trailing:Text('$conf'))),Card(child:ListTile(title: const Text('Prestations accomplies'),trailing:Text('$comp')))]);}); }
