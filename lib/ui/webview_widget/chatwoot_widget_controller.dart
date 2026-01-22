import 'package:chatwoot_sdk/ui/webview_widget/constants.dart';
import 'package:chatwoot_sdk/ui/webview_widget/utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Controller for interacting with an active Chatwoot widget instance.
class ChatwootWidgetController {
  WebViewController? _webViewController;

  void attach(WebViewController controller) {
    _webViewController = controller;
  }

  void detach() {
    _webViewController = null;
  }

  Future<void> setConversationCustomAttributes(
      Map<String, dynamic> customAttributes) async {
    final script = generateConversationMetadataScript(
      conversationCustomAttributes: customAttributes,
    );
    if (script.trim().isEmpty) {
      return;
    }
    await _webViewController?.runJavaScript(script);
  }

  Future<void> setLabel(String label) async {
    final script = createWootPostMessage({
      'event': PostMessageEvents.SET_LABEL,
      'label': label,
    });
    await _webViewController?.runJavaScript(script);
  }

  Future<void> removeLabel(String label) async {
    final script = createWootPostMessage({
      'event': PostMessageEvents.REMOVE_LABEL,
      'label': label,
    });
    await _webViewController?.runJavaScript(script);
  }
}
