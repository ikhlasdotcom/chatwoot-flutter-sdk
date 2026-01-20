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

String generateScripts(
    {ChatwootUser? user,
    String? locale,
    dynamic customAttributes,
    dynamic conversationCustomAttributes}) {
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
  if (conversationCustomAttributes != null) {
    final conversationAttributeObject = {
      "event": PostMessageEvents.SET_CONVERSATION_CUSTOM_ATTRIBUTES,
      "customAttributes": conversationCustomAttributes,
    };
    final conversationScript =
        createWootPostMessage(conversationAttributeObject);
    // Send conversation attributes after the first outbound message request completes
    script += """
(function(){
  if (window.__cw_conversation_attrs_hooked) { return; }
  window.__cw_conversation_attrs_hooked = true;
  var fired = false;
  function sendOnce() {
    if (fired) { return; }
    fired = true;
    $conversationScript
  }
  function isMessagePost(url, method) {
    var u = (url || '').toString();
    var m = (method || '').toString().toUpperCase();
    if (m !== 'POST') { return false; }
    // Chatwoot widget endpoints vary; match broadly on message/conversation posts
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
            sendOnce();
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
            sendOnce();
          });
        }
      } catch (e) {}
      return send.apply(this, arguments);
    };
  }
})();
""";
  }
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
