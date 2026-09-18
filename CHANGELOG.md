## 0.1.0

- Initial release.
- `createQuery` / `createQueryFamily` — cached async queries with sliding `staleTime` cache window.
- `createQueryEditable` / `createQueryEditableFamily` — queries with manually overridable state (optimistic updates).
- `createMutation` / `createMutationWithParam` — mutations with idle/pending/success/error state, built on Riverpod 3's experimental `Mutation` API.
- `createInfinityQuery` — cursor-based infinite pagination with `fetchNextPage` / `refresh`.
- `createStore` / `createStoreFamily` — synchronous state containers with the same `staleTime` / `persist` semantics.
- `ref.staleFor(duration)` extension for keeping any `autoDispose` provider alive for a grace period after its last listener is removed.
