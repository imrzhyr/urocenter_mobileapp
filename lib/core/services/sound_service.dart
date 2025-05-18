import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

/// Service to manage audio playback for call ringtones and other sounds
class SoundService {
  // Players for different sound types to avoid conflicts
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _dialingPlayer = AudioPlayer();
  final AudioPlayer _notificationPlayer = AudioPlayer();
  
  // Track if a sound is currently playing
  bool _isRingtonePlaying = false;
  bool _isDialingPlaying = false;
  
  // Sound paths
  static const String _incomingRingtonePath = 'sounds/incoming_ringtone.mp3';
  static const String _outgoingRingtonePath = 'sounds/outgoing_ringtone.mp3';
  static const String _connectSoundPath = 'sounds/call_connect.mp3';
  static const String _disconnectSoundPath = 'sounds/call_end.mp3';
  static const String _messageNotificationPath = 'sounds/message.mp3';
  
  SoundService() {
    _initializePlayers();
  }
  
  /// Initialize audio players and configure options
  Future<void> _initializePlayers() async {
    try {
      // Set global audio player settings
      AudioPlayer.global.setAudioContext(
        const AudioContext(
          android: AudioContextAndroid(
            audioMode: AndroidAudioMode.normal,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: [
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            ],
          ),
        ),
      );
      
      // Configure ringtone player (should loop by default)
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.setVolume(1.0);
      
      // Configure dialing player (should also loop)
      await _dialingPlayer.setReleaseMode(ReleaseMode.loop);
      await _dialingPlayer.setVolume(0.7);
      
      // Configure notification player (single play)
      await _notificationPlayer.setReleaseMode(ReleaseMode.release);
      await _notificationPlayer.setVolume(0.5);
      
      // Add listeners to track when sounds stop
      _ringtonePlayer.onPlayerComplete.listen((_) {
        _isRingtonePlaying = false;
      });
      
      _dialingPlayer.onPlayerComplete.listen((_) {
        _isDialingPlaying = false;
      });
      
    } catch (e) {
      AppLogger.e("Error initializing sound service: $e");
    }
  }
  
  /// Play incoming call ringtone (looping)
  Future<void> playIncomingRingtone() async {
    if (_isRingtonePlaying) return;
    
    try {
      AppLogger.d("Playing incoming ringtone");
      await _ringtonePlayer.play(AssetSource(_incomingRingtonePath));
      _isRingtonePlaying = true;
    } catch (e) {
      AppLogger.e("Error playing incoming ringtone: $e");
    }
  }
  
  /// Play outgoing call dialing sound (looping)
  Future<void> playDialingSound() async {
    if (_isDialingPlaying) return;
    
    try {
      AppLogger.d("Playing outgoing dialing sound");
      await _dialingPlayer.play(AssetSource(_outgoingRingtonePath));
      _isDialingPlaying = true;
    } catch (e) {
      AppLogger.e("Error playing outgoing dialing sound: $e");
    }
  }
  
  /// Play a short sound when call connects
  Future<void> playConnectSound() async {
    try {
      // Stop any ongoing ringtones first
      stopRingtone();
      stopDialingSound();
      
      AppLogger.d("Playing call connect sound");
      await _notificationPlayer.play(AssetSource(_connectSoundPath));
    } catch (e) {
      AppLogger.e("Error playing connect sound: $e");
    }
  }
  
  /// Play a short sound when call ends
  Future<void> playDisconnectSound() async {
    try {
      // Make sure ringtones are stopped
      stopRingtone();
      stopDialingSound();
      
      AppLogger.d("Playing call disconnect sound");
      await _notificationPlayer.play(AssetSource(_disconnectSoundPath));
    } catch (e) {
      AppLogger.e("Error playing disconnect sound: $e");
    }
  }
  
  /// Play message notification sound
  Future<void> playMessageNotification() async {
    try {
      AppLogger.d("Playing message notification");
      await _notificationPlayer.play(AssetSource(_messageNotificationPath));
    } catch (e) {
      AppLogger.e("Error playing message notification: $e");
    }
  }
  
  /// Stop incoming ringtone
  Future<void> stopRingtone() async {
    if (!_isRingtonePlaying) return;
    
    try {
      await _ringtonePlayer.stop();
      _isRingtonePlaying = false;
    } catch (e) {
      AppLogger.e("Error stopping ringtone: $e");
    }
  }
  
  /// Stop outgoing dialing sound
  Future<void> stopDialingSound() async {
    if (!_isDialingPlaying) return;
    
    try {
      await _dialingPlayer.stop();
      _isDialingPlaying = false;
    } catch (e) {
      AppLogger.e("Error stopping dialing sound: $e");
    }
  }
  
  /// Stop all sounds
  Future<void> stopAllSounds() async {
    try {
      await _ringtonePlayer.stop();
      await _dialingPlayer.stop();
      await _notificationPlayer.stop();
      _isRingtonePlaying = false;
      _isDialingPlaying = false;
    } catch (e) {
      AppLogger.e("Error stopping all sounds: $e");
    }
  }
  
  /// Dispose all players when service is no longer needed
  Future<void> dispose() async {
    try {
      await _ringtonePlayer.dispose();
      await _dialingPlayer.dispose();
      await _notificationPlayer.dispose();
    } catch (e) {
      AppLogger.e("Error disposing sound service: $e");
    }
  }
}

/// Provider for SoundService
final soundServiceProvider = Provider<SoundService>((ref) {
  final soundService = SoundService();
  
  // Clean up when provider is disposed
  ref.onDispose(() {
    soundService.dispose();
  });
  
  return soundService;
}); 