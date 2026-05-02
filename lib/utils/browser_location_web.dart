import 'dart:html' as html;

Uri currentBrowserLocation() => Uri.parse(html.window.location.href);
