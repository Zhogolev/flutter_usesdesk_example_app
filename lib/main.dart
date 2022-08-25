import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usedesk/usedesk.dart';
import 'package:uuid/uuid.dart';

import 'usedesk_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  UsedeskChat usedeskChat = await UsedeskChat.init(
    /* Required */
    storage: SharedPreferencesUsedeskChatStorage(prefs),
    companyId: '163798',
    debug: true,
    apiConfig: const ChatApiConfiguration(
      urlChat: 'https://pubsubsec.usedesk.ru',
      urlOfflineForm: 'https://secure.usedesk.ru/',
      urlToSendFile: 'https://secure.usedesk.ru/uapi/v1/send_file',
    ),
  );

  usedeskChat
    ..identify = const IdentifyConfiguration(
      name: 'Test mobile 3',
      phoneNumber: 79529029974,
      additionalId: 'uuid_t_APP_UUID',
    )
    ..additionalFields = {'2032': 'test', '20231': 't_app'};

  initializeDateFormatting().then((_) => runApp(MyApp(usedeskChat)));
}

class MyApp extends StatelessWidget {
  final UsedeskChat usedeskChat;
  const MyApp(this.usedeskChat, {super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: ChatPage(usedeskChat),
      );
}

class ChatPage extends StatefulWidget {
  final UsedeskChat usedeskChat;
  const ChatPage(this.usedeskChat, {super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<types.Message> _messages = [];
  final _user = const types.User(
    id: 'Test mobile 3',
    firstName: 'Test mobile 3',
    role: types.Role.user,
  );

  @override
  void initState() {
    super.initState();
    _loadMessages();
    widget.usedeskChat.messagesStream.listen((List<MessageResponse> messages) {
      for (MessageResponse response in messages) {
        final msg = response.message;
        final author = msg.name == _user.firstName || (msg.name ?? "").isEmpty
            ? _user
            : types.User(
                firstName: msg.name ?? 'Оператор',
                id: msg.name ?? 'Оператор',
                role: types.Role.moderator);

        if (response.message.text != null) {
          _addMessage(types.TextMessage(
              text: response.message.text!,
              id: response.message.id.toString(),
              author: author));
        }

        if (response.message.file != null) {
          final file = response.message.file!;
          final size = file.size.split("")[0];
          _addMessage(types.ImageMessage(
              name: file.name,
              uri: file.content,
              size: num.parse(size),
              id: response.message.id.toString(),
              author: author));
        }
      }
    });
    widget.usedeskChat.connect();
  }

  @override
  void dispose() {
    widget.usedeskChat.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Chat(
          messages: _messages,
          onAttachmentPressed: _handleAttachmentPressed,
          onMessageTap: _handleMessageTap,
          onPreviewDataFetched: _handlePreviewDataFetched,
          onSendPressed: _handleSendPressed,
          showUserAvatars: true,
          showUserNames: true,
          user: _user,
        ),
      );

  void _addMessage(types.Message message) {
    int index = _messages
        .indexWhere((types.Message element) => message.id == element.id);

    if (index != -1) {
      setState(() {
        _messages[index] = message;
      });
    } else {
      setState(() {
        _messages.insert(0, message);
      });
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection();
                },
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Photo'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('File'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<File> getlocalFile(String path) async {
    return File(path);
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final message = types.FileMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        mimeType: lookupMimeType(result.files.single.path!),
        name: result.files.single.name,
        size: result.files.single.size,
        uri: path,
      );

      final bytes = await (await getlocalFile(path)).readAsBytes();

      widget.usedeskChat.sendFile(result.files.single.name, bytes);
      _addMessage(message);
    }
  }

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );

    if (result != null) {
      final bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);

      final message = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        height: image.height.toDouble(),
        id: const Uuid().v4(),
        name: result.name,
        size: bytes.length,
        uri: result.path,
        width: image.width.toDouble(),
      );
      widget.usedeskChat.sendFile(result.name, bytes);
      _addMessage(message);
    }
  }

  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;

      if (message.uri.startsWith('http')) {
        try {
          final index =
              _messages.indexWhere((element) => element.id == message.id);
          final updatedMessage =
              (_messages[index] as types.FileMessage).copyWith(
            isLoading: true,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });

          final client = http.Client();
          final request = await client.get(Uri.parse(message.uri));
          final bytes = request.bodyBytes;
          final documentsDir = (await getApplicationDocumentsDirectory()).path;
          localPath = '$documentsDir/${message.name}';

          if (!File(localPath).existsSync()) {
            final file = File(localPath);
            await file.writeAsBytes(bytes);
          }
        } finally {
          final index =
              _messages.indexWhere((element) => element.id == message.id);
          final updatedMessage =
              (_messages[index] as types.FileMessage).copyWith(
            isLoading: null,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });
        }
      }

      //await OpenFile.open(localPath);
    }
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );

    setState(() {
      _messages[index] = updatedMessage;
    });
  }

  void _handleSendPressed(types.PartialText message) {
    final localMessageId = const Uuid().v4();

    widget.usedeskChat.sendText(message.text, localMessageId.hashCode);
  }

  void _loadMessages() async {
    final response = await rootBundle.loadString('assets/messages.json');
    final messages = (jsonDecode(response) as List)
        .map((e) => types.Message.fromJson(e as Map<String, dynamic>))
        .toList();

    setState(() {
      _messages = messages;
    });
  }
}
