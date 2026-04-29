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
const _lightGray = Color(0xFFF4F4F4);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BookingApp());
}

class BookingApp extends StatelessWidget {
  const BookingApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _white,
          textTheme: GoogleFonts.interTextTheme(),
          cardTheme: const CardThemeData(
            color: _white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16)), side: BorderSide(color: Color(0xFFE7E7E7))),
          ),
        ),
        home: const AppRoot(),
      );
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
            return FutureBuilder<String>(
              future: _loadRole(auth.data!.uid),
              builder: (_, role) => Scaffold(
                body: role.hasData ? (role.data == 'admin' ? const AdminDashboardPage() : const ClientDashboardPage()) : const Center(child: CircularProgressIndicator()),
              ),
            );
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
    Timer(const Duration(milliseconds: 1600), () => mounted ? setState(() => done = true) : null);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => done
      ? widget.child
      : Scaffold(backgroundColor: _black, body: Center(child: FadeTransition(opacity: c, child: Text('Instant Maquillage', style: GoogleFonts.playfairDisplay(color: _white, fontSize: 36)))));
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Instant Maquillage', style: GoogleFonts.playfairDisplay(fontSize: 32)),
                  const SizedBox(height: 8),
                  const Text('Booking beauté premium'),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: AuthService().signInWithGoogleWeb, style: FilledButton.styleFrom(backgroundColor: _black), child: const Text('Connexion Google')),
                ]),
              ),
            ),
          ),
        ),
      );
}

class ClientDashboardPage extends StatefulWidget { const ClientDashboardPage({super.key}); @override State<ClientDashboardPage> createState()=>_ClientDashboardPageState(); }
class _ClientDashboardPageState extends State<ClientDashboardPage>{ int i=0; final tabs=const ['Accueil','Réserver','Mes réservations','Historique','Profil']; @override Widget build(BuildContext c)=>Scaffold(appBar: AppBar(title: const Text('Espace cliente'),actions:[TextButton(onPressed: AuthService().signOut, child: const Text('Déconnexion'))],bottom: PreferredSize(preferredSize: const Size.fromHeight(58), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for(int x=0;x<tabs.length;x++) Padding(padding: const EdgeInsets.fromLTRB(6,0,6,10), child: ChoiceChip(label: Text(tabs[x]), selected: i==x, onSelected: (_)=>setState(()=>i=x), selectedColor:_black, labelStyle: TextStyle(color: i==x?_white:_black), side: const BorderSide(color: Color(0xFFDCDCDC))))]))), body: IndexedStack(index: i, children: const [ClientHomePage(), ReservationPage(), ClientReservationsView(), ClientReservationsView(showHistory: true), Center(child: Text('Profil'))])); }

class ClientHomePage extends StatelessWidget { const ClientHomePage({super.key}); @override Widget build(BuildContext context)=>const Padding(padding: EdgeInsets.all(16), child: Text('Bienvenue. Réservez vos prestations en quelques clics.')); }

class ReservationPage extends StatefulWidget { const ReservationPage({super.key}); @override State<ReservationPage> createState()=>_ReservationPageState(); }
class _ReservationPageState extends State<ReservationPage>{
  final _catalog=ServiceCatalogService(); final selected=<String,Map<String,dynamic>>{}; final name=TextEditingController(); final phone=TextEditingController(); DateTime? date; TimeOfDay? time;
  int _line(Map<String,dynamic>e)=>(e['price'] as int)*(e['quantity'] as int); int get subtotal=>selected.values.fold(0,(s,e)=>s+_line(e));
  List<Map<String,dynamic>> _fallback()=>ServiceCatalogService.defaultServices.where((e)=>e['isActive']==true).map((e)=>{'id':e['name'],...e,'price':(e['price'] as num).toInt()}).toList();
  void _toggle(Map<String,dynamic>s,bool v){setState((){if(!v){selected.remove(s['id']);return;} selected[s['id']]={'serviceId':s['id'],'name':s['name'],'price':s['price'],'quantityType':s['quantityType'],'quantity':1};});}
  Future<void> _submit() async { final u=FirebaseAuth.instance.currentUser!; final prestations=selected.values.map((e)=>{...e,'lineTotal':_line(e)}).toList(); await ReservationService().createReservation({'clientUid':u.uid,'clientName':name.text,'clientEmail':u.email ?? '','clientPhone':phone.text,'prestations':prestations,'date':Timestamp.fromDate(date!),'heure':time!.format(context),'subtotal':subtotal,'totalAfterDiscount':subtotal,'statutReservation':'En attente','statutPaiement':'Non soldé','createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()}); await launchUrl(Uri.parse('https://wa.me/$kAdminWhatsApp')); }
  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:_catalog.watchServices(),builder:(_,snap){final services = !snap.hasData ? _fallback() : (snap.data!.docs.map((d){final data=d.data(); return {'id':data['id']??d.id,'name':data['name']??'','description':data['description']??'','price':(data['price'] as num?)?.toInt() ??0,'quantityType':data['quantityType']??'fixe','isActive':data['isActive']??true};}).where((e)=>e['isActive']==true).toList()); final rows=services.isEmpty?_fallback():services; return ListView(padding: const EdgeInsets.all(16),children:[for(final s in rows) Card(child: CheckboxListTile(value:selected.containsKey(s['id']),onChanged:(v)=>_toggle(s,v??false),title:Text('${s['name']} • ${s['price']} FCFA'),subtitle:Text('${s['description']} (${serviceTypeLabels[s['quantityType']]})'))),TextField(controller:name,decoration: const InputDecoration(labelText:'Nom')),TextField(controller:phone,decoration: const InputDecoration(labelText:'Téléphone')),ListTile(title: Text(date==null?'Date':DateFormat('dd/MM/yyyy').format(date!)),onTap:() async {final d=await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2032), initialDate: DateTime.now()); if(d!=null)setState(()=>date=d);} ),ListTile(title: Text(time==null?'Heure':time!.format(context)),onTap:() async {final t=await showTimePicker(context: context, initialTime: TimeOfDay.now()); if(t!=null)setState(()=>time=t);} ),FilledButton(onPressed:selected.isNotEmpty&&date!=null&&time!=null?_submit:null,style: FilledButton.styleFrom(backgroundColor:_black), child: Text('Valider • $subtotal FCFA'))]);});
}

class ClientReservationsView extends StatelessWidget { const ClientReservationsView({super.key,this.showHistory=false}); final bool showHistory; @override Widget build(BuildContext context){final uid=FirebaseAuth.instance.currentUser!.uid; return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:ReservationService().clientReservations(uid), builder:(_,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator()); final docs=snap.data!.docs.where((d)=>showHistory?true:d.data()['statutReservation']!='Accomplie').toList(); return ListView(padding: const EdgeInsets.all(12),children:docs.map((d){final r=d.data(); return Card(child: ListTile(title: Text('${DateFormat('dd/MM/yyyy').format((r['date'] as Timestamp).toDate())} • ${r['heure']}'), subtitle: Text('${r['statutReservation']} · ${r['statutPaiement']}\nTotal: ${r['totalAfterDiscount'] ?? r['subtotal']} FCFA')));}).toList());}); }}

class AdminDashboardPage extends StatefulWidget { const AdminDashboardPage({super.key}); @override State<AdminDashboardPage> createState()=>_AdminDashboardPageState(); }
class _AdminDashboardPageState extends State<AdminDashboardPage>{ int i=0; final tabs=const ['Dashboard','Calendrier','Réservations','Prestations','Clientes','Gains','Historique','Paramètres']; @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title: const Text('Administration'),actions:[TextButton(onPressed: AuthService().signOut, child: const Text('Déconnexion'))],bottom: PreferredSize(preferredSize: const Size.fromHeight(58), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:[for(int x=0;x<tabs.length;x++) Padding(padding: const EdgeInsets.fromLTRB(6,0,6,10), child: ChoiceChip(label: Text(tabs[x]), selected: i==x, onSelected: (_)=>setState(()=>i=x), selectedColor: _black, labelStyle: TextStyle(color: i==x?_white:_black), side: const BorderSide(color: Color(0xFFDCDCDC))))]))), body: IndexedStack(index:i, children: const [AdminOverviewPage(),AdminCalendarPage(),AdminReservationsPage(),AdminServicesPage(),AdminClientsPage(),AdminEarningsPage(),AdminHistoryPage(),Center(child: Text('Paramètres'))])); }

class _AdminReservationsBuilder extends StatelessWidget { const _AdminReservationsBuilder({required this.builder}); final Widget Function(List<Map<String,dynamic>>) builder; @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: ReservationService().allReservations(), builder:(_,snap){if(!snap.hasData) return const Center(child:CircularProgressIndicator()); return builder(snap.data!.docs.map((e)=>e.data()).toList());}); }
class AdminOverviewPage extends StatelessWidget { const AdminOverviewPage({super.key}); @override Widget build(BuildContext context)=>_AdminReservationsBuilder(builder:(rows){final today=DateTime.now(); bool same(Timestamp t){final d=t.toDate(); return d.year==today.year&&d.month==today.month&&d.day==today.day;} int byStatus(String s)=>rows.where((r)=>r['statutReservation']==s).length; final cards=[('Réservations aujourd’hui',rows.where((r)=>same(r['date'])).length),('À confirmer',byStatus('En attente')),('Confirmées',byStatus('Confirmée')),('Accomplies',byStatus('Accomplie')),('Paiements non soldés',rows.where((r)=>r['statutPaiement']!='Soldé').length)]; return ListView(padding: const EdgeInsets.all(16),children:[Wrap(spacing:12,runSpacing:12,children:[for(final c in cards) SizedBox(width:220,child:Card(color:_lightGray,child:Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text(c.$1),const SizedBox(height:6),Text('${c.$2}',style: const TextStyle(fontSize:24,fontWeight:FontWeight.w700))]))))]),const SizedBox(height:16),const Text('Prochaines réservations',style: TextStyle(fontWeight: FontWeight.bold)),...rows.take(5).map((r)=>AdminReservationTile(r:r,compact:true))]);}); }

class AdminReservationsPage extends StatefulWidget { const AdminReservationsPage({super.key}); @override State<AdminReservationsPage> createState()=>_AdminReservationsPageState(); }
class _AdminReservationsPageState extends State<AdminReservationsPage>{ String status='Toutes'; final statuses=['Toutes','En attente','Confirmée','Accomplie','Annulée','Reportée']; @override Widget build(BuildContext context)=>Column(children:[SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:[for(final s in statuses) Padding(padding: const EdgeInsets.all(6), child: ChoiceChip(label: Text(s), selected: status==s, onSelected: (_)=>setState(()=>status=s)))])),Expanded(child:_AdminReservationsBuilder(builder:(rows){final data=status=='Toutes'?rows:rows.where((r)=>r['statutReservation']==status).toList(); return ListView(padding: const EdgeInsets.all(12),children:data.map((r)=>AdminReservationTile(r:r)).toList());}))]); }

class AdminReservationTile extends StatelessWidget { const AdminReservationTile({super.key, required this.r,this.compact=false}); final Map<String,dynamic> r; final bool compact; @override Widget build(BuildContext context){final id=r['id']; final total=r['totalAfterDiscount'] ?? r['subtotal'] ?? 0; return Card(child: ListTile(title: Text('${r['clientName']} • ${r['heure']}'),subtitle: Text('${r['statutReservation']} · ${r['statutPaiement']} • $total FCFA'),trailing: Wrap(spacing:4,children:[if(!compact) IconButton(onPressed:()=>ReservationService().updateStatus(id:id,reservationStatus:'Confirmée'), icon: const Icon(Icons.check_circle_outline)),if(!compact) IconButton(onPressed:()=>ReservationService().updateStatus(id:id,reservationStatus:'Accomplie'), icon: const Icon(Icons.task_alt)),if(!compact) IconButton(onPressed:()=>ReservationService().updateStatus(id:id,reservationStatus:'Annulée'), icon: const Icon(Icons.cancel_outlined)),if(!compact) IconButton(onPressed:()=>ReservationService().updateStatus(id:id,reservationStatus:'Reportée'), icon: const Icon(Icons.update)),if(!compact) IconButton(onPressed:()=>ReservationService().updateStatus(id:id,paymentStatus:'Acompte payé'), icon: const Icon(Icons.payments_outlined)),if(!compact) IconButton(onPressed:()=>ReservationService().updateStatus(id:id,paymentStatus:'Soldé'), icon: const Icon(Icons.price_check)),IconButton(onPressed:()=>launchUrl(Uri.parse('https://wa.me/${r['clientPhone']}')), icon: const Icon(Icons.message_outlined))]))); }}

class AdminCalendarPage extends StatelessWidget { const AdminCalendarPage({super.key}); @override Widget build(BuildContext context)=>const _AdminReservationsBuilder(builder:_build); static Widget _build(List<Map<String,dynamic>> rows){final byDay=<String,List<Map<String,dynamic>>>{}; for(final r in rows){final d=(r['date'] as Timestamp).toDate(); final k=DateFormat('yyyy-MM-dd').format(d); byDay.putIfAbsent(k,()=>[]).add(r);} final now=DateTime.now(); final first=DateTime(now.year,now.month,1); return GridView.builder(padding: const EdgeInsets.all(16),gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),itemCount: DateUtils.getDaysInMonth(now.year, now.month),itemBuilder:(c,i){final day=first.add(Duration(days:i)); final k=DateFormat('yyyy-MM-dd').format(day); final count=byDay[k]?.length ?? 0; return InkWell(onTap: count==0?null:()=>showModalBottomSheet(context:c,builder:(_)=>ListView(children:byDay[k]!.map((r)=>ListTile(title: Text('${r['heure']} • ${r['clientName']}'),subtitle: Text('${r['statutReservation']} · ${r['statutPaiement']} • ${r['totalAfterDiscount'] ?? r['subtotal']} FCFA'))).toList())), child: Card(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,children:[Text('${day.day}'),if(count>0) const Icon(Icons.circle,size:8,color:Colors.red)]))));}); }}

class AdminHistoryPage extends StatelessWidget { const AdminHistoryPage({super.key}); @override Widget build(BuildContext context)=>_AdminReservationsBuilder(builder:(rows)=>ListView(children:rows.where((r)=>r['statutReservation']=='Accomplie'||r['statutReservation']=='Annulée').map((r)=>AdminReservationTile(r:r)).toList())); }
class AdminClientsPage extends StatelessWidget { const AdminClientsPage({super.key}); @override Widget build(BuildContext context)=>_AdminReservationsBuilder(builder:(rows){final map=<String,int>{}; for(final r in rows){map[r['clientEmail'] ?? 'Sans email']=(map[r['clientEmail'] ?? 'Sans email'] ?? 0)+1;} return ListView(children:map.entries.map((e)=>ListTile(title: Text(e.key),trailing: Text('${e.value}'))).toList());}); }
class AdminEarningsPage extends StatelessWidget { const AdminEarningsPage({super.key}); @override Widget build(BuildContext context)=>_AdminReservationsBuilder(builder:(rows){final gains=rows.where((r)=>r['statutPaiement']=='Soldé').fold<int>(0,(s,r)=>s+((r['totalAfterDiscount'] ?? r['subtotal'] ?? 0) as int)); return Center(child: Text('Gains réalisés: $gains FCFA'));}); }

class AdminServicesPage extends StatefulWidget { const AdminServicesPage({super.key}); @override State<AdminServicesPage> createState()=>_AdminServicesPageState(); }
class _AdminServicesPageState extends State<AdminServicesPage>{ final _catalog=ServiceCatalogService(); @override Widget build(BuildContext context)=>Scaffold(body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:_catalog.watchServices(),builder:(_,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator()); final rows=snap.data!.docs.map((e)=>{'id':e.data()['id']??e.id,...e.data(),'price':(e.data()['price'] as num?)?.toInt() ?? 0,'isActive':e.data()['isActive']??true}).toList(); return ListView(padding: const EdgeInsets.all(12),children:[Row(children:[Expanded(child: FilledButton(onPressed: ()=>_serviceDialog(context), style: FilledButton.styleFrom(backgroundColor:_black), child: const Text('Ajouter'))),const SizedBox(width:8),Expanded(child: OutlinedButton(onPressed: () async {await _catalog.initializeDefaultServicesIfEmpty();}, child: const Text('Initialiser par défaut')))]),...rows.map((s)=>Card(child:ListTile(title: Text('${s['name']} • ${s['price']} FCFA'),subtitle: Text('${s['description']}\n${s['quantityType']} • ${s['isActive']?'Actif':'Inactif'}'),trailing: Wrap(children:[IconButton(onPressed: ()=>_serviceDialog(context,data:s), icon: const Icon(Icons.edit)),IconButton(onPressed: ()=>_catalog.updateService(s['id'], {'isActive': !(s['isActive'] as bool)}), icon: const Icon(Icons.toggle_on)),IconButton(onPressed: ()=>_catalog.deleteService(s['id']), icon: const Icon(Icons.delete_outline))]))))]);}));
  Future<void> _serviceDialog(BuildContext context,{Map<String,dynamic>? data}) async {final name=TextEditingController(text:data?['name']??''); final desc=TextEditingController(text:data?['description']??''); final price=TextEditingController(text:'${data?['price'] ?? 0}'); String qty=data?['quantityType'] ?? 'personne'; bool active=data?['isActive'] ?? true; await showDialog(context: context, builder:(_)=>AlertDialog(title: Text(data==null?'Nouvelle prestation':'Modifier prestation'),content: StatefulBuilder(builder:(context,set)=>Column(mainAxisSize: MainAxisSize.min,children:[TextField(controller:name,decoration: const InputDecoration(labelText:'Nom')),TextField(controller:desc,decoration: const InputDecoration(labelText:'Description')),TextField(controller:price,keyboardType: TextInputType.number,decoration: const InputDecoration(labelText:'Prix')),DropdownButtonFormField(value: qty, items: const [DropdownMenuItem(value:'personne',child:Text('personne')),DropdownMenuItem(value:'photo',child:Text('photo')),DropdownMenuItem(value:'session',child:Text('session')),DropdownMenuItem(value:'fixe',child:Text('fixe'))], onChanged:(v)=>set(()=>qty=v!)),SwitchListTile(value: active, onChanged:(v)=>set(()=>active=v), title: const Text('Actif'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context), child: const Text('Annuler')),FilledButton(onPressed:() async {if(data==null){await _catalog.createService(name:name.text.trim(), description:desc.text.trim(), price:int.tryParse(price.text) ?? 0, quantityType:qty, isActive:active);} else {await _catalog.updateService(data['id'], {'name':name.text.trim(),'description':desc.text.trim(),'price':int.tryParse(price.text) ?? 0,'quantityType':qty,'isActive':active});} if(context.mounted)Navigator.pop(context);}, child: const Text('Enregistrer'))])); }
}
