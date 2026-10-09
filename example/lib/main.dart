import 'package:flutter/widgets.dart';
import 'package:permate_attribution/permate_attribution.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PermateAttribution.onDeepLinkResolved = (result) {
    debugPrint('deep link: ${result.rawParams}');
  };

  await PermateAttribution.configure(
    appKey: const String.fromEnvironment('PERMATE_APP_KEY'),
  );
  await PermateAttribution.start();

  runApp(const SizedBox.shrink());
}
