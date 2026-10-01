import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReceiptaApp extends StatelessWidget {
  const ReceiptaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Receipta',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ReceiptPage(),
    );
  }
}

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({super.key});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  static const MethodChannel _channel =
      MethodChannel('receipta/hce');

  String status = 'Ready';

  final String receiptText = '''
Ahmed Ibrahim
Receipt #12345
Product: Coffee
Quantity: 2
Total: 250 EGP
''';

  final String receiptUrl =
      'https://example.com/receipt/12345';

  Future<void> startHce() async {
    try {
      final result = await _channel.invokeMethod(
        'startHce',
        {
          'text': receiptText,
          'url': receiptUrl,
        },
      );

      setState(() {
        status = result?.toString() ?? 'HCE started';
      });
    } on PlatformException catch (e) {
      setState(() {
        status = 'Error: ${e.message}';
      });
    }
  }

  Future<void> stopHce() async {
    try {
      final result = await _channel.invokeMethod(
        'stopHce',
      );

      setState(() {
        status = result?.toString() ?? 'HCE stopped';
      });
    } on PlatformException catch (e) {
      setState(() {
        status = 'Error: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipta'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Receipt',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Text(receiptText),

            const SizedBox(height: 10),

            Text(
              receiptUrl,
              style: const TextStyle(
                color: Colors.blue,
              ),
            ),

            const SizedBox(height: 40),

            Text(
              status,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: startHce,
              child: const Text(
                'Enable NFC Receipt',
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton(
              onPressed: stopHce,
              child: const Text(
                'Stop NFC',
              ),
            ),
          ],
        ),
      ),
    );
  }
}