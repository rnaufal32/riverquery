import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverquery/riverquery.dart';

void main() {
  group('staleFor', () {
    test('keeps an autoDispose provider alive for the grace period', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var buildCount = 0;
      final provider = Provider.autoDispose<String>((ref) {
        ref.staleFor(const Duration(milliseconds: 100));
        buildCount++;
        return 'value';
      });

      final sub = container.listen(provider, (_, _) {});
      expect(container.read(provider), 'value');
      sub.close();

      // No listeners, but the grace period keeps it alive.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(buildCount, 1);

      // After the grace period expires it can be disposed.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await container.pump();
      expect(container.read(provider), 'value');
      expect(buildCount, 2);
    });
  });

  group('createQuery', () {
    test('caches the result within the staleTime window', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var calls = 0;
      final query = createQuery<int>((ref) async {
        calls++;
        return 42;
      }, staleTime: const Duration(minutes: 1));

      expect(await container.read(query.future), 42);
      // Re-read: still cached, no new call.
      expect(await container.read(query.future), 42);
      expect(calls, 1);
    });

    test('dispose on unwatch when staleTime is null', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var calls = 0;
      final query = createQuery<int>((ref) async {
        calls++;
        return 42;
      }, staleTime: null);

      final sub = container.listen(query, (_, _) {});
      expect(await container.read(query.future), 42);
      sub.close();
      await container.pump();
      expect(calls, 1);

      // Watched again from scratch — re-executes the query function.
      final sub2 = container.listen(query, (_, _) {});
      expect(await container.read(query.future), 42);
      expect(calls, 2);
      sub2.close();
    });
  });

  group('createStore', () {
    test('creates a synchronous store', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final store = createStore<int>((ref) => 7);
      expect(container.read(store), 7);
    });
  });

  group('createMutation', () {
    test('transitions idle -> pending -> success', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mutation = createMutation<String>(
        (tsx) async => tsx.get(currentTodo),
      );

      final (state, runMutation) = container.read(mutation);
      expect(state, isA<MutationIdle>());

      final result = await runMutation.run();
      expect(result, 'done');
      expect(container.read(mutation).$1, isA<MutationSuccess>());
    });

    test('transitions to error state when the action throws', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mutation = createMutation<String>((tsx) async {
        throw StateError('boom');
      });

      final (state, runMutation) = container.read(mutation);
      expect(state, isA<MutationIdle>());
      await expectLater(runMutation.run(), throwsA(isA<StateError>()));
      expect(container.read(mutation).$1, isA<MutationError>());
    });
  });

  group('createMutationWithParam', () {
    test('passes the payload to the action', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mutation = createMutationWithParam<int, int>(
        (tsx, payload) async => payload * 2,
      );

      final (state, runMutation) = container.read(mutation);
      expect(await runMutation.run(21), 42);
    });
  });
}

final currentTodo = Provider<String>((ref) => 'done');
