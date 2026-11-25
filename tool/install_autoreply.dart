// Developed by @Ramana Code Softwares
//
// One-time installer for the Android call auto-reply (run from project root):
//   dart run tool/install_autoreply.dart
//
// It copies the Kotlin files into android/, adds the permissions and the
// receiver to AndroidManifest.xml. Safe to run twice. Originals saved as .bak.

import 'dart:io';

const marker = 'drivepro-autoreply';

void fail(String m) {
  stderr.writeln('ERROR: $m');
  exit(1);
}

void main() {
  final gradle = [
    File('android/app/build.gradle.kts'),
    File('android/app/build.gradle'),
  ].where((f) => f.existsSync()).toList();
  if (gradle.isEmpty) fail('android/app/build.gradle not found. Run from the project root.');
  final text = gradle.first.readAsStringSync();
  final m = RegExp(r'''namespace\s*=?\s*["']([\w.]+)["']''').firstMatch(text) ??
      RegExp(r'''applicationId\s*=?\s*["']([\w.]+)["']''').firstMatch(text);
  if (m == null) fail('Could not find namespace/applicationId in ${gradle.first.path}.');
  final pkg = m!.group(1)!;
  stdout.writeln('Package: $pkg');

  final main = Directory('android/app/src/main');
  final javaMain = main
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('MainActivity.java'))
      .toList();
  if (javaMain.isNotEmpty) {
    fail('MainActivity is Java (${javaMain.first.path}). Convert it to Kotlin first.');
  }
  final existing = main
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('MainActivity.kt'))
      .toList();
  final dir = existing.isNotEmpty
      ? existing.first.parent
      : Directory('${main.path}/kotlin/${pkg.replaceAll('.', '/')}');
  dir.createSync(recursive: true);

  String tpl(String name) => File('android_native/$name').readAsStringSync().replaceAll('__PACKAGE__', pkg);

  final mainFile = File('${dir.path}/MainActivity.kt');
  if (mainFile.existsSync()) {
    final cur = mainFile.readAsStringSync();
    if (!cur.contains('drivepro/call_autoreply')) {
      mainFile.copySync('${mainFile.path}.bak');
    }
  }
  mainFile.writeAsStringSync(tpl('MainActivity.kt.tpl'));
  File('${dir.path}/CallAutoReply.kt').writeAsStringSync(tpl('CallAutoReply.kt.tpl'));
  stdout.writeln('Kotlin files written to ${dir.path}');

  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) fail('AndroidManifest.xml not found.');
  var xml = manifest.readAsStringSync();
  if (xml.contains(marker)) {
    stdout.writeln('Manifest already patched. Done.');
    return;
  }
  manifest.copySync('${manifest.path}.bak');
  final perms = '''
    <!-- $marker -->
    <uses-permission android:name="android.permission.READ_PHONE_STATE"/>
    <uses-permission android:name="android.permission.READ_CALL_LOG"/>
    <uses-permission android:name="android.permission.SEND_SMS"/>
    <uses-feature android:name="android.hardware.telephony" android:required="false"/>
''';
  final openTag = RegExp(r'<manifest\b[^>]*>').firstMatch(xml);
  if (openTag == null) fail('<manifest> tag not found.');
  xml = xml.replaceRange(openTag!.end, openTag.end, '\n$perms');
  const receiver = '''
        <receiver android:name=".CallAutoReplyReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.PHONE_STATE"/>
            </intent-filter>
        </receiver>
''';
  final close = xml.lastIndexOf('</application>');
  if (close < 0) fail('</application> not found.');
  xml = xml.replaceRange(close, close, receiver);
  manifest.writeAsStringSync(xml);
  stdout.writeln('Manifest patched. Now run: flutter run  (on the school phone)');
}
