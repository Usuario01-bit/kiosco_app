import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StoreConfig extends ChangeNotifier {
  StoreConfig._();

  static final instance = StoreConfig._();

  bool _loaded = false;
  String _storeName = 'Kiosco Escolar';
  String _entityName = 'Estudiante';
  String _entityPlural = 'Estudiantes';
  String _currency = '\$';
  String _debtorTitle = 'Reporte de Deudores';
  String _appSubtitle = 'Resumen general del kiosco';

  bool get loaded => _loaded;
  String get storeName => _storeName;
  String get entityName => _entityName;
  String get entityPlural => _entityPlural;
  String get currency => _currency;
  String get debtorTitle => _debtorTitle;
  String get appSubtitle => _appSubtitle;

  String entityLC() => _entityName.toLowerCase();
  String entityPluralLC() => _entityPlural.toLowerCase();

  Future<void> load() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('config').doc('app').get();
      if (doc.exists) {
        final data = doc.data()!;
        _storeName = data['storeName'] as String? ?? _storeName;
        _entityName = data['entityName'] as String? ?? _entityName;
        _entityPlural = data['entityPlural'] as String? ?? _entityPlural;
        _currency = data['currency'] as String? ?? _currency;
        _debtorTitle = data['debtorTitle'] as String? ?? _debtorTitle;
        _appSubtitle = data['appSubtitle'] as String? ?? _appSubtitle;
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> save({
    String? storeName,
    String? entityName,
    String? entityPlural,
    String? currency,
    String? debtorTitle,
    String? appSubtitle,
  }) async {
    _storeName = storeName ?? _storeName;
    _entityName = entityName ?? _entityName;
    _entityPlural = entityPlural ?? _entityPlural;
    _currency = currency ?? _currency;
    _debtorTitle = debtorTitle ?? _debtorTitle;
    _appSubtitle = appSubtitle ?? _appSubtitle;

    await FirebaseFirestore.instance.collection('config').doc('app').set({
      'storeName': _storeName,
      'entityName': _entityName,
      'entityPlural': _entityPlural,
      'currency': _currency,
      'debtorTitle': _debtorTitle,
      'appSubtitle': _appSubtitle,
    });
    notifyListeners();
  }
}
