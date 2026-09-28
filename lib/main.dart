import 'package:flutter/material.dart';

import 'contracts/contracts.dart';
import 'logic.dart';
import 'ui/finni_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinniBootstrapRoot());
}

/// Opens the real local store; failure never falls back to test data.
class FinniBootstrapRoot extends StatefulWidget {
  const FinniBootstrapRoot({
    super.key,
    this.serviceFactory = createLogicService,
  });
  final Future<LogicService> Function() serviceFactory;

  @override
  State<FinniBootstrapRoot> createState() => _FinniBootstrapRootState();
}

class _FinniBootstrapRootState extends State<FinniBootstrapRoot> {
  late Future<({LogicService? service, bool failed})> service;
  Future<({LogicService? service, bool failed})> open() async {
    try {
      return (service: await widget.serviceFactory(), failed: false);
    } catch (_) {
      return (service: null, failed: true);
    }
  }

  @override
  void initState() {
    super.initState();
    service = open();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<({LogicService? service, bool failed})>(
        future: service,
        builder: (context, snapshot) {
          if (snapshot.data?.service != null) {
            return FinniApp(service: snapshot.data!.service);
          }
          return MaterialApp(
            home: Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (snapshot.data?.failed ?? false)
                              ? 'Не удалось открыть игру. Попробуй ещё раз.'
                              : 'Открываем игру…',
                        ),
                        if ((snapshot.data?.failed ?? false))
                          FilledButton(
                            onPressed: () => setState(() {
                              service = open();
                            }),
                            child: const Text('Повторить'),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
