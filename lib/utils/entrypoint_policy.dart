enum EntryPointDestination {
  loginWall,
  appShell,
}

const String kAppHost = 'app.immogestion.app';

bool isAppHost(String host) => host == kAppHost;

String normalizeAppPath(String path) {
  if (path.isEmpty) {
    return '/';
  }
  if (path == '/') {
    return path;
  }
  return path.replaceAll(RegExp(r'/+$'), '');
}

EntryPointDestination resolveEntryPointDestination({
  required Uri location,
  required bool isLoggedIn,
}) {
  return isLoggedIn ? EntryPointDestination.appShell : EntryPointDestination.loginWall;
}
