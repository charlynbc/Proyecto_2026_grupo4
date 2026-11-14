import '../../../core/network/api_exception.dart';
import '../models/app_notification_page.dart';
import '../models/notification_query.dart';

abstract class NotificationRepository {
  Future<AppNotificationPage> list(NotificationQuery query);
}

enum NotificationFailure { unauthenticated, forbidden, other }

class NotificationException extends ApiException {
  const NotificationException(this.failure, [super.message]);

  final NotificationFailure failure;
}
