import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ui/finni_app.dart';
import 'ui/preview/preview_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode) {
    throw StateError('The preview adapter must not run in release mode.');
  }
  runApp(FinniApp(service: PreviewService(), previewMode: true));
}
