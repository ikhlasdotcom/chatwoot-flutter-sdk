import 'dart:convert';
import 'dart:io';

import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_sdk/ui/webview_widget/utils.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
    as webview_flutter_android;

///Chatwoot webview widget
/// {@category FlutterClientSdk}
class Webview extends StatefulWidget {
  /// Url for Chatwoot widget in webview
  late final String widgetUrl;

  /// Chatwoot user & locale initialisation script
  late final String injectedJavaScript;

  /// See [ChatwootWidget.closeWidget]
  final void Function()? closeWidget;

  /// See [ChatwootWidget.onAttachFile]
  final Future<List<String>> Function()? onAttachFile;

  /// See [ChatwootWidget.onLoadStarted]
  final void Function()? onLoadStarted;

  /// See [ChatwootWidget.onLoadProgress]
  final void Function(int)? onLoadProgress;

  /// See [ChatwootWidget.onLoadCompleted]
  final void Function()? onLoadCompleted;

  Webview(
      {Key? key,
      required String websiteToken,
      required String baseUrl,
      ChatwootUser? user,
      String locale = "en",
      customAttributes,
      dynamic conversationCustomAttributes,
      bool resetConversation = false,
      String? conversationToken,
      bool persistConversationToken = true,
      void Function(String)? onAuthToken,
      void Function(String authToken, int? conversationId)?
          onConversationLoaded,
      this.closeWidget,
      this.onAttachFile,
      this.onLoadStarted,
      this.onLoadProgress,
      this.onLoadCompleted})
      : super(key: key) {
    widgetUrl =
        "${baseUrl}/widget?website_token=${websiteToken}&locale=${locale}";
    _baseUri = Uri.parse(baseUrl);

    injectedJavaScript = generateScripts(
        user: user,
        locale: locale,
        customAttributes: customAttributes,
        conversationCustomAttributes: conversationCustomAttributes);

    _resetConversation = resetConversation;
    _conversationToken = conversationToken;
    _persistConversationToken = persistConversationToken;
    _onAuthToken = onAuthToken;
    _onConversationLoaded = onConversationLoaded;
  }

  late final bool _resetConversation;
  late final String? _conversationToken;
  late final bool _persistConversationToken;
  late final void Function(String)? _onAuthToken;
  late final void Function(String authToken, int? conversationId)?
      _onConversationLoaded;
  late final Uri _baseUri;

  @override
  _WebviewState createState() => _WebviewState();
}

class _WebviewState extends State<Webview> {
  WebViewController? _controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String webviewUrl = widget.widgetUrl;
      if (widget._resetConversation) {
        await StoreHelper.clearCookie();
      }

      final cwCookie =
          widget._conversationToken ?? await StoreHelper.getCookie();
      if (cwCookie.isNotEmpty) {
        webviewUrl = "${webviewUrl}&cw_conversation=${cwCookie}";
      }
      setState(() {
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.white)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                // Update loading bar.
                widget.onLoadProgress?.call(progress);
              },
              onPageStarted: (String url) {
                widget.onLoadStarted?.call();
              },
              onPageFinished: (String url) async {
                widget.onLoadCompleted?.call();
              },
              onWebResourceError: (WebResourceError error) {},
              onNavigationRequest: (NavigationRequest request) {
                if (_shouldOpenExternally(request.url)) {
                  _goToUrl(request.url);
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..addJavaScriptChannel("ReactNativeWebView",
              onMessageReceived: (JavaScriptMessage jsMessage) {
            print("Chatwoot message received: ${jsMessage.message}");
            final message = getMessage(jsMessage.message);
            if (isJsonString(message)) {
              final parsedMessage = jsonDecode(message);
              final eventType = parsedMessage["event"];
              final type = parsedMessage["type"];
              if (eventType == 'loaded') {
                final config = parsedMessage["config"];
                final authToken = config["authToken"];
                final conversationIdRaw =
                    config["conversationId"] ?? config["conversation_id"];
                final conversationId = conversationIdRaw != null
                    ? int.tryParse(conversationIdRaw.toString())
                    : null;
                print(
                    "Chatwoot loaded - authToken: $authToken, conversationId: $conversationId");
                if (widget._persistConversationToken) {
                  StoreHelper.storeCookie(authToken);
                }
                widget._onAuthToken?.call(authToken);
                widget._onConversationLoaded?.call(authToken, conversationId);
                _controller?.runJavaScript(widget.injectedJavaScript);
              }
              if (type == 'close-widget') {
                widget.closeWidget?.call();
              }
            }
          })
          ..loadRequest(Uri.parse(webviewUrl));

        if (Platform.isAndroid && widget.onAttachFile != null) {
          final androidController = _controller!.platform
              as webview_flutter_android.AndroidWebViewController;
          androidController
              .setOnShowFileSelector((_) => widget.onAttachFile!.call());
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _controller != null
        ? WebViewWidget(controller: _controller!)
        : SizedBox();
  }

  _goToUrl(String url) {
    launchUrl(Uri.parse(url));
  }

  bool _shouldOpenExternally(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return true;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return true;
    }

    final baseHost = widget._baseUri.host.toLowerCase();
    final targetHost = uri.host.toLowerCase();
    if (baseHost.isEmpty || targetHost.isEmpty) {
      return true;
    }

    // Allow navigation within the Chatwoot host (including subdomains)
    if (targetHost == baseHost || targetHost.endsWith('.$baseHost')) {
      return false;
    }

    return true;
  }
}
