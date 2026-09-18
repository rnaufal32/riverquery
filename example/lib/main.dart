import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverquery/riverquery.dart';

// Fake API
Future<List<String>> fetchPosts(Ref ref) async {
  await Future.delayed(const Duration(seconds: 1));
  return ['Post 1', 'Post 2', 'Post 3'];
}

final postsQuery = createQuery(fetchPosts);

void main() => runApp(const ProviderScope(child: MyApp()));

class MyApp extends StatelessWidget { ... }

class PostsPage extends ConsumerWidget {
  Widget build(context, ref) {
    final posts = ref.watch(postsQuery);
    return posts.when(
      data: (data) => ListView(...),
      loading: () => CircularProgressIndicator(),
      error: (e, st) => Text('Error: $e'),
    );
  }
}
