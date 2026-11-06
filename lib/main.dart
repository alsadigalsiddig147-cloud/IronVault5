import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
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
  String _selectedCarrierPath = '';
  bool _enableDoD = false; // خيار المسح العسكري
  String _logText = '[*] Iron Vault Core V10.0 (Steganography + DoD) Ready.\n';

  final _algorithm = AesGcm.with256bits();
  static const _platform = MethodChannel('com.ironvault.app/native');

  void _addLog(String msg) {
    setState(() => _logText += '\n$msg');
  }

  // توليد اسم عشوائي 32 حرفاً
  String _generateRandomName() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(32, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _requestStoragePermission() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<Directory> _getIronVaultDirectory() async {
    Directory downloadsDir = Directory('/storage/emulated/0/Download');
    if (!await downloadsDir.exists()) downloadsDir = Directory('/storage/emulated/0/Downloads');
    final vaultDir = Directory(p.join(downloadsDir.path, 'IronVault'));
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
    return vaultDir;
  }

  // دالة التمزيق العسكري عبر C++
  Future<void> _secureWipe(String path) async {
    if (!_enableDoD) return;
    try {
      await _platform.invokeMethod('nativeWipe', {'path': path});
      _addLog('[✓] Original file securely wiped (DoD 7-Pass).');
    } catch (e) {
      _addLog('[-] Wipe failed: $e');
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
    return await pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
  }

  // --- 1. التشفير القياسي (ملفات) ---
  Future<void> _encryptFile() async {
    if (_selectedFilePath.isEmpty || _passwordController.text.isEmpty) return;
    await _requestStoragePermission();

    try {
      _addLog('[*] Encrypting file with Smart Streaming...');
      final file = File(_selectedFilePath);
      final originalName = p.basename(_selectedFilePath);
      final vaultDir = await _getIronVaultDirectory();
      
      final randomName = _generateRandomName();
      final savePath = p.join(vaultDir.path, '$randomName.iron');
      final outputFile = File(savePath);

      final salt = _algorithm.newNonce();
      final secretKey = await _deriveKey(_passwordController.text, salt);

      final headerData = utf8.encode(jsonEncode({'name': originalName}));
      final headerBox = await _algorithm.encrypt(headerData, secretKey: secretKey);
      
      final sink = outputFile.openWrite();
      sink.add(salt); // 12 bytes
      final headerBytes = headerBox.concatenation();
      final headerLengthBytes = ByteData(4)..setUint32(0, headerBytes.length);
      sink.add(headerLengthBytes.buffer.asUint8List());
      sink.add(headerBytes);

      final fileNonce = _algorithm.newNonce();
      sink.add(fileNonce);
      Mac? fileMac;

      final encryptedStream = _algorithm.encryptStream(
        file.openRead(),
        secretKey: secretKey,
        nonce: fileNonce,
        onMac: (mac) => fileMac = mac,
      );

      await sink.addStream(encryptedStream);
      if (fileMac != null) sink.add(fileMac!.bytes);
      await sink.close();

      _addLog('[✓] Encrypted Successfully! Saved as: $randomName.iron');
      await _secureWipe(_selectedFilePath); // مسح الملف الأصلي إذا تم تفعيل DoD
      setState(() => _selectedFilePath = '');

    } catch (e) {
      _addLog('[-] Encryption Error: $e');
    }
  }

  // --- 2. فك التشفير (التلقائي للملفات أو الوسائط) ---
  Future<void> _decryptFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    String encryptedPath = result.files.single.path!;

    if (_passwordController.text.isEmpty) {
      _addLog('[-] Error: Password required.');
      return;
    }
    await _requestStoragePermission();

    try {
      _addLog('[*] Analyzing File for Decryption...');
      final file = File(encryptedPath);
      final raf = await file.open();
      final totalLength = await file.length();

      // فحص إذا كان الملف صورة/فيديو/صوت مخفي (Stego) أو ملف iron عادي
      bool isStego = false;
      int stegoOffset = 0;
      
      // البحث عن التوقيع السري في نهاية الملف
      final magicBytes = utf8.encode('IRON_STEGO_MAGIC');
      final searchLength = min(totalLength, 1024 * 1024); // فحص آخر 1 ميجا
      await raf.setPosition(totalLength - searchLength);
      final tailBytes = await raf.read(searchLength);
      
      final index = _indexOf(tailBytes, magicBytes);
      if (index != -1) {
        isStego = true;
        stegoOffset = totalLength - searchLength + index + magicBytes.length;
        _addLog('[+] Steganography detected in media file.');
      } else {
        stegoOffset = 0; // ملف iron عادي
      }

      await raf.setPosition(stegoOffset);
      
      final salt = await raf.read(12);
      final secretKey = await _deriveKey(_passwordController.text, salt);

      final lengthBytes = await raf.read(4);
      final headerLength = ByteData.sublistView(lengthBytes).getUint32(0);
      final headerBytes = await raf.read(headerLength);
      final headerBox = SecretBox.fromConcatenation(headerBytes, nonceLength: 12, macLength: 16);
      
      final decryptedHeader = await _algorithm.decrypt(headerBox, secretKey: secretKey);
      final originalName = jsonDecode(utf8.decode(decryptedHeader))['name'];

      final fileNonce = await raf.read(12);
      final macLength = 16;
      
      final dataStart = stegoOffset + 12 + 4 + headerLength + 12;
      final dataEnd = totalLength - macLength;

      await raf.setPosition(dataEnd);
      final macBytes = await raf.read(macLength);
      await raf.close();

      final vaultDir = await _getIronVaultDirectory();
      final savePath = p.join(vaultDir.path, 'RESTORED_$originalName');
      final outputFile = File(savePath);

      final decryptedStream = _algorithm.decryptStream(
        file.openRead(dataStart, dataEnd),
        secretKey: secretKey,
        nonce: fileNonce,
        mac: Mac(macBytes),
      );

      final sink = outputFile.openWrite();
      await sink.addStream(decryptedStream);
      await sink.close();

      _addLog('[✓] Restored 100% to: $savePath');

    } catch (e) {
      _addLog('[-] Decryption Failed: Wrong Password or Corrupted.');
    }
  }

  // --- 3. الإخفاء في الصور/الفيديو/MP3 (Steganography) ---
  Future<void> _hideFileInMedia() async {
    if (_selectedCarrierPath.isEmpty || _selectedFilePath.isEmpty || _passwordController.text.isEmpty) {
      _addLog('[-] Error: Carrier, File, and Password are required.');
      return;
    }
    await _requestStoragePermission();

    try {
      _addLog('[*] Hiding encrypted file into media (Steganography)...');
      final carrierFile = File(_selectedCarrierPath);
      final secretFile = File(_selectedFilePath);
      final originalName = p.basename(_selectedFilePath);
      final vaultDir = await _getIronVaultDirectory();
      
      final randomName = _generateRandomName();
      final ext = p.extension(_selectedCarrierPath);
      final savePath = p.join(vaultDir.path, '$randomName$ext');
      final outputFile = File(savePath);

      // 1. نسخ ملف الوسائط الأصلي (الصورة/الفيديو) كما هو
      await carrierFile.copy(savePath);

      // 2. إضافة علامة سحرية في النهاية
      final sink = outputFile.openWrite(mode: FileMode.append);
      sink.add(utf8.encode('IRON_STEGO_MAGIC'));

      // 3. تشفير وإضافة الملف السري بنفس الطريقة القياسية
      final salt = _algorithm.newNonce();
      final secretKey = await _deriveKey(_passwordController.text, salt);
      sink.add(salt);

      final headerData = utf8.encode(jsonEncode({'name': originalName}));
      final headerBox = await _algorithm.encrypt(headerData, secretKey: secretKey);
      final headerBytes = headerBox.concatenation();
      
      final headerLengthBytes = ByteData(4)..setUint32(0, headerBytes.length);
      sink.add(headerLengthBytes.buffer.asUint8List());
      sink.add(headerBytes);

      final fileNonce = _algorithm.newNonce();
      sink.add(fileNonce);
      Mac? fileMac;

      final encryptedStream = _algorithm.encryptStream(
        secretFile.openRead(),
        secretKey: secretKey,
        nonce: fileNonce,
        onMac: (mac) => fileMac = mac,
      );

      await sink.addStream(encryptedStream);
      if (fileMac != null) sink.add(fileMac!.bytes);
      await sink.close();

      _addLog('[✓] File hidden inside media! Saved as: $randomName$ext');
      _addLog('[*] The media file remains fully playable/viewable.');
      
      await _secureWipe(_selectedFilePath); // مسح الملف السري إذا تم تفعيل DoD
      setState(() => _selectedFilePath = '');

    } catch (e) {
      _addLog('[-] Steganography Error: $e');
    }
  }

  int _indexOf(List<int> source, List<int> pattern) {
    for (int i = source.length - pattern.length; i >= 0; i--) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  // --- 4. الهويات (RSA + ECC) ---
  Future<void> _generateIdentities() async {
    _addLog('[*] Generating RSA-4096 and ECC keys...');
    final rsa = RsaPss.sha256();
    final rsaPair = await rsa.newKeyPair();
    
    final ecc = Ecdsa.p256(Sha256());
    final eccPair = await ecc.newKeyPair();

    final rsaPub = await rsaPair.extractPublicKey();
    final eccPub = await eccPair.extractPublicKey();
    
    // دمج المفاتيح في مصفوفة واحدة مشفرة
    final bundle = jsonEncode({
      'rsa': rsaPub.toString(),
      'ecc': eccPub.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    });

    final vaultDir = await _getIronVaultDirectory();
    final randomName = _generateRandomName();
    final savePath = p.join(vaultDir.path, '$randomName.iron');
    
    final salt = _algorithm.newNonce();
    final secretKey = await _deriveKey(
      _identityPasswordController.text.isNotEmpty ? _identityPasswordController.text : 'default', 
      salt
    );
    
    final encryptedBundle = await _algorithm.encrypt(utf8.encode(bundle), secretKey: secretKey);
    
    final finalFile = File(savePath);
    final sink = finalFile.openWrite();
    sink.add(salt);
    sink.add(encryptedBundle.concatenation());
    await sink.close();

    _addLog('[✓] Hybrid Identity Bundle Saved: $randomName.iron');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ IronVault V10 (Military Grade)', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 14)),
        backgroundColor: const Color(0xFF111418),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            height: 110,
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
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildFileVaultTab(),
                  _buildSteganographyTab(),
                  _buildIdentityManagerTab(),
                ],
              ),
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
          BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: 'تشفير الملفات'),
          BottomNavigationBarItem(icon: Icon(Icons.image), label: 'إخفاء في الوسائط'),
          BottomNavigationBarItem(icon: Icon(Icons.security), label: 'الهويات'),
        ],
      ),
    );
  }

  Widget _buildFileVaultTab() {
    return ListView(
      children: [
        const Text('تشفير الملفات (توليد اسم عشوائي 32 حرف):', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F26)),
          onPressed: () async {
            final r = await FilePicker.platform.pickFiles();
            if (r != null) setState(() => _selectedFilePath = r.files.single.path!);
          },
          icon: const Icon(Icons.attach_file, color: Color(0xFFD4AF37)),
          label: Text(_selectedFilePath.isEmpty ? 'اختر ملفاً' : p.basename(_selectedFilePath), style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
        const SizedBox(height: 12),
        _buildPasswordField(),
        const SizedBox(height: 10),
        _buildDoDSwitch(),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)), onPressed: _encryptFile, child: const Text('🔒 تشفير', style: TextStyle(color: Colors.black)))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF444444)), onPressed: _decryptFile, child: const Text('🔓 فك التشفير', style: TextStyle(color: Colors.white)))),
          ],
        ),
      ],
    );
  }

  Widget _buildSteganographyTab() {
    return ListView(
      children: [
        const Text('إخفاء ملف مشفر داخل صورة/فيديو/MP3:', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F26)),
          onPressed: () async {
            final r = await FilePicker.platform.pickFiles();
            if (r != null) setState(() => _selectedCarrierPath = r.files.single.path!);
          },
          icon: const Icon(Icons.image, color: Color(0xFFD4AF37)),
          label: Text(_selectedCarrierPath.isEmpty ? 'اختر صورة/فيديو/MP3 (الغطاء)' : p.basename(_selectedCarrierPath), style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F26)),
          onPressed: () async {
            final r = await FilePicker.platform.pickFiles();
            if (r != null) setState(() => _selectedFilePath = r.files.single.path!);
          },
          icon: const Icon(Icons.attach_file, color: Color(0xFFD4AF37)),
          label: Text(_selectedFilePath.isEmpty ? 'اختر الملف السري' : p.basename(_selectedFilePath), style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
        const SizedBox(height: 12),
        _buildPasswordField(),
        const SizedBox(height: 10),
        _buildDoDSwitch(),
        const SizedBox(height: 15),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
          onPressed: _hideFileInMedia,
          child: const Text('🕵️ إخفاء وتشفير داخل الوسائط', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildIdentityManagerTab() {
    return ListView(
      children: [
        const Text('توليد هوية هجينة (RSA-4096 + ECC):', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 10),
        TextField(
          controller: _identityPasswordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: 'كلمة سر لحماية الهوية', filled: true, fillColor: const Color(0xFF1A1F26), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
        ),
        const SizedBox(height: 15),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
          onPressed: _generateIdentities,
          child: const Text('⚡ توليد وتصدير الهوية', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(hintText: 'كلمة المرور', filled: true, fillColor: const Color(0xFF1A1F26), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
    );
  }

  Widget _buildDoDSwitch() {
    return SwitchListTile(
      title: const Text('مسح عسكري آمن DoD 7-Pass للملف الأصلي', style: TextStyle(color: Colors.white70, fontSize: 12)),
      value: _enableDoD,
      activeColor: const Color(0xFFD4AF37),
      onChanged: (val) => setState(() => _enableDoD = val),
    );
  }
}
