import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';
import 'media_provider.dart';
import 'media_player_controls.dart';
import 'audio_player_screen.dart';

const _appBackground = Color(0xFF000000);
const _appSurface = Color(0xFF121212);
const _appAccent = Color(0xFF3B82F6);

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => MediaProvider(),
      child: const MediaPlayApp(),
    ),
  );
}

class MediaPlayApp extends StatelessWidget {
  const MediaPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediaPlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _appBackground,
        primaryColor: _appAccent,
        colorScheme: const ColorScheme.dark(
          primary: _appAccent,
          secondary: _appAccent,
          surface: _appSurface,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    LibraryScreen(),
    PlaylistsScreen(),
    BrowseScreen(),
    SettingsScreen(),
  ];

  static const List<({IconData icon, String label})> _navItems = [
    (icon: Icons.library_books, label: 'Library'),
    (icon: Icons.playlist_play, label: 'Playlists'),
    (icon: Icons.folder_open_rounded, label: 'Browse'),
    (icon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: _AnimatedBottomNavBar(
        currentIndex: _selectedIndex,
        items: _navItems,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

void _openMediaPlayer(BuildContext context, MediaFile file) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => file.isVideo
          ? VideoPlayerScreen(file: file)
          : AudioPlayerScreen(file: file),
    ),
  );
}

String _displayName(MediaProvider provider, MediaFile file) {
  return provider.displayName(file);
}

class _AnimatedBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final List<({IconData icon, String label})> items;
  final ValueChanged<int> onTap;

  const _AnimatedBottomNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          margin: EdgeInsets.zero,
          height: isLandscape ? 48 : 74,
          decoration: BoxDecoration(
            color: const Color(0xFF171C1D),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(i),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      overlayColor: MaterialStateProperty.all(Colors.transparent),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(vertical: isLandscape ? 2 : 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              items[i].icon,
                              size: isLandscape ? 16 : 22,
                              color: i == currentIndex ? _appAccent : const Color(0xFF8A9599),
                            ),
                            SizedBox(height: isLandscape ? 2 : 5),
                            Text(
                              items[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: i == currentIndex ? _appAccent : const Color(0xFF8A9599),
                                fontSize: isLandscape ? 9 : 11,
                                fontWeight: i == currentIndex ? FontWeight.w600 : FontWeight.w500,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MediaProvider>(context);
    final playlists = provider.playlists;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Playlists',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                ),
                IconButton(
                  onPressed: () => _showCreatePlaylistDialog(context, provider),
                  icon: const Icon(Icons.add_circle_outline, color: _appAccent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              playlists.isEmpty
                  ? 'Create a playlist to start organizing your library.'
                  : '${playlists.length} playlist${playlists.length == 1 ? '' : 's'} ready to go',
              style: const TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: provider.isLoadingPlaylists
                  ? const Center(child: CircularProgressIndicator())
                  : playlists.isEmpty
                      ? _PlaylistEmptyState(
                          onCreate: () => _showCreatePlaylistDialog(context, provider),
                        )
                      : ListView.separated(
                          itemCount: playlists.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final playlist = playlists[index];
                            return _PlaylistCard(playlist: playlist);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MediaProvider>(context);
    final defaultViewLabel = provider.viewMode == ViewMode.grid ? 'Grid' : 'List';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.3),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Playback',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _SettingsActionRow(
                title: 'Default view',
                subtitle: defaultViewLabel,
                onTap: () => _showDefaultViewPicker(context, provider),
              ),
              _SettingsSwitchRow(
                title: 'Autoplay videos',
                subtitle: 'Start playback automatically',
                value: provider.autoPlayVideos,
                onChanged: provider.setAutoPlayVideos,
              ),
              _SettingsSwitchRow(
                title: 'Loop videos',
                subtitle: 'Repeat videos continuously',
                value: provider.loopVideos,
                onChanged: provider.setLoopVideos,
              ),
              _SettingsSwitchRow(
                title: 'Auto Picture in Picture',
                subtitle: 'Enter PiP when leaving the app during playback',
                value: provider.autoPictureInPicture,
                onChanged: provider.setAutoPictureInPicture,
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Library',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _SettingsSwitchRow(
                title: 'Show file size',
                subtitle: 'Display size in media lists',
                value: provider.showFileSize,
                onChanged: provider.setShowFileSize,
              ),
              _SettingsSwitchRow(
                title: 'Show file extensions',
                subtitle: 'Display extensions like .mp3 and .mp4',
                value: provider.showFileExtensions,
                onChanged: provider.setShowFileExtensions,
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Safety',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _SettingsSwitchRow(
                title: 'Confirm destructive actions',
                subtitle: 'Ask before deleting media or playlists',
                value: provider.confirmDestructiveActions,
                onChanged: provider.setConfirmDestructiveActions,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MediaProvider>(context);
    final recentFiles = provider.mediaFiles.reversed.take(6).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Browse',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.3),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Import',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _SettingsActionRow(
                title: provider.isPicking ? 'Opening file picker...' : 'Browse device',
                subtitle: 'Supported formats: MP3, MP4, MKV, WAV',
                showDivider: false,
                onTap: provider.isPicking ? () {} : provider.pickFiles,
              ),
            ],
          ),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recently Added',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
                ),
                Text(
                  '${provider.mediaFiles.length} total',
                  style: const TextStyle(color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (recentFiles.isEmpty)
            _SettingsGroup(
              children: const [
                _BrowseInfoRow(
                  message: 'No imported files yet. Use Browse device to add media to your library.',
                ),
              ],
            )
          else
            _SettingsGroup(
              children: [
                for (var i = 0; i < recentFiles.length; i++)
                  _BrowseRecentRow(
                    file: recentFiles[i],
                    showDivider: i != recentFiles.length - 1,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BrowseInfoRow extends StatelessWidget {
  final String message;

  const _BrowseInfoRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      showDivider: false,
      child: Text(
        message,
        style: const TextStyle(color: Colors.blueGrey, fontSize: 15, height: 1.35),
      ),
    );
  }
}

class _BrowseRecentRow extends StatelessWidget {
  final MediaFile file;
  final bool showDivider;

  const _BrowseRecentRow({
    required this.file,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MediaProvider>(context);

    return _SettingsRowShell(
      showDivider: showDivider,
      child: InkWell(
        onTap: () {
          _openMediaPlayer(context, file);
        },
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            _MediaThumbnail(file: file, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName(provider, file),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.showFileSize
                        ? '${file.isVideo ? 'Video' : 'Audio'} • ${file.size}'
                        : (file.isVideo ? 'Video' : 'Audio'),
                    style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 28),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRowShell extends StatelessWidget {
  final Widget child;
  final bool showDivider;

  const _SettingsRowShell({
    required this.child,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: child,
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.white.withOpacity(0.08),
          ),
      ],
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  const _SettingsActionRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      showDivider: showDivider,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 28),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const _SettingsSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      showDivider: showDivider,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: _appAccent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}

Future<void> _showDefaultViewPicker(BuildContext context, MediaProvider provider) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: _appSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: const Text('Grid'),
              trailing: provider.viewMode == ViewMode.grid ? const Icon(Icons.check, color: _appAccent) : null,
              onTap: () async {
                await provider.toggleViewMode(ViewMode.grid);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('List'),
              trailing: provider.viewMode == ViewMode.list ? const Icon(Icons.check, color: _appAccent) : null,
              onTap: () async {
                await provider.toggleViewMode(ViewMode.list);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    },
  );
}

class _PlaylistEmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _PlaylistEmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'No playlists yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Build playlists for your favorite videos and audio files.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create Playlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _appAccent,
              foregroundColor: _appBackground,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;

  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MediaProvider>(context);
    final preview = playlist.items.take(3).toList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaylistDetailScreen(playlistId: playlist.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: _appSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.08)),
              bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.queue_music_rounded, color: _appAccent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${playlist.items.length} item${playlist.items.length == 1 ? '' : 's'}',
                            style: const TextStyle(color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showPlaylistMenu(context, provider, playlist),
                      icon: const Icon(Icons.more_horiz, color: Colors.blueGrey, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (preview.isEmpty)
                  const Text(
                    'This playlist is empty. Add media from the Library tab.',
                    style: TextStyle(color: Colors.blueGrey),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: preview
                        .map(
                          (file) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Text(
                              _displayName(provider, file),
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlaylistDetailScreen extends StatelessWidget {
  final int playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MediaProvider>(context);
    final playlist = provider.playlists.cast<Playlist?>().firstWhere(
      (entry) => entry?.id == playlistId,
      orElse: () => null,
    );

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: Text('Playlist not found', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showAddMediaPickerForPlaylist(context, provider, playlist),
            icon: const Icon(Icons.playlist_add, color: _appAccent),
          ),
          IconButton(
            onPressed: () => _showPlaylistMenu(context, provider, playlist, fromDetail: true),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: playlist.items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: _appSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.library_music_outlined, color: _appAccent, size: 52),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'This playlist is empty',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add items from your library to fill it out.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddMediaPickerForPlaylist(context, provider, playlist),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Media'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _appAccent,
                        foregroundColor: _appBackground,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: playlist.items.length,
              itemBuilder: (context, index) {
                final file = playlist.items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _appSurface,
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.08)),
                      bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  child: ListTile(
                    onTap: () {
                      _openMediaPlayer(context, file);
                    },
                    leading: _MediaThumbnail(file: file, size: 52),
                    title: Text(_displayName(provider, file)),
                    subtitle: Text(
                      '${file.isVideo ? 'Video' : 'Audio'} • ${file.size}',
                      style: const TextStyle(color: Colors.blueGrey),
                    ),
                    trailing: IconButton(
                      onPressed: () => provider.removeMediaFromPlaylist(playlist.id, file.path),
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  final MediaFile file;
  final double size;

  const _MediaThumbnail({required this.file, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _appBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: file.thumbnailPath != null
          ? Image.file(
              File(file.thumbnailPath!),
              fit: BoxFit.cover,
            )
          : Icon(
              file.isVideo ? Icons.play_circle_outline : Icons.music_note,
              color: _appAccent.withOpacity(0.65),
            ),
    );
  }
}

Future<void> _showPlaylistMenu(
  BuildContext context,
  MediaProvider provider,
  Playlist playlist, {
  bool fromDetail = false,
}) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: _appSurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      return SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: _appAccent),
              title: const Text('Rename Playlist'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRenamePlaylistDialog(context, provider, playlist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete Playlist', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final shouldDelete = provider.confirmDestructiveActions
                    ? await _showDeletePlaylistDialog(context, playlist.name)
                    : true;
                if (shouldDelete == true) {
                  await provider.deletePlaylist(playlist.id);
                  if (fromDetail && context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showCreatePlaylistDialog(
  BuildContext context,
  MediaProvider provider, {
  MediaFile? fileToAdd,
}) async {
  final controller = TextEditingController();
  String? errorText;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _appSurface,
            title: const Text('Create Playlist'),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Playlist name',
                errorText: errorText,
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _appAccent),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: Colors.blueGrey)),
              ),
              TextButton(
                onPressed: () async {
                  final message = await provider.createPlaylist(controller.text);
                  if (message != null) {
                    setDialogState(() => errorText = message);
                    return;
                  }

                  if (fileToAdd != null) {
                    final playlist = provider.playlists.first;
                    await provider.addMediaToPlaylist(playlist.id, fileToAdd);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${fileToAdd.name} added to ${playlist.name}.')),
                      );
                    }
                  }

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Create', style: TextStyle(color: _appAccent)),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showRenamePlaylistDialog(
  BuildContext context,
  MediaProvider provider,
  Playlist playlist,
) async {
  final controller = TextEditingController(text: playlist.name);
  String? errorText;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _appSurface,
            title: const Text('Rename Playlist'),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                errorText: errorText,
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _appAccent),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: Colors.blueGrey)),
              ),
              TextButton(
                onPressed: () async {
                  final message = await provider.renamePlaylist(playlist, controller.text);
                  if (message != null) {
                    setDialogState(() => errorText = message);
                    return;
                  }
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Save', style: TextStyle(color: _appAccent)),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<bool?> _showDeletePlaylistDialog(BuildContext context, String playlistName) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: _appSurface,
        title: const Text('Delete Playlist'),
        content: Text('Delete "$playlistName"? The media files will stay in your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.blueGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      );
    },
  );
}

Future<bool?> _showDeleteMediaDialog(BuildContext context, String mediaName) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: _appSurface,
        title: const Text('Delete Media'),
        content: Text('Delete "$mediaName" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.blueGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      );
    },
  );
}

Future<void> _showAddToPlaylistSheet(
  BuildContext context,
  MediaFile file,
  MediaProvider provider,
) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: _appSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add "${_displayName(provider, file)}" to playlist',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_circle_outline, color: _appAccent),
                title: const Text('Create new playlist'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showCreatePlaylistDialog(context, provider, fileToAdd: file);
                },
              ),
              const SizedBox(height: 8),
              if (provider.playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No playlists yet. Create one to get started.',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: provider.playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = provider.playlists[index];
                      final alreadyAdded = provider.isFileInPlaylist(playlist.id, file.path);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          alreadyAdded ? Icons.check_circle : Icons.queue_music_rounded,
                          color: alreadyAdded ? _appAccent : Colors.white70,
                        ),
                        title: Text(playlist.name),
                        subtitle: Text(
                          alreadyAdded
                              ? 'Already in this playlist'
                              : '${playlist.items.length} item${playlist.items.length == 1 ? '' : 's'}',
                          style: const TextStyle(color: Colors.blueGrey),
                        ),
                        onTap: alreadyAdded
                            ? null
                            : () async {
                                await provider.addMediaToPlaylist(playlist.id, file);
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${_displayName(provider, file)} added to ${playlist.name}.')),
                                  );
                                }
                              },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _showAddMediaPickerForPlaylist(
  BuildContext context,
  MediaProvider provider,
  Playlist playlist,
) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: _appSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      final availableFiles = provider.mediaFiles
          .where((file) => !provider.isFileInPlaylist(playlist.id, file.path))
          .toList();

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add media to ${playlist.name}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (availableFiles.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Everything in your library is already in this playlist.',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableFiles.length,
                    itemBuilder: (context, index) {
                      final file = availableFiles[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _MediaThumbnail(file: file, size: 48),
                        title: Text(_displayName(provider, file)),
                        subtitle: Text(
                          '${file.isVideo ? 'Video' : 'Audio'} • ${file.size}',
                          style: const TextStyle(color: Colors.blueGrey),
                        ),
                        onTap: () async {
                          await provider.addMediaToPlaylist(playlist.id, file);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MediaProvider>(context);
    final visibleFiles = provider.filteredMediaFiles;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (_searchController.text != provider.searchQuery) {
      _searchController.value = TextEditingValue(
        text: provider.searchQuery,
        selection: TextSelection.collapsed(offset: provider.searchQuery.length),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isLandscape ? 8.0 : 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: isLandscape ? 6 : 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Media',
                  style: TextStyle(
                    fontSize: isLandscape ? 18 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      visualDensity: isLandscape ? VisualDensity.compact : VisualDensity.standard,
                      constraints: BoxConstraints.tightFor(
                        width: isLandscape ? 32 : 48,
                        height: isLandscape ? 32 : 48,
                      ),
                      icon: Icon(
                        Icons.grid_view_rounded,
                        size: isLandscape ? 18 : 24,
                        color: provider.viewMode == ViewMode.grid ? _appAccent : Colors.blueGrey,
                      ),
                      onPressed: () => provider.toggleViewMode(ViewMode.grid),
                    ),
                    IconButton(
                      visualDensity: isLandscape ? VisualDensity.compact : VisualDensity.standard,
                      constraints: BoxConstraints.tightFor(
                        width: isLandscape ? 32 : 48,
                        height: isLandscape ? 32 : 48,
                      ),
                      icon: Icon(
                        Icons.list,
                        size: isLandscape ? 18 : 24,
                        color: provider.viewMode == ViewMode.list ? _appAccent : Colors.blueGrey,
                      ),
                      onPressed: () => provider.toggleViewMode(ViewMode.list),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: isLandscape ? 6 : 10),
            TextField(
              controller: _searchController,
              onChanged: provider.setSearchQuery,
              style: TextStyle(fontSize: isLandscape ? 14 : 16),
              decoration: InputDecoration(
                hintText: 'Search your media...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: isLandscape ? 14 : 16),
                prefixIcon: Icon(Icons.search, color: Colors.white30, size: isLandscape ? 18 : 20),
                suffixIcon: provider.searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          provider.setSearchQuery('');
                          _searchController.clear();
                        },
                        icon: Icon(Icons.close, color: Colors.white30, size: isLandscape ? 16 : 18),
                      ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.035),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: isLandscape ? 8 : 12),
                isDense: isLandscape,
              ),
            ),
            SizedBox(height: isLandscape ? 8 : 12),
            Wrap(
              spacing: 8,
              runSpacing: isLandscape ? 4 : 8,
              children: [
                _LibraryFilterChip(
                  label: 'All',
                  selected: provider.mediaFilter == MediaFilter.all,
                  onTap: () => provider.setMediaFilter(MediaFilter.all),
                ),
                _LibraryFilterChip(
                  label: 'Videos',
                  selected: provider.mediaFilter == MediaFilter.video,
                  onTap: () => provider.setMediaFilter(MediaFilter.video),
                ),
                _LibraryFilterChip(
                  label: 'Audio',
                  selected: provider.mediaFilter == MediaFilter.audio,
                  onTap: () => provider.setMediaFilter(MediaFilter.audio),
                ),
              ],
            ),
            SizedBox(height: isLandscape ? 8 : 14),
            const Divider(color: Colors.white10, thickness: 1, height: 1),
            Expanded(
              child: provider.mediaFiles.isEmpty
                  ? const EmptyState()
                  : visibleFiles.isEmpty
                      ? const SearchEmptyState()
                      : provider.viewMode == ViewMode.grid
                          ? const MediaGridView()
                          : const MediaListView(),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MediaProvider>(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'No media files',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload videos or audio files to get started',
            style: TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => provider.pickFiles(),
            icon: provider.isPicking 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _appBackground))
                : const Icon(Icons.cloud_upload_outlined),
            label: const Text('Upload Files'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _appAccent,
              foregroundColor: _appBackground,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class MediaGridView extends StatelessWidget {
  const MediaGridView({super.key});

  Future<void> _handleMenuAction(
    BuildContext context,
    MediaFile file,
    MediaProvider provider,
    String value,
  ) async {
    switch (value) {
      case 'playlist':
        await _showAddToPlaylistSheet(context, file, provider);
        break;
      case 'rename':
        _showRenameDialog(context, file, provider);
        break;
      case 'delete':
        final shouldDelete = provider.confirmDestructiveActions
            ? await _showDeleteMediaDialog(context, _displayName(provider, file))
            : true;
        if (shouldDelete == true) {
          await provider.deleteFile(file);
        }
        break;
    }
  }

  void _showRenameDialog(BuildContext context, MediaFile file, MediaProvider provider) {
    final controller = TextEditingController(text: file.name);
    String? errorText;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _appSurface,
              title: const Text('Rename File'),
              content: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  errorText: errorText,
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _appAccent)),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.blueGrey))),
                TextButton(
                  onPressed: () async {
                    final message = await provider.renameFile(file, controller.text);
                    if (message != null) {
                      setDialogState(() => errorText = message);
                      return;
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: _appAccent)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MediaProvider>(context);
    final files = provider.filteredMediaFiles;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = isLandscape ? ((width ~/ 180).clamp(4, 7) as int) : 2;

    return GridView.builder(
      padding: EdgeInsets.only(top: isLandscape ? 6 : 10, bottom: isLandscape ? 6 : 10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isLandscape ? 6 : 8,
        mainAxisSpacing: isLandscape ? 6 : 8,
        childAspectRatio: 1.45,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return GestureDetector(
          onTap: () {
            _openMediaPlayer(context, file);
          },
          child: Container(
            decoration: BoxDecoration(
              color: _appSurface,
              borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: file.thumbnailPath != null
                      ? Image.file(
                          File(file.thumbnailPath!),
                          fit: BoxFit.cover,
                        )
                        : Container(
                          color: _appBackground,
                          child: Center(
                            child: Icon(
                              file.isVideo ? Icons.play_arrow_rounded : Icons.music_note_rounded,
                              size: isLandscape ? 28 : 40,
                              color: _appAccent.withOpacity(0.2),
                            ),
                          ),
                        ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.84),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (provider.showFileSize)
                          Positioned(
                            left: isLandscape ? 8 : 10,
                            right: isLandscape ? 30 : 34,
                            bottom: isLandscape ? 26 : 30,
                            child: Text(
                              file.size,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isLandscape ? 10 : 11,
                              ),
                            ),
                          ),
                        Positioned(
                          left: isLandscape ? 8 : 10,
                          right: isLandscape ? 4 : 6,
                          bottom: -2,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  _displayName(provider, file),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isLandscape ? 12 : 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'More options',
                                color: _appSurface,
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(
                                  minWidth: isLandscape ? 24 : 28,
                                  minHeight: isLandscape ? 24 : 28,
                                ),
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Colors.white70,
                                  size: isLandscape ? 14 : 18,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                onSelected: (value) => _handleMenuAction(context, file, provider, value),
                                itemBuilder: (context) => const [
                                  PopupMenuItem<String>(
                                    value: 'playlist',
                                    child: _MediaMenuItem(
                                      icon: Icons.playlist_add,
                                      label: 'Add to Playlist',
                                      iconColor: _appAccent,
                                      textColor: Colors.white,
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'rename',
                                    child: _MediaMenuItem(
                                      icon: Icons.edit_outlined,
                                      label: 'Rename',
                                      iconColor: _appAccent,
                                      textColor: Colors.white,
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: _MediaMenuItem(
                                      icon: Icons.delete_outline,
                                      label: 'Delete',
                                      iconColor: Colors.redAccent,
                                      textColor: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MediaListView extends StatelessWidget {
  const MediaListView({super.key});

  Future<void> _handleMenuAction(
    BuildContext context,
    MediaFile file,
    MediaProvider provider,
    String value,
  ) async {
    switch (value) {
      case 'playlist':
        await _showAddToPlaylistSheet(context, file, provider);
        break;
      case 'rename':
        _showRenameDialog(context, file, provider);
        break;
      case 'delete':
        final shouldDelete = provider.confirmDestructiveActions
            ? await _showDeleteMediaDialog(context, _displayName(provider, file))
            : true;
        if (shouldDelete == true) {
          await provider.deleteFile(file);
        }
        break;
    }
  }

  void _showRenameDialog(BuildContext context, MediaFile file, MediaProvider provider) {
    final controller = TextEditingController(text: file.name);
    String? errorText;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _appSurface,
              title: const Text('Rename File'),
              content: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  errorText: errorText,
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _appAccent)),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.blueGrey))),
                TextButton(
                  onPressed: () async {
                    final message = await provider.renameFile(file, controller.text);
                    if (message != null) {
                      setDialogState(() => errorText = message);
                      return;
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: _appAccent)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MediaProvider>(context);
    final files = provider.filteredMediaFiles;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return ListView.builder(
      padding: EdgeInsets.only(top: isLandscape ? 8 : 16),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return ListTile(
          onTap: () {
            _openMediaPlayer(context, file);
          },
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: isLandscape ? 40 : 50,
            height: isLandscape ? 40 : 50,
            decoration: BoxDecoration(
              color: _appSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: file.thumbnailPath != null
                ? Image.file(
                    File(file.thumbnailPath!),
                    fit: BoxFit.cover,
                  )
                : Icon(
                    file.isVideo ? Icons.play_circle_outline : Icons.music_note,
                    size: isLandscape ? 20 : 24,
                    color: _appAccent.withOpacity(0.5),
                  ),
          ),
          dense: isLandscape,
          minVerticalPadding: isLandscape ? 2 : 4,
          title: Text(
            _displayName(provider, file),
            style: TextStyle(fontSize: isLandscape ? 14 : 16),
          ),
          subtitle: provider.showFileSize
              ? Text(
                  '${file.isVideo ? 'Video' : 'Audio'} • ${file.size}',
                  style: TextStyle(color: Colors.blueGrey, fontSize: isLandscape ? 11 : 13),
                )
              : Text(
                  file.isVideo ? 'Video' : 'Audio',
                  style: TextStyle(color: Colors.blueGrey, fontSize: isLandscape ? 11 : 13),
                ),
          trailing: PopupMenuButton<String>(
            tooltip: 'More options',
            color: _appSurface,
            icon: Icon(Icons.more_vert, color: Colors.blueGrey, size: isLandscape ? 18 : 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (value) => _handleMenuAction(context, file, provider, value),
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'playlist',
                child: _MediaMenuItem(
                  icon: Icons.playlist_add,
                  label: 'Add to Playlist',
                  iconColor: _appAccent,
                  textColor: Colors.white,
                ),
              ),
              PopupMenuItem<String>(
                value: 'rename',
                child: _MediaMenuItem(
                  icon: Icons.edit_outlined,
                  label: 'Rename',
                  iconColor: _appAccent,
                  textColor: Colors.white,
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: _MediaMenuItem(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  iconColor: Colors.redAccent,
                  textColor: Colors.redAccent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MediaProvider>(context, listen: false);
    final filterLabel = switch (provider.mediaFilter) {
      MediaFilter.all => 'media',
      MediaFilter.video => 'videos',
      MediaFilter.audio => 'audio files',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: _appSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 52, color: Colors.white54),
          ),
          const SizedBox(height: 18),
          const Text(
            'No matches found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            provider.searchQuery.trim().isEmpty
                ? 'No $filterLabel matched the current filter.'
                : 'No $filterLabel matched "${provider.searchQuery.trim()}".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => provider.setSearchQuery(''),
            child: const Text('Clear Search', style: TextStyle(color: _appAccent)),
          ),
        ],
      ),
    );
  }
}

class _LibraryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LibraryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 10 : 12,
            vertical: isLandscape ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: selected ? _appAccent.withOpacity(0.14) : Colors.white.withOpacity(0.035),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? _appAccent.withOpacity(0.35) : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _appAccent : Colors.white70,
              fontSize: isLandscape ? 11 : 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;

  const _MediaMenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: textColor)),
      ],
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final MediaFile file;
  const VideoPlayerScreen({super.key, required this.file});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  static const MethodChannel _pipChannel = MethodChannel('mediaplay/pip');
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  String? _initError;
  late final bool _autoPlay;
  late final bool _loopVideos;
  late final String _displayTitle;
  bool _isEnteringPip = false;
  bool? _lastAutoPipEnabled;
  int? _lastPipWidth;
  int? _lastPipHeight;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<MediaProvider>(context, listen: false);
    _autoPlay = provider.autoPlayVideos;
    _loopVideos = provider.loopVideos;
    _displayTitle = provider.displayName(widget.file);
    _initializePlayer();
  }

  Future<void> _enterPictureInPicture() async {
    final controller = _videoPlayerController;
    if (_isEnteringPip || !Platform.isAndroid || controller == null || !controller.value.isInitialized) {
      return;
    }

    _isEnteringPip = true;
    try {
      final size = controller.value.size;
      final width = size.width.isFinite && size.width > 0 ? size.width.round() : 16;
      final height = size.height.isFinite && size.height > 0 ? size.height.round() : 9;

      await _pipChannel.invokeMethod<void>('enterPictureInPicture', {
        'aspectRatioWidth': width,
        'aspectRatioHeight': height,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to enter PiP: ${e.message}');
    } finally {
      _isEnteringPip = false;
    }
  }

  Future<void> _syncPictureInPictureAvailability() async {
    final controller = _videoPlayerController;
    if (!Platform.isAndroid || controller == null || !controller.value.isInitialized) {
      return;
    }

    final size = controller.value.size;
    final width = size.width.isFinite && size.width > 0 ? size.width.round() : 16;
    final height = size.height.isFinite && size.height > 0 ? size.height.round() : 9;
    final provider = Provider.of<MediaProvider>(context, listen: false);
    final enabled = provider.autoPictureInPicture && controller.value.isPlaying;

    if (_lastAutoPipEnabled == enabled &&
        _lastPipWidth == width &&
        _lastPipHeight == height) {
      return;
    }

    _lastAutoPipEnabled = enabled;
    _lastPipWidth = width;
    _lastPipHeight = height;

    try {
      await _pipChannel.invokeMethod<void>('updateAutoPipState', {
        'enabled': enabled,
        'aspectRatioWidth': width,
        'aspectRatioHeight': height,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to sync PiP state: ${e.message}');
    }
  }

  Future<void> _initializePlayer() async {
    final controller = VideoPlayerController.file(File(widget.file.path));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setVolume(1.0);

      final aspectRatio = controller.value.aspectRatio;
      final safeAspectRatio = (aspectRatio > 0 && aspectRatio.isFinite) ? aspectRatio : (16 / 9);

      _videoPlayerController = controller;
      controller.addListener(_syncPictureInPictureAvailability);
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: _autoPlay,
        looping: _loopVideos,
        allowMuting: false,
        aspectRatio: safeAspectRatio,
        customControls: MediaPlayerControls(
          title: _displayTitle,
          onBackPressed: () {
            if (mounted) {
              Navigator.of(context).maybePop();
            }
          },
          onPictureInPicturePressed: Platform.isAndroid
              ? _enterPictureInPicture
              : null,
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: _appAccent,
          handleColor: _appAccent,
          backgroundColor: Colors.white10,
          bufferedColor: Colors.white24,
        ),
      );
      await _syncPictureInPictureAvailability();
      setState(() {});
    } catch (e, st) {
      debugPrint('Video init failed: $e\n$st');
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _initError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_syncPictureInPictureAvailability);
    if (Platform.isAndroid) {
      _pipChannel.invokeMethod<void>('updateAutoPipState', {
        'enabled': false,
      }).catchError((Object error) {
        debugPrint('Failed to disable PiP state: $error');
      });
    }
    _lastAutoPipEnabled = null;
    _lastPipWidth = null;
    _lastPipHeight = null;
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _initError != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not play this file.\n$_initError',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            : _chewieController != null &&
                    _videoPlayerController != null &&
                    _videoPlayerController!.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(),
      ),
    );
  }
}
