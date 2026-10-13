import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/commuter_alert.dart';
import 'package:smartcommute_app/providers/alerts_provider.dart';
import 'package:smartcommute_app/providers/load_state.dart';
import 'package:smartcommute_app/services/alerts_service.dart';

import '../support/commuter_fixtures.dart';
import '../support/fake_dio.dart';

AlertsProvider buildProvider(FakeAdapter backend, {bool isGuest = false}) =>
    AlertsProvider(service: AlertsService(fakeDio(backend)), isGuest: isGuest);

void main() {
  group('load', () {
    test('loads the commuter feed and counts unread alerts', () async {
      final backend = fakeBackend({'GET /alerts/feed': sampleFeed()});
      final alerts = buildProvider(backend);

      await alerts.load();

      expect(alerts.state, LoadState.ready);
      expect(alerts.alerts, hasLength(5));
      expect(alerts.unreadCount, 4);
      expect(alerts.alerts.first.severity, AlertSeverity.critical);
      expect(alerts.alerts.first.routeCode, 'J01');
    });

    test('guests use the public list and have no unread count', () async {
      final backend = fakeBackend({'GET /alerts': sampleFeed()});
      final alerts = buildProvider(backend, isGuest: true);

      await alerts.load();

      expect(calls(backend), ['GET /alerts']);
      expect(alerts.tracksReadState, isFalse);
      expect(alerts.unreadCount, 0);
    });

    test('a failed first load is an error with a message', () async {
      final alerts = buildProvider(fakeBackend({'GET /alerts/feed': 500}));

      await alerts.load();

      expect(alerts.state, LoadState.error);
      expect(alerts.errorMessage, isNotNull);
    });

    test('a failed refresh keeps the alerts on screen', () async {
      var fail = false;
      final backend = FakeAdapter((_) async =>
          fail ? jsonBody({'detail': 'down'}, status: 500) : jsonBody(sampleFeed()));
      final alerts = buildProvider(backend);
      await alerts.load();

      fail = true;
      await alerts.load();

      expect(alerts.state, LoadState.ready);
      expect(alerts.alerts, hasLength(5));
      expect(alerts.errorMessage, 'down');
    });
  });

  group('filters', () {
    late AlertsProvider alerts;

    setUp(() async {
      alerts = buildProvider(fakeBackend({'GET /alerts/feed': sampleFeed()}));
      await alerts.load();
    });

    List<String> visibleTitles() => [for (final a in alerts.visibleAlerts) a.title];

    test('All shows everything', () {
      expect(visibleTitles(), hasLength(5));
    });

    test('severity filters show only active alerts of that severity', () {
      alerts.setFilter(AlertFilter.warning);
      expect(visibleTitles(), ['Heavy Traffic Ahead']); // not the resolved warning

      alerts.setFilter(AlertFilter.info);
      expect(visibleTitles(), ['Schedule Change', 'New Stop Added']);
    });

    test('Resolved shows only resolved alerts', () {
      alerts.setFilter(AlertFilter.resolved);
      expect(visibleTitles(), ['Incident Cleared']);
    });
  });

  group('read state', () {
    test('markRead updates right away and tells the backend', () async {
      final backend = fakeBackend({'GET /alerts/feed': sampleFeed(), 'POST /alerts/a1/read': null});
      final alerts = buildProvider(backend);
      await alerts.load();

      await alerts.markRead(alerts.alerts.first);

      expect(alerts.alerts.first.isRead, isTrue);
      expect(alerts.unreadCount, 3);
      expect(calls(backend), contains('POST /alerts/a1/read'));
    });

    test('markRead is restored if the backend refuses', () async {
      final alerts = buildProvider(fakeBackend({'GET /alerts/feed': sampleFeed(), 'POST /alerts/a1/read': 500}));
      await alerts.load();

      await alerts.markRead(alerts.alerts.first);

      expect(alerts.alerts.first.isRead, isFalse);
    });

    test('markAllRead marks everything read', () async {
      final backend = fakeBackend({'GET /alerts/feed': sampleFeed(), 'POST /alerts/read-all': {'updated': 4}});
      final alerts = buildProvider(backend);
      await alerts.load();

      final error = await alerts.markAllRead();

      expect(error, isNull);
      expect(alerts.unreadCount, 0);
    });

    test('markAllRead rolls back and reports a failure', () async {
      final alerts = buildProvider(fakeBackend({'GET /alerts/feed': sampleFeed(), 'POST /alerts/read-all': 500}));
      await alerts.load();

      final error = await alerts.markAllRead();

      expect(error, isNotNull);
      expect(alerts.unreadCount, 4);
    });

    test('guests never call the read endpoints', () async {
      final backend = fakeBackend({'GET /alerts': sampleFeed()});
      final alerts = buildProvider(backend, isGuest: true);
      await alerts.load();

      await alerts.markRead(alerts.alerts.first);
      await alerts.markAllRead();

      expect(calls(backend), ['GET /alerts']);
    });
  });
}
