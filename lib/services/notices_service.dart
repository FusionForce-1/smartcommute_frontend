// lib/services/notices_service.dart
//
// The signed-in commuter's notifications: what operators sent about the
// routes they saved or rode (/notices/inbox). Guests have no inbox.

import 'package:dio/dio.dart';

import '../models/commuter_notice.dart';

class NoticesService {
  NoticesService(this._dio);

  final Dio _dio;

  /// Newest first; [category] keeps one kind, [skip] pages further back.
  Future<List<CommuterNotice>> inbox({NoticeCategory? category, int skip = 0, int limit = 50}) async {
    final response = await _dio.get('/notices/inbox', queryParameters: {
      'skip': skip,
      'limit': limit,
      if (category != null) 'category': category.apiValue,
    });
    return [for (final n in response.data as List) CommuterNotice.fromJson(n as Map<String, dynamic>)];
  }

  Future<int> unreadCount() async {
    final response = await _dio.get('/notices/inbox/unread-count');
    return (response.data['count'] as num).toInt();
  }

  Future<void> markRead(String id) => _dio.patch('/notices/inbox/$id/read');

  Future<void> markAllRead() => _dio.post('/notices/inbox/read-all');
}
