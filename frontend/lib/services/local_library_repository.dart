import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_details.dart';
import '../models/media_item.dart';

final libraryControllerProvider = StateNotifierProvider<LibraryController, LibraryState>((ref) {
  return LibraryController()..load();
});

class LibraryState {
  const LibraryState({
    this.isLoading = true,
    this.favorites = const [],
    this.progress = const [],
  });

  final bool isLoading;
  final List<MediaItem> favorites;
  final List<PlaybackProgress> progress;

  List<MediaItem> get continueWatchingItems => progress.map((entry) => entry.item).toList(growable: false);

  bool isFavorite(MediaDetails details) {
    return favorites.any((item) => item.id == details.id && item.mediaType == details.mediaType);
  }

  PlaybackProgress? progressFor(MediaDetails details) {
    for (final entry in progress) {
      if (entry.item.id == details.id && entry.item.mediaType == details.mediaType) return entry;
    }
    return null;
  }

  LibraryState copyWith({
    bool? isLoading,
    List<MediaItem>? favorites,
    List<PlaybackProgress>? progress,
  }) {
    return LibraryState(
      isLoading: isLoading ?? this.isLoading,
      favorites: favorites ?? this.favorites,
      progress: progress ?? this.progress,
    );
  }
}

class PlaybackProgress {
  const PlaybackProgress({
    required this.item,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAt,
    this.season,
    this.episode,
  });

  final MediaItem item;
  final int positionSeconds;
  final int durationSeconds;
  final DateTime updatedAt;
  final int? season;
  final int? episode;

  double get fraction {
    if (durationSeconds <= 0) return 0;
    return (positionSeconds / durationSeconds).clamp(0, 1).toDouble();
  }

  String get label {
    final remaining = (durationSeconds - positionSeconds).clamp(0, durationSeconds);
    final minutes = (remaining / 60).ceil();
    return minutes <= 0 ? 'Almost done' : '$minutes min left';
  }

  Map<String, dynamic> toJson() {
    return {
      'item': item.toJson(),
      'positionSeconds': positionSeconds,
      'durationSeconds': durationSeconds,
      'updatedAt': updatedAt.toIso8601String(),
      'season': season,
      'episode': episode,
    };
  }

  factory PlaybackProgress.fromJson(Map<String, dynamic> json) {
    return PlaybackProgress(
      item: MediaItem.fromJson((json['item'] as Map).cast<String, dynamic>()),
      positionSeconds: (json['positionSeconds'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 1,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      season: (json['season'] as num?)?.toInt(),
      episode: (json['episode'] as num?)?.toInt(),
    );
  }
}

class LibraryController extends StateNotifier<LibraryState> {
  LibraryController() : super(const LibraryState());

  static const _favoritesKey = 'library.favorites.v1';
  static const _progressKey = 'library.playback_progress.v1';

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    state = LibraryState(
      isLoading: false,
      favorites: _readMediaList(_favoritesKey),
      progress: _readProgressList(),
    );
  }

  Future<void> toggleFavorite(MediaDetails details) async {
    await _ensureLoaded();
    final item = details.toMediaItem();
    final exists = state.favorites.any((entry) => entry.id == item.id && entry.mediaType == item.mediaType);
    final next = exists
        ? state.favorites.where((entry) => entry.id != item.id || entry.mediaType != item.mediaType).toList(growable: false)
        : [item, ...state.favorites];
    state = state.copyWith(favorites: next);
    await _writeMediaList(_favoritesKey, next);
  }

  Future<void> saveProgress(
    MediaDetails details, {
    int positionSeconds = 420,
    int durationSeconds = 3600,
    int? season,
    int? episode,
  }) async {
    await _ensureLoaded();
    final item = details.toMediaItem();
    final safeDuration = durationSeconds <= 0 ? 1 : durationSeconds;
    final withoutCurrent =
        state.progress.where((entry) => entry.item.id != item.id || entry.item.mediaType != item.mediaType).toList();
    final entry = PlaybackProgress(
      item: item,
      positionSeconds: positionSeconds.clamp(0, safeDuration).toInt(),
      durationSeconds: safeDuration,
      updatedAt: DateTime.now(),
      season: season,
      episode: episode,
    );
    final next = [entry, ...withoutCurrent].take(30).toList(growable: false);
    state = state.copyWith(progress: next);
    await _writeProgressList(next);
  }

  Future<void> clearProgress(PlaybackProgress progress) async {
    await _ensureLoaded();
    final next = state.progress
        .where((entry) => entry.item.id != progress.item.id || entry.item.mediaType != progress.item.mediaType)
        .toList(growable: false);
    state = state.copyWith(progress: next);
    await _writeProgressList(next);
  }

  Future<void> _ensureLoaded() async {
    if (_prefs != null) return;
    await load();
  }

  List<MediaItem> _readMediaList(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.whereType<Map>().map((item) => MediaItem.fromJson(item.cast<String, dynamic>())).toList(growable: false);
  }

  List<PlaybackProgress> _readProgressList() {
    final raw = _prefs?.getString(_progressKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    final entries = decoded.whereType<Map>().map((item) => PlaybackProgress.fromJson(item.cast<String, dynamic>())).toList();
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  Future<void> _writeMediaList(String key, List<MediaItem> items) async {
    await _prefs?.setString(key, jsonEncode(items.map((item) => item.toJson()).toList()));
  }

  Future<void> _writeProgressList(List<PlaybackProgress> items) async {
    await _prefs?.setString(_progressKey, jsonEncode(items.map((item) => item.toJson()).toList()));
  }
}
