import 'package:isar/isar.dart';

part 'isar_chat_message.g.dart';

@collection
class IsarChatMessage {
  Id id = Isar.autoIncrement; // Isar internal ID

  @Index(type: IndexType.value)
  late String chatId; // Index for fast fetching by room

  late String senderId;
  late String text;

  @Index(type: IndexType.value)
  late DateTime sentAt; // Index for sorting by time

  String? documentId;
  String? status;      // sent/delivered/read
  String? clientMsgId; // local UUID for dedup
  DateTime? deliveredAt;
  DateTime? readAt;
}
