import 'package:flutter/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinniBootstrapRoot());
}

/// Empty integration point. The interface owner supplies the application UI.
class FinniBootstrapRoot extends StatelessWidget {
  const FinniBootstrapRoot({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
