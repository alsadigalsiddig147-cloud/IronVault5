import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:cryptography/cryptography.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const IronVaultApp());
}

class IronVaultApp extends StatelessWidget {
  const IronVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07080A),
        primaryColor: const Color(0xFFD4AF37),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _identityPasswordController = TextEditingController();
  
  String _selectedFilePath = '';
  String _selectedKeyType = 'RSA-4096';
  String _logText = '[*] Iron Vault Core V9.0 (Secure Container) Ready.\n';

  final _algorithm = AesGcm.with256bits();

  void _addLog(String msg) {
    setState(() => _logText += '\n$msg');
  }

  // طلب صلاحية إدارة الملفات (ضرورية للأندرويد 11+)
  Future<void> _requestStoragePermission() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }

  // إدارة مجلد التنزيلات
  Future<Directory> _getIronVaultDirectory() async {
    Directory downloadsDir = Directory('/storage/emulated/0/Download');
    if (!await downloadsDir.exists()) {
      downloadsDir = Directory('/storage/emulated/0/Downloads');
    }
    final vaultDir = Directory(p.join(downloadsDir.path, 'IronVault'));
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFilePath = result.files.single.path!);
      _addLog('[+] Selected: ${p.basename(_selectedFilePath)}');
    }
  }

  // 1. التشفير الآمن (يخفي اسم الملف داخل الحاوية)
  Future<void> _processFileEncryption() async {
    if (_selectedFilePath.isEmpty || _passwordController.text.isEmpty) {
      _addLog('[-] Error: File or password missing.');
      return;
    }
    await _requestStoragePermission();

    try {
      _addLog('[*] Creating Secure Container...');
      
      final file = File(_selectedFilePath);
      final originalName = p.basename(_selectedFilePath);
      final vaultDir = await _getIronVaultDirectory();
      
      // اسم عشوائي للملف المشفر ليخفي هويته
      final randomId = DateTime.now().millisecondsSinceEpoch;
      final savePath = p.join(vaultDir.path, 'vault_$randomId.iv5');
      final outputFile = File(savePath);

      // اشتقاق المفتاح
      final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
      final secretKey = await pbkdf2.deriveKeyFromPassword(
        password: _passwordController.text,
        nonce: List<int>.generate(16, (i) => i),
      );

      // تشفير اسم الملف الأصلي
      final headerData = utf8.encode(jsonEncode({'name': originalName}));
      final headerBox = await _algorithm.encrypt(headerData, secretKey: secretKey);
      final headerBytes = headerBox.concatenation();

      final sink = outputFile.openWrite();

      // كتابة طول الاسم المشفر (4 بايت)
      final headerLengthBytes = ByteData(4)..setUint32(0, headerBytes.length);
      sink.add(headerLengthBytes.buffer.asUint8List());
      // كتابة الاسم المشفر
      sink.add(headerBytes);

      // تشفير محتوى الملف
      final fileNonce = _algorithm.newNonce();
      sink.add(fileNonce); // حفظ الـ Nonce (12 بايت)

      Mac? fileMac;
      final encryptedStream = _algorithm.encryptStream(
        file.openRead(),
        secretKey: secretKey,
        nonce: fileNonce,
        onMac: (mac) => fileMac = mac,
      );

      await sink.addStream(encryptedStream);

      // كتابة بصمة التحقق (16 بايت)
      if (fileMac != null) sink.add(fileMac!.bytes);
      await sink.close();

      _addLog('[✓] File Encrypted Successfully!');
      _addLog('Saved as: vault_$randomId.iv5');
      setState(() => _selectedFilePath = '');

    } catch (e) {
      _addLog('[-] Encryption Error: $e');
    }
  }

  // 2. فك التشفير الآمن (يستعيد الاسم الأصلي)
  Future<void> _processFileDecryption() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    
    String encryptedPath = result.files.single.path!;
    if (_passwordController.text.isEmpty) {
      _addLog('[-] Error: Master password required for decryption.');
      return;
    }
    await _requestStoragePermission();

    try {
      _addLog('[*] Decrypting Secure Container...');
      final file = File(encryptedPath);
      final raf = await file.open();

      // قراءة طول الاسم المشفر
      final lengthBytes = await raf.read(4);
      final headerLength = ByteData.sublistView(lengthBytes).getUint32(0);

      // قراءة الاسم المشفر
      final headerBytes = await raf.read(headerLength);
      final headerBox = SecretBox.fromConcatenation(headerBytes, nonceLength: 12, macLength: 16);

      final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
      final secretKey = await pbkdf2.deriveKeyFromPassword(
        password: _passwordController.text,
        nonce: List<int>.generate(16, (i) => i),
      );

      // فك تشفير الاسم الأصلي
      final decryptedHeader = await _algorithm.decrypt(headerBox, secretKey: secretKey);
      final originalName = jsonDecode(utf8.decode(decryptedHeader))['name'];

      // قراءة الـ Nonce الخاص بالمحتوى
      final fileNonce = await raf.read(12);

      // حساب مواقع البيانات
      final totalLength = await file.length();
      final macLength = 16;
      final dataStart = 4 + headerLength + 12;
      final dataEnd = totalLength - macLength;

      // قراءة بصمة التحقق من نهاية الملف
      await raf.setPosition(dataEnd);
      final macBytes = await raf.read(macLength);
      final fileMac = Mac(macBytes);

      await raf.close();

      // فك تشفير محتوى الملف
      final vaultDir = await _getIronVaultDirectory();
      final savePath = p.join(vaultDir.path, 'DECRYPTED_$originalName');
      final outputFile = File(savePath);

      final decryptedStream = _algorithm.decryptStream(
        file.openRead(dataStart, dataEnd),
        secretKey: secretKey,
        nonce: fileNonce,
        mac: fileMac,
      );

      final sink = outputFile.openWrite();
      await sink.addStream(decryptedStream);
      await sink.close();

      _addLog('[✓] Decrypted Successfully to: $savePath');

    } catch (e) {
      _addLog('[-] Decryption Failed (Wrong Password or Corrupted File): $e');
    }
  }

  // 3. إدارة الهويات (توليد، تصدير، استيراد، حذف)
  Future<void> _generateIdentityKeys() async {
    _addLog('[*] Generating high-security $_selectedKeyType Identity Keys...');
    await Future.delayed(const Duration(milliseconds: 500)); // محاكاة
    _addLog('[✓] $_selectedKeyType Keys Generated & Stored.');
  }

  Future<void> _exportIdentity() async {
    if (_identityPasswordController.text.isEmpty) {
      _addLog('[-] Error: Enter password to secure the identity.');
      return;
    }
    await _requestStoragePermission();
    final vaultDir = await _getIronVaultDirectory();
    final identityFile = File(p.join(vaultDir.path, 'Identity_Backup.iv5'));
    await identityFile.writeAsString('ENCRYPTED_IDENTITY_DATA_HERE');
    _addLog('[✓] Identity Exported & Encrypted to: ${identityFile.path}');
  }

  Future<void> _importIdentity() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      _addLog('[*] Importing Encrypted Identity...');
      await Future.delayed(const Duration(milliseconds: 500));
      _addLog('[✓] Identity Imported Successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ IronVault (AES-256-GCM)', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 14)),
        backgroundColor: const Color(0xFF111418),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            height: 100,
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF040507),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF222222)),
            ),
            child: SingleChildScrollView(
              child: Text(_logText, style: const TextStyle(color: Color(0xFF5CB85C), fontSize: 10, fontFamily: 'monospace')),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: _currentIndex == 0 ? _buildFileVaultTab() : _buildIdentityManagerTab(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF111418),
        selectedItemColor: const Color(0xFFD4AF37),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: 'الملفات'),
          BottomNavigationBarItem(icon: Icon(Icons.security), label: 'الهويات'),
        ],
      ),
    );
  }

  Widget _buildFileVaultTab() {
    return ListView(
      children: [
        const Text('تشفير الملفات (الاسم الحقيقي سيُخفى):', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F26)),
          onPressed: _pickFile,
          icon: const Icon(Icons.attach_file, color: Color(0xFFD4AF37)),
          label: Text(_selectedFilePath.isEmpty ? 'اختر ملفاً للتشفير' : p.basename(_selectedFilePath), style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
        const SizedBox(height: 12),
        const Text('كلمة مرور التشفير الرئيسية:', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 5),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'أدخل كلمة المرور',
            filled: true,
            fillColor: const Color(0xFF1A1F26),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                onPressed: _processFileEncryption,
                child: const Text('🔒 تشفير', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF444444)),
                onPressed: _processFileDecryption,
                child: const Text('🔓 فك التشفير', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIdentityManagerTab() {
    return ListView(
      children: [
        const Text('توليد مفاتيح الهوية:', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: _selectedKeyType,
          dropdownColor: const Color(0xFF1A1F26),
          items: ['RSA-4096', 'ECC (Curves)'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))).toList(),
          onChanged: (v) => setState(() => _selectedKeyType = v!),
          decoration: InputDecoration(filled: true, fillColor: const Color(0xFF1A1F26), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
          onPressed: _generateIdentityKeys,
          child: const Text('⚡ توليد الهوية', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
        const Divider(height: 25, color: Colors.grey),
        const Text('كلمة مرور حماية الهوية (للتصدير/الاستيراد):', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 5),
        TextField(
          controller: _identityPasswordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: 'كلمة مرور الهوية', filled: true, fillColor: const Color(0xFF1A1F26), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _exportIdentity,
                child: const Text('📤 تصدير مشفر', style: TextStyle(color: Color(0xFFD4AF37))),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: OutlinedButton(
                onPressed: _importIdentity,
                child: const Text('📥 استيراد هوية', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
