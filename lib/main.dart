import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'holiday_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('Firebase 초기화 오류:\n$e'),
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '공휴일 달력 & 한 줄 메모장',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snap.data;
          return user == null ? const LoginScreen() : HomeScreen(user: user);
        },
      ),
    );
  }
}

// ───────────────────────── 로그인 ─────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? e.code);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '📅 공휴일 달력 & 한 줄 메모장',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pw,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호 (6자 이상)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => auth.signInWithEmailAndPassword(
                            email: _email.text.trim(),
                            password: _pw.text,
                          ),
                        ),
                  child: const Text('로그인'),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => auth.createUserWithEmailAndPassword(
                            email: _email.text.trim(),
                            password: _pw.text,
                          ),
                        ),
                  child: const Text('회원가입'),
                ),
                const Divider(height: 32),
                OutlinedButton.icon(
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Google로 로그인'),
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => auth.signInWithPopup(GoogleAuthProvider()),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 홈 ─────────────────────────

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;
  late Future<List<Holiday>> _future = HolidayService.fetch(_year, _month);

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('users')
      .doc(widget.user.uid)
      .collection('memos');

  void _reload() {
    setState(() {
      _future = HolidayService.fetch(_year, _month);
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _monthMemos() {
    final base = _year * 10000 + _month * 100;
    return _col
        .where('date', isGreaterThanOrEqualTo: base)
        .where('date', isLessThanOrEqualTo: base + 31)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(11, (i) => 2020 + i);
    return Scaffold(
      appBar: AppBar(
        title: const Text('공휴일 달력 & 한 줄 메모장'),
        actions: [
          Center(
            child: Text(
              widget.user.email ?? widget.user.displayName ?? '',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    DropdownButton<int>(
                      value: _year,
                      items: [
                        for (final y in years)
                          DropdownMenuItem(value: y, child: Text('$y년')),
                      ],
                      onChanged: (v) {
                        _year = v!;
                        _reload();
                      },
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: _month,
                      items: [
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem(value: m, child: Text('$m월')),
                      ],
                      onChanged: (v) {
                        _month = v!;
                        _reload();
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _monthMemos(),
                  builder: (context, memoSnap) {
                    final counts = <int, List<String>>{};
                    for (final d in memoSnap.data?.docs ?? []) {
                      counts
                          .putIfAbsent(d['date'] as int, () => [])
                          .add('${d['memo']}');
                    }
                    return FutureBuilder<List<Holiday>>(
                      future: _future,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '불러오기 실패\n${snap.error}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        final list = snap.data!;
                        if (list.isEmpty) {
                          return Center(
                            child: Text('$_year년 $_month월에는 공휴일이 없습니다.'),
                          );
                        }
                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final h = list[i];
                            final memos = counts[h.date] ?? [];
                            return ListTile(
                              leading: const Icon(
                                Icons.celebration,
                                color: Colors.redAccent,
                              ),
                              title: Text(h.name),
                              subtitle: Text(
                                memos.isEmpty
                                    ? h.label
                                    : '${h.label}\n📝 ${memos.join(' · ')}',
                              ),
                              isThreeLine: memos.isNotEmpty,
                              trailing: memos.isEmpty
                                  ? const Icon(Icons.add)
                                  : Badge(
                                      label: Text('${memos.length}'),
                                      child: const Icon(Icons.edit_note),
                                    ),
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) =>
                                    MemoDialog(holiday: h, col: _col),
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
        ),
      ),
    );
  }
}

// ───────────────────────── 메모 다이얼로그 ─────────────────────────

class MemoDialog extends StatefulWidget {
  final Holiday holiday;
  final CollectionReference<Map<String, dynamic>> col;
  const MemoDialog({super.key, required this.holiday, required this.col});
  @override
  State<MemoDialog> createState() => _MemoDialogState();
}

class _MemoDialogState extends State<MemoDialog> {
  final _ctrl = TextEditingController();

  Future<void> _add() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    await widget.col.add({
      'date': widget.holiday.date,
      'holidayName': widget.holiday.name,
      'memo': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.holiday;
    return AlertDialog(
      title: Text('${h.name} · ${h.label}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    maxLength: 100,
                    decoration: const InputDecoration(hintText: '일정·한 줄 메모'),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                IconButton(onPressed: _add, icon: const Icon(Icons.save)),
              ],
            ),
            Flexible(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.col.where('date', isEqualTo: h.date).snapshots(),
                builder: (context, snap) {
                  final docs = [...?snap.data?.docs]
                    ..sort((a, b) {
                      final ta =
                          (a['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          1 << 50;
                      final tb =
                          (b['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          1 << 50;
                      return ta.compareTo(tb);
                    });
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('저장된 메모가 없습니다.'),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final d in docs)
                        ListTile(
                          dense: true,
                          title: Text('${d['memo']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => d.reference.delete(),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
