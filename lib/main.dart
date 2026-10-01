import 'package:receipta/core/config/env.dart';
import 'package:receipta/core/network/api_client.dart';
import 'package:receipta/core/services/auth_service.dart';
import 'package:receipta/core/services/hce_service.dart';
import 'package:receipta/core/services/nfc_service.dart';
import 'package:receipta/data/repositories/auth_repository.dart';
import 'package:receipta/data/repositories/claim_device_repository.dart';
import 'package:receipta/data/repositories/claims_repository.dart';
import 'package:receipta/data/repositories/receipts_repository.dart';
import 'package:receipta/presentation/cubit/auth_cubit.dart';
import 'package:receipta/presentation/cubit/auth_state.dart';
import 'package:receipta/presentation/cubit/receipts_list_cubit.dart';
import 'package:receipta/presentation/screens/auth_page.dart';
import 'package:receipta/presentation/screens/receipt_flow_screen.dart';
import 'package:receipta/presentation/screens/receipts_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// AuthState is also exported by supabase_flutter (an auth-change event type);
// hidden here since main.dart only needs Supabase.initialize and our own
// presentation-layer AuthState.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Composition root: services and repositories are constructed once here
    // and passed down explicitly (no singleton/service locator).
    final apiClient = ApiClient();
    final authRepository = AuthRepository(authService: AuthService());
    final claimsRepository = ClaimsRepository(apiClient: apiClient);
    final deviceRepository = ClaimDeviceRepository(hceService: HceService(), nfcService: const NfcService());
    final receiptsRepository = ReceiptsRepository(apiClient: apiClient);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit(authRepository)),
        BlocProvider(create: (_) => ReceiptsListCubit(receiptsRepository)),
      ],
      child: MaterialApp(
        home: AuthGate(
          claimsRepository: claimsRepository,
          deviceRepository: deviceRepository,
          receiptsRepository: receiptsRepository,
        ),
      ),
    );
  }
}

/// Shows a splash while a persisted session is being resolved, the auth
/// screen while signed out, and the main app once signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.claimsRepository,
    required this.deviceRepository,
    required this.receiptsRepository,
  });

  final ClaimsRepository claimsRepository;
  final ClaimDeviceRepository deviceRepository;
  final ReceiptsRepository receiptsRepository;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.unknown:
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          case AuthStatus.authenticating:
          case AuthStatus.unauthenticated:
            return const AuthPage();
          case AuthStatus.authenticated:
            return HomePage(
              claimsRepository: claimsRepository,
              deviceRepository: deviceRepository,
              receiptsRepository: receiptsRepository,
            );
        }
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.claimsRepository,
    required this.deviceRepository,
    required this.receiptsRepository,
  });

  final ClaimsRepository claimsRepository;
  final ClaimDeviceRepository deviceRepository;
  final ReceiptsRepository receiptsRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
        ],
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReceiptFlowScreen(
                      claimsRepository: claimsRepository,
                      deviceRepository: deviceRepository,
                      receiptsRepository: receiptsRepository,
                    ),
                  ),
                );
              },
              child: Text("Receipta (Production)"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReceiptsListScreen(receiptsRepository: receiptsRepository),
                  ),
                );
              },
              child: Text("My Receipts"),
            ),
          ],
        ),
      ),
    );
  }
}
