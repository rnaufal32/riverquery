import 'dart:async';

import 'package:riverpod/riverpod.dart';

/// Default duration a store/query/infinity query is kept alive after its
/// last listener is removed, before it actually gets disposed.
///
/// Used as the default `staleTime` for [createStore], [createQuery], and
/// [createInfinityQuery] (see their respective files). Pass
/// `staleTime: null` to any of them to disable this behavior entirely.
const defaultStaleTime = Duration(minutes: 1);

/// Keeps an `autoDispose` provider alive for [duration] after its last
/// listener is removed, instead of disposing immediately.
///
/// - `null` disables the behavior: the provider disposes as soon as it has
///   no listeners left — the normal `autoDispose` semantics.
/// - Has no effect on `persist`-ed (non-autoDispose) providers, since those
///   never dispose based on listener count in the first place.
///
/// Calling this from `build()` means the timer restarts on every rebuild,
/// giving a sliding cache window (fresh data extends the stale time).
///
/// Example:
/// ```dart
/// final myProvider = Provider.autoDispose((ref) {
///   ref.staleFor(const Duration(minutes: 1));
///   return computeExpensiveValue();
/// });
/// ```
extension StaleTimeRef on Ref {
  void staleFor(Duration? duration) {
    if (duration == null) return;

    final link = keepAlive();
    final timer = Timer(duration, link.close);

    onDispose(timer.cancel);
  }
}
