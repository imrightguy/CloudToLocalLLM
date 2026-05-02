import 'dart:html' as html;

void openExternalUrl(String url) {
  html.window.location.assign(url);
}
