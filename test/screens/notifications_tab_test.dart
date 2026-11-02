import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartcommute_app/providers/notices_provider.dart';
import 'package:smartcommute_app/screens/commuter/notifications_tab.dart';
import 'package:smartcommute_app/services/notices_service.dart';
import 'package:smartcommute_app/widgets/commuter/notice_card.dart';
import 'package:smartcommute_app/widgets/commuter/notice_details_sheet.dart';

import '../support/commuter_fixtures.dart';
import '../support/fake_dio.dart';

Future<NoticesProvider> pumpNotificationsTab(
  WidgetTester tester,
  FakeAdapter backend, {
  bool isGuest = false,
  VoidCallback? onCreateAccount,
}) async {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final notices = NoticesProvider(service: NoticesService(fakeDio(backend)), isGuest: isGuest);
  addTearDown(notices.dispose);
  // Real async work (the fake HTTP call) must run outside the test clock.
  await tester.runAsync(notices.load);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ChangeNotifierProvider.value(
        value: notices,
        child: NotificationsTab(onCreateAccount: onCreateAccount),
      ),
    ),
  ));
  return notices;
}

void main() {
  testWidgets('shows the unread count and every notice', (tester) async {
    await pumpNotificationsTab(tester, noticesBackend(sampleInbox()));

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('4 unread'), findsOneWidget);
    expect(find.byType(NoticeCard), findsNWidgets(5));
    expect(find.text('Route Suspended'), findsOneWidget);
    expect(find.text('2 min ago'), findsOneWidget);
    expect(find.text('Critical alert'), findsOneWidget);
    expect(find.text('Promotion'), findsOneWidget);
    expect(find.text('J01, J02'), findsOneWidget);
    expect(find.text('From Cebu City Transport Co.'), findsNWidgets(5));
  });

  testWidgets('Mark all read clears the unread count', (tester) async {
    await pumpNotificationsTab(
      tester,
      noticesBackend(sampleInbox(), routes: {'POST /notices/inbox/read-all': {'updated': 4}}),
    );

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(find.text('0 unread'), findsOneWidget);
  });

  Future<void> tapFilter(WidgetTester tester, String label) async {
    final pill = find.widgetWithText(InkWell, label);
    await tester.ensureVisible(pill); // the pill row scrolls sideways on phones
    await tester.tap(pill);
    // The filter asks the server: let the fake HTTP call finish.
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('filters ask for one category', (tester) async {
    await pumpNotificationsTab(tester, noticesBackend(sampleInbox()));

    await tapFilter(tester, 'Schedule');
    expect(find.byType(NoticeCard), findsOneWidget);
    expect(find.text('New Stop Added'), findsOneWidget);

    await tapFilter(tester, 'Service alerts');
    expect(find.byType(NoticeCard), findsNWidgets(3));
  });

  testWidgets('tapping a notice marks it read and opens its details', (tester) async {
    final backend = noticesBackend(sampleInbox(), routes: {'PATCH /notices/inbox/n1/read': noticeJson('n1', isRead: true)});
    await pumpNotificationsTab(tester, backend);

    await tester.tap(find.text('Route Suspended'));
    await tester.pumpAndSettle();

    expect(find.byType(NoticeDetailsSheet), findsOneWidget);
    expect(find.textContaining('Route Suspended — details for commuters.'), findsWidgets);
    expect(calls(backend), contains('PATCH /notices/inbox/n1/read'));
    expect(find.text('3 unread'), findsOneWidget);
  });

  testWidgets('an empty inbox explains how to get notifications', (tester) async {
    await pumpNotificationsTab(tester, noticesBackend([]));

    expect(find.textContaining('Save a route or plan a trip'), findsOneWidget);

    await tapFilter(tester, 'Promotions');
    expect(find.text('No promotions right now.'), findsOneWidget);
  });

  testWidgets('a failed load offers Try again', (tester) async {
    await pumpNotificationsTab(tester, fakeBackend({'GET /notices/inbox': 500}));

    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('guests are invited to sign up and nothing is fetched', (tester) async {
    final backend = noticesBackend(sampleInbox());
    var created = false;
    await pumpNotificationsTab(tester, backend, isGuest: true, onCreateAccount: () => created = true);

    expect(backend.requests, isEmpty);
    expect(find.byType(NoticeCard), findsNothing);
    expect(find.textContaining('unread'), findsNothing);
    expect(find.textContaining('Sign in to get notifications'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    expect(created, isTrue);
  });
}
