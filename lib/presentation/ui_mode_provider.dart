import 'package:flutter_riverpod/flutter_riverpod.dart';

// false = Show New HTML UI
// true = Show Original Debug UI
final useDebugUiProvider = StateProvider<bool>((ref) => false);
