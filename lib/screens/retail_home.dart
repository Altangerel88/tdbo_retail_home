import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/accents.dart';
import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
import '../widgets/header_logo_trace.dart';
import '../widgets/header_logo_v1_fast.dart';
import '../widgets/header_logo_v3.dart';
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

  /// Header background variants, in the order a tap cycles them. Only v1
  /// is in use now, so the cycle is v1 and its reworks. The earlier
  /// v2–v12 (tilted knots, four arrows) are still in lib/widgets and in git
  /// (tags v2-v7-variants, v8-smooth, v9-v12-arrows), just not listed here.
  static final _backgrounds = <(String, Widget)>[
    ('Лого v1 — жижиг, баруун талд', const HeaderLogoTrace(underlap: 28)),
    (
      'Лого v2 — v1, лого нэг дор зурагдана',
      const HeaderLogoV1Fast(underlap: 28),
    ),
    ('Лого v3 — v2, лавлагааны хөдөлгөөнөөр', const HeaderLogoV3(underlap: 28)),
  ];

  int _tab = 0;
  bool _balanceHidden = false;

  /// Accent the header background is drawn in, and the mode whose brand
  /// value it uses. Picked from the swatch button in the header.
  int _accent = 0;
  AccentMode _mode = AccentMode.dark;
  int _background = 2;

  void _copyIban() {
    Clipboard.setData(ClipboardData(text: _iban.replaceAll(' ', '')));
    _toast('Дансны дугаар хуулагдлаа');
  }

  /// A tap anywhere on the header background switches the logo variant.
  void _cycleBackground() {
    setState(() => _background = (_background + 1) % _backgrounds.length);
    _toast(_backgrounds[_background].$1);
  }

  /// Opens the accent picker. Picks apply as they're tapped, so the header
  /// above the sheet previews them.
  void _pickAccent() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (_) => _AccentSheet(
        accent: _accent,
        mode: _mode,
        onChanged: (accent, mode) => setState(() {
          _accent = accent;
          _mode = mode;
        }),
      ),
    );
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

  /// The background in the picked accent. The backgrounds themselves stay
  /// in brand yellow; a colour filter maps them over (see [accentFilter]).
  Widget _recolour(Widget background) {
    final filter = accentFilter(accents[_accent], _mode);
    if (filter == null) return background;
    return ColorFiltered(colorFilter: filter, child: background);
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
                      // v1-logo-thread); v2 is v1 with the knot drawn all at
                      // once. HeaderShader is the earlier silk. It runs 28px
                      // under the sheet so its rounded corners show it too.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: -28,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _cycleBackground,
                          child: _recolour(_backgrounds[_background].$2),
                        ),
                      ),
                      _Header(
                        iban: _iban,
                        topInset: MediaQuery.paddingOf(context).top,
                        swatch: accents[_accent].of(_mode),
                        onPickAccent: _pickAccent,
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
    required this.swatch,
    required this.onPickAccent,
    required this.balanceHidden,
    required this.onToggleBalance,
    required this.onCopyIban,
  });

  final String iban;
  final double topInset;

  /// The accent the header is drawn in, shown on the picker button.
  final Color swatch;
  final VoidCallback onPickAccent;
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
                onTap: onPickAccent,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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

// ---------------------------------------------------------------------------
// Accent picker
// ---------------------------------------------------------------------------

/// Bottom sheet for the header's accent: light or dark mode, then one of the
/// eight accents. Each swatch shows both brand values, light over dark.
class _AccentSheet extends StatefulWidget {
  const _AccentSheet({
    required this.accent,
    required this.mode,
    required this.onChanged,
  });

  final int accent;
  final AccentMode mode;
  final void Function(int accent, AccentMode mode) onChanged;

  @override
  State<_AccentSheet> createState() => _AccentSheetState();
}

class _AccentSheetState extends State<_AccentSheet> {
  late int _accent = widget.accent;
  late AccentMode _mode = widget.mode;

  void _set(int accent, AccentMode mode) {
    setState(() {
      _accent = accent;
      _mode = mode;
    });
    widget.onChanged(accent, mode);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: T.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Өнгө сонгох', style: mr(18, FontWeight.w800, T.black)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: T.plate,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                for (final (mode, label) in const [
                  (AccentMode.light, 'Цайвар горим'),
                  (AccentMode.dark, 'Бараан горим'),
                ])
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _set(_accent, mode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _mode == mode ? T.ink : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          label,
                          style: mr(
                            14,
                            FontWeight.w700,
                            _mode == mode ? Colors.white : T.label,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
            children: [
              for (var i = 0; i < accents.length; i++)
                _Swatch(
                  accent: accents[i],
                  mode: _mode,
                  selected: i == _accent,
                  onTap: () => _set(i, _mode),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One accent: a circle split light over dark, the current mode's half
/// a little larger, ringed when picked.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.accent,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final Accent accent;
  final AccentMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? T.ink : Colors.transparent,
                width: 2,
              ),
            ),
            child: Container(
              width: 46,
              height: 46,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: mode == AccentMode.light ? 3 : 2,
                    child: ColoredBox(color: accent.light),
                  ),
                  Expanded(
                    flex: mode == AccentMode.dark ? 3 : 2,
                    child: ColoredBox(color: accent.dark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            accent.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: mr(
              11.5,
              selected ? FontWeight.w700 : FontWeight.w500,
              selected ? T.black : T.label,
            ),
          ),
        ],
      ),
    );
  }
}
