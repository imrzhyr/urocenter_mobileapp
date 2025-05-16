import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/models/message_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/haptic_utils.dart';
import 'image_message.dart';
import 'document_message.dart';
import 'voice_message_player.dart';
import '../utils/message_options.dart';

/// A widget that displays a chat message bubble
class MessageBubble extends ConsumerStatefulWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> with AutomaticKeepAliveClientMixin<MessageBubble> {
  @override
  bool get wantKeepAlive => true; // Keep the state alive
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // Get the current locale and check if it's Arabic for RTL
    final currentLocale = context.locale.languageCode;
    final isRtl = currentLocale == 'ar';
    
    // Adjust alignment based on RTL and sender
    final alignment = widget.isMe 
        ? (isRtl ? Alignment.centerLeft : Alignment.centerRight)
        : (isRtl ? Alignment.centerRight : Alignment.centerLeft);
    
    // Use theme colors instead of hardcoded colors
    final color = widget.isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor;
    final textColor = widget.isMe 
        ? Theme.of(context).colorScheme.onPrimary 
        : Theme.of(context).colorScheme.onSurface;
    final iconColor = widget.isMe ? Theme.of(context).colorScheme.onPrimary.withAlpha(179) : Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    
    // Adjust bubble radius based on text direction and sender
    final bubbleRadius = isRtl
        ? BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: widget.isMe ? Radius.zero : const Radius.circular(16),
            bottomRight: widget.isMe ? const Radius.circular(16) : Radius.zero,
          )
        : BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: widget.isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: widget.isMe ? Radius.zero : const Radius.circular(16),
          );

    // Create the appropriate content based on message type
    Widget messageContent;
    switch (widget.message.type) {
      case MessageType.text:
        messageContent = Text(
          widget.message.content,
          style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
        );
        break;
        
      case MessageType.image:
        messageContent = ImageMessage(
          message: widget.message,
          borderRadius: bubbleRadius,
        );
        break;
        
      case MessageType.document:
        messageContent = DocumentMessage(
          message: widget.message,
          borderRadius: bubbleRadius,
          textColor: textColor,
        );
        break;
        
      case MessageType.voice:
        messageContent = VoiceMessagePlayer(
          message: widget.message,
          textColor: textColor,
          iconColor: iconColor,
        );
        break;
        
      case MessageType.call_event:
        // Special styling for call events
        messageContent = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getCallEventIcon(widget.message.content),
              size: 18,
              color: textColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.message.content, 
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        );
        break;
        
      default:
        messageContent = Text('[Unsupported message type]', style: TextStyle(color: textColor));
    }

    return GestureDetector(
      onLongPress: () {
        HapticUtils.lightTap();
        MessageOptions.showMessageOptions(context, widget.message, ref);
      },
      child: Align(
        alignment: alignment,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: bubbleRadius,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withAlpha(8),
                blurRadius: 3,
                offset: const Offset(0, 1),
              )
            ],
            border: !widget.isMe 
                ? Border.all(color: Theme.of(context).dividerColor, width: 0.5) 
                : null,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              messageContent,
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Text(
                    AppDateUtils.formatMessageTime(widget.message.createdAt),
                    style: TextStyle(color: iconColor, fontSize: 11),
                  ),
                  if (widget.isMe) ...[
                    const SizedBox(width: 5),
                    Icon(
                      _getMessageStatusIcon(widget.message.status),
                      color: iconColor,
                      size: 14,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  IconData _getMessageStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
      case MessageStatus.sent:
        return Icons.done;
      case MessageStatus.delivered:
      case MessageStatus.read:
        return Icons.done_all;
      default:
        return Icons.error_outline;
    }
  }

  // Helper method to get the appropriate icon for call events
  IconData _getCallEventIcon(String content) {
    if (content.contains('Missed')) {
      return Icons.call_missed;
    } else if (content.contains('Declined')) {
      return Icons.call_end;
    } else if (content.contains('duration')) {
      return Icons.call;
    } else {
      return Icons.call_made;
    }
  }
} 