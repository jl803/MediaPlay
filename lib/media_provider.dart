import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'database_helper.dart';

enum ViewMode { grid, list }
enum MediaFilter { all, video, audio }

class MediaFile {
  String name;
  final String path;
  final bool isVideo;
  final String size;
  String? thumbnailPath;
  String? originalThumbnailPath;

  MediaFile({
    required this.name,
    required this.path,
    required this.isVideo,
    required this.size,
    this.thumbnailPath,
    this.originalThumbnailPath,
  });
}

class Playlist {
  final int id;
  String name;
  final DateTime createdAt;
  List<MediaFile> items;

  Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    this.items = const [],
  });
}

class MediaProvider extends ChangeNotifier {
  static const Set<String> _supportedExtensions = {
    'mp3',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'flac',
    'mp4',
    'mkv',
    'mov',
    'webm',
  };
  static const _prefViewMode = 'viewMode';
  static const _prefAutoPlayVideos = 'autoPlayVideos';
  static const _prefLoopVideos = 'loopVideos';
  static const _prefAutoPictureInPicture = 'autoPictureInPicture';
  static const _prefDoubleTapSeekSeconds = 'doubleTapSeekSeconds';
  static const _prefShowFileSize = 'showFileSize';
  static const _prefShowFileExtensions = 'showFileExtensions';
  static const _prefConfirmDestructiveActions = 'confirmDestructiveActions';
  static const _prefPlaybackPositionPrefix = 'playbackPositionMs:';
  static const _prefPlaybackDurationPrefix = 'playbackDurationMs:';

  List<MediaFile> _mediaFiles = [];
  List<Playlist> _playlists = [];
  ViewMode _viewMode = ViewMode.grid;
  MediaFilter _mediaFilter = MediaFilter.all;
  bool _isPicking = false;
  bool _isLoadingPlaylists = false;
  String _searchQuery = '';
  bool _autoPlayVideos = true;
  bool _loopVideos = false;
  bool _autoPictureInPicture = true;
  int _doubleTapSeekSeconds = 10;
  bool _showFileSize = true;
  bool _showFileExtensions = false;
  bool _confirmDestructiveActions = true;
  final Map<String, int> _savedPlaybackPositionsMs = {};
  final Map<String, int> _savedPlaybackDurationsMs = {};

  List<MediaFile> get mediaFiles => _mediaFiles;
  List<Playlist> get playlists => _playlists;
  ViewMode get viewMode => _viewMode;
  MediaFilter get mediaFilter => _mediaFilter;
  bool get isPicking => _isPicking;
  bool get isLoadingPlaylists => _isLoadingPlaylists;
  String get searchQuery => _searchQuery;
  bool get autoPlayVideos => _autoPlayVideos;
  bool get loopVideos => _loopVideos;
  bool get autoPictureInPicture => _autoPictureInPicture;
  int get doubleTapSeekSeconds => _doubleTapSeekSeconds;
  bool get showFileSize => _showFileSize;
  bool get showFileExtensions => _showFileExtensions;
  bool get confirmDestructiveActions => _confirmDestructiveActions;
  List<MediaFile> get filteredMediaFiles {
    final query = _searchQuery.trim().toLowerCase();
    return _mediaFiles.where((file) {
      final matchesFilter = switch (_mediaFilter) {
        MediaFilter.all => true,
        MediaFilter.video => file.isVideo,
        MediaFilter.audio => !file.isVideo,
      };

      final matchesQuery = query.isEmpty || file.name.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  MediaProvider() {
    _loadAppData();
  }

  Future<void> _loadAppData() async {
    await _loadSettings();
    _mediaFiles = await DatabaseHelper.instance.getAllMedia();
    await loadPlaylists(notify: false);
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _viewMode = (prefs.getString(_prefViewMode) ?? 'grid') == 'list' ? ViewMode.list : ViewMode.grid;
    _autoPlayVideos = prefs.getBool(_prefAutoPlayVideos) ?? true;
    _loopVideos = prefs.getBool(_prefLoopVideos) ?? false;
    _autoPictureInPicture = prefs.getBool(_prefAutoPictureInPicture) ?? true;
    _doubleTapSeekSeconds = prefs.getInt(_prefDoubleTapSeekSeconds) ?? 10;
    _showFileSize = prefs.getBool(_prefShowFileSize) ?? true;
    _showFileExtensions = prefs.getBool(_prefShowFileExtensions) ?? false;
    _confirmDestructiveActions = prefs.getBool(_prefConfirmDestructiveActions) ?? true;

    _savedPlaybackPositionsMs
      ..clear()
      ..addEntries(
        prefs
            .getKeys()
            .where((key) => key.startsWith(_prefPlaybackPositionPrefix))
            .map((key) => MapEntry(
                  key.substring(_prefPlaybackPositionPrefix.length),
                  prefs.getInt(key) ?? 0,
                ))
            .where((entry) => entry.value > 0),
      );

    _savedPlaybackDurationsMs
      ..clear()
      ..addEntries(
        prefs
            .getKeys()
            .where((key) => key.startsWith(_prefPlaybackDurationPrefix))
            .map((key) => MapEntry(
                  key.substring(_prefPlaybackDurationPrefix.length),
                  prefs.getInt(key) ?? 0,
                ))
            .where((entry) => entry.value > 0),
      );
  }

  Future<void> loadPlaylists({bool notify = true}) async {
    _isLoadingPlaylists = true;
    if (notify) {
      notifyListeners();
    }

    _playlists = await DatabaseHelper.instance.getAllPlaylistsWithMedia();
    _isLoadingPlaylists = false;

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> toggleViewMode(ViewMode mode) async {
    _viewMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefViewMode, mode == ViewMode.grid ? 'grid' : 'list');
    notifyListeners();
  }

  void setMediaFilter(MediaFilter filter) {
    if (_mediaFilter == filter) {
      return;
    }
    _mediaFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    if (_searchQuery == value) {
      return;
    }
    _searchQuery = value;
    notifyListeners();
  }

  Future<void> setAutoPlayVideos(bool value) async {
    _autoPlayVideos = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoPlayVideos, value);
    notifyListeners();
  }

  Future<void> setLoopVideos(bool value) async {
    _loopVideos = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefLoopVideos, value);
    notifyListeners();
  }

  Future<void> setAutoPictureInPicture(bool value) async {
    _autoPictureInPicture = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoPictureInPicture, value);
    notifyListeners();
  }

  Future<void> setDoubleTapSeekSeconds(int value) async {
    _doubleTapSeekSeconds = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefDoubleTapSeekSeconds, value);
    notifyListeners();
  }

  Future<void> setShowFileSize(bool value) async {
    _showFileSize = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefShowFileSize, value);
    notifyListeners();
  }

  Future<void> setShowFileExtensions(bool value) async {
    _showFileExtensions = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefShowFileExtensions, value);
    notifyListeners();
  }

  Future<void> setConfirmDestructiveActions(bool value) async {
    _confirmDestructiveActions = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefConfirmDestructiveActions, value);
    notifyListeners();
  }

  Future<Duration?> getSavedPlaybackPosition(String path) async {
    final cachedMilliseconds = _savedPlaybackPositionsMs[path];
    if (cachedMilliseconds != null && cachedMilliseconds > 0) {
      return Duration(milliseconds: cachedMilliseconds);
    }

    final prefs = await SharedPreferences.getInstance();
    final milliseconds = prefs.getInt('$_prefPlaybackPositionPrefix$path');
    if (milliseconds == null || milliseconds <= 0) {
      return null;
    }
    _savedPlaybackPositionsMs[path] = milliseconds;
    return Duration(milliseconds: milliseconds);
  }

  Future<void> savePlaybackPosition(
    String path,
    Duration position, {
    Duration? duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefPlaybackPositionPrefix$path';
    final nearStart = position <= const Duration(seconds: 2);
    final nearEnd = duration != null &&
        duration > Duration.zero &&
        position >= duration - const Duration(seconds: 2);

    if (nearStart || nearEnd) {
      await prefs.remove(key);
      await prefs.remove('$_prefPlaybackDurationPrefix$path');
      _savedPlaybackPositionsMs.remove(path);
      _savedPlaybackDurationsMs.remove(path);
      notifyListeners();
      return;
    }

    await prefs.setInt(key, position.inMilliseconds);
    if (duration != null && duration > Duration.zero) {
      await prefs.setInt('$_prefPlaybackDurationPrefix$path', duration.inMilliseconds);
      _savedPlaybackDurationsMs[path] = duration.inMilliseconds;
    }
    _savedPlaybackPositionsMs[path] = position.inMilliseconds;
    notifyListeners();
  }

  Future<void> clearPlaybackPosition(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefPlaybackPositionPrefix$path');
    await prefs.remove('$_prefPlaybackDurationPrefix$path');
    _savedPlaybackPositionsMs.remove(path);
    _savedPlaybackDurationsMs.remove(path);
    notifyListeners();
  }

  double? playbackProgressFraction(String path) {
    final positionMs = _savedPlaybackPositionsMs[path];
    final durationMs = _savedPlaybackDurationsMs[path];
    if (positionMs == null || durationMs == null || positionMs <= 0 || durationMs <= 0) {
      return null;
    }

    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  Future<void> updateVideoThumbnailFromPosition(MediaFile file, Duration position) async {
    if (!file.isVideo) {
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final thumbFolder = p.join(appDir.path, 'thumbnails');
    await Directory(thumbFolder).create(recursive: true);

    final currentFile = _mediaFiles.cast<MediaFile?>().firstWhere(
          (entry) => entry?.path == file.path,
          orElse: () => null,
        ) ??
        file;
    final previousThumbnailPath = currentFile.thumbnailPath;
    final uniqueThumbnailPath = p.join(
      thumbFolder,
      'resume_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final newThumbnailPath = await VideoThumbnail.thumbnailFile(
      video: file.path,
      thumbnailPath: uniqueThumbnailPath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 300,
      quality: 75,
      timeMs: position.inMilliseconds,
    );

    if (newThumbnailPath == null) {
      return;
    }

    _syncMediaThumbnail(file.path, newThumbnailPath);
    await DatabaseHelper.instance.updateMediaThumbnailPath(file.path, newThumbnailPath);
    notifyListeners();

    if (previousThumbnailPath != null &&
        previousThumbnailPath != currentFile.originalThumbnailPath &&
        previousThumbnailPath != newThumbnailPath) {
      await _deleteThumbnailFile(previousThumbnailPath);
    }
  }

  Future<void> restoreOriginalVideoThumbnail(MediaFile file) async {
    if (!file.isVideo) {
      return;
    }

    final currentFile = _mediaFiles.cast<MediaFile?>().firstWhere(
          (entry) => entry?.path == file.path,
          orElse: () => null,
        ) ??
        file;
    final previousThumbnailPath = currentFile.thumbnailPath;
    _syncMediaThumbnail(file.path, currentFile.originalThumbnailPath);
    await DatabaseHelper.instance.updateMediaThumbnailPath(
      file.path,
      currentFile.originalThumbnailPath,
    );
    notifyListeners();

    if (previousThumbnailPath != null &&
        previousThumbnailPath != currentFile.originalThumbnailPath) {
      await _deleteThumbnailFile(previousThumbnailPath);
    }
  }

  void _syncMediaThumbnail(String mediaPath, String? thumbnailPath) {
    for (final mediaFile in _mediaFiles.where((entry) => entry.path == mediaPath)) {
      mediaFile.thumbnailPath = thumbnailPath;
    }

    for (final playlist in _playlists) {
      for (final item in playlist.items.where((entry) => entry.path == mediaPath)) {
        item.thumbnailPath = thumbnailPath;
      }
    }
  }

  Future<void> _deleteThumbnailFile(String thumbnailPath) async {
    try {
      final thumbFile = File(thumbnailPath);
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
    } catch (e) {
      debugPrint("Error deleting thumbnail file: $e");
    }
  }

  String displayName(MediaFile file) {
    if (_showFileExtensions) {
      final extension = p.extension(file.path);
      return extension.isEmpty ? file.name : '${file.name}$extension';
    }
    return file.name;
  }

  Future<String?> renameFile(MediaFile file, String newName) async {
    final sanitized = newName.trim();
    if (sanitized.isEmpty) {
      return 'File name cannot be empty.';
    }

    await DatabaseHelper.instance.renameMedia(file.path, sanitized);
    file.name = sanitized;
    notifyListeners();
    return null;
  }

  Future<String?> createPlaylist(String name) async {
    final sanitized = name.trim();
    if (sanitized.isEmpty) {
      return 'Playlist name cannot be empty.';
    }

    final exists = _playlists.any(
      (playlist) => playlist.name.toLowerCase() == sanitized.toLowerCase(),
    );
    if (exists) {
      return 'A playlist with that name already exists.';
    }

    await DatabaseHelper.instance.createPlaylist(sanitized);
    await loadPlaylists(notify: false);
    notifyListeners();
    return null;
  }

  Future<String?> renamePlaylist(Playlist playlist, String newName) async {
    final sanitized = newName.trim();
    if (sanitized.isEmpty) {
      return 'Playlist name cannot be empty.';
    }

    final exists = _playlists.any(
      (entry) => entry.id != playlist.id && entry.name.toLowerCase() == sanitized.toLowerCase(),
    );
    if (exists) {
      return 'A playlist with that name already exists.';
    }

    await DatabaseHelper.instance.renamePlaylist(playlist.id, sanitized);
    playlist.name = sanitized;
    notifyListeners();
    return null;
  }

  Future<void> deletePlaylist(int playlistId) async {
    await DatabaseHelper.instance.deletePlaylist(playlistId);
    _playlists.removeWhere((playlist) => playlist.id == playlistId);
    notifyListeners();
  }

  bool isFileInPlaylist(int playlistId, String mediaPath) {
    final playlist = _playlists.cast<Playlist?>().firstWhere(
      (entry) => entry?.id == playlistId,
      orElse: () => null,
    );
    if (playlist == null) return false;
    return playlist.items.any((item) => item.path == mediaPath);
  }

  Future<void> addMediaToPlaylist(int playlistId, MediaFile file) async {
    if (isFileInPlaylist(playlistId, file.path)) {
      return;
    }

    await DatabaseHelper.instance.addMediaToPlaylist(playlistId, file.path);
    final playlistIndex = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (playlistIndex != -1) {
      _playlists[playlistIndex].items = [..._playlists[playlistIndex].items, file];
      notifyListeners();
    }
  }

  Future<void> removeMediaFromPlaylist(int playlistId, String mediaPath) async {
    await DatabaseHelper.instance.removeMediaFromPlaylist(playlistId, mediaPath);
    final playlistIndex = _playlists.indexWhere((playlist) => playlist.id == playlistId);
    if (playlistIndex != -1) {
      _playlists[playlistIndex].items =
          _playlists[playlistIndex].items.where((item) => item.path != mediaPath).toList();
      notifyListeners();
    }
  }

  Future<void> deleteFile(MediaFile file) async {
    // 1. Delete from database
    await DatabaseHelper.instance.deleteMedia(file.path);
    
    // 2. Delete the physical thumbnail file from disk if it exists
    if (file.thumbnailPath != null) {
      await _deleteThumbnailFile(file.thumbnailPath!);
    }
    if (file.originalThumbnailPath != null &&
        file.originalThumbnailPath != file.thumbnailPath) {
      await _deleteThumbnailFile(file.originalThumbnailPath!);
    }

    // 3. Update UI
    _mediaFiles.remove(file);
    for (final playlist in _playlists) {
      playlist.items = playlist.items.where((item) => item.path != file.path).toList();
    }
    notifyListeners();
  }

  Future<void> pickFiles() async {
    if (_isPicking) return; // Prevent multiple picker instances

    _isPicking = true;
    notifyListeners();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.media,
      );

      if (result != null) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String thumbFolder = p.join(appDir.path, 'thumbnails');
        
        await Directory(thumbFolder).create(recursive: true);

        for (var file in result.files) {
          if (file.path != null) {
            final extension = (file.extension ?? p.extension(file.name).replaceFirst('.', ''))
                .toLowerCase();
            if (!_supportedExtensions.contains(extension)) {
              continue;
            }

            final isVideo = {'mp4', 'mkv', 'mov', 'webm'}.contains(extension);
            double sizeInMb = file.size / (1024 * 1024);
            
            String nameWithoutExtension = p.basenameWithoutExtension(file.name);

            String? thumbPath;
            if (isVideo) {
              try {
                thumbPath = await VideoThumbnail.thumbnailFile(
                  video: file.path!,
                  thumbnailPath: thumbFolder,
                  imageFormat: ImageFormat.JPEG,
                  maxWidth: 300,
                  quality: 75,
                );
              } catch (e) {
                debugPrint("Thumbnail failed for ${file.name}: $e");
              }
            }

            final mediaFile = MediaFile(
              name: nameWithoutExtension,
              path: file.path!,
              isVideo: isVideo,
              size: '${sizeInMb.toStringAsFixed(1)} MB',
              thumbnailPath: thumbPath,
              originalThumbnailPath: thumbPath,
            );

            await DatabaseHelper.instance.insertMedia(mediaFile);
            
            _mediaFiles.add(mediaFile);
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint("Error picking files: $e");
    } finally {
      _isPicking = false;
      notifyListeners();
    }
  }
}
