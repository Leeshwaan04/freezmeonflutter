import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const bool _runExport = bool.fromEnvironment('EXPORT_ICON');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'export Freezme icon from SVG',
    (tester) async {
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox.square(
                dimension: 1024,
                child: SvgPicture.asset('assets/images/freezme_icon_vector.svg'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('assets/images/freezme_icon_1024.png');
      await file.writeAsBytes(byteData!.buffer.asUint8List(), flush: true);
    },
    skip: !_runExport,
  );
}
