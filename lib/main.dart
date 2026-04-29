import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const int kTravelFee = 10000;
const String kDefaultWhatsAppNumber = '2250700000000';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BookingApp());
}

enum ReservationStatus { pending, confirmed, completed, cancelled, postponed }
enum PaymentStatus { unpaid, depositPaid, paid }
enum ServiceLocation { studio, travel }

String reservationStatusLabel(ReservationStatus status) => switch (status) {
  ReservationStatus.pending => 'En attente',
  ReservationStatus.confirmed => 'Confirmée',
  ReservationStatus.completed => 'Accomplie',
  ReservationStatus.cancelled => 'Annulée',
  ReservationStatus.postponed => 'Reportée',
};

String paymentStatusLabel(PaymentStatus status) => switch (status) {
  PaymentStatus.unpaid => 'Non payé',
  PaymentStatus.depositPaid => 'Acompte payé',
  PaymentStatus.paid => 'Payé',
};

class ServiceItem {
  const ServiceItem({required this.id, required this.name, required this.price});

  final String id;
  final String name;
  final int price;

  Map<String, dynamic> toMap() => {'nom': name, 'prix': price};
}

class Reservation {
  Reservation({
    required this.id,
    required this.nomClient,
    required this.telephone,
    required this.prestations,
    required this.lieu,
    required this.fraisDeplacement,
    required this.adresse,
    required this.date,
    required this.heure,
    required this.total,
    required this.statutReservation,
    required this.statutPaiement,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String nomClient;
  final String telephone;
  final List<Map<String, dynamic>> prestations;
  final String lieu;
  final int fraisDeplacement;
  final String adresse;
  final DateTime date;
  final String heure;
  final int total;
  final String statutReservation;
  final String statutPaiement;
  final String message;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Reservation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Reservation(
      id: doc.id,
      nomClient: data['nomClient'] ?? '',
      telephone: data['telephone'] ?? '',
      prestations: List<Map<String, dynamic>>.from(data['prestations'] ?? []),
      lieu: data['lieu'] ?? 'Studio',
      fraisDeplacement: data['fraisDeplacement'] ?? 0,
      adresse: data['adresse'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      heure: data['heure'] ?? '',
      total: data['total'] ?? 0,
      statutReservation: data['statutReservation'] ?? 'En attente',
      statutPaiement: data['statutPaiement'] ?? 'Non payé',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class BookingApp extends StatelessWidget {
  const BookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Instant Maquillage Booking',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(primary: Colors.black),
      ),
      home: FutureBuilder(
        future: Firebase.initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return const Scaffold(body: Center(child: Text('Configurer Firebase pour continuer.')));
          }
          return const RootShell();
        },
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  bool adminMode = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(adminMode ? 'Espace admin' : 'Réservation beauté'),
        actions: [TextButton(onPressed: () => setState(() => adminMode = !adminMode), child: Text(adminMode ? 'Mode cliente' : 'Mode admin', style: const TextStyle(color: Colors.black)))],
      ),
      body: adminMode ? const AdminGate() : const ClientBookingFlow(),
    );
  }
}

class ClientBookingFlow extends StatefulWidget { const ClientBookingFlow({super.key}); @override State<ClientBookingFlow> createState() => _ClientBookingFlowState(); }
class _ClientBookingFlowState extends State<ClientBookingFlow> {
  int step = 0;
  final services = const [
    ServiceItem(id: 'event', name: 'Maquillage événement / maquillage simple', price: 25000),
    ServiceItem(id: 'bride', name: 'Maquillage mariée', price: 35000),
    ServiceItem(id: 'class', name: 'Cours d’auto-maquillage', price: 50000),
    ServiceItem(id: 'hair', name: 'Conseils beauté coiffure', price: 60000),
  ];
  final selected = <String>{};
  ServiceLocation location = ServiceLocation.studio;
  final nom = TextEditingController(); final tel = TextEditingController(); final adresse = TextEditingController(); final msg = TextEditingController();
  DateTime? date; TimeOfDay? time;
  int get total => services.where((e) => selected.contains(e.id)).fold(0, (a, b) => a + b.price) + (location == ServiceLocation.travel ? kTravelFee : 0);

  Future<void> save() async {
    final coll = FirebaseFirestore.instance.collection('reservations');
    final ref = coll.doc();
    await ref.set({
      'id': ref.id,
      'nomClient': nom.text.trim(),
      'telephone': tel.text.trim(),
      'prestations': services.where((e) => selected.contains(e.id)).map((e) => e.toMap()).toList(),
      'lieu': location == ServiceLocation.studio ? 'Studio' : 'Déplacement',
      'fraisDeplacement': location == ServiceLocation.travel ? kTravelFee : 0,
      'adresse': location == ServiceLocation.travel ? adresse.text.trim() : '',
      'date': Timestamp.fromDate(date!),
      'heure': time!.format(context),
      'total': total,
      'statutReservation': 'En attente',
      'statutPaiement': 'Non payé',
      'message': msg.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override Widget build(BuildContext context) {
    final pad = const EdgeInsets.all(16);
    if (step == 0) return Padding(padding: pad, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Réservez votre prestation beauté', style: TextStyle(fontSize: 30,fontWeight: FontWeight.w300)), const SizedBox(height: 8), const Text('Parcours rapide, premium et minimaliste.'), const SizedBox(height: 24), FilledButton(onPressed: ()=>setState(()=>step=1), child: const Text('Commencer ma réservation'))]));
    if (step == 1) return ListView(padding: pad, children: [for (final s in services) CheckboxListTile(value: selected.contains(s.id), onChanged: (v)=>setState(()=>v==true?selected.add(s.id):selected.remove(s.id)), title: Text(s.name), subtitle: Text('${s.price} FCFA')), RadioListTile(value: ServiceLocation.studio, groupValue: location, onChanged: (v)=>setState(()=>location=v!), title: const Text('Au studio : 0 FCFA')), RadioListTile(value: ServiceLocation.travel, groupValue: location, onChanged: (v)=>setState(()=>location=v!), title: const Text('Déplacement : +10 000 FCFA')), Text('Total: $total FCFA'), FilledButton(onPressed: selected.isEmpty?null:()=>setState(()=>step=2), child: const Text('Continuer'))]);
    if (step == 2) return ListView(padding: pad, children: [TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom complet')), TextField(controller: tel, decoration: const InputDecoration(labelText: 'Téléphone WhatsApp')), ListTile(title: Text(date==null?'Date souhaitée':DateFormat('dd/MM/yyyy').format(date!)), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030), initialDate: DateTime.now()); if (d!=null) setState(()=>date=d);}), ListTile(title: Text(time==null?'Heure souhaitée':time!.format(context)), onTap: () async { final t = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (t!=null) setState(()=>time=t);}), if (location==ServiceLocation.travel) TextField(controller: adresse, decoration: const InputDecoration(labelText: 'Adresse')), TextField(controller: msg, decoration: const InputDecoration(labelText: 'Message facultatif')), FilledButton(onPressed: nom.text.isEmpty||tel.text.isEmpty||date==null||time==null||(location==ServiceLocation.travel&&adresse.text.isEmpty)?null:()=>setState(()=>step=3), child: const Text('Voir récapitulatif'))]);
    return ListView(padding: pad, children: [Text('Nom: ${nom.text}'), Text('Téléphone: ${tel.text}'), Text('Lieu: ${location == ServiceLocation.studio ? 'Studio' : 'Déplacement'}'), Text('Date: ${DateFormat('dd/MM/yyyy').format(date!)}'), Text('Heure: ${time!.format(context)}'), Text('Total: $total FCFA'), FilledButton(onPressed: () async { await save(); if (!mounted) return; setState(()=>step=4);}, child: const Text('Valider et enregistrer')), if (step==4) const SizedBox()]);
  }
}

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) => snapshot.data == null ? const AdminLoginPage() : const AdminDashboard(),
    );
  }
}

class AdminLoginPage extends StatefulWidget { const AdminLoginPage({super.key}); @override State<AdminLoginPage> createState()=>_AdminLoginPageState(); }
class _AdminLoginPageState extends State<AdminLoginPage> {
  final email = TextEditingController(); final password = TextEditingController(); String? err;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: Column(children: [TextField(controller: email, decoration: const InputDecoration(labelText: 'Email admin')), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe')), FilledButton(onPressed: () async { try { await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: password.text); } catch (e) { setState(()=>err='Connexion impossible'); } }, child: const Text('Connexion')), if (err!=null) Text(err!, style: const TextStyle(color: Colors.red))]));
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Column(children: [
        const TabBar(isScrollable: true, tabs: [Tab(text: 'Dashboard'), Tab(text: 'À confirmer'), Tab(text: 'Confirmées'), Tab(text: 'Accomplies'), Tab(text: 'Historique'), Tab(text: 'Calendrier'), Tab(text: 'Gains')]),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('reservations').snapshots(),
          builder: (context, s) {
            final docs = s.data?.docs.map(Reservation.fromDoc).toList() ?? [];
            return TabBarView(children: [
              _StatsPage(items: docs),
              _StatusPage(items: docs, status: 'En attente'),
              _StatusPage(items: docs, status: 'Confirmée'),
              _StatusPage(items: docs, status: 'Accomplie'),
              _HistoryPage(items: docs),
              _CalendarPage(items: docs),
              _EarningsPage(items: docs),
            ]);
          },
        ))
      ]),
    );
  }
}

class _StatsPage extends StatelessWidget { const _StatsPage({required this.items}); final List<Reservation> items; @override Widget build(BuildContext context) { final now=DateTime.now(); int count(String s)=>items.where((e)=>e.statutReservation==s).length; int monthTotal(Iterable<Reservation> it)=>it.where((e)=>e.date.month==now.month&&e.date.year==now.year).fold(0,(a,b)=>a+b.total); return ListView(padding: const EdgeInsets.all(12), children: [for (final e in {'Nombre total':items.length,'Réservations aujourd’hui':items.where((r)=>DateUtils.isSameDay(r.date, now)).length,'Réservations à venir':items.where((r)=>r.date.isAfter(now)).length,'Réservations en attente':count('En attente'),'Réservations confirmées':count('Confirmée'),'Prestations accomplies':count('Accomplie'),'Réservations annulées':count('Annulée'),'Gains estimés du mois':monthTotal(items.where((e)=>e.statutReservation=='En attente'||e.statutReservation=='Confirmée')),'Gains confirmés du mois':monthTotal(items.where((e)=>e.statutReservation=='Confirmée')),'Gains réalisés du mois':monthTotal(items.where((e)=>e.statutReservation=='Accomplie'))}.entries) Card(child: ListTile(title: Text(e.key), trailing: Text('${e.value}')))]); }}
class _StatusPage extends StatelessWidget { const _StatusPage({required this.items, required this.status}); final List<Reservation> items; final String status; @override Widget build(BuildContext context) { final filtered=items.where((e)=>e.statutReservation==status).toList(); return ListView(children: filtered.map((e)=>ListTile(title: Text(e.nomClient), subtitle: Text('${DateFormat('dd/MM/yyyy').format(e.date)} • ${e.heure} • ${e.total} FCFA'), trailing: PopupMenuButton<String>(onSelected: (v)=>FirebaseFirestore.instance.collection('reservations').doc(e.id).update({'statutReservation': v,'updatedAt': FieldValue.serverTimestamp()}), itemBuilder: (_)=>const [PopupMenuItem(value:'Confirmée',child:Text('Confirmer')),PopupMenuItem(value:'Annulée',child:Text('Annuler')),PopupMenuItem(value:'Reportée',child:Text('Reporter')),PopupMenuItem(value:'Accomplie',child:Text('Accomplie'))]))).toList()); }}
class _HistoryPage extends StatelessWidget { const _HistoryPage({required this.items}); final List<Reservation> items; @override Widget build(BuildContext context) => ListView(children: items.map((e)=>ListTile(title: Text(e.nomClient), subtitle: Text('${e.statutReservation} • ${DateFormat('dd/MM/yyyy').format(e.date)}'))).toList()); }
class _CalendarPage extends StatelessWidget { const _CalendarPage({required this.items}); final List<Reservation> items; @override Widget build(BuildContext context) { final grouped=<String,List<Reservation>>{}; for(final r in items){ final key=DateFormat('yyyy-MM-dd').format(r.date); grouped.putIfAbsent(key, ()=>[]).add(r);} return ListView(children: grouped.entries.map((e)=>ExpansionTile(title: Text(e.key), children: e.value.map((r)=>ListTile(title: Text('${r.heure} - ${r.nomClient}'), subtitle: Text('${r.total} FCFA • ${r.statutReservation}'))).toList())).toList()); }}
class _EarningsPage extends StatelessWidget { const _EarningsPage({required this.items}); final List<Reservation> items; @override Widget build(BuildContext context) { int sum(String s)=>items.where((e)=>e.statutReservation==s).fold(0,(a,b)=>a+b.total); final byService=<String,int>{}; for(final r in items){ for(final p in r.prestations){ final name=(p['nom']??'').toString(); byService[name]=(byService[name]??0)+(p['prix'] as int? ?? 0);} } final travelCount=items.where((e)=>e.lieu=='Déplacement').length; final travelAmount=items.fold(0,(a,b)=>a+b.fraisDeplacement); return ListView(padding: const EdgeInsets.all(12),children:[Text('Gains estimés: ${sum('En attente')+sum('Confirmée')} FCFA'),Text('Gains confirmés: ${sum('Confirmée')} FCFA'),Text('Gains réalisés: ${sum('Accomplie')} FCFA'),Text('Gains annulés: ${sum('Annulée')} FCFA'),const SizedBox(height:8),...byService.entries.map((e)=>Text('${e.key}: ${e.value} FCFA')),Text('Nombre de déplacements: $travelCount'),Text('Montant frais déplacement: $travelAmount FCFA')]); }}
