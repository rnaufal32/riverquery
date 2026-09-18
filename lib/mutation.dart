import 'package:riverpod/experimental/mutation.dart';
import 'package:riverpod/misc.dart';
import 'package:riverpod/riverpod.dart';

class MutationRunner<T> {
  const MutationRunner(this._run, this._reset);
  final Future<T> Function() _run;
  final void Function() _reset;

  Future<T> call() => _run();
  Future<T> run() => _run();
  void reset() => _reset();
}

typedef MutationRecord<T> = (
  MutationState<T> state,
  MutationRunner<T> mutation,
);

ProviderBase<MutationRecord<T>> createMutation<T>(
  Future<T> Function(MutationTransaction tsx) action, {
  bool persist = false,
}) {
  final mutation = Mutation<T>();

  MutationRecord<T> build(Ref ref) {
    final state = ref.watch(mutation);
    final runner = MutationRunner<T>(
      () => mutation.run(ref, action),
      () => mutation.reset(ref),
    );
    return (state, runner);
  }

  return persist
      ? Provider<MutationRecord<T>>(build)
      : Provider.autoDispose<MutationRecord<T>>(build);
}

class MutationRunnerWithParam<T, P> {
  const MutationRunnerWithParam(this._run, this._reset);
  final Future<T> Function(P payload) _run;
  final void Function() _reset;

  Future<T> call(P payload) => _run(payload);
  Future<T> run(P payload) => _run(payload);
  void reset() => _reset();
}

typedef MutationRecordWithParam<T, P> = (
  MutationState<T> state,
  MutationRunnerWithParam<T, P> mutation,
);

ProviderBase<MutationRecordWithParam<T, P>> createMutationWithParam<T, P>(
  Future<T> Function(MutationTransaction tsx, P payload) action, {
  bool persist = false,
}) {
  final mutation = Mutation<T>();

  MutationRecordWithParam<T, P> build(Ref ref) {
    final state = ref.watch(mutation);
    final runner = MutationRunnerWithParam<T, P>(
      (payload) => mutation.run(ref, (tsx) => action(tsx, payload)),
      () => mutation.reset(ref),
    );
    return (state, runner);
  }

  return persist
      ? Provider<MutationRecordWithParam<T, P>>(build)
      : Provider.autoDispose<MutationRecordWithParam<T, P>>(build);
}
