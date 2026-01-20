import 'package:chatwoot_sdk/data/local/entity/chatwoot_user.dart';
import 'package:chatwoot_sdk/ui/webview_widget/webview.dart';
import 'package:flutter/material.dart';

///ChatwootWidget
/// {@category FlutterClientSdk}
class ChatwootWidget extends StatefulWidget {
  ///Website channel token
  final String websiteToken;

  ///Installation url for chatwoot
  final String baseUrl;

  ///User information about the user like email, username and avatar_url
  final ChatwootUser? user;

  ///User locale
  final String locale;

  ///Widget Close event
  final void Function()? closeWidget;

  ///Additional information about the customer
  final customAttributes;

  ///Widget Attachment event. Currently supported only on Android devices
  final Future<List<String>> Function()? onAttachFile;

  ///Widget Load started event
  final void Function()? onLoadStarted;

  ///Widget Load progress event
  final void Function(int)? onLoadProgress;

  ///Widget Load completed event
  final void Function()? onLoadCompleted;

  /// If true, clears any stored conversation token before loading (forces a fresh conversation).
  final bool resetConversation;

  /// If provided, forces the widget to open the given conversation token instead of the last stored one.
  final String? conversationToken;

  /// If false, the widget will not persist the conversation token after load.
  final bool persistConversationToken;

  /// Callback when widget reports the current conversation auth token (from loaded event).
  final void Function(String authToken)? onAuthToken;

  /// Callback when conversation is loaded, providing auth token and conversation ID.
  final void Function(String authToken, int? conversationId)?
      onConversationLoaded;

  /// Conversation-level custom attributes to set on load.
  final dynamic conversationCustomAttributes;
  ChatwootWidget(
      {Key? key,
      required this.websiteToken,
      required this.baseUrl,
      this.user,
      this.locale = "en",
      this.customAttributes,
      this.conversationCustomAttributes,
      this.closeWidget,
      this.onAttachFile,
      this.onLoadStarted,
      this.onLoadProgress,
      this.onLoadCompleted,
      this.resetConversation = false,
      this.conversationToken,
      this.persistConversationToken = true,
      this.onAuthToken,
      this.onConversationLoaded})
      : super(key: key);

  @override
  _ChatwootWidgetState createState() => _ChatwootWidgetState();
}

class _ChatwootWidgetState extends State<ChatwootWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Webview(
      websiteToken: widget.websiteToken,
      baseUrl: widget.baseUrl,
      user: widget.user,
      locale: widget.locale,
      customAttributes: widget.customAttributes,
      conversationCustomAttributes: widget.conversationCustomAttributes,
      closeWidget: widget.closeWidget,
      resetConversation: widget.resetConversation,
      conversationToken: widget.conversationToken,
      persistConversationToken: widget.persistConversationToken,
      onAuthToken: widget.onAuthToken,
      onConversationLoaded: widget.onConversationLoaded,
      onAttachFile: widget.onAttachFile,
      onLoadStarted: widget.onLoadStarted,
      onLoadCompleted: widget.onLoadCompleted,
      onLoadProgress: widget.onLoadProgress,
    );
  }
}
