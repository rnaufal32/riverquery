import 'package:riverpod/riverpod.dart';
import 'package:riverpod/misc.dart';

import 'stale_time.dart';

/// Creates a [Provider] for a synchronous state container ("store").
///
/// - [persist]: if `true`, the store never disposes on its own (same as a
///   plain non-`autoDispose` [Provider]). [staleTime] is ignored in that case.
/// - [staleTime]: how long to keep the store alive after its last listener
///   is removed, before disposing. Defaults to 1 minute. Pass `null` to
///   disable it — the store then disposes immediately once unwatched,
///   which is the classic `Provider.autoDispose` behavior.
///
/// Example:
/// ```dart
/// // Default: disposes 1 minute after the last widget stops watching it.
/// final counterStore = createStore((ref) => Counter());
///
/// // Disposes immediately once unwatched (no grace period).
/// final ephemeralStore = createStore((ref) => Counter(), staleTime: null);
///
/// // Never disposes.
/// final globalStore = createStore((ref) => Counter(), persist: true);
/// ```
Provider<T> createStore<T>(
  T Function(Ref ref) store, {
  bool persist = false,
  Duration? staleTime = defaultStaleTime,
}) {
  T build(Ref ref) {
    ref.staleFor(persist ? null : staleTime);
    return store(ref);
  }

  return persist ? Provider<T>(build) : Provider.autoDispose<T>(build);
}

/// Family version of [createStore]. See [createStore] for the meaning of
/// [persist] and [staleTime].
ProviderFamily<T, TParam> createStoreFamily<T, TParam>(
  T Function(Ref ref, TParam param) store, {
  bool persist = false,
  Duration? staleTime = defaultStaleTime,
}) {
  T build(Ref ref, TParam param) {
    ref.staleFor(persist ? null : staleTime);
    return store(ref, param);
  }

  return persist
      ? Provider.family<T, TParam>(build)
      : Provider.autoDispose.family<T, TParam>(build);
}
