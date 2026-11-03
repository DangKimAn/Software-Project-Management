import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';

/// Compact Facebook Messenger style voice message bubble.
/// Matches Messenger's minimalist pill design: [ ▶ ]  [ | · · | | | | | · | | | ]  [ 0:03 ]
class ChatAudioBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final String? caption;

  const ChatAudioBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
    this.caption,
  });

  /// Ensures only one audio message plays at a time across the entire chat
  static AudioPlayer? _activePlayer;

  @override
  State<ChatAudioBubble> createState() => _ChatAudioBubbleState();
}

class _ChatAudioBubbleState extends State<ChatAudioBubble> {
  late final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;

  // Waveform bars pattern matching Facebook Messenger voice note
  static const List<double> _waveformHeights = [
    18.0, 4.0, 4.0, 18.0, 18.0, 15.0, 12.0, 7.0, 4.0, 12.0, 15.0, 12.0,
  ];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playerState = state;
        if (state == PlayerState.playing) {
          _isLoading = false;
        } else if (state == PlayerState.completed) {
          _position = Duration.zero;
        }
      });
    });

    _durationSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() {
        _duration = d;
      });
    });

    _positionSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() {
        _position = p;
      });
    });
  }

  @override
  void dispose() {
    if (ChatAudioBubble._activePlayer == _player) {
      ChatAudioBubble._activePlayer = null;
    }
    _stateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Source _createSource(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return UrlSource(url);
    } else if (url.startsWith('asset')) {
      return AssetSource(url.replaceFirst('assets/', ''));
    } else {
      return DeviceFileSource(url);
    }
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      // Pause any other voice message currently playing
      if (ChatAudioBubble._activePlayer != null &&
          ChatAudioBubble._activePlayer != _player) {
        try {
          await ChatAudioBubble._activePlayer?.pause();
        } catch (_) {}
      }
      ChatAudioBubble._activePlayer = _player;

      setState(() {
        _isLoading = true;
      });

      try {
        if (_playerState == PlayerState.paused) {
          await _player.resume();
        } else {
          final source = _createSource(widget.audioUrl);
          await _player.play(source);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _seekToFraction(double frac) {
    if (_duration.inMilliseconds > 0) {
      final targetMs = (_duration.inMilliseconds * frac).toInt();
      _player.seek(Duration(milliseconds: targetMs));
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final isPlaying = _playerState == PlayerState.playing;

    // Time display: formatted as 0:03 just like Messenger
    final displayTime = isPlaying || _position > Duration.zero
        ? _formatDuration(_position)
        : (_duration > Duration.zero ? _formatDuration(_duration) : '0:03');

    final progress = (_duration.inMilliseconds > 0)
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final primaryColor = isMe ? Colors.white : AppColors.primary;
    final secondaryColor = isMe ? Colors.white.withValues(alpha: 0.38) : const Color(0xFFCBD5E1);

    return InkWell(
      onTap: _togglePlay,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Play / Pause triangle glyph (no extra borders, just like Messenger)
            SizedBox(
              width: 22,
              height: 22,
              child: Center(
                child: _isLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : Icon(
                        isPlaying ? LucideIcons.pause : LucideIcons.play,
                        size: 17,
                        color: primaryColor,
                      ),
              ),
            ),
            const SizedBox(width: 8),

            // 2. Waveform bars (compact: 12 bars, tap/scrub to seek)
            GestureDetector(
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  // Fraction based on touch inside waveform
                  _seekToFraction(details.localPosition.dx.clamp(0.0, 65.0) / 65.0);
                }
              },
              child: SizedBox(
                height: 22,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(_waveformHeights.length, (idx) {
                    final barHeight = _waveformHeights[idx];
                    final barProgress = (idx + 1) / _waveformHeights.length;
                    final isPassed = progress >= barProgress;

                    return Container(
                      margin: EdgeInsets.only(
                        right: idx < _waveformHeights.length - 1 ? 2.5 : 0,
                      ),
                      width: 2.8,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: isPassed ? primaryColor : secondaryColor,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 3. Compact duration text (e.g. 0:03)
            Text(
              displayTime,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: primaryColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
