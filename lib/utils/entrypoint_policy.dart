enum EntryPointDestination {
  publicLanding,
  loginWall,
  appShell,
}

const String kAppHost = 'app.immogestion.app';
const Set<String> kPublicLandingHosts = {
  'immogestion.app',
  'www.immogestion.app',
};

bool isAppHost(String host) => host == kAppHost;

bool isPublicLandingHost(String host) => kPublicLandingHosts.contains(host);

bool isPublicLandingPath(String path) {
  return path.isEmpty || path == '/' || path == '/index.html';
}

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
  if (isAppHost(location.host)) {
    return isLoggedIn ? EntryPointDestination.appShell : EntryPointDestination.loginWall;
  }

  if (isPublicLandingHost(location.host)) {
    return isPublicLandingPath(location.path)
        ? EntryPointDestination.publicLanding
        : EntryPointDestination.loginWall;
  }

  return isLoggedIn ? EntryPointDestination.appShell : EntryPointDestination.loginWall;
}
