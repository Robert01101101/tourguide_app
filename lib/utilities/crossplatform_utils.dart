import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class CrossplatformUtils {

  CrossplatformUtils._();

  /// to help detect whether the web app is running on mobile or web
  static bool isMobile() {
    if (!kIsWeb) return true;
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('mobi');
  }
}