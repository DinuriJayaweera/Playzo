import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'data/game_repository.dart';
import 'services/audio_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  final repo = await GameRepository.open();
  final state = AppState(repo, AudioService());
  await state.load();
  runApp(ArrowEscapeApp(state: state));
}

class ArrowEscapeApp extends StatefulWidget {
  const ArrowEscapeApp({super.key, required this.state});
  final AppState state;

  @override
  State<ArrowEscapeApp> createState() => _ArrowEscapeAppState();
}

class _ArrowEscapeAppState extends State<ArrowEscapeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Silence the music while the app is in the background.
    widget.state.audio.setPaused(state != AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => MaterialApp(
          title: 'Arrow Escape',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: widget.state.themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
