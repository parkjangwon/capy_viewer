import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

@riverpod
GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey(ScaffoldMessengerKeyRef ref) {
  return GlobalKey<ScaffoldMessengerState>();
} 