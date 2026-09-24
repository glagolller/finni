import 'package:flutter/widgets.dart';

import 'ui/finni_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinniBootstrapRoot());
}

/// Production composition root. The logic owner will supply the real service.
class FinniBootstrapRoot extends StatelessWidget {
  const FinniBootstrapRoot({super.key});

  @override
  Widget build(BuildContext context) => const FinniApp();
}
