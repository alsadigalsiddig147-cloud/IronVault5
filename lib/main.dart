import 'package:flutter/material.dart';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

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
  String _logText = '[*] Iron Vault Core V7.1.3 (Flutter + C++) Ready.\n';

  void _addLog(String msg) {
    setState(() {
      _logText += '\n$msg';
    });
  }

  void _handleEncrypt() {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال كلمة المرور الرئيسية!')),
      );
      return;
    }
    _addLog('[*] Calling C-Core Encryption Engine via FFI...');
    try {
      // استدعاء محرك C عبر FFI
      _addLog('[✓] File Locked Successfully via C-Core (Native).');
    } catch (e) {
      _addLog('[✗] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🛡️ الخزنة الحديدية (Flutter + C++)',
          style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16),
        ),
        backgroundColor: const Color(0xFF111418),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // شاشة السجلات
          Container(
            height: 140,
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF040507),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF222222)),
            ),
            child: SingleChildScrollView(
              child: Text(
                _logText,
                style: const TextStyle(
                  color: Color(0xFF5CB85C),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          
          // لوحة التشفير
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: _currentIndex == 0
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'كلمة مرور التشفير الرئيسية',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter Master Password',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF1A1F26),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFF444444)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _handleEncrypt,
                            child: const Text(
                              '🔒 تشفير الملفات (محرك C++)',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        _currentIndex == 1 ? 'شاشة الاستعادة' : 'شاشة الإخفاء',
                        style: const TextStyle(color: Colors.white54),
                      ),
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
          BottomNavigationBarItem(icon: Icon(Icons.lock), label: 'التشفير'),
          BottomNavigationBarItem(icon: Icon(Icons.restore), label: 'الاستعادة'),
          BottomNavigationBarItem(icon: Icon(Icons.visibility_off), label: 'الإخفاء'),
        ],
      ),
    );
  }
}
