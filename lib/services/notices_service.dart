// Notices service
import 'package:dio/dio.dart';

import '../models/commuter_notice.dart';

/// Notices service
class NoticesService {
  /// Create notices
  NoticesService(this._dio);

  final Dio _dio;

  /// Notices inbox
  Future<List<CommuterNotice>> inbox({NoticeCategory? category, int skip = 0, int limit = 50}) async {
    final response = await _dio.get('/notices/inbox', queryParameters: {
      'skip': skip,
      'limit': limit,
      if (category != null) 'category': category.apiValue,
    });
    return [for (final n in response.data as List) CommuterNotice.fromJson(n as Map<String, dynamic>)];
  }

  /// Unread count
  Future<int> unreadCount() async {
    final response = await _dio.get('/notices/inbox/unread-count');
    return (response.data['count'] as num).toInt();
  }

  /// Mark read
  Future<void> markRead(String id) => _dio.patch('/notices/inbox/$id/read');

  /// Mark all read
  Future<void> markAllRead() => _dio.post('/notices/inbox/read-all');
}
