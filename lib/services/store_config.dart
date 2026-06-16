import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecreoConfig {
  String name;
  int startHour;
  int startMinute;
  int endHour;
  int endMinute;

  RecreoConfig({
    required this.name,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'startHour': startHour,
    'startMinute': startMinute,
    'endHour': endHour,
    'endMinute': endMinute,
  };

  factory RecreoConfig.fromJson(Map<String, dynamic> json) => RecreoConfig(
    name: json['name'] as String,
    startHour: json['startHour'] as int,
    startMinute: json['startMinute'] as int,
    endHour: json['endHour'] as int,
    endMinute: json['endMinute'] as int,
  );

  static List<RecreoConfig> defaults() => [
    RecreoConfig(name: 'Recreo 1', startHour: 10, startMinute: 0, endHour: 10, endMinute: 20),
    RecreoConfig(name: 'Recreo 2', startHour: 12, startMinute: 20, endHour: 12, endMinute: 40),
    RecreoConfig(name: 'Salida', startHour: 14, startMinute: 0, endHour: 15, endMinute: 0),
  ];
}

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
  List<RecreoConfig> _recreos = RecreoConfig.defaults();

  bool get loaded => _loaded;
  String get storeName => _storeName;
  String get entityName => _entityName;
  String get entityPlural => _entityPlural;
  String get currency => _currency;
  String get debtorTitle => _debtorTitle;
  String get appSubtitle => _appSubtitle;
  List<RecreoConfig> get recreos => _recreos;

  String entityLC() => _entityName.toLowerCase();
  String entityPluralLC() => _entityPlural.toLowerCase();

  Future<void> load() async {
    try {
      final data = await Supabase.instance.client
          .from('store_config')
          .select('value')
          .eq('key', 'app')
          .limit(1)
          .maybeSingle();
      if (data != null && data['value'] is Map) {
        final d = data['value'] as Map<String, dynamic>;
        _storeName = d['storeName'] as String? ?? _storeName;
        _entityName = d['entityName'] as String? ?? _entityName;
        _entityPlural = d['entityPlural'] as String? ?? _entityPlural;
        _currency = d['currency'] as String? ?? _currency;
        _debtorTitle = d['debtorTitle'] as String? ?? _debtorTitle;
        _appSubtitle = d['appSubtitle'] as String? ?? _appSubtitle;
        if (d['recreos'] != null) {
          _recreos = (d['recreos'] as List)
              .map((e) => RecreoConfig.fromJson(e as Map<String, dynamic>))
              .toList();
        }
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
    List<RecreoConfig>? recreos,
  }) async {
    _storeName = storeName ?? _storeName;
    _entityName = entityName ?? _entityName;
    _entityPlural = entityPlural ?? _entityPlural;
    _currency = currency ?? _currency;
    _debtorTitle = debtorTitle ?? _debtorTitle;
    _appSubtitle = appSubtitle ?? _appSubtitle;
    if (recreos != null) _recreos = recreos;

    await Supabase.instance.client.from('store_config').upsert({
      'key': 'app',
      'value': {
        'storeName': _storeName,
        'entityName': _entityName,
        'entityPlural': _entityPlural,
        'currency': _currency,
        'debtorTitle': _debtorTitle,
        'appSubtitle': _appSubtitle,
        'recreos': _recreos.map((r) => r.toJson()).toList(),
      },
    });
    notifyListeners();
  }
}
