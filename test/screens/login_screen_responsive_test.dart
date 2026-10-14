// The Login screen across phone sizes, orientations and text scales.
// Matches the mockup: ice-blue top panel (~72% of the height, rounded
// bottom corners) over teal, logo sized to the screen, card straddling
// the split — and never an overflow.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/config/theme_config.dart';
import 'package:smartcommute_app/screens/auth/login_screen.dart';
import 'package:smartcommute_app/widgets/auth/smart_commute_logo.dart';

const _portraitPhones = <Size>[
  Size(320, 568), // iPhone SE (1st gen)
  Size(360, 640), // small Android
  Size(412, 915), // Pixel
  Size(430, 932), // iPhone Pro Max
];
const _landscapePhone = Size(915, 412);

Future<void> pumpLogin(WidgetTester tester, Size size, {double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const LoginScreen(),
  ));
  await tester.pump();
}

double _logoHeight(WidgetTester tester) =>
    tester.widget<SmartCommuteLogo>(find.byType(SmartCommuteLogo)).height;

// The default test font draws every glyph as a full square, which makes
// text far wider than Poppins. Load the real font so widths are honest.
Future<void> _loadPoppins() async {
  final loader = FontLoader('Poppins');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Poppins-$w.ttf'));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadPoppins);

  for (final size in [..._portraitPhones, _landscapePhone]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()} '
          'text x$scale', (tester) async {
        await pumpLogin(tester, size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('Login'), findsOneWidget);
      });
    }
  }

  testWidgets('top panel fills ~72% of the height with rounded bottom corners',
      (tester) async {
    await pumpLogin(tester, const Size(412, 915));

    final panel = find.byKey(const Key('loginTopPanel'));
    expect(tester.getSize(panel).height, closeTo(915 * 0.72, 1));

    final decoration = tester.widget<DecoratedBox>(panel).decoration as BoxDecoration;
    final radius = decoration.borderRadius! as BorderRadius;
    expect(radius.bottomLeft.x, greaterThan(0));
    expect(radius.bottomRight.x, greaterThan(0));
  });

  // Measured off the 414x896 mockup: panel corners ~12, card ~16,
  // buttons and fields ~35 tall with ~12 corners (not pills).
  group('matches the mockup at its own size (414x896)', () {
    double cornerOf(Decoration d) =>
        ((d as BoxDecoration).borderRadius! as BorderRadius).bottomLeft.x;
    Size visualSize(WidgetTester tester, Finder button) => tester.getSize(
        find.descendant(of: button, matching: find.byType(Material)).first);
    double shapeRadius(WidgetTester tester, Finder button) {
      final material = tester.widget<Material>(
          find.descendant(of: button, matching: find.byType(Material)).first);
      return ((material.shape! as RoundedRectangleBorder).borderRadius
              as BorderRadius)
          .topLeft
          .x;
    }

    testWidgets('panel and card corners', (tester) async {
      await pumpLogin(tester, const Size(414, 896));
      expect(
          cornerOf(tester
              .widget<DecoratedBox>(find.byKey(const Key('loginTopPanel')))
              .decoration),
          closeTo(12, 0.5));
      expect(
          cornerOf(tester
              .widget<Container>(find.byKey(const Key('loginCard')))
              .decoration!),
          closeTo(16, 0.5));
    });

    testWidgets('buttons are 35 tall with 12 corners', (tester) async {
      await pumpLogin(tester, const Size(414, 896));
      for (final b in [
        find.widgetWithText(ElevatedButton, 'Login'),
        find.widgetWithText(OutlinedButton, 'Continue as Guest'),
        find.widgetWithText(OutlinedButton, 'Continue with Google'),
      ]) {
        expect(visualSize(tester, b).height, closeTo(35, 1));
        expect(shapeRadius(tester, b), closeTo(12, 0.5));
      }
    });

    testWidgets('card sits where the mockup puts it (435–840)', (tester) async {
      await pumpLogin(tester, const Size(414, 896));
      final card = tester.getRect(find.byKey(const Key('loginCard')));
      expect(card.top, closeTo(435, 10));
      expect(card.bottom, closeTo(840, 10));
    });

    testWidgets('fields are 35 tall', (tester) async {
      await pumpLogin(tester, const Size(414, 896));
      for (final field in tester.widgetList(find.byType(InputDecorator))) {
        expect(tester.getSize(find.byWidget(field)).height, closeTo(35, 1));
      }
    });
  });

  // The fields used to be capped at 35 including the error text, which
  // squashed the outline into a line through the hint.
  testWidgets('error text sits below an intact field outline', (tester) async {
    await pumpLogin(tester, const Size(414, 896));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    final error = tester.getRect(find.text('Enter your email'));
    final field = tester.getRect(find.byType(InputDecorator).first);
    expect(field.height, greaterThan(35 + error.height - 1));
    expect(error.top, greaterThanOrEqualTo(field.top + 35 - 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sizes scale with the phone width', (tester) async {
    double loginHeight() => tester
        .getSize(find
            .descendant(
                of: find.widgetWithText(ElevatedButton, 'Login'),
                matching: find.byType(Material))
            .first)
        .height;
    await pumpLogin(tester, const Size(360, 640));
    final narrow = loginHeight();
    await pumpLogin(tester, const Size(430, 932));
    final wide = loginHeight();
    expect(wide, greaterThan(narrow));
  });

  testWidgets('card straddles the panel/teal split on a tall phone', (tester) async {
    await pumpLogin(tester, const Size(412, 915));

    final card = tester.getRect(find.byKey(const Key('loginCard')));
    final split = tester.getRect(find.byKey(const Key('loginTopPanel'))).bottom;
    expect(card.top, lessThan(split));
    expect(card.bottom, greaterThan(split));
  });

  testWidgets('logo scales with screen height, within 80–240', (tester) async {
    await pumpLogin(tester, const Size(320, 568));
    final small = _logoHeight(tester);
    await pumpLogin(tester, const Size(430, 932));
    final tall = _logoHeight(tester);

    expect(small, inInclusiveRange(80, 240));
    expect(tall, inInclusiveRange(80, 240));
    expect(tall, greaterThan(small));
  });

  testWidgets('Login button is on screen without scrolling on a 360x640 phone',
      (tester) async {
    await pumpLogin(tester, const Size(360, 640));
    final button = tester.getRect(find.widgetWithText(ElevatedButton, 'Login'));
    expect(button.bottom, lessThanOrEqualTo(640));
  });

  for (final size in const [Size(320, 568), Size(360, 640)]) {
    testWidgets('whole card fits without scrolling on '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpLogin(tester, size);
      final card = tester.getRect(find.byKey(const Key('loginCard')));
      expect(card.bottom, lessThanOrEqualTo(size.height));
    });
  }

  testWidgets('card is capped at 420 wide', (tester) async {
    await pumpLogin(tester, const Size(600, 960)); // large phone / small foldable
    expect(tester.getSize(find.byKey(const Key('loginCard'))).width, lessThanOrEqualTo(420));
  });

  testWidgets('landscape puts the logo beside the card', (tester) async {
    await pumpLogin(tester, _landscapePhone);
    final logo = tester.getRect(find.byType(SmartCommuteLogo));
    final card = tester.getRect(find.byKey(const Key('loginCard')));
    expect(logo.right, lessThanOrEqualTo(card.left));
  });

  for (final size in const [Size(1920, 950), Size(1366, 650), Size(1280, 800)]) {
    testWidgets('desktop ${size.width.toInt()}x${size.height.toInt()} keeps '
        'the stacked mobile layout, centred', (tester) async {
      await pumpLogin(tester, size);
      expect(tester.takeException(), isNull);
      final logo = tester.getRect(find.byType(SmartCommuteLogo));
      final card = tester.getRect(find.byKey(const Key('loginCard')));
      expect(logo.bottom, lessThanOrEqualTo(card.top));
      expect(card.center.dx, closeTo(size.width / 2, 1));
      expect(card.bottom, lessThanOrEqualTo(size.height));
    });
  }

  testWidgets('landscape keeps the logo inside the ice-blue panel', (tester) async {
    await pumpLogin(tester, _landscapePhone);
    final logo = tester.getRect(find.byType(SmartCommuteLogo));
    final panel = tester.getRect(find.byKey(const Key('loginTopPanel')));
    expect(logo.bottom, lessThanOrEqualTo(panel.bottom));
  });
}
