import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Foto de producto elegida por el usuario, ya lista para subir a Storage.
class PickedProductImage {
  /// Bytes comprimidos listos para `uploadProductImage`.
  final Uint8List bytes;

  /// Nombre de archivo con extension coherente con el formato final.
  final String name;

  const PickedProductImage({required this.bytes, required this.name});
}

/// Lado mayor al que se redimensiona una foto de producto.
///
/// La foto se muestra a 64 px en la lista y a ~1:1 en la grilla, asi que
/// 800 px alcanza de sobra incluso en pantallas grandes.
const int kProductImageMaxSide = 800;

/// Calidad JPEG de salida. 80 es el punto donde la diferencia visual deja de
/// notarse y el peso ya cae a decenas de kB.
const int kProductImageQuality = 80;

/// Abre el selector de imagenes del sistema y devuelve la foto comprimida.
///
/// Devuelve `null` si el usuario cancela, si no se pudieron leer los bytes o
/// si el formato no se puede procesar; en los dos ultimos casos avisa con un
/// SnackBar para que el admin sepa que la imagen quedo sin cargar.
Future<PickedProductImage?> pickCompressedProductImage(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);

  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.first;
  final raw = file.bytes;
  if (raw == null) {
    _notify(messenger, 'No se pudo leer la imagen elegida.');
    return null;
  }

  final compressed = await compressProductImageBytes(raw);
  if (compressed == null) {
    _notify(messenger, 'Formato de imagen no soportado. Usa JPG o PNG.');
    return null;
  }

  return PickedProductImage(bytes: compressed, name: _withJpgExtension(file.name));
}

/// Redimensiona y re-comprime una imagen en un isolate aparte.
///
/// Devuelve `null` cuando el formato de origen no se puede decodificar.
Future<Uint8List?> compressProductImageBytes(
  Uint8List source, {
  int maxSide = kProductImageMaxSide,
  int quality = kProductImageQuality,
}) {
  return compute(
    _compressInIsolate,
    _CompressRequest(source, maxSide, quality),
    debugLabel: 'compressProductImage',
  );
}

/// Misma compresion que [compressProductImageBytes] pero sincrona, sin
/// isolate. Existe para poder testearla sin depender de `compute`.
Uint8List? compressProductImageSync(
  Uint8List source, {
  int maxSide = kProductImageMaxSide,
  int quality = kProductImageQuality,
}) {
  return _compressImage(source, maxSide, quality);
}

class _CompressRequest {
  final Uint8List bytes;
  final int maxSide;
  final int quality;

  const _CompressRequest(this.bytes, this.maxSide, this.quality);
}

Uint8List? _compressInIsolate(_CompressRequest request) {
  return _compressImage(request.bytes, request.maxSide, request.quality);
}

Uint8List? _compressImage(Uint8List source, int maxSide, int quality) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return null;

  final longestSide =
      decoded.width >= decoded.height ? decoded.width : decoded.height;

  var output = decoded;
  if (longestSide > maxSide) {
    output = decoded.width >= decoded.height
        ? img.copyResize(
            decoded,
            width: maxSide,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            decoded,
            height: maxSide,
            interpolation: img.Interpolation.average,
          );
  }

  return Uint8List.fromList(
    img.encodeJpg(output, quality: quality),
  );
}

/// Reemplaza la extension original por `.jpg`, que es lo que realmente se
/// sube: el contenido se re-encodea siempre a JPEG.
String _withJpgExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final base = dot > 0 ? fileName.substring(0, dot) : fileName;
  return '$base.jpg';
}

void _notify(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
