
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import 'firebase_options.dart';

const int zegoAppID = 0; // ضع App ID الحقيقي
const String zegoAppSign = ''; // للتجربة فقط؛ لا تستخدم AppSign ثابتاً في الإنتاج

final auth = FirebaseAuth.instance;
final db = FirebaseFirestore.instance;

String publicId(String uid) => 'W${uid.toUpperCase()}';

String conversationId(String a, String b) {
  final ids = [a, b]..sort();
  return '${ids[0]}_${ids[1]}';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const WaslApp());
}

class WaslApp extends StatefulWidget {
  const WaslApp({super.key});

  @override
  State<WaslApp> createState() => _WaslAppState();
}

class _WaslAppState extends State<WaslApp> {
  ThemeMode mode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => mode =
          p.getBool('dark') == true ? ThemeMode.dark : ThemeMode.light);
    }
  }

  Future<void> _toggleTheme() async {
    final p = await SharedPreferences.getInstance();
    final dark = mode != ThemeMode.dark;
    await p.setBool('dark', dark);
    if (mounted) setState(() => mode = dark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وَصْل',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF087F70),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF16A894),
        brightness: Brightness.dark,
      ),
      home: StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == null) return const AuthPage();
          return HomePage(onToggleTheme: _toggleTheme);
        },
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = true;
  bool busy = false;

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);

    try {
      UserCredential credential;

      if (register) {
        credential = await auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );

        final user = credential.user!;
        final id = publicId(user.uid);

        await user.updateDisplayName(name.text.trim());

        await db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'publicId': id,
          'displayName': name.text.trim(),
          'email': user.email,
          'contacts': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        credential = await auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );

        final user = credential.user!;
        final profile = db.collection('users').doc(user.uid);
        final snap = await profile.get();

        // ترحيل الحسابات القديمة إن لم يكن ملف المستخدم موجوداً.
        if (!snap.exists) {
          await profile.set({
            'uid': user.uid,
            'publicId': publicId(user.uid),
            'displayName': user.displayName ?? 'مستخدم وَصْل',
            'email': user.email,
            'contacts': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'تعذر تسجيل الدخول')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 38,
                  child: Icon(Icons.forum_rounded, size: 38),
                ),
                const SizedBox(height: 16),
                const Text('وَصْل',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const Text('تواصل مع من تختار'),
                const SizedBox(height: 28),
                if (register)
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (register) const SizedBox(height: 12),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(busy
                        ? 'يرجى الانتظار...'
                        : register
                            ? 'إنشاء حساب'
                            : 'تسجيل الدخول'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => register = !register),
                  child: Text(register
                      ? 'لدي حساب بالفعل'
                      : 'إنشاء حساب جديد'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomePage({super.key, required this.onToggleTheme});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final idController = TextEditingController();
  bool searching = false;

  String get uid => auth.currentUser!.uid;

  Future<void> addContact() async {
    final targetId = idController.text.trim().toUpperCase();
    if (targetId.isEmpty) return;

    if (targetId == publicId(uid)) {
      showMessage('لا يمكنك إضافة حسابك الشخصي');
      return;
    }

    setState(() => searching = true);

    try {
      final result = await db
          .collection('users')
          .where('publicId', isEqualTo: targetId)
          .limit(1)
          .get();

      if (result.docs.isEmpty) {
        showMessage('لم يتم العثور على هذا المعرّف');
        return;
      }

      final target = result.docs.first;
      await db.collection('users').doc(uid).update({
        'contacts': FieldValue.arrayUnion([target.id]),
      });

      showMessage('تمت إضافة ${target.data()['displayName']}');
      idController.clear();
    } catch (e) {
      showMessage('تعذرت إضافة جهة الاتصال: $e');
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  void dispose() {
    idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = auth.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('وَصْل'),
        actions: [
          IconButton(
            tooltip: 'تغيير الثيم',
            onPressed: widget.onToggleTheme,
            icon: const Icon(Icons.contrast),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: db.collection('users').doc(uid).snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? {};
              final id = data['publicId'] ?? publicId(uid);

              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(data['displayName'] ?? me.displayName ?? 'حسابي'),
                  subtitle: SelectableText('معرّفك: $id'),
                  trailing: IconButton(
                    tooltip: 'نسخ المعرّف',
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      // أضف Clipboard.setData من flutter/services.dart
                      // أو استخدم زر نسخ مخصصاً.
                      showMessage('معرّفك: $id');
                    },
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: idController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'أدخل ID الشخص لإضافته',
                      prefixIcon: Icon(Icons.person_add_alt_1),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => addContact(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: searching ? null : addContact,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('محادثاتي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: db.collection('users').doc(uid).snapshots(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final contacts = List<String>.from(
                  userSnapshot.data!.data()?['contacts'] ?? [],
                );

                if (contacts.isEmpty) {
                  return const Center(
                    child: Text('لا توجد محادثات بعد. أضف صديقاً باستخدام ID.'),
                  );
                }

                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contactUid = contacts[index];

                    return FutureBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      future: db.collection('users').doc(contactUid).get(),
                      builder: (context, contactSnapshot) {
                        if (!contactSnapshot.hasData ||
                            !contactSnapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }

                        final contact = contactSnapshot.data!.data()!;
                        final chatId = conversationId(uid, contactUid);

                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(contact['displayName'] ?? 'مستخدم'),
                          subtitle: Text(contact['publicId'] ?? ''),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                chatId: chatId,
                                otherUid: contactUid,
                                otherName: contact['displayName'] ?? 'مستخدم',
                              ),
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'مكالمة فيديو',
                            icon: const Icon(Icons.video_call),
                            onPressed: () {
                              final callId = chatId;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VideoCallPage(
                                    callId: callId,
                                    userId: uid,
                                    userName: me.displayName ?? 'مستخدم',
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUid;
  final String otherName;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.otherName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final messageController = TextEditingController();
  bool sending = false;

  CollectionReference<Map<String, dynamic>> get messages =>
      db.collection('chats').doc(widget.chatId).collection('messages');

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || sending) return;

    setState(() => sending = true);
    messageController.clear();

    try {
      final me = auth.currentUser!;

      await db.collection('chats').doc(widget.chatId).set({
        'members': [me.uid, widget.otherUid]..sort(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': text,
      }, SetOptions(merge: true));

      await messages.add({
        'senderId': me.uid,
        'text': text,
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      messageController.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إرسال الرسالة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messages
                  .orderBy('createdAt', descending: false)
                  .limitToLast(200)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('تعذر تحميل الرسائل'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('ابدأ أول محادثة بينكما'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final mine = data['senderId'] == myUid;

                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(data['text'] ?? ''),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : sendMessage,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VideoCallPage extends StatelessWidget {
  final String callId;
  final String userId;
  final String userName;

  const VideoCallPage({
    super.key,
    required this.callId,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    if (zegoAppID == 0 || zegoAppSign.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'يجب إعداد بيانات ZEGOCLOUD الحقيقية قبل إجراء المكالمات.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return ZegoUIKitPrebuiltCall(
      appID: zegoAppID,
      appSign: zegoAppSign,
      userID: userId,
      userName: userName,
      callID: callId,
      config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall(),
    );
  }
}