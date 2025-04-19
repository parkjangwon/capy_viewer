import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigator_provider.g.dart';

@riverpod
GlobalKey<NavigatorState> navigatorKey(NavigatorKeyRef ref) {
  return GlobalKey<NavigatorState>();
} 