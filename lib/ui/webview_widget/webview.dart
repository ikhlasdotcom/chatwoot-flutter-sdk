import 'dart:convert';
import 'dart:io';

import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_sdk/ui/webview_widget/utils.dart';
import 'package:file_picker/file_picker.dart';
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
      String? conversationLabel,
      bool resetConversation = false,
      String? conversationToken,
      bool persistConversationToken = true,
      ChatwootWidgetController? controller,
      ChatwootCallbacks? callbacks,
      void Function(String)? onAuthToken,
      void Function(String authToken, int? conversationId)?
          onConversationLoaded,
      void Function(Map<String, dynamic> message)? onMessage,
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
        conversationCustomAttributes: conversationCustomAttributes,
        conversationLabel: conversationLabel);

    _resetConversation = resetConversation;
    _conversationToken = conversationToken;
    _persistConversationToken = persistConversationToken;
    _onAuthToken = onAuthToken;
    _onConversationLoaded = onConversationLoaded;
    _onMessage = onMessage;
    _controllerBridge = controller;
    _callbacks = callbacks;
  }

  late final bool _resetConversation;
  late final String? _conversationToken;
  late final bool _persistConversationToken;
  late final void Function(String)? _onAuthToken;
  late final void Function(String authToken, int? conversationId)?
      _onConversationLoaded;
  late final void Function(Map<String, dynamic> message)? _onMessage;
  late final ChatwootWidgetController? _controllerBridge;
  late final ChatwootCallbacks? _callbacks;
  late final Uri _baseUri;

  @override
  _WebviewState createState() => _WebviewState();
}

class _WebviewState extends State<Webview> {
  WebViewController? _controller;

  void _handleWidgetMessage(Map<String, dynamic> data) {
    try {
      final message = ChatwootMessage.fromJson(data);
      if (data['event'] == 'message.updated') {
        widget._callbacks?.onMessageUpdated?.call(message);
        return;
      }
      if (message.isMine) {
        widget._callbacks?.onMessageSent?.call(message, '');
      } else {
        widget._callbacks?.onMessageReceived?.call(message);
      }
    } catch (_) {
      // ignore parse failures
    }
  }

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
            if (!jsMessage.message.contains('"event":"message-posted"')) {
              print("Chatwoot message received: ${jsMessage.message}");
            }
            final message = getMessage(jsMessage.message);
            if (isJsonString(message)) {
              final parsedMessage = jsonDecode(message);
              final eventType = parsedMessage["event"];
              final type = parsedMessage["type"];
              if (eventType == 'onEvent') {
                print(
                    "Chatwoot onEvent received: ${parsedMessage["eventIdentifier"]}");
              }
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
              if (eventType == 'onEvent' &&
                  parsedMessage["eventIdentifier"] == 'chatwoot:on-message') {
                final data = parsedMessage["data"];
                print("Chatwoot on-message payload: $data");
                if (data is Map<String, dynamic>) {
                  _handleWidgetMessage(data);
                  widget._onMessage?.call(data);
                } else if (data != null) {
                  final normalized = Map<String, dynamic>.from(data as dynamic);
                  _handleWidgetMessage(normalized);
                  widget._onMessage?.call(normalized);
                }
              }
              if (eventType == 'message-posted') {
                // Ignore widget message-posted events; they can fire on load.
              }
              if (eventType == 'open-url') {
                final url = parsedMessage["url"]?.toString();
                if (url != null && url.isNotEmpty) {
                  _goToUrl(url);
                }
              }
              if (type == 'close-widget') {
                widget.closeWidget?.call();
              }
            }
          })
          ..loadRequest(Uri.parse(webviewUrl));

        widget._controllerBridge?.attach(_controller!);

        if (Platform.isAndroid) {
          final androidController = _controller!.platform
              as webview_flutter_android.AndroidWebViewController;
          androidController.setOnShowFileSelector((params) async {
            // Use custom callback if provided, otherwise use default file picker
            if (widget.onAttachFile != null) {
              return widget.onAttachFile!.call();
            }
            return _defaultFilePicker(params);
          });
        }
      });
    });
  }

  /// Default file picker implementation for Android when onAttachFile is not provided.
  /// Uses file_picker package to handle all file types based on WebView's accept types.
  Future<List<String>> _defaultFilePicker(
      webview_flutter_android.FileSelectorParams params) async {
    try {
      // Determine file type based on accept types from WebView
      FileType fileType = FileType.any;
      List<String>? allowedExtensions;

      final acceptTypes = params.acceptTypes;
      if (acceptTypes.isNotEmpty) {
        final firstType = acceptTypes.first.toLowerCase();
        if (firstType.startsWith('image/')) {
          fileType = FileType.image;
        } else if (firstType.startsWith('video/')) {
          fileType = FileType.video;
        } else if (firstType.startsWith('audio/')) {
          fileType = FileType.audio;
        } else if (firstType == 'application/pdf') {
          fileType = FileType.custom;
          allowedExtensions = ['pdf'];
        }
        // For other types or mixed types, use FileType.any
      }

      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        allowMultiple: params.mode ==
            webview_flutter_android.FileSelectorMode.openMultiple,
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      // Return file URIs
      return result.files
          .where((file) => file.path != null)
          .map((file) => File(file.path!).uri.toString())
          .toList();
    } catch (e) {
      print('Chatwoot file picker error: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return _controller != null
        ? WebViewWidget(controller: _controller!)
        : SizedBox();
  }

  @override
  void dispose() {
    widget._controllerBridge?.detach();
    super.dispose();
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
