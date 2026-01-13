// KOD BLOK BAŞLANGICI (navigation_service.dart)
import 'package:flutter/material.dart';

// Bu dosya, uygulamamızın "yol haritasına" (Navigator)
// her yerden erişebilmemizi sağlayan evrensel bir anahtar tutar.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
// KOD BLOK SONU