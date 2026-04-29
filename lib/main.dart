import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const String kWhatsAppNumber = '2250700000000';
const int kTravelFee = 10000;

void main() {
  runApp(const BeautyBookingApp());
}

class BeautyBookingApp extends StatelessWidget {
  const BeautyBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Booking Beauté',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.black,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.2,
            height: 1.2,
          ),
          headlineSmall: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w400,
          ),
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
        useMaterial3: true,
      ),
      home: const BookingFlowPage(),
    );
  }
}

class ServiceItem {
  ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    this.selected = false,
  });

  final String id;
  final String name;
  final int price;
  bool selected;
}

enum ServiceLocation { studio, travel }

class BookingFlowPage extends StatefulWidget {
  const BookingFlowPage({super.key});

  @override
  State<BookingFlowPage> createState() => _BookingFlowPageState();
}

class _BookingFlowPageState extends State<BookingFlowPage> {
  int _step = 0;

  final List<ServiceItem> _services = [
    ServiceItem(
      id: 'event',
      name: 'Maquillage événement / maquillage simple',
      price: 25000,
    ),
    ServiceItem(id: 'bride', name: 'Maquillage mariée', price: 35000),
    ServiceItem(id: 'class', name: 'Cours d’auto-maquillage', price: 50000),
    ServiceItem(
      id: 'advice',
      name: 'Conseils beauté coiffure',
      price: 60000,
    ),
  ];

  ServiceLocation _location = ServiceLocation.studio;

  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _timeCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int calculateTotal() {
    final serviceTotal = _services
        .where((service) => service.selected)
        .fold<int>(0, (sum, service) => sum + service.price);

    if (_location == ServiceLocation.travel) {
      return serviceTotal + kTravelFee;
    }
    return serviceTotal;
  }

  List<ServiceItem> get _selectedServices =>
      _services.where((service) => service.selected).toList();

  String get _locationLabel => _location == ServiceLocation.studio
      ? 'Au studio'
      : 'Déplacement (+10 000 FCFA)';

  String _formatPrice(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      final indexFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(' ');
      }
    }
    return '${buffer.toString()} FCFA';
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      initialDate: now,
      helpText: 'Date souhaitée',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );

    if (result != null) {
      setState(() {
        _dateCtrl.text =
            '${result.day.toString().padLeft(2, '0')}/${result.month.toString().padLeft(2, '0')}/${result.year}';
      });
    }
  }

  Future<void> _selectTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );

    if (result != null) {
      setState(() {
        _timeCtrl.text = result.format(context);
      });
    }
  }

  Future<void> _sendToWhatsApp() async {
    final services = _selectedServices
        .map((e) => '- ${e.name} (${_formatPrice(e.price)})')
        .join('\n');

    final message = '''Bonjour, je souhaite confirmer une réservation beauté.

Prestations:
$services

Lieu: $_locationLabel
Total: ${_formatPrice(calculateTotal())}

Nom: ${_fullNameCtrl.text.trim()}
Téléphone: ${_phoneCtrl.text.trim()}
Date: ${_dateCtrl.text.trim()}
Heure: ${_timeCtrl.text.trim()}
${_location == ServiceLocation.travel ? 'Adresse: ${_addressCtrl.text.trim()}\n' : ''}Précision: ${_noteCtrl.text.trim().isEmpty ? 'Aucune' : _noteCtrl.text.trim()}
''';

    final uri = Uri.parse(
      'https://wa.me/$kWhatsAppNumber?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir WhatsApp.')),
      );
    }
  }

  bool get _canGoToForm => _selectedServices.isNotEmpty;

  bool get _canGoToSummary {
    if (_fullNameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _dateCtrl.text.trim().isEmpty ||
        _timeCtrl.text.trim().isEmpty) {
      return false;
    }

    if (_location == ServiceLocation.travel && _addressCtrl.text.trim().isEmpty) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width < 700 ? 520.0 : 820.0;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: switch (_step) {
              0 => _buildWelcome(),
              1 => _buildServices(),
              2 => _buildForm(),
              _ => _buildSummary(),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Réservez votre prestation beauté',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Choisissez vos services, calculez le total et confirmez sur WhatsApp en quelques secondes.',
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(() => _step = 1),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Commencer ma réservation'),
          ),
        ),
      ],
    );
  }

  Widget _buildServices() {
    final total = calculateTotal();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle('Choix des prestations'),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              ..._services.map(_buildServiceCard),
              const SizedBox(height: 16),
              _buildLocationCard(),
              const SizedBox(height: 90),
            ],
          ),
        ),
        _buildTotalAndAction(
          total,
          label: 'Continuer',
          onPressed: _canGoToForm ? () => setState(() => _step = 2) : null,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle('Vos informations'),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              _inputField(controller: _fullNameCtrl, label: 'Nom complet'),
              _inputField(
                controller: _phoneCtrl,
                label: 'Téléphone WhatsApp',
                keyboardType: TextInputType.phone,
              ),
              _inputField(
                controller: _dateCtrl,
                label: 'Date souhaitée',
                readOnly: true,
                onTap: _selectDate,
              ),
              _inputField(
                controller: _timeCtrl,
                label: 'Heure souhaitée',
                readOnly: true,
                onTap: _selectTime,
              ),
              if (_location == ServiceLocation.travel)
                _inputField(controller: _addressCtrl, label: 'Adresse'),
              _inputField(
                controller: _noteCtrl,
                label: 'Message / précision (facultatif)',
                maxLines: 3,
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 1),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black12),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retour'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _canGoToSummary ? () => setState(() => _step = 3) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Voir le récapitulatif'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final total = calculateTotal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle('Confirmation'),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              _summaryBlock(
                'Prestations choisies',
                _selectedServices
                    .map((item) => '${item.name} — ${_formatPrice(item.price)}')
                    .join('\n'),
              ),
              _summaryBlock('Lieu', _locationLabel),
              _summaryBlock('Total', _formatPrice(total)),
              _summaryBlock('Nom', _fullNameCtrl.text.trim()),
              _summaryBlock('Téléphone', _phoneCtrl.text.trim()),
              _summaryBlock('Date', _dateCtrl.text.trim()),
              _summaryBlock('Heure', _timeCtrl.text.trim()),
              if (_location == ServiceLocation.travel)
                _summaryBlock('Adresse', _addressCtrl.text.trim()),
              _summaryBlock(
                'Précision',
                _noteCtrl.text.trim().isEmpty ? 'Aucune' : _noteCtrl.text.trim(),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 2),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black12),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Modifier'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _sendToWhatsApp,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Envoyer sur WhatsApp'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepTitle(String label) {
    return Text(label, style: Theme.of(context).textTheme.headlineSmall);
  }

  Widget _buildServiceCard(ServiceItem item) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE7E7E7)),
      ),
      child: CheckboxListTile(
        value: item.selected,
        onChanged: (value) {
          setState(() {
            item.selected = value ?? false;
          });
        },
        activeColor: Colors.black,
        checkColor: Colors.white,
        title: Text(item.name),
        subtitle: Text(_formatPrice(item.price)),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE7E7E7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lieu de la prestation',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            RadioListTile<ServiceLocation>(
              value: ServiceLocation.studio,
              groupValue: _location,
              activeColor: Colors.black,
              title: const Text('Au studio'),
              subtitle: const Text('Aucun supplément'),
              onChanged: (value) => setState(() => _location = value!),
            ),
            RadioListTile<ServiceLocation>(
              value: ServiceLocation.travel,
              groupValue: _location,
              activeColor: Colors.black,
              title: const Text('Déplacement'),
              subtitle: const Text('+10 000 FCFA'),
              onChanged: (value) => setState(() => _location = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalAndAction(
    int total, {
    required String label,
    VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7E7E7)),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Total: ${_formatPrice(total)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE7E7E7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE7E7E7)),
          ),
        ),
      ),
    );
  }

  Widget _summaryBlock(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(content),
        ],
      ),
    );
  }
}
