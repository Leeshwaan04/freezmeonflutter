import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freezme/main.dart';
import 'package:freezme/ui/components/freezme_logo.dart';

void main() {
  // This test doubles as a manual utility for regenerating large PNG exports.
  // It stays skipped in CI to keep runs deterministic and fast.
  testWidgets(
    'export Freezme logo asset',
    (tester) async {
      final boundaryKey = GlobalKey();
      final logo = Transform.scale(
        scale: 8,
        child: const FreezmeLogo(
          size: LogoSize.lg,
          showText: false,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child:
                  SizedBox(width: 400, height: 400, child: Center(child: logo)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final render =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      final uiImage = await render.toImage(pixelRatio: 3.0);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      for (final path in [
        'assets/images/freezme_logo_hd.png',
        'marketing-site/freezme-logo.png',
      ]) {
        final file = File(path);
        await file.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
        // ignore: avoid_print
        print('Wrote ${file.path}');
      }
    },
    skip: true,
  );
}
