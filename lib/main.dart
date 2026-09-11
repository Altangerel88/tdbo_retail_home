import 'package:flutter/material.dart';

import 'screens/retail_home.dart';
import 'theme/tokens.dart';

void main() => runApp(const RetailApp());

class RetailApp extends StatelessWidget {
  const RetailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TDB Online',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: T.font,
        scaffoldBackgroundColor: T.navy,
        colorScheme: ColorScheme.fromSeed(seedColor: T.yellow),
      ),
      // Split extra line height evenly above/below the glyphs, like Figma/CSS,
      // so explicit line heights (22px rows, 1.074 nav labels) land where designed.
      builder: (context, child) => DefaultTextHeightBehavior(
        textHeightBehavior: const TextHeightBehavior(
          leadingDistribution: TextLeadingDistribution.even,
        ),
        child: child!,
      ),
      home: const RetailHome(),
    );
  }
}
