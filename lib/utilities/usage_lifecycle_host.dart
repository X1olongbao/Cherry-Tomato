import 'package:flutter/widgets.dart';
import '../services/app_usage_service.dart';

/// UsageLifecycleHost observes app lifecycle and records usage minutes.
/// Wrap your app with this widget to automatically start/stop tracking
/// when the app is opened, backgrounded, or closed.
class UsageLifecycleHost extends StatefulWidget {
  final Widget child;
  const UsageLifecycleHost({super.key, required this.child});

  @override
  State<UsageLifecycleHost> createState() => _UsageLifecycleHostState();
}

class _UsageLifecycleHostState extends State<UsageLifecycleHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start a session immediately when the host initializes (app just opened)
    AppUsageService.instance.startSession();
    // Prefetch current week data so stats page has initial values
    AppUsageService.instance.refreshCurrentWeek();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Persist any final usage before disposing
    AppUsageService.instance.endSessionAndPersist();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Respond to lifecycle transitions to ensure timely tracking.
    switch (state) {
      case AppLifecycleState.resumed:
        // App returned to foreground: start session.
        AppUsageService.instance.startSession();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is no longer in foreground: end session and persist.
        AppUsageService.instance.endSessionAndPersist();
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}