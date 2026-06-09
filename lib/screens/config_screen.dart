import 'package:flutter/material.dart';
import '../services/store_config.dart';
import '../services/responsive.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late TextEditingController _storeCtrl;
  late TextEditingController _entityCtrl;
  late TextEditingController _pluralCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _debtorCtrl;
  late TextEditingController _subtitleCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = StoreConfig.instance;
    _storeCtrl = TextEditingController(text: c.storeName);
    _entityCtrl = TextEditingController(text: c.entityName);
    _pluralCtrl = TextEditingController(text: c.entityPlural);
    _currencyCtrl = TextEditingController(text: c.currency);
    _debtorCtrl = TextEditingController(text: c.debtorTitle);
    _subtitleCtrl = TextEditingController(text: c.appSubtitle);
  }

  @override
  void dispose() {
    _storeCtrl.dispose();
    _entityCtrl.dispose();
    _pluralCtrl.dispose();
    _currencyCtrl.dispose();
    _debtorCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await StoreConfig.instance.save(
        storeName: _storeCtrl.text.trim(),
        entityName: _entityCtrl.text.trim(),
        entityPlural: _pluralCtrl.text.trim(),
        currency: _currencyCtrl.text.trim(),
        debtorTitle: _debtorCtrl.text.trim(),
        appSubtitle: _subtitleCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = R.sp(context, 16);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de tienda')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field('Nombre de la tienda', _storeCtrl, 'Kiosco Escolar'),
            SizedBox(height: s),
            _field('Nombre de la entidad (singular)', _entityCtrl, 'Estudiante'),
            SizedBox(height: s),
            _field('Nombre de la entidad (plural)', _pluralCtrl, 'Estudiantes'),
            SizedBox(height: s),
            _field('Símbolo de moneda', _currencyCtrl, r'$'),
            SizedBox(height: s),
            _field('Título reporte de deudores', _debtorCtrl, 'Reporte de Deudores'),
            SizedBox(height: s),
            _field('Subtítulo del app', _subtitleCtrl, 'Resumen general del kiosco'),
            SizedBox(height: s * 2),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Guardar configuración'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: s),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
