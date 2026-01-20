import 'package:chatwoot_sdk/data/local/entity/chatwoot_contact.dart';
import 'package:chatwoot_sdk/data/local/entity/chatwoot_conversation.dart';
import 'package:chatwoot_sdk/data/local/local_storage.dart';
import 'package:chatwoot_sdk/data/remote/service/chatwoot_client_auth_service.dart';
import 'package:chatwoot_sdk/chatwoot_parameters.dart';
import 'package:dio/dio.dart';
import 'package:synchronized/synchronized.dart' as synchronized;

///Intercepts network requests and attaches inbox identifier, contact identifiers, conversation identifiers
class ChatwootClientApiInterceptor extends Interceptor {
  static const INTERCEPTOR_INBOX_IDENTIFIER_PLACEHOLDER = "{INBOX_IDENTIFIER}";
  static const INTERCEPTOR_CONTACT_IDENTIFIER_PLACEHOLDER =
      "{CONTACT_IDENTIFIER}";
  static const INTERCEPTOR_CONVERSATION_IDENTIFIER_PLACEHOLDER =
      "{CONVERSATION_IDENTIFIER}";

  final ChatwootParameters _params;
  final LocalStorage _localStorage;
  final ChatwootClientAuthService _authService;
  final requestLock = synchronized.Lock();
  final responseLock = synchronized.Lock();

  ChatwootClientApiInterceptor(
      this._params, this._localStorage, this._authService);

  /// Creates a new contact and conversation when no persisted contact is found when an api call is made
  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    await requestLock.synchronized(() async {
      RequestOptions newOptions = options;
      ChatwootContact? contact = _localStorage.contactDao.getContact();
      ChatwootConversation? conversation =
          _localStorage.conversationDao.getConversation();

      if (contact == null) {
        // create new contact from user if no token found
        contact = await _authService.createNewContact(
            _params.inboxIdentifier, _localStorage.userDao.getUser());
        conversation = await _authService.createNewConversation(
            _params.inboxIdentifier, contact.contactIdentifier!,
            customAttributes: _params.conversationCustomAttributes);
        await _localStorage.conversationDao.saveConversation(conversation);
        await _localStorage.contactDao.saveContact(contact);
      }

      if (_params.conversationId != null &&
          (conversation == null || conversation.id != _params.conversationId)) {
        conversation = ChatwootConversation(
            id: _params.conversationId!,
            inboxId: conversation?.inboxId ?? 0,
            messages: conversation?.messages ?? [],
            contact: contact);
        await _localStorage.conversationDao.saveConversation(conversation);
      }

      if (conversation == null) {
        conversation = await _authService.createNewConversation(
            _params.inboxIdentifier, contact.contactIdentifier!,
            customAttributes: _params.conversationCustomAttributes);
        await _localStorage.conversationDao.saveConversation(conversation);
      }

      newOptions.path = newOptions.path.replaceAll(
          INTERCEPTOR_INBOX_IDENTIFIER_PLACEHOLDER, _params.inboxIdentifier);
      newOptions.path = newOptions.path.replaceAll(
          INTERCEPTOR_CONTACT_IDENTIFIER_PLACEHOLDER,
          contact.contactIdentifier!);
      newOptions.path = newOptions.path.replaceAll(
          INTERCEPTOR_CONVERSATION_IDENTIFIER_PLACEHOLDER,
          "${conversation.id}");

      handler.next(newOptions);
    });
  }

  /// Clears and recreates contact when a 401 (Unauthorized), 403 (Forbidden) or 404 (Not found)
  /// response is returned from chatwoot public client api
  @override
  Future<void> onResponse(
      Response response, ResponseInterceptorHandler handler) async {
    await responseLock.synchronized(() async {
      if (response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 404) {
        await _localStorage.clear(clearChatwootUserStorage: false);

        // create new contact from user if unauthorized,forbidden or not found
        final contact = _localStorage.contactDao.getContact()!;
        final conversation = await _authService.createNewConversation(
            _params.inboxIdentifier, contact.contactIdentifier!,
            customAttributes: _params.conversationCustomAttributes);
        await _localStorage.contactDao.saveContact(contact);
        await _localStorage.conversationDao.saveConversation(conversation);

        RequestOptions newOptions = response.requestOptions;

        newOptions.path = newOptions.path.replaceAll(
            INTERCEPTOR_INBOX_IDENTIFIER_PLACEHOLDER, _params.inboxIdentifier);
        newOptions.path = newOptions.path.replaceAll(
            INTERCEPTOR_CONTACT_IDENTIFIER_PLACEHOLDER,
            contact.contactIdentifier!);
        newOptions.path = newOptions.path.replaceAll(
            INTERCEPTOR_CONVERSATION_IDENTIFIER_PLACEHOLDER,
            "${conversation.id}");

        //use authservice's dio without the interceptor for subsequent call
        handler.next(await _authService.dio.fetch(newOptions));
      } else {
        // if response is not unauthorized, forbidden or not found forward response
        handler.next(response);
      }
    });
  }
}

extension Range on num {
  bool isBetween(num from, num to) {
    return from < this && this < to;
  }
}
