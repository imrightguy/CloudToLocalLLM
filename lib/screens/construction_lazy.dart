import 'package:go_router/go_router.dart';
import 'construction_screen.dart';

/// Lazy-loaded construction screen routes
final constructionRoutes = [
  GoRoute(
    path: '/construction',
    name: 'construction',
    builder: (context, state) => const ConstructionScreen(),
  ),
];
