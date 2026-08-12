import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/database_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';
import 'features/settings/presentation/providers/communication_settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseService.instance.initialize();

  runApp(const ProviderScope(child: _AppBootstrap()));
}

class _AppBootstrap extends ConsumerStatefulWidget {
  const _AppBootstrap();

  @override
  ConsumerState<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<_AppBootstrap> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(syncServiceProvider).start());
  }

  @override
  Widget build(BuildContext context) {
    return const PharmaFlowApp();
  }
}

class PharmaFlowApp extends StatelessWidget {
  const PharmaFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PharmaFlow',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fa'), Locale('en')],
      locale: const Locale('fa'),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: AppTextStyles.fontFamily,
        scaffoldBackgroundColor: AppColors.scaffold,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        dividerColor: AppColors.divider,
      ),
    );
  }
}
