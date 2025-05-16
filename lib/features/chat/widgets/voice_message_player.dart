import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../core/models/message_model.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/widgets/circular_loading_indicator.dart';
import '../../../providers/service_providers.dart';

/// A widget that displays a voice message player in a chat bubble
class VoiceMessagePlayer extends ConsumerStatefulWidget {
  final Message message;
  final Color textColor;
  final Color iconColor;

  const VoiceMessagePlayer({
    super.key,
    required this.message,
    required this.textColor,
    required this.iconColor,
  });

  @override
  ConsumerState<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends ConsumerState<VoiceMessagePlayer> with AutomaticKeepAliveClientMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _localFilePath;
  
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkIfVoiceFileExists();
    
    // Try setting duration from metadata
    final durationMs = widget.message.metadata?['duration_ms'];
    if (durationMs is int && durationMs > 0) {
      _totalDuration = Duration(milliseconds: durationMs);
      AppLogger.d("[VoicePlayer] Set initial duration from metadata: $_totalDuration");
    }
    
    if (_isDownloaded || widget.message.localFilePath != null) {
      _initAudioPlayer();
    }
  }
  
  // Check if voice file exists in app documents directory
  Future<void> _checkIfVoiceFileExists() async {
    if (widget.message.type != MessageType.voice) return;
    
    // First check for an existing localFilePath
    if (widget.message.localFilePath != null) {
      final file = File(widget.message.localFilePath!);
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _isDownloaded = true;
            _localFilePath = widget.message.localFilePath;
          });
        }
        return;
      }
    }
    
    // If message has a mediaUrl, check if it's already cached
    if (widget.message.mediaUrl != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final filename = widget.message.mediaUrl!.split('/').last.split('?').first;
      final filepath = '${appDir.path}/voice_messages/$filename';
      
      final file = File(filepath);
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _isDownloaded = true;
            _localFilePath = filepath;
          });
        }
      }
    }
  }
  
  // Download voice message
  Future<void> _downloadVoiceMessage() async {
    if (widget.message.mediaUrl == null) {
      AppLogger.d("Cannot download voice message: No URL");
      return;
    }
    
    setState(() {
      _isDownloading = true;
    });
    
    try {
      // Create directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final voiceDir = Directory('${appDir.path}/voice_messages');
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }
      
      // Extract filename from URL
      final filename = widget.message.mediaUrl!.split('/').last.split('?').first;
      final filepath = '${voiceDir.path}/$filename';
      
      // Download the file
      final response = await http.get(Uri.parse(widget.message.mediaUrl!));
      if (response.statusCode == 200) {
        final file = File(filepath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Initialize audio player immediately after download completes
        _localFilePath = filepath; 
        await _initAudioPlayer();
        
        if (mounted) {
          setState(() {
            _isDownloaded = true;
            _isDownloading = false;
          });
        }
      } else {
        throw Exception('Failed to download: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.e("Error downloading voice message: $e");
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download voice message'))
        );
      }
    }
  }
  
  Future<void> _initAudioPlayer() async {
    // Cancel any existing subscriptions before setting up new ones
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    
    // Determine audio source
    String? sourcePathToUse = _localFilePath ?? widget.message.localFilePath;
    if (sourcePathToUse == null && widget.message.mediaUrl != null && _isDownloaded) {
      // If file was downloaded but path not stored in state yet
      final appDir = await getApplicationDocumentsDirectory();
      final filename = widget.message.mediaUrl!.split('/').last.split('?').first;
      sourcePathToUse = '${appDir.path}/voice_messages/$filename';
    }
    
    if (sourcePathToUse == null) {
      AppLogger.d("Cannot initialize player: No audio source path available");
      return;
    }
    
    // Listen to states: playing, paused, stopped
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      AppLogger.d("[VoicePlayer] State changed: $state");
      
      setState(() {
        _isPlaying = state == PlayerState.playing;
        _isLoadingAudio = false; 
      });
      
      if (state == PlayerState.stopped || state == PlayerState.paused || state == PlayerState.completed) {
        ref.read(chatPlaybackProvider).reportStopped(widget.message.id);
      }
    });
    
    // Listen to audio duration
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      AppLogger.d("[VoicePlayer] Duration changed: $duration");
      setState(() {
        _totalDuration = duration;
        _isLoadingAudio = false;
      });
    });
    
    // Listen to audio position
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      
      if (_isLoadingAudio) {
        setState(() {
          _isLoadingAudio = false;
          _currentPosition = position;
        });
      } else {
        setState(() {
          _currentPosition = position;
        });
      }
    });
    
    // Listen for when audio completes
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return;
      AppLogger.d("[VoicePlayer] Playback Complete");
      
      ref.read(chatPlaybackProvider).reportStopped(widget.message.id);
      setState(() {
        _currentPosition = Duration.zero;
        _isPlaying = false;
        _isLoadingAudio = false;
      });
    });
    
    // Set up the audio source
    try {
      Source source = DeviceFileSource(sourcePathToUse);
      
      // Set source but don't play yet
      await _audioPlayer.setSource(source);
      
      // Try to get duration immediately after setting source
      Duration? duration = await _audioPlayer.getDuration();
      if (duration != null && mounted) {
        setState(() { 
          _totalDuration = duration;
        });
      } else if (widget.message.metadata?['duration_ms'] != null && mounted) {
        // Fallback to metadata if getDuration fails
        setState(() { 
          _totalDuration = Duration(milliseconds: widget.message.metadata!['duration_ms']); 
        });
      }
    } catch (e) {
      AppLogger.e("Error setting audio source or getting duration: $e");
      // Fallback to metadata if setting source fails
      if (widget.message.metadata?['duration_ms'] != null && mounted) {
        setState(() { 
          _totalDuration = Duration(milliseconds: widget.message.metadata!['duration_ms']); 
        });
      }
      
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  Future<void> _togglePlayPause() async {
    if (!mounted) return;
    
    // If file is not downloaded yet, don't try to play
    if (!_isDownloaded && widget.message.localFilePath == null) {
      AppLogger.d("Cannot play: audio file not downloaded");
      return;
    }
    
    // Get playback service
    final playbackService = ref.read(chatPlaybackProvider);
    
    if (_isPlaying) {
      // Already playing - just pause
      await _audioPlayer.pause();
      playbackService.reportStopped(widget.message.id);
    } else {
      // Start playback
      setState(() {
        _isLoadingAudio = true;
      });
      
      // Request exclusive playback
      playbackService.requestPlay(widget.message.id, () { 
        if (mounted) {
          _audioPlayer.pause(); 
        }
      });
      
      try {
        // Check if player has a source and is properly initialized
        if (_audioPlayer.source == null) {
          AppLogger.d("[VoicePlayer] Player source is null. Re-initializing...");
          await _initAudioPlayer();
          if (_audioPlayer.source != null) {
            await _audioPlayer.play(_audioPlayer.source!);
          } else {
            throw Exception("Failed to initialize player source.");
          }
        } else {
          // Source exists, just resume playback
          await _audioPlayer.resume();
        }
      } catch (e) {
        AppLogger.e("Error playing/resuming audio: $e");
        if (mounted) {
          setState(() => _isLoadingAudio = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to play audio message'))
        );
      }
    }
  }
  
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // Handle not downloaded state
    if (!_isDownloaded && widget.message.localFilePath == null && widget.message.mediaUrl != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: _isDownloading
              ? CircularLoadingIndicator(strokeWidth: 2, color: widget.textColor)
              : IconButton(
                  icon: const Icon(Icons.download_for_offline_outlined, size: 28),
                  color: widget.textColor,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Download Voice Message',
                  onPressed: () {
                    HapticUtils.lightTap();
                    _downloadVoiceMessage();
                  },
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 30,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbColor: widget.textColor.withAlpha(128),
                        overlayColor: Colors.transparent,
                        activeTrackColor: widget.textColor.withAlpha(77),
                        inactiveTrackColor: widget.textColor.withAlpha(77),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                        trackHeight: 2.0,
                      ),
                      child: Slider(
                        value: 0.0,
                        min: 0.0,
                        max: (_totalDuration.inMilliseconds > 0 ? _totalDuration.inMilliseconds : 1).toDouble(),
                        onChanged: null,
                      ),
                    ),
                  ),
                  Text(
                    "00:00 / ${_formatDuration(_totalDuration)}",
                    style: TextStyle(color: widget.iconColor, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    // Show player when file is downloaded
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: _isLoadingAudio
            ? CircularLoadingIndicator(strokeWidth: 2, color: widget.textColor)
            : IconButton(
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 32),
                color: widget.textColor,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _isLoadingAudio
                  ? null
                  : () {
                      HapticUtils.lightTap();
                      _togglePlayPause();
                    },
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 30,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: widget.textColor.withAlpha(255),
                      overlayColor: widget.textColor.withAlpha(38),
                      activeTrackColor: widget.textColor.withAlpha(204),
                      inactiveTrackColor: widget.textColor.withAlpha(102),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                      trackHeight: 2.0,
                    ),
                    child: Slider(
                      value: _currentPosition.inMilliseconds.toDouble().clamp(
                        0.0, 
                        _totalDuration.inMilliseconds.toDouble()
                      ),
                      min: 0.0,
                      max: (_totalDuration.inMilliseconds > 0 ? _totalDuration.inMilliseconds : 1).toDouble(),
                      onChanged: (_totalDuration > Duration.zero && !_isLoadingAudio)
                        ? (value) async {
                            if (_isLoadingAudio) return;
                            final position = Duration(milliseconds: value.toInt());
                            await _audioPlayer.seek(position);
                            if (mounted) {
                              setState(() { _currentPosition = position; });
                            }
                          }
                        : null,
                    ),
                  ),
                ),
                Text(
                  "${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}",
                  style: TextStyle(color: widget.iconColor, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
} 