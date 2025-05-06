import 'package:flutter/foundation.dart';
import 'package:urocenter/core/utils/logger.dart';

class ChatPlaybackService {
  String? _currentlyPlayingMessageId;
  VoidCallback? _pauseCurrentPlayerCallback;

  // Call this before starting playback in a bubble
  void requestPlay(String messageId, VoidCallback pauseCallback) {
    if (_currentlyPlayingMessageId != null && _currentlyPlayingMessageId != messageId) {
      // If another player is active, pause it
      _pauseCurrentPlayerCallback?.call();
      AppLogger.d("[ChatPlaybackService] Paused previous player: $_currentlyPlayingMessageId");
    }
    // Store info for the new player
    _currentlyPlayingMessageId = messageId;
    _pauseCurrentPlayerCallback = pauseCallback;
     AppLogger.d("[ChatPlaybackService] Now playing: $_currentlyPlayingMessageId");
  }

  // Call this when a player stops (paused, completed, disposed)
  void reportStopped(String messageId) {
    // Only clear if the stopped player is the one we were tracking
    if (_currentlyPlayingMessageId == messageId) {
      _currentlyPlayingMessageId = null;
      _pauseCurrentPlayerCallback = null;
      AppLogger.d("[ChatPlaybackService] Player stopped/cleared: $messageId");
    }
  }

  // Optional: Check if a specific message is the one currently playing
  bool isPlaying(String messageId) {
    return _currentlyPlayingMessageId == messageId;
  }
} 
