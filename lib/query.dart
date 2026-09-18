import 'package:riverpod/riverpod.dart';
import 'package:riverpod/misc.dart';

import 'stale_time.dart';

/// Creates a [FutureProvider] for an async query.
///
/// - [persist]: if `true`, the query never disposes on its own. [staleTime]
///   is ignored in that case.
/// - [staleTime]: how long to keep the fetched result cached after the last
///   listener leaves, before disposing. Defaults to 1 minute. Pass `null`
///   to disable it — disposes (and re-fetches on next watch) immediately
///   once unwatched.
///
/// Example:
/// ```dart
/// // Cached for 1 minute after the last widget stops watching it.
/// final userQuery = createQuery((ref) => api.getUser());
///
/// // No grace period: re-fetches every time it's watched again from zero.
/// final liveQuery = createQuery((ref) => api.getUser(), staleTime: null);
/// ```
FutureProvider<T> createQuery<T>(
  Future<T> Function(Ref ref) query, {
  bool persist = false,
  Duration? staleTime = defaultStaleTime,
}) {
  Future<T> build(Ref ref) {
    ref.staleFor(persist ? null : staleTime);
    return query(ref);
  }

  return persist
      ? FutureProvider<T>(build)
      : FutureProvider.autoDispose<T>(build);
}

/// Family version of [createQuery]. See [createQuery] for the meaning of
/// [persist] and [staleTime].
FutureProviderFamily<T, TParam> createQueryFamily<T, TParam>(
  Future<T> Function(Ref ref, TParam param) query, {
  bool persist = false,
  Duration? staleTime = defaultStaleTime,
}) {
  Future<T> build(Ref ref, TParam param) {
    ref.staleFor(persist ? null : staleTime);
    return query(ref, param);
  }

  return persist
      ? FutureProvider.family<T, TParam>(build)
      : FutureProvider.autoDispose.family<T, TParam>(build);
}

/// Creates an [AsyncNotifierProvider] for a [QueryEditable] — a query whose
/// state can be manually overridden (optimistic updates, manual error or
/// loading states) in addition to the normal fetch-driven flow.
///
/// See [createQuery] for the meaning of [persist] and [staleTime].
AsyncNotifierProvider<QueryEditable<NResult>, NResult>
createQueryEditable<NResult>(
  Future<NResult> Function(Ref ref) query, {
  bool persist = false,
  Duration? staleTime = defaultStaleTime,
}) {
  final effectiveStaleTime = persist ? null : staleTime;

  return persist
      ? AsyncNotifierProvider<QueryEditable<NResult>, NResult>(
          () => QueryEditable(query, staleTime: effectiveStaleTime),
        )
      : AsyncNotifierProvider.autoDispose<QueryEditable<NResult>, NResult>(
          () => QueryEditable(query, staleTime: effectiveStaleTime),
        );
}

/// Family version of [createQueryEditable]. See [createQuery] for the
/// meaning of [persist] and [staleTime].
AsyncNotifierProviderFamily<
  QueryEditableFamily<NResult, NParam>,
  NResult,
  NParam
>
createQueryEditableFamily<NResult, NParam>(
  Future<NResult> Function(Ref ref, NParam param) query, {
  bool persist = false,
  Duration? staleTime = defaultStaleTime,
}) {
  final effectiveStaleTime = persist ? null : staleTime;

  return persist
      ? AsyncNotifierProvider.family<
          QueryEditableFamily<NResult, NParam>,
          NResult,
          NParam
        >(
          (param) =>
              QueryEditableFamily(query, param, staleTime: effectiveStaleTime),
        )
      : AsyncNotifierProvider.autoDispose.family<
          QueryEditableFamily<NResult, NParam>,
          NResult,
          NParam
        >(
          (param) =>
              QueryEditableFamily(query, param, staleTime: effectiveStaleTime),
        );
}

/// An [AsyncNotifier] that allows manual modification of its state.
///
/// This is useful for optimistic updates or scenarios where you need to
/// manually control the query state.
class QueryEditable<NResult> extends AsyncNotifier<NResult> {
  QueryEditable(this.query, {this.staleTime});

  /// The function to fetch the initial data.
  final Future<NResult> Function(Ref ref) query;

  /// How long to keep this notifier alive after its last listener leaves.
  /// `null` disables the grace period.
  final Duration? staleTime;

  @override
  Future<NResult> build() async {
    ref.staleFor(staleTime);
    return query(ref);
  }

  /// Manually sets the state to [AsyncValue.data] with the given [value].
  void setValue(NResult value) => state = AsyncValue.data(value);

  /// Manually sets the state to [AsyncValue.error] with the given [error]
  /// and [stackTrace].
  void setError(Object error, StackTrace stackTrace) =>
      state = AsyncValue.error(error, stackTrace);

  /// Manually sets the state to [AsyncValue.loading].
  ///
  /// Optionally accepts a [progress] value.
  void setLoading([num progress = 0]) =>
      state = AsyncValue.loading(progress: progress);
}

/// An [AsyncNotifier] for a family of editable queries.
class QueryEditableFamily<NResult, NParam> extends AsyncNotifier<NResult> {
  QueryEditableFamily(this.query, this.param, {this.staleTime});

  /// The function to fetch the initial data.
  final Future<NResult> Function(Ref ref, NParam param) query;

  /// The parameter associated with this query instance.
  final NParam param;

  /// How long to keep this notifier alive after its last listener leaves.
  /// `null` disables the grace period.
  final Duration? staleTime;

  @override
  Future<NResult> build() async {
    ref.staleFor(staleTime);
    return query(ref, param);
  }

  /// Manually sets the state to [AsyncValue.data] with the given [value].
  void setValue(NResult value) => state = AsyncValue.data(value);

  /// Manually sets the state to [AsyncValue.error] with the given [error]
  /// and [stackTrace].
  void setError(Object error, StackTrace stackTrace) =>
      state = AsyncValue.error(error, stackTrace);

  /// Manually sets the state to [AsyncValue.loading].
  ///
  /// Optionally accepts a [progress] value.
  void setLoading([num progress = 0]) =>
      state = AsyncValue.loading(progress: progress);
}
