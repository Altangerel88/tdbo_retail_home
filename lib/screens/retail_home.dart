import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
import '../widgets/header_logo_trace.dart';
import '../widgets/header_logo_trace_v2.dart';
import '../widgets/header_logo_variants.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/nav_bar.dart';

/// "A · Retail" home — Figma TDBO 2.0 mobile, node 74444:14342.
///
/// Charcoal header with the animated logo thread behind it (greeting, IBAN,
/// balance, Liquid Glass buttons, two pills) over a white sheet with
/// quick actions, the promo carousel and recent transactions, plus the
/// floating nav bar.
class RetailHome extends StatefulWidget {
  const RetailHome({super.key});

  @override
  State<RetailHome> createState() => _RetailHomeState();
}

class _RetailHomeState extends State<RetailHome> {
  static const _iban = 'MN91 0004 0040 0238 9817';

  /// Header background variants, in the order a tap cycles them: the two
  /// hand-tuned originals, then the five from the shared engine.
  static final _backgrounds = <(String, Widget)>[
    ('Лого v1 — жижиг, баруун талд', const HeaderLogoTrace(underlap: 28)),
    ('Лого v2 — том, налуу, зүүн талд', const HeaderLogoTraceV2(underlap: 28)),
    for (final variant in logoVariants)
      (
        variant.name,
        HeaderLogoVariant(
          key: ValueKey(variant.name),
          variant: variant,
          underlap: 28,
        ),
      ),
  ];

  int _tab = 0;
  bool _balanceHidden = false;
  int _background = 1;

  void _copyIban() {
    Clipboard.setData(ClipboardData(text: _iban.replaceAll(' ', '')));
    _toast('Дансны дугаар хуулагдлаа');
  }

  /// A tap anywhere on the header background switches the logo variant.
  void _cycleBackground() {
    setState(() => _background = (_background + 1) % _backgrounds.length);
    _toast(_backgrounds[_background].$1);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 108),
          backgroundColor: T.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(message, style: mr(14, FontWeight.w600, Colors.white)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: T.ink,
        body: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Logo thread behind the header — tap it to switch
                      // variants. v1 is the small knot on the right (git tag
                      // v1-logo-thread), v2 the large tilted one on the left;
                      // HeaderShader is the earlier silk. It runs 28px under
                      // the sheet so its rounded corners show it too.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: -28,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _cycleBackground,
                          child: _backgrounds[_background].$2,
                        ),
                      ),
                      _Header(
                        iban: _iban,
                        topInset: MediaQuery.paddingOf(context).top,
                        balanceHidden: _balanceHidden,
                        onToggleBalance: () =>
                            setState(() => _balanceHidden = !_balanceHidden),
                        onCopyIban: _copyIban,
                      ),
                    ],
                  ),
                  const Expanded(child: _ContentCard()),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: HomeNavBar(
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header (74444:14349)
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.iban,
    required this.topInset,
    required this.balanceHidden,
    required this.onToggleBalance,
    required this.onCopyIban,
  });

  final String iban;
  final double topInset;
  final bool balanceHidden;
  final VoidCallback onToggleBalance;
  final VoidCallback onCopyIban;

  @override
  Widget build(BuildContext context) {
    final white72 = Colors.white.withValues(alpha: 0.72);

    return Padding(
      // Figma: 56 top = 44 status bar + 12.
      padding: EdgeInsets.fromLTRB(24, topInset + 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Disc(
                size: 46,
                alpha: 0.14,
                child: AppIcon('user', size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Өдрийн мэнд!',
                      style: mr(13, FontWeight.w500, white72),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Алтангэрэл',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mr(18, FontWeight.w800, Colors.white),
                    ),
                  ],
                ),
              ),
              _Disc(
                size: 42,
                alpha: 0.10,
                onTap: onToggleBalance,
                child: const AppIcon('eye', size: 22),
              ),
              const SizedBox(width: 12),
              const _Disc(
                size: 42,
                alpha: 0.10,
                child: AppIcon('bell', size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCopyIban,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(iban, style: mr(13, FontWeight.w500, white72)),
                  const SizedBox(width: 8),
                  const AppIcon('copy', size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                balanceHidden ? '••• ••• •••.••' : '123,456,789.12',
                style: mr(24, FontWeight.w700, Colors.white),
              ),
              const SizedBox(width: 7),
              Text(
                'MNT',
                style: mr(
                  16,
                  FontWeight.w700,
                  Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const _Pill('Дансны хуулга', color: T.yellow, textColor: T.black),
              const SizedBox(width: 10),
              _Pill(
                'Данс хайх',
                glass: true,
                textColor: Colors.white.withValues(alpha: 0.95),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Liquid Glass circle holding a header icon. [alpha] is the white fill used
/// where native glass isn't available (the web build).
class _Disc extends StatelessWidget {
  const _Disc({
    required this.size,
    required this.alpha,
    required this.child,
    this.onTap,
  });

  final double size;
  final double alpha;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disc = LiquidGlass(
      shape: GlassShape.circle,
      fallbackAlpha: alpha,
      child: SizedBox.square(
        dimension: size,
        child: Center(child: child),
      ),
    );
    if (onTap == null) return disc;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: disc,
    );
  }
}

/// Header pill: a solid [color] fill, or Liquid Glass when [glass] is set.
class _Pill extends StatelessWidget {
  const _Pill(
    this.label, {
    required this.textColor,
    this.color,
    this.glass = false,
  });

  final String label;
  final Color textColor;
  final Color? color;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(label, style: mr(14, FontWeight.w600, textColor)),
    );
    if (glass) return LiquidGlass(shape: GlassShape.capsule, child: content);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// Content card (74444:14387)
// ---------------------------------------------------------------------------

class _ContentCard extends StatelessWidget {
  const _ContentCard();

  static const _radius = BorderRadius.vertical(top: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: _radius,
      child: ColoredBox(
        color: T.surface,
        child: ListView(
          // Bottom: 24 + nav 68 + 24 so the last row can scroll clear of the nav.
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 116),
          children: const [
            _QuickActions(),
            // Figma measures the 20 gap from the label's trimmed baseline;
            // Flutter's line box adds the ~4px descent below it.
            SizedBox(height: 16),
            _PromoCarousel(),
            SizedBox(height: 20),
            _RecentTransactions(),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _items = [
    ('qa_account', 20.0, 'Данс'),
    ('qa_loan', 24.0, 'Зээл'),
    ('qa_card', 24.0, 'Карт'),
    ('qa_bulb', 20.0, 'Хэрэглээ'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icon, size, label) in _items)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: T.plate,
                    shape: BoxShape.circle,
                  ),
                  child: AppIcon(icon, size: size),
                ),
                // Figma's 12 gap is to the cap line; Manrope's ascent sits
                // ~5px above the caps inside the line box.
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: mr(14, FontWeight.w600, T.black),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  // Both banners are fills of the Figma node (Component 25): the Britto card
  // promo is the visible one, "Хуримтлалтай Монгол" sits beneath it.
  static const _banners = [
    'assets/images/banner_britto.png',
    'assets/images/banner_huurimtlaltai.png',
  ];

  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 222,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            PageView.builder(
              itemCount: _banners.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Image.asset(
                _banners[i],
                fit: BoxFit.cover,
                width: double.infinity,
                height: 222,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _banners.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        width: i == _page ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? T.yellow
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions();

  static const _date = '03/05/2023 15:10';
  static const _desc =
      'POS Normal Purchase Ner/HaanaPOS Normal Purchase Ner/Haana';
  static const _items = [
    (true, '+260,000,000,000.78'),
    (false, '-260,000,000,000.78'),
    (true, '+260,000,000,000.78'),
    (false, '-260,000,000,000.78'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              Text('Сүүлийн гүйлгээ', style: mr(14, FontWeight.w500, T.label)),
              const Spacer(),
              Text('Хуулга', style: mr(14, FontWeight.w700, T.ink)),
              const AppIcon('caret_right', size: 16),
            ],
          ),
        ),
        for (final (incoming, amount) in _items)
          _TxRow(incoming: incoming, amount: amount, date: _date, desc: _desc),
      ],
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({
    required this.incoming,
    required this.amount,
    required this.date,
    required this.desc,
  });

  final bool incoming;
  final String amount;
  final String date;
  final String desc;

  static const double _lh = 22 / 14; // 22px line height on 14px text

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: incoming ? T.greenBg : T.outBg,
              shape: BoxShape.circle,
            ),
            child: AppIcon(incoming ? 'tx_in' : 'tx_out', size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      date,
                      style: mr(14, FontWeight.w500, T.muted, height: _lh),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            amount,
                            style: mr(
                              14,
                              FontWeight.w600,
                              incoming ? T.green : T.ink,
                              height: _lh,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mr(14, FontWeight.w500, T.ink, height: _lh),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
