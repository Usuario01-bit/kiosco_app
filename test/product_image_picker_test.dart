import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kiosco_app/services/product_image_picker.dart';

/// Pinta un disco solido. Se hace pixel a pixel a proposito: el fixture tiene
/// que parecerse a una foto de producto (fondo claro y un sujeto con bordes),
/// que es lo que realmente comprime bien en JPEG.
void _disc(img.Image image, int cx, int cy, int radius, img.Color color) {
  final r2 = radius * radius;
  for (var y = cy - radius; y <= cy + radius; y++) {
    if (y < 0 || y >= image.height) continue;
    for (var x = cx - radius; x <= cx + radius; x++) {
      if (x < 0 || x >= image.width) continue;
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy <= r2) image.setPixel(x, y, color);
    }
  }
}

/// Foto sintetica del tamano pedido, guardada como JPEG de calidad alta para
/// simular la salida de la camara del celular.
Uint8List _syntheticPhoto(int width, int height) {
  final image = img.Image(width: width, height: height);
  final background = img.ColorRgb8(247, 247, 245);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixel(x, y, background);
    }
  }

  final cx = width ~/ 2;
  final cy = height ~/ 2;
  _disc(image, cx, cy, (width * 0.32).round(), img.ColorRgb8(214, 138, 74));
  _disc(image, cx - width ~/ 6, cy + height ~/ 9, (width * 0.13).round(),
      img.ColorRgb8(178, 62, 48));
  _disc(image, cx + width ~/ 6, cy - height ~/ 10, (width * 0.11).round(),
      img.ColorRgb8(120, 170, 96));

  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

void main() {
  test('una foto de camara queda en 800 px de lado mayor y mucho mas liviana',
      () {
    final original = _syntheticPhoto(1200, 1600);

    final compressed = compressProductImageSync(original);

    expect(compressed, isNotNull);
    final decoded = img.decodeJpg(compressed!);
    expect(decoded, isNotNull);
    expect(decoded!.height, kProductImageMaxSide);
    expect(decoded.width, 600);
    expect(compressed.length, lessThan(original.length));
    expect(compressed.length, lessThan(150 * 1024));
  });

  test('una foto horizontal recorta por el ancho', () {
    final original = _syntheticPhoto(1600, 1200);

    final decoded = img.decodeJpg(compressProductImageSync(original)!)!;

    expect(decoded.width, kProductImageMaxSide);
    expect(decoded.height, 600);
  });

  test('no agranda una imagen que ya es mas chica que el limite', () {
    final original = _syntheticPhoto(300, 200);

    final decoded = img.decodeJpg(compressProductImageSync(original)!)!;

    expect(decoded.width, 300);
    expect(decoded.height, 200);
  });

  test('devuelve null cuando los bytes no son una imagen', () {
    final garbage = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

    expect(compressProductImageSync(garbage), isNull);
  });
}
