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

  MediaFile({
    required this.name,
    required this.path,
    required this.isVideo,
    required this.size,
    this.thumbnailPath,
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
  static const _prefViewMode = 'viewMode';
  static const _prefAutoPlayVideos = 'autoPlayVideos';
  static const _prefLoopVideos = 'loopVideos';
  static const _prefShowFileSize = 'showFileSize';
  static const _prefConfirmDestructiveActions = 'confirmDestructiveActions';

  List<MediaFile> _mediaFiles = [];
  List<Playlist> _playlists = [];
  ViewMode _viewMode = ViewMode.grid;
  MediaFilter _mediaFilter = MediaFilter.all;
  bool _isPicking = false;
  bool _isLoadingPlaylists = false;
  String _searchQuery = '';
  bool _autoPlayVideos = true;
  bool _loopVideos = false;
  bool _showFileSize = true;
  bool _confirmDestructiveActions = true;

  List<MediaFile> get mediaFiles => _mediaFiles;
  List<Playlist> get playlists => _playlists;
  ViewMode get viewMode => _viewMode;
  MediaFilter get mediaFilter => _mediaFilter;
  bool get isPicking => _isPicking;
  bool get isLoadingPlaylists => _isLoadingPlaylists;
  String get searchQuery => _searchQuery;
  bool get autoPlayVideos => _autoPlayVideos;
  bool get loopVideos => _loopVideos;
  bool get showFileSize => _showFileSize;
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
    _showFileSize = prefs.getBool(_prefShowFileSize) ?? true;
    _confirmDestructiveActions = prefs.getBool(_prefConfirmDestructiveActions) ?? true;
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

  Future<void> setShowFileSize(bool value) async {
    _showFileSize = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefShowFileSize, value);
    notifyListeners();
  }

  Future<void> setConfirmDestructiveActions(bool value) async {
    _confirmDestructiveActions = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefConfirmDestructiveActions, value);
    notifyListeners();
  }

  Future<void> renameFile(MediaFile file, String newName) async {
    await DatabaseHelper.instance.renameMedia(file.path, newName);
    file.name = newName;
    notifyListeners();
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
      try {
        final thumbFile = File(file.thumbnailPath!);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      } catch (e) {
        debugPrint("Error deleting thumbnail file: $e");
      }
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
        type: FileType.custom,
        allowedExtensions: ['mp3', 'mp4', 'mkv', 'wav'],
      );

      if (result != null) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String thumbFolder = p.join(appDir.path, 'thumbnails');
        
        await Directory(thumbFolder).create(recursive: true);

        for (var file in result.files) {
          if (file.path != null) {
            bool isVideo = file.extension == 'mp4' || file.extension == 'mkv';
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
