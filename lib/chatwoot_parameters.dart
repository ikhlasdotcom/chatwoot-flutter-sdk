import 'package:equatable/equatable.dart';

class ChatwootParameters extends Equatable {
  final bool isPersistenceEnabled;
  final String baseUrl;
  final String clientInstanceKey;
  final String inboxIdentifier;
  final String? userIdentifier;
  final int? conversationId;
  final String? conversationContext;
  final Map<String, dynamic>? conversationCustomAttributes;

  ChatwootParameters(
      {required this.isPersistenceEnabled,
      required this.baseUrl,
      required this.inboxIdentifier,
      required this.clientInstanceKey,
      this.userIdentifier,
      this.conversationId,
      this.conversationContext,
      this.conversationCustomAttributes});

  @override
  List<Object?> get props => [
        isPersistenceEnabled,
        baseUrl,
        clientInstanceKey,
        inboxIdentifier,
        userIdentifier,
        conversationId,
        conversationContext,
        conversationCustomAttributes
      ];
}
