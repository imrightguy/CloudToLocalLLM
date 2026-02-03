import 'dart:async';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

/// Web implementation for loading Auth0 script
Future<void> loadAuth0Script() async {
  // Check if script is already present in the DOM
  final scripts = web.document.getElementsByTagName('script');
  bool isLoaded = false;
  for (int i = 0; i < scripts.length; i++) {
    final item = scripts.item(i);
    final scriptElement = item as web.HTMLScriptElement?;
    if (scriptElement != null && scriptElement.src.contains('auth0-spa-js')) {
      isLoaded = true;
      break;
    }
  }

  if (!isLoaded) {
    final script = web.HTMLScriptElement();
    script.src =
        'https://cdn.auth0.com/js/auth0-spa-js/2.1/auth0-spa-js.production.js';
    script.async = true;

    final completer = Completer<void>();
    script.onload = (web.Event e) {
      completer.complete();
    }.toJS;
    script.onerror = (web.Event e) {
      completer.completeError(Exception('Failed to load Auth0 SDK'));
    }.toJS;

    web.document.head!.appendChild(script);
    await completer.future;
  }
}
