import "dart:convert";

import "package:chatwoot_sdk/data/local/entity/chatwoot_user.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "constants.dart";

bool isJsonString(string) {
  try {
    jsonDecode(string);
  } catch (e) {
    return false;
  }
  return true;
}

String createWootPostMessage(object) {
  final stringfyObject = "${WOOT_PREFIX}${jsonEncode(object)}";
  final script = 'window.postMessage(\'${stringfyObject}\');';
  return script;
}

String getMessage(String data) {
  return data.replaceAll(WOOT_PREFIX, '');
}

String generateConversationMetadataScript(
    {dynamic conversationCustomAttributes, String? conversationLabel}) {
  String script = '';
  if (conversationCustomAttributes != null) {
    final conversationAttributeObject = {
      "event": PostMessageEvents.SET_CONVERSATION_CUSTOM_ATTRIBUTES,
      "customAttributes": conversationCustomAttributes,
    };
    script += createWootPostMessage(conversationAttributeObject);
  }
  if (conversationLabel != null && conversationLabel.isNotEmpty) {
    final conversationLabelObject = {
      "event": PostMessageEvents.SET_LABEL,
      "label": conversationLabel,
    };
    script += createWootPostMessage(conversationLabelObject);
  }
  return script;
}

String generateScripts(
    {ChatwootUser? user,
    String? locale,
    dynamic customAttributes,
    dynamic conversationCustomAttributes,
    String? conversationLabel}) {
  String script = '';

  if (user != null) {
    final userObject = {
      "event": PostMessageEvents.SET_USER,
      "identifier": user.identifier,
      "user": user,
    };
    script += createWootPostMessage(userObject);
  }
  if (locale != null) {
    final localeObject = {
      "event": PostMessageEvents.SET_LOCALE,
      "locale": locale
    };
    script += createWootPostMessage(localeObject);
  }
  if (customAttributes != null) {
    final attributeObject = {
      "event": PostMessageEvents.SET_CUSTOM_ATTRIBUTES,
      "customAttributes": customAttributes,
    };
    script += createWootPostMessage(attributeObject);
  }
  script += generateConversationMetadataScript(
    conversationCustomAttributes: conversationCustomAttributes,
    conversationLabel: conversationLabel,
  );
  // Intercept attachment links (blob/download/target=_blank) and forward to Flutter
  script += """
(function(){
  if (window.__cw_attachment_click_hooked) { return; }
  window.__cw_attachment_click_hooked = true;
  function postMessage(obj){
    try {
      var msg = '$WOOT_PREFIX' + JSON.stringify(obj);
      if (window.ReactNativeWebView && window.ReactNativeWebView.postMessage) {
        window.ReactNativeWebView.postMessage(msg);
      } else if (window.postMessage) {
        window.postMessage(msg);
      }
    } catch (e) {}
  }
  document.addEventListener('click', function(e){
    var el = e.target;
    while (el && el.tagName && el.tagName.toLowerCase() !== 'a') {
      el = el.parentElement;
    }
    if (!el || !el.getAttribute) { return; }
    var href = el.getAttribute('href');
    if (!href) { return; }
    var target = (el.getAttribute('target') || '').toLowerCase();
    var isBlob = href.indexOf('blob:') === 0;
    var isDownload = el.hasAttribute('download');
    var isBlank = target === '_blank';
    if (isBlob || isDownload || isBlank) {
      e.preventDefault();
      postMessage({ event: 'open-url', url: href });
    }
  }, true);
})();
""";
  // Notify Flutter when the first outbound message request completes
  script += """
(function(){
  if (window.__cw_message_posted_hooked) { return; }
  window.__cw_message_posted_hooked = true;
  function postMessage(obj){
    try {
      var msg = '$WOOT_PREFIX' + JSON.stringify(obj);
      if (window.ReactNativeWebView && window.ReactNativeWebView.postMessage) {
        window.ReactNativeWebView.postMessage(msg);
      } else if (window.postMessage) {
        window.postMessage(msg);
      }
    } catch (e) {}
  }
  function notifyOnce(){
    if (window.__cw_message_posted_once) { return; }
    window.__cw_message_posted_once = true;
    postMessage({ event: 'message-posted' });
    if (window.__cw_apply_attrs_apply) {
      window.__cw_apply_attrs_apply();
    }
  }
  function isMessagePost(url, method) {
    var u = (url || '').toString();
    var m = (method || '').toString().toUpperCase();
    if (m !== 'POST') { return false; }
    if (u.indexOf('/messages') !== -1) { return true; }
    if (u.indexOf('/conversations') !== -1) { return true; }
    return false;
  }
  if (window.fetch) {
    var originalFetch = window.fetch;
    window.fetch = function(input, init){
      try {
        var url = (typeof input === 'string') ? input : (input && input.url) ? input.url : '';
        var method = init && init.method ? init.method : (input && input.method) ? input.method : 'GET';
        if (isMessagePost(url, method)) {
          return originalFetch.apply(this, arguments).then(function(resp){
            notifyOnce();
            return resp;
          });
        }
      } catch (e) {}
      return originalFetch.apply(this, arguments);
    };
  }
  if (window.XMLHttpRequest) {
    var open = XMLHttpRequest.prototype.open;
    var send = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function(method, url){
      this.__cw_method = method;
      this.__cw_url = url;
      return open.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function(body){
      try {
        if (isMessagePost(this.__cw_url, this.__cw_method)) {
          this.addEventListener('load', function(){
            notifyOnce();
          });
        }
      } catch (e) {}
      return send.apply(this, arguments);
    };
  }
})();
""";
  return script;
}

const _androidOptions = AndroidOptions(
  encryptedSharedPreferences: true,
);
final secureStorage = new FlutterSecureStorage(aOptions: _androidOptions);
const cookieKey = 'cwCookie';

class StoreHelper {
  static Future<String> getCookie() async {
    final cookie = await secureStorage.read(key: cookieKey);
    return cookie ?? "";
  }

  static storeCookie(value) async {
    await secureStorage.write(key: cookieKey, value: value);
  }

  static Future<void> clearCookie() async {
    await secureStorage.delete(key: cookieKey);
  }
}
