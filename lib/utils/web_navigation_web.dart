// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

void openExternalUrl(String url) {
  html.window.location.assign(url);
}
