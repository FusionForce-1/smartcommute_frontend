import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/commuter_notice.dart';
import 'package:smartcommute_app/providers/load_state.dart';
import 'package:smartcommute_app/providers/notices_provider.dart';
import 'package:smartcommute_app/services/notices_service.dart';

import '../support/commuter_fixtures.dart';
import '../support/fake_dio.dart';

NoticesProvider buildProvider(FakeAdapter backend, {bool isGuest = false, int pageSize = 50}) =>
    NoticesProvider(service: NoticesService(fakeDio(backend)), isGuest: isGuest, pageSize: pageSize);

void main() {
  group('load', () {
    test('loads the inbox and the unread count', () async {
      final notices = buildProvider(noticesBackend(sampleInbox()));

      await notices.load();

      expect(notices.state, LoadState.ready);
      expect(notices.notices, hasLength(5));
      expect(notices.unreadCount, 4);
      final first = notices.notices.first;
      expect((first.category, first.severity), (NoticeCategory.serviceAlert, NoticeSeverity.critical));
      expect(first.routeCodes, ['J01']);
      expect(notices.notices[3].category, NoticeCategory.promotion);
      expect(notices.hasMore, isFalse);
    });

    test('guests have no inbox, so nothing is fetched', () async {
      final backend = noticesBackend(sampleInbox());
      final notices = buildProvider(backend, isGuest: true);

      await notices.load();
      await notices.checkForNew();
      await notices.markAllRead();

      expect(backend.requests, isEmpty);
      expect(notices.state, LoadState.ready);
      expect(notices.notices, isEmpty);
    });

    test('a failed first load is an error with a message', () async {
      final notices = buildProvider(fakeBackend({'GET /notices/inbox': 500}));

      await notices.load();

      expect(notices.state, LoadState.error);
      expect(notices.errorMessage, isNotNull);
    });

    test('a failed refresh keeps the notices on screen', () async {
      var fail = false;
      final ok = noticesBackend(sampleInbox());
      final backend = FakeAdapter((o) async => fail ? jsonBody({'detail': 'down'}, status: 500) : await ok.handler(o));
      final notices = buildProvider(backend);
      await notices.load();

      fail = true;
      await notices.load();

      expect(notices.state, LoadState.ready);
      expect(notices.notices, hasLength(5));
      expect(notices.errorMessage, 'down');
    });
  });

  group('filters and paging', () {
    test('a filter asks the server for that category', () async {
      final backend = noticesBackend(sampleInbox());
      final notices = buildProvider(backend);
      await notices.load();

      notices.setFilter(NoticeFilter.promotions);
      await pumpEventQueue();

      final asked = backend.requests.lastWhere((r) => r.path == '/notices/inbox');
      expect(asked.queryParameters['category'], 'promotion');
      expect([for (final n in notices.notices) n.title], ['Free Ride Friday']);
      expect(notices.unreadCount, 4, reason: 'the badge counts every category');
    });

    test('Load more fetches the next page and skips repeats', () async {
      final backend = noticesBackend(sampleInbox());
      final notices = buildProvider(backend, pageSize: 2);
      await notices.load();
      expect((notices.notices.length, notices.hasMore), (2, true));

      await notices.loadMore();
      await notices.loadMore();

      expect([for (final n in notices.notices) n.id], ['n1', 'n2', 'n3', 'n4', 'n5']);
      expect(notices.hasMore, isFalse);
      final skips = [
        for (final r in backend.requests)
          if (r.path == '/notices/inbox') r.queryParameters['skip']
      ];
      expect(skips, [0, 2, 4]);
    });
  });

  group('read state', () {
    test('marking one read is instant and saved', () async {
      final backend = noticesBackend(sampleInbox(), routes: {'PATCH /notices/inbox/n1/read': noticeJson('n1', isRead: true)});
      final notices = buildProvider(backend);
      await notices.load();

      await notices.markRead(notices.notices.first);

      expect(notices.notices.first.isRead, isTrue);
      expect(notices.unreadCount, 3);
      expect(calls(backend), contains('PATCH /notices/inbox/n1/read'));
    });

    test('a refused mark-read is undone', () async {
      final notices = buildProvider(noticesBackend(sampleInbox(), routes: {'PATCH /notices/inbox/n1/read': 500}));
      await notices.load();

      await notices.markRead(notices.notices.first);

      expect(notices.notices.first.isRead, isFalse);
      expect(notices.unreadCount, 4);
    });

    test('Mark all read, and its rollback', () async {
      final ok = buildProvider(noticesBackend(sampleInbox(), routes: {'POST /notices/inbox/read-all': {'updated': 4}}));
      await ok.load();
      expect(await ok.markAllRead(), isNull);
      expect((ok.unreadCount, ok.notices.every((n) => n.isRead)), (0, true));

      final refused = buildProvider(noticesBackend(sampleInbox(), routes: {'POST /notices/inbox/read-all': 500}));
      await refused.load();
      expect(await refused.markAllRead(), 'Request failed');
      expect(refused.unreadCount, 4);
      expect(refused.notices.where((n) => !n.isRead), hasLength(4));
    });
  });

  group('new notices', () {
    test('a higher unread count reloads the list; the same count does not', () async {
      final inbox = sampleInbox();
      final backend = noticesBackend(inbox);
      final notices = buildProvider(backend);
      await notices.load();
      final loads = backend.requests.where((r) => r.path == '/notices/inbox').length;

      await notices.checkForNew();
      expect(backend.requests.where((r) => r.path == '/notices/inbox').length, loads);

      inbox.insert(0, noticeJson('n6', title: 'Bridge Closed', minutesAgo: 0));
      await notices.checkForNew();

      expect(notices.notices.first.title, 'Bridge Closed');
      expect(notices.unreadCount, 5);
    });
  });
}
