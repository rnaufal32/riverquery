# riverquery

TanStack Query-inspired data fetching & caching for Flutter, built on [Riverpod 3](https://riverpod.dev).

Caching with a sliding `staleTime` window, mutations with built-in loading/error/success state, and infinite pagination — without writing a `Notifier` yourself.

## Features

- **`createQuery`** — cached async queries (`FutureProvider` under the hood) with an optional `staleTime` grace period
- **`createQueryEditable`** — queries whose state can be manually overridden (optimistic updates, manual loading/error)
- **`createMutation`** — side-effects with ready-made `MutationState` (idle / pending / success / error) using Riverpod 3's experimental `Mutation` API
- **`createInfinityQuery`** — cursor-based pagination (`fetchNextPage`, `refresh`, flattened `data`)
- **`createStore`** — synchronous state containers with the same caching semantics
- All of the above have **family** variants and a `persist` mode

## Getting started

```yaml
dependencies:
  flutter_riverpod: ^3.0.0
  riverquery: ^0.1.0
```

Wrap your app with `ProviderScope` as usual:

```dart
void main() => runApp(const ProviderScope(child: MyApp()));
```

## Usage

### Query

Fetches data and caches it. By default, the result stays alive for 1 minute after the last widget stops watching it (sliding window — refreshed on every rebuild), then disposes.

```dart
final postsQuery = createQuery((ref) => api.getPosts());

// Family version:
final postQuery = createQueryFamily((ref, int id) => api.getPost(id));

class PostsList extends ConsumerWidget {
  const PostsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(postsQuery);

    return posts.when(
      data: (data) => ListView.builder(
        itemCount: data.length,
        itemBuilder: (_, i) => ListTile(title: Text(data[i])),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error: $e'),
    );
  }
}
```

Cache behavior:

| | Behavior |
|---|---|
| `staleTime: default` | Cached 1 min after last listener leaves, then disposed |
| `staleTime: Duration(minutes: 5)` | Custom grace period |
| `staleTime: null` | Disposes immediately when unwatched (re-fetches on next watch) |
| `persist: true` | Never disposes; lives for the app's lifetime |

### Editable query (optimistic updates)

A query you can override manually — useful for optimistic updates or manual loading/error states.

```dart
final todoQuery = createQueryEditable((ref) => api.getTodos());

// Somewhere in a mutation/callback:
ref.read(todoQuery.notifier).setValue(optimisticTodos);
```

### Mutation

Wraps Riverpod 3's experimental `Mutation` so you get a state + runner pair from a single provider.

```dart
final addTodoMutation = createMutationWithParam((tsx, String title) => api.addTodo(title));

class AddTodoButton extends ConsumerWidget {
  const AddTodoButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (state, mutation) = ref.watch(addTodoMutation);

    return switch (state) {
      MutationPending() => const CircularProgressIndicator(),
      MutationError(:final error) => Text('Failed: $error'),
      _ => FilledButton(
        onPressed: () => mutation.run('New todo'),
        child: const Text('Add'),
      ),
    };
  }
}
```

### Infinite query

Cursor-based pagination with `fetchNextPage` / `refresh` and a flattened `data` notifier.

```dart
final feedQuery = createInfinityQuery<String, int>(
  fetch: (tsx, cursor) => api.getFeed(cursor: cursor),
  getNextCursor: (container, lastPage, pages) => lastPage?.lastOrNull?.id,
);

class Feed extends ConsumerWidget {
  const Feed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedQuery);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
          feed.fetchNext();
        }
        return false;
      },
      child: ValueListenableBuilder(
        valueListenable: feed.data,
        builder: (_, items, __) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) => ListTile(title: Text(items[i])),
        ),
      ),
    );
  }
}
```

See the [example app](https://github.com/rnaufal32/riverquery/tree/main/example) for a complete, runnable demo of query, mutation, and infinite query together.

## Additional information

- Requires Riverpod 3.x (`flutter_riverpod ^3.0.0`)
- `Mutation` is an **experimental** Riverpod API — its behavior may change upstream without a major version bump
- Issues and PRs: https://github.com/rnaufal32/riverquery
