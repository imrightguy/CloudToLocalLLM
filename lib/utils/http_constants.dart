abstract class HttpStatus {
  static const int ok = 200;
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int internalServerError = 500;
  static const int serviceUnavailable = 503;

  const HttpStatus._();
}

abstract class TimeMs {
  static const int oneSecond = 1000;
  static const int thirtySeconds = 30000;
  static const int oneMinute = 60000;
  static const int fiveMinutes = 300000;
  static const int oneHour = 3600000;
  static const int oneDay = 86400000;
  static const int oneWeek = 604800000;

  const TimeMs._();
}
