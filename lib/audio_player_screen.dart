import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'media_provider.dart';

const _audioBackground = Color(0xFF000000);
const _audioSurface = Color(0xFF121212);
const _audioAccent = Color(0xFF3B82F6);

class AudioPlayerScreen extends StatefulWidget {
  final MediaFile file;

  const AudioPlayerScreen({super.key, required this.file});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      final audioFile = File(widget.file.path);
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found at ${widget.file.path}');
      }

      await _player.setFilePath(widget.file.path);
      await _player.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '${duration.inMinutes}:${seconds}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _audioBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: _initError != null
              ? Center(
                  child: Text(
                    'Could not play this audio file.\n$_initError',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, stateSnapshot) {
                    final playerState = stateSnapshot.data;
                    final isBuffering =
                        playerState?.processingState == ProcessingState.loading ||
                        playerState?.processingState == ProcessingState.buffering;
                    final isCompleted =
                        playerState?.processingState == ProcessingState.completed;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),
                        Container(
                          height: 220,
                          decoration: BoxDecoration(
                            color: _audioSurface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.music_note_rounded,
                              size: 88,
                              color: _audioAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          widget.file.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.file.size,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.blueGrey),
                        ),
                        const SizedBox(height: 28),
                        StreamBuilder<Duration>(
                          stream: _player.positionStream,
                          builder: (context, positionSnapshot) {
                            final position = positionSnapshot.data ?? Duration.zero;
                            final duration = _player.duration ?? Duration.zero;
                            final safeMax = duration.inMilliseconds > 0
                                ? duration.inMilliseconds.toDouble()
                                : 1.0;
                            final safeValue = position.inMilliseconds
                                .clamp(0, duration.inMilliseconds > 0 ? duration.inMilliseconds : 1)
                                .toDouble();

                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: _audioAccent,
                                    inactiveTrackColor: Colors.white12,
                                    thumbColor: _audioAccent,
                                    overlayColor: _audioAccent.withOpacity(0.12),
                                    trackHeight: 4,
                                  ),
                                  child: Slider(
                                    value: safeValue,
                                    max: safeMax,
                                    onChanged: duration.inMilliseconds <= 0
                                        ? null
                                        : (value) {
                                            _player.seek(Duration(milliseconds: value.round()));
                                          },
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: const TextStyle(color: Colors.white60),
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: const TextStyle(color: Colors.white60),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ControlButton(
                              icon: Icons.replay_10_rounded,
                              onPressed: () async {
                                final target = _player.position - const Duration(seconds: 10);
                                await _player.seek(target >= Duration.zero ? target : Duration.zero);
                              },
                            ),
                            const SizedBox(width: 20),
                            Container(
                              decoration: const BoxDecoration(
                                color: _audioAccent,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: isBuffering
                                    ? null
                                    : () async {
                                        if (isCompleted) {
                                          await _player.seek(Duration.zero);
                                        }
                                        await _togglePlayback();
                                      },
                                iconSize: 34,
                                color: Colors.black,
                                icon: Icon(
                                  isBuffering
                                      ? Icons.hourglass_bottom_rounded
                                      : (_player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            _ControlButton(
                              icon: Icons.forward_10_rounded,
                              onPressed: () async {
                                final target = _player.position + const Duration(seconds: 10);
                                final duration = _player.duration;
                                if (duration == null) {
                                  await _player.seek(target);
                                  return;
                                }
                                await _player.seek(target <= duration ? target : duration);
                              },
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Future<void> Function() onPressed;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _audioSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
