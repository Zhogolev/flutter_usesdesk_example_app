import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_chat_test_with_use_desk/take_picture_screen.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as ui;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usedesk/usedesk.dart' as usedesk;
import 'package:uuid/uuid.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mime/mime.dart';
import 'usedesk_db.dart';

Future<XFile?> _takePicture(BuildContext context) async {
  final cameras = await availableCameras();
  final firstCamera = cameras.first;
  final picture = await Navigator.of(context)
      .push<XFile?>(MaterialPageRoute(builder: (context) {
    return TakePictureScreen(camera: firstCamera);
  }));
  return picture;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const FirstScreen());
}

class FirstScreen extends StatefulWidget {
  const FirstScreen({Key? key}) : super(key: key);

  @override
  State<FirstScreen> createState() => _FirstScreenState();
}

class _FirstScreenState extends State<FirstScreen> {
  TextEditingController? controller;

  @override
  void initState() {
    controller = TextEditingController(text: '77770000010');
    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FirstScreenBody(controller: controller),
    );
  }
}

class FirstScreenBody extends StatelessWidget {
  const FirstScreenBody({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(
              height: 29,
            ),
            InkWell(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.blue,
                  child: const Text('remove token'),
                ),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final sp = SharedPreferencesUsedeskChatStorage(prefs);
                  await sp.clearToken();
                }),
            const SizedBox(
              height: 29,
            ),
            InkWell(
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.blue,
                child: const Text('go to chat'),
              ),
              onTap: () async {
                String text = controller?.text ?? '0';
                int phone = int.parse(text);

                final prefs = await SharedPreferences.getInstance();

                usedesk.UsedeskChat usedeskChat =
                    await usedesk.UsedeskChat.init(
                  /* Required */
                  storage: SharedPreferencesUsedeskChatStorage(prefs),
                  companyId: '163798',
                  channelId: '40227',
                  debug: true,
                  apiConfig: const usedesk.ChatApiConfiguration(
                    urlChat: 'https://pubsubsec.usedesk.ru',
                    urlOfflineForm: 'https://secure.usedesk.ru/',
                    urlToSendFile:
                        'https://secure.usedesk.ru/uapi/v1/send_file',
                  ),
                );

                usedeskChat
                  ..identify = usedesk.IdentifyConfiguration(
                    name: '$phone: remove',
                    phoneNumber: phone,
                    additionalId: 'uuid_$phone',
                  )
                  ..additionalFields = {
                    '20266': 'Простой вопрос',
                    '20265': 'se_app'
                  };

                Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
                  return ChatPage(usedeskChat);
                }));
              },
            )
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final usedesk.UsedeskChat usedeskChat;
  const MyApp(this.usedeskChat, {super.key});

  @override
  Widget build(BuildContext context) => ChatPage(usedeskChat);
}

class ChatPage extends StatefulWidget {
  final usedesk.UsedeskChat usedeskChat;
  const ChatPage(this.usedeskChat, {super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<types.Message> _messages = [];
  final _user = const types.User(
    id: 'Test mobile',
    firstName: 'Test mobile',
    role: types.Role.user,
  );

  bool isImage(String file) {
    final fileExt = file.split('.').last.toUpperCase();
    return ['PNG', 'JPEG', 'JPG'].contains(fileExt);
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    widget.usedeskChat.messagesStream.listen((List<usedesk.Message> messages) {
      for (usedesk.Message msg in messages) {
        final author = msg.name == _user.firstName || (msg.name ?? "").isEmpty
            ? _user
            : types.User(
                firstName: msg.name ?? 'Оператор',
                id: msg.name ?? 'Оператор',
                role: types.Role.moderator);

        if ((msg.text ?? "").isNotEmpty && msg.name == 'UseDesk Bot') {
          _addMessage(
            types.TextMessage(
                text: msg.text!,
                id: msg.id.toString(),
                author: const types.User(id: 'system', firstName: 'System')),
          );
        } else if ((msg.text ?? "").isNotEmpty) {
          _addMessage(types.TextMessage(
              text: msg.text!, id: msg.id.toString(), author: author));
        }

        if (msg.file != null) {
          final file = msg.file!;
          final name = file.name.split('/').last;
          final size = file.size.split("").first;
          if (isImage(name)) {
            _addMessage(types.ImageMessage(
                name: name,
                uri: file.content,
                size: num.parse(size),
                id: name,
                author: author));
          } else {
            _addMessage(types.FileMessage(
                name: name,
                uri: file.content,
                size: num.parse(size),
                id: name,
                author: author));
          }
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
        body: ui.Chat(
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

    if (result != null &&
        result.files.single.path != null &&
        result.files.single.path != '__loading__') {
      final path = result.files.single.path!;
      final message = types.FileMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: result.files.single.name,
        mimeType: lookupMimeType(result.files.single.path!),
        name: result.files.single.name,
        size: result.files.single.size,
        uri: path,
      );

      final bytes = await (await getlocalFile(path)).readAsBytes();

      widget.usedeskChat.sendFile(
          result.files.single.path!, bytes, result.files.single.name.hashCode);
      _addMessage(message);
    }
  }

  void _handleImageSelection() async {
    final result = await _takePicture(context);

    if (result != null && result.path != '__loading__') {
      final bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);

      final message = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        height: image.height.toDouble(),
        id: result.name,
        name: result.name,
        size: bytes.length,
        uri: result.path,
        width: image.width.toDouble(),
      );
      widget.usedeskChat.sendFile(result.path, bytes, result.name.hashCode);
      print('send message with id ');
      print(result.name);
      print('send message with id ');
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
    setState(() {
      _messages = [];
    });
  }
}
