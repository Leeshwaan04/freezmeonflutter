import 'package:flutter/material.dart';

enum MessageStatus { pending, sent, delivered, read, failed }

MessageStatus parseMessageStatus(String? status) {
  return switch (status) {
    'read' => MessageStatus.read,
    'delivered' => MessageStatus.delivered,
    'sent' => MessageStatus.sent,
    'failed' => MessageStatus.failed,
    _ => MessageStatus.delivered, // Default
  };
}

IconData statusIcon(MessageStatus status) {
  switch (status) {
    case MessageStatus.pending:
      return Icons.access_time;
    case MessageStatus.sent:
      return Icons.check;
    case MessageStatus.delivered:
      return Icons.done_all;
    case MessageStatus.read:
      return Icons.done_all;
    case MessageStatus.failed:
      return Icons.error_outline;
  }
}
