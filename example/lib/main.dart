import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverquery/riverquery.dart';

void main() {
  runApp(const ProviderScope(child: RiverQueryApp()));
}

// ---------------------------------------------------------------------------
// Fake API
// ---------------------------------------------------------------------------

/// Simulated network latency for every fake API call.
const _latency = Duration(milliseconds: 800);

class Todo {
  const Todo({required this.id, required this.title, this.done = false});

  final int id;
  final String title;
  final bool done;

  Todo copyWith({String? title, bool? done}) =>
      Todo(id: id, title: title ?? this.title, done: done ?? this.done);
}

class FeedItem {
  const FeedItem({required this.id, required this.title});

  final int id;
  final String title;
}

/// A fake in-memory database that survives across query refreshes.
class FakeApi {
  int _nextId = 4;
  bool _shouldFail = false;
  final List<Todo> _todos = [
    const Todo(id: 1, title: 'Install riverquery', done: true),
    const Todo(id: 2, title: 'Try createQuery'),
    const Todo(id: 3, title: 'Add a mutation'),
  ];

  Future<List<Todo>> getTodos() async {
    await Future<void>.delayed(_latency);
    return List.of(_todos);
  }

  /// Fails every other call to demonstrate mutation error states.
  Future<Todo> addTodo(String title) async {
    await Future<void>.delayed(_latency);
    _shouldFail = !_shouldFail;
    if (_shouldFail) throw Exception('Server error (fake)');
    final todo = Todo(id: _nextId++, title: title);
    _todos.insert(0, todo);
    return todo;
  }

  Future<void> toggleTodo(Todo todo) async {
    await Future<void>.delayed(_latency);
    final index = _todos.indexWhere((t) => t.id == todo.id);
    _todos[index] = todo.copyWith(done: !todo.done);
  }

  /// Returns a page of fake feed items for the given cursor.
  /// The first page uses `cursor: null`, passed by the infinity query.
  Future<List<FeedItem>> getFeed({required int cursor}) async {
    await Future<void>.delayed(_latency);
    return List.generate(
      10,
      (i) => FeedItem(id: cursor + i, title: 'Feed item #${cursor + i + 1}'),
    );
  }
}

final apiProvider = Provider<FakeApi>((ref) => FakeApi());

// ---------------------------------------------------------------------------
// Queries & mutations
// ---------------------------------------------------------------------------

/// Cached for 1 minute after the last widget stops watching it (default
/// `staleTime`). Switch back to the Todos tab within a minute and there is
/// no loading spinner — data comes from cache.
final todosQuery = createQuery((ref) => ref.watch(apiProvider).getTodos());

/// Adding a todo. Widgets watch the provider to get a `(state, runner)` pair:
/// the state drives the button UI, the runner executes the side-effect.
/// The fake API fails every other call, so you can see `MutationError` in
/// action.
final addTodoMutation = createMutationWithParam<Todo, String>(
  (tsx, title) => tsx.get(apiProvider).addTodo(title),
);

final toggleTodoMutation = createMutationWithParam<void, Todo>(
  (tsx, todo) => tsx.get(apiProvider).toggleTodo(todo),
);

/// Cursor-based pagination. `getNextCursor` derives the next page cursor from
/// the last loaded page; returning `null` means "no more pages".
final feedQuery = createInfinityQuery<FeedItem, int>(
  fetch: (tsx, cursor) => tsx.get(apiProvider).getFeed(cursor: cursor ?? 0),
  getNextCursor: (container, lastPage, pages) {
    if (lastPage == null || lastPage.isEmpty) return null;
    // Stop after 5 pages (50 items) so "no more pages" is reachable in the demo.
    if (pages.length >= 5) return null;
    return lastPage.last.id + 1;
  },
);

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class RiverQueryApp extends StatelessWidget {
  const RiverQueryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'riverquery example',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('riverquery — $_tabTitle')),
      body: switch (_tab) {
        0 => const TodosTab(),
        _ => const FeedTab(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Todos'),
          NavigationDestination(icon: Icon(Icons.feed), label: 'Feed'),
        ],
      ),
    );
  }

  String get _tabTitle => _tab == 0 ? 'createQuery + createMutation' : 'createInfinityQuery';
}

// ---------------------------------------------------------------------------
// Tab 1: createQuery + createMutation
// ---------------------------------------------------------------------------

class TodosTab extends ConsumerWidget {
  const TodosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(todosQuery);

    return switch (todos) {
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
      AsyncError(:final error) => ErrorRetryView(
        message: '$error',
        onRetry: () => ref.invalidate(todosQuery),
      ),
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: () async => ref.refresh(todosQuery.future),
        child: TodoList(todos: value),
      ),
    };
  }
}

class TodoList extends ConsumerWidget {
  const TodoList({super.key, required this.todos});

  final List<Todo> todos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (addState, addMutation) = ref.watch(addTodoMutation);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: MutationStateBanner(state: addState),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: todos.length,
            itemBuilder: (context, i) {
              final todo = todos[i];
              return CheckboxListTile(
                value: todo.done,
                title: Text(todo.title),
                onChanged: (_) async {
                  final (_, toggle) = ref.read(toggleTodoMutation);
                  await toggle.run(todo);
                  ref.invalidate(todosQuery);
                },
              );
            },
          ),
        ),
        SafeArea(
          child: AddTodoField(
            isPending: addState.isPending,
            onSubmit: (title) async {
              await addMutation.run(title);
              ref.invalidate(todosQuery);
            },
          ),
        ),
      ],
    );
  }
}

/// Shows the live [MutationState] — this is the "free" part of riverquery:
/// loading/error/success UI without any manual state management.
class MutationStateBanner extends StatelessWidget {
  const MutationStateBanner({super.key, required this.state});

  final MutationState<Todo> state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return switch (state) {
      MutationPending() => const LinearProgressIndicator(),
      MutationError(:final error) => ColoredBox(
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text('Add failed: $error — try again'),
        ),
      ),
      MutationSuccess() => const Text('Todo added!'),
      _ => const Text('Type below and submit to add a todo.'),
    };
  }
}

class AddTodoField extends StatefulWidget {
  const AddTodoField({super.key, required this.isPending, required this.onSubmit});

  final bool isPending;
  final Future<void> Function(String title) onSubmit;

  @override
  State<AddTodoField> createState() => _AddTodoFieldState();
}

class _AddTodoFieldState extends State<AddTodoField> {
  final _controller = TextEditingController();

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    _controller.clear();
    await widget.onSubmit(title);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'New todo title',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 8),
          widget.isPending
              ? const CircularProgressIndicator()
              : IconButton.filled(
                  onPressed: _submit,
                  icon: const Icon(Icons.add),
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: createInfinityQuery
// ---------------------------------------------------------------------------

class FeedTab extends ConsumerWidget {
  const FeedTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedQuery);
    // Mutation implements ProviderListenable, so it can be watched directly.
    final loadState = ref.watch(feed.loadState);
    final isFetching = loadState is MutationPending;

    return ValueListenableBuilder(
      valueListenable: feed.data,
      builder: (context, items, _) {
        if (items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Fetch the next page when the user approaches the end of the
            // list. `fetchNext` is a no-op while a fetch is already pending.
            if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 300) {
              feed.fetchNext();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: feed.refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == items.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: isFetching
                          ? const CircularProgressIndicator()
                          : const SizedBox.shrink(),
                    ),
                  );
                }
                return ListTile(title: Text(items[i].title));
              },
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
