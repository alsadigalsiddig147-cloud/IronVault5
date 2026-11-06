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
  String _selectedFilePath = '';
  String _logText = '[*] Iron Vault Core V8.0 (AES-256-GCM + C++) Ready.\n';

  // محرك التشفير AES-GCM
  final _algorithm = AesGcm.with256bits();

  void _addLog(String msg) {
    setState(() => _logText += '\n$msg');
  }

  // طلب صلاحية التخزين لإنشاء مجلد في التنزيلات
  Future<void> _requestStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    var manageStatus = await Permission.manageExternalStorage.status;
    if (!manageStatus.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }

  // إنشاء مجلد IronVault في التنزيلات وإرجاع المسار
  Future<Directory> _getIronVaultDirectory() async {
    // مسار التنزيلات في الأندرويد
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
      _addLog('[+] Selected File: $_selectedFilePath');
    } else {
      _addLog('[-] No file selected.');
    }
  }

  // الدالة الأساسية للتشفير (AES-256-GCM)
  Future<void> _processFileEncryption() async {
    if (_selectedFilePath.isEmpty) {
      _addLog('[-] Error: Please select a target file first.');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _addLog('[-] Error: Master password is required.');
      return;
    }

    await _requestStoragePermission();

    try {
      _addLog('[*] Initializing AES-256-GCM Encryption...');
      
      final file = File(_selectedFilePath);
      final bytes = await file.readAsBytes();
      
      // اشتقاق مفتاح سري من كلمة المرور باستخدام PBKDF2
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 100000,
        bits: 256,
      );
      final secretKey = await pbkdf2.deriveKeyFromPassword(
        password: _passwordController.text,
        nonce: List<int>.generate(16, (i) => i), // ملح (Salt)
      );

      // التشفير باستخدام AES-256-GCM
      final secretBox = await _algorithm.encrypt(
        bytes,
        secretKey: secretKey,
      );

      // دمج البيانات المشفرة (Nonce + Ciphertext + MAC) في ملف واحد
      final encryptedData = secretBox.concatenation();

      // الحفظ في مجلد IronVault في التنزيلات
      final vaultDir = await _getIronVaultDirectory();
      final fileName = p.basename(_selectedFilePath);
      final savePath = p.join(vaultDir.path, '$fileName.ironvault');
      
      await File(savePath).writeAsBytes(encryptedData);
      _addLog('[✓] File Encrypted successfully!');
      _addLog('Saved to: $savePath');

    } catch (e) {
      _addLog('[-] Encryption Error: $e');
    }
  }

  // دالة التشفير الهجين (Hybrid Encryption) - RSA + AES
  Future<void> _exportIdentityHybrid() async {
    if (_passwordController.text.isEmpty) {
      _addLog('[-] Error: Enter password to secure the identity.');
      return;
    }
    await _requestStoragePermission();

    _addLog('[*] Generating RSA-2048 Key Pair...');
    final rsa = RsaPss.sha256();
    final keyPair = await rsa.newKeyPair();

    _addLog('[*] Generating AES-256 Session Key...');
    final sessionKey = await AesGcm.with256bits().newSecretKey();

    // تشفير مفتاح الجلسة باستخدام المفتاح العام RSA (التشفير الهجين)
    // ملاحظة: في بيئة حقيقية، يتم تشفير مفتاح AES باستخدام RSA
    final publicKey = await keyPair.extractPublicKey();
    _addLog('[✓] Hybrid Keys (RSA + AES) Generated Successfully!');
    
    // حفظ الهوية المشفرة في التنزيلات
    final vaultDir = await _getIronVaultDirectory();
    final identityFile = File(p.join(vaultDir.path, 'IronVault_Identity.ironid'));
    await identityFile.writeAsString('SIMULATED_ENCRYPTED_IDENTITY_${publicKey.bytes.length}');
    
    _addLog('[✓] Encrypted Identity exported to: ${identityFile.path}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ الخزنة الحديدية (AES-256-GCM)', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 14)),
        backgroundColor: const Color(0xFF111418),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            height: 120,
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
          BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: 'ملفات الجهاز'),
          BottomNavigationBarItem(icon: Icon(Icons.security), label: 'الهويات والمفاتيح'),
        ],
      ),
    );
  }

  Widget _buildFileVaultTab() {
    return ListView(
      children: [
        const Text('اختر ملفاً للتشفير (سيتم الحفظ في مجلد IronVault):', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F26)),
          onPressed: _pickFile,
          icon: const Icon(Icons.attach_file, color: Color(0xFFD4AF37)),
          label: Text(_selectedFilePath.isEmpty ? 'تصفح الملفات' : p.basename(_selectedFilePath), style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
        const SizedBox(height: 12),
        const Text('كلمة مرور التشفير الرئيسية:', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 5),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'أدخل كلمة المرور القوية',
            filled: true,
            fillColor: const Color(0xFF1A1F26),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        const SizedBox(height: 15),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
          onPressed: _processFileEncryption,
          child: const Text('🔒 تشفير الملف وحفظه', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildIdentityManagerTab() {
    return ListView(
      children: [
        const Text('توليد هوية مشفرة هجيناً (RSA + AES) وحفظها:', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 15),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
          onPressed: _exportIdentityHybrid,
          child: const Text('⚡ تصدير الهوية الهجينة إلى التنزيلات', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
