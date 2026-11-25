// Developed by @Ramana Code Softwares

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../data/call_autoreply_channel.dart';
import '../../../core/services/backend.dart';

/// Admin (on the school's Android phone): automatic SMS after incoming calls.
class CallAutoReplyPage extends StatefulWidget {
  const CallAutoReplyPage({super.key});

  @override
  State<CallAutoReplyPage> createState() => _CallAutoReplyPageState();
}

class _CallAutoReplyPageState extends State<CallAutoReplyPage> with WidgetsBindingObserver {
  final _school = TextEditingController();
  final _missed = TextEditingController();
  final _answered = TextEditingController();
  final _cooldown = TextEditingController(text: '30');
  final _testNumber = TextEditingController();
  bool _enabled = false;
  bool _sendMissed = true;
  bool _sendAnswered = true;
  bool _loading = true;
  Map<String, bool> _perm = {};
  List<AutoReplyLogEntry> _log = [];
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _school.dispose();
    _missed.dispose();
    _answered.dispose();
    _cooldown.dispose();
    _testNumber.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && CallAutoReplyChannel.supported) _refreshLog();
  }

  Future<void> _load() async {
    if (!CallAutoReplyChannel.supported) {
      setState(() => _loading = false);
      return;
    }
    try {
      final cfg = await CallAutoReplyChannel.getConfig();
      var school = cfg['schoolName'] as String? ?? '';
      if (school.isEmpty) {
        // Pre-fill from the public school info the admin already saved.
        final info = await Backend.firestore.collection('public_info').doc('school').get();
        school = info.data()?['schoolName'] as String? ?? '';
      }
      _school.text = school;
      _missed.text = cfg['missedTemplate'] as String? ?? '';
      _answered.text = cfg['answeredTemplate'] as String? ?? '';
      _cooldown.text = '${cfg['cooldownMinutes'] ?? 30}';
      _enabled = cfg['enabled'] == true;
      _sendMissed = cfg['sendMissed'] != false;
      _sendAnswered = cfg['sendAnswered'] != false;
      _perm = await CallAutoReplyChannel.permissions();
      await _refreshLog();
    } catch (e) {
      _message = 'Native auto-reply is not installed: run "dart run tool/install_autoreply.dart" ($e)';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Copies new device log rows into Firestore so they show in Call Enquiries.
  Future<void> _refreshLog() async {
    final log = await CallAutoReplyChannel.getLog();
    final fresh = log.where((e) => !e.synced).toList();
    if (fresh.isNotEmpty) {
      try {
        final db = Backend.firestore;
        final batch = db.batch();
        for (final e in fresh) {
          batch.set(db.collection('call_enquiries').doc('device_${e.id}'), {
            'source': 'phone_autoreply',
            'provider': 'android_device',
            'phoneNumber': e.number,
            'callStatus': e.kind,
            'smsStatus': e.sms,
            'followUpStatus': 'pending',
            'followUpNotes': '',
            'receivedAt': Timestamp.fromDate(e.at),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        await CallAutoReplyChannel.markSynced(fresh.map((e) => e.id).toList());
      } catch (_) {
        // Offline or signed out: rows stay unsynced and retry next time.
      }
    }
    final updated = await CallAutoReplyChannel.getLog();
    if (mounted) setState(() => _log = updated);
  }

  Future<void> _save() async {
    await CallAutoReplyChannel.saveConfig({
      'enabled': _enabled,
      'schoolName': _school.text.trim(),
      'missedTemplate': _missed.text.trim(),
      'answeredTemplate': _answered.text.trim(),
      'sendMissed': _sendMissed,
      'sendAnswered': _sendAnswered,
      'cooldownMinutes': int.tryParse(_cooldown.text.trim()) ?? 30,
    });
    _snack('Saved.');
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _grant() async {
    final p = await CallAutoReplyChannel.requestPermissions();
    if (mounted) setState(() => _perm = p);
  }

  Future<void> _test() async {
    if (_testNumber.text.replaceAll(RegExp(r'\D'), '').length < 10) {
      _snack('Enter a 10-digit mobile number for the test SMS.');
      return;
    }
    await _save();
    try {
      await CallAutoReplyChannel.sendTest(_testNumber.text.trim());
      _snack('Test SMS submitted.');
    } catch (e) {
      _snack('Test failed: $e');
    }
  }

  int get _preview1 => _missed.text.length;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!CallAutoReplyChannel.supported) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Call auto-reply works only in the Android app installed on the school phone (the SIM that receives enquiry calls).'),
        ),
      );
    }
    final allOk = _perm['sms'] == true && _perm['callLog'] == true && _perm['phoneState'] == true;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Auto SMS after calls', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      const Text('Install this app on the school phone and keep this SIM in it. After every incoming call the app sends an SMS from this SIM, even when the app is closed.'),
      if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: Icon(allOk ? Icons.verified_user : Icons.warning_amber, color: allOk ? Colors.green : Colors.orange),
          title: Text(allOk ? 'Permissions granted' : 'Permissions needed'),
          subtitle: const Text('SMS, Call log, Phone state'),
          trailing: allOk ? null : FilledButton(onPressed: _grant, child: const Text('Grant')),
        ),
      ),
      SwitchListTile(
        title: const Text('Auto SMS enabled'),
        value: _enabled,
        onChanged: (v) => setState(() => _enabled = v),
      ),
      SwitchListTile(
        title: const Text('Send when call is missed / not picked'),
        value: _sendMissed,
        onChanged: (v) => setState(() => _sendMissed = v),
      ),
      SwitchListTile(
        title: const Text('Send thanks after an answered call'),
        value: _sendAnswered,
        onChanged: (v) => setState(() => _sendAnswered = v),
      ),
      TextField(controller: _school, decoration: const InputDecoration(labelText: 'School name (used as {school})')),
      const SizedBox(height: 8),
      TextField(
        controller: _missed,
        maxLines: 3,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: 'Missed-call message', helperText: '$_preview1 characters • {school} is replaced'),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _answered,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Answered-call message', helperText: '{school} is replaced'),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _cooldown,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Do not message the same number again for (minutes)'),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton(onPressed: _save, child: const Text('Save')),
        SizedBox(
          width: 190,
          child: TextField(controller: _testNumber, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Test number')),
        ),
        OutlinedButton(onPressed: _test, child: const Text('Send test SMS')),
      ]),
      const SizedBox(height: 8),
      const Text('Tip: keep messages under 160 characters (70 if they contain Telugu) to avoid multi-part SMS charges. On Xiaomi/Oppo/Vivo/Samsung phones set this app to "No restrictions" in battery settings and allow auto-start.', style: TextStyle(fontSize: 12)),
      const Divider(height: 32),
      Row(children: [
        Text('Recent calls', style: Theme.of(context).textTheme.titleLarge),
        IconButton(onPressed: _refreshLog, icon: const Icon(Icons.refresh)),
      ]),
      if (_log.isEmpty) const Text('No calls handled yet.'),
      for (final e in _log.take(30))
        ListTile(
          dense: true,
          leading: Icon(e.kind == 'missed' ? Icons.phone_missed : Icons.phone_in_talk,
              color: e.kind == 'missed' ? Colors.red : Colors.green),
          title: Text(e.number.isEmpty ? 'Hidden number' : e.number),
          subtitle: Text('${e.kind} • SMS: ${e.sms}\n${e.at}'),
          isThreeLine: true,
        ),
    ]);
  }
}
