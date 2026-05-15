import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'dart:developer';

class DeepLinkListener extends StatefulWidget {
  const DeepLinkListener({super.key});

  @override
  State<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<DeepLinkListener> {
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    final appLinks = AppLinks(); // AppLinks is singleton

    // Subscribe to all events (initial link and further)
    _sub = appLinks.uriLinkStream.listen((uri) {
      log('URI: ${uri.toString()}');
    });
    super.initState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
