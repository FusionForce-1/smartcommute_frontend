// lib/providers/load_state.dart

/// Where a screen's first load stands. Later refreshes keep the data on
/// screen and only report failures.
enum LoadState { idle, loading, ready, error }
