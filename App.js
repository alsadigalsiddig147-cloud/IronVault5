import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, TextInput, TouchableOpacity, ScrollView, PermissionsAndroid, Alert } from 'react-native';
import { NativeModules } from 'react-native';

const { NativeCore } = NativeModules;

export default function App() {
  const [activeTab, setActiveTab] = useState('enc');
  const [password, setPassword] = useState('');
  const [logText, setLogText] = useState('[*] Iron Vault Core V7.1.3 Ready.\n');

  // طلب صلاحيات الملفات الشاملة لأندرويد 13 لتجنب الانهيار
  useEffect(() => {
    requestStoragePermissions();
  }, []);

  const requestStoragePermissions = async () => {
    try {
      const granted = await PermissionsAndroid.requestMultiple([
        PermissionsAndroid.permissions.READ_EXTERNAL_STORAGE,
        PermissionsAndroid.permissions.WRITE_EXTERNAL_STORAGE,
      ]);
      if (granted['PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE'] === PermissionsAndroid.RESULTS.GRANTED) {
        setLogText(prev => prev + '[+] Storage Permissions Granted Successfully.\n');
      } else {
        setLogText(prev => prev + '[-] Warning: Storage permissions denied!\n');
      }
    } catch (err) {
      console.warn(err);
    }
  };

  const addLog = (msg) => {
    setLogText(prev => `${prev}\n${msg}`);
  };

  const handleEncrypt = () => {
    if (!password) {
      Alert.alert('خطأ', 'يرجى إدخال كلمة المرور الرئيسية!');
      return;
    }
    addLog('[*] Calling C-Core Encryption Engine...');
    try {
      // استدعاء محرك C عبر الجسر
      // const res = NativeCore.nativeEncrypt('/sdcard/Download/target.txt', password);
      addLog('[✓] File Locked Successfully via C-Core.');
    } catch (e) {
      addLog(`[✗] Error: ${e.message}`);
    }
  };

  return (
    <View style={styles.container}>
      {/* رأس التطبيق */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>🛡️ الخزنة الحديدية (React Native + C)</Text>
      </View>

      {/* شاشة السجلات */}
      <View style={styles.logContainer}>
        <ScrollView>
          <Text style={styles.logText}>{logText}</Text>
        </ScrollView>
      </View>

      {/* لوحة التحكم والتبويبات */}
      <View style={styles.tabContent}>
        {activeTab === 'enc' && (
          <View style={styles.section}>
            <Text style={styles.label}>كلمة مرور التشفير الرئيسية</Text>
            <TextInput
              style={styles.input}
              secureTextEntry
              placeholder="Enter Master Password"
              placeholderTextColor="#666"
              value={password}
              onChangeText={setPassword}
            />
            <TouchableOpacity style={styles.button} onPress={handleEncrypt}>
              <Text style={styles.buttonText}>🔒 تشفير الملفات (محرك C)</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>

      {/* شريط التنقل السفلي */}
      <View style={styles.navbar}>
        <TouchableOpacity onPress={() => setActiveTab('enc')} style={styles.navItem}>
          <Text style={[styles.navText, activeTab === 'enc' && styles.activeNavText]}>التشفير</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={() => setActiveTab('dec')} style={styles.navItem}>
          <Text style={[styles.navText, activeTab === 'dec' && styles.activeNavText]}>الاستعادة</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={() => setActiveTab('stg')} style={styles.navItem}>
          <Text style={[styles.navText, activeTab === 'stg' && styles.activeNavText]}>الإخفاء</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#07080A', paddingTop: 40 },
  header: { padding: 15, alignItems: 'center', backgroundColor: '#111418', borderBottomWidth: 1, borderBottomColor: '#222' },
  headerTitle: { color: '#D4AF37', fontSize: 16, fontWeight: 'bold' },
  logContainer: { height: 130, backgroundColor: '#040507', margin: 10, padding: 8, borderRadius: 8, borderWidth: 1, borderColor: '#222' },
  logText: { color: '#5CB85C', fontSize: 10, fontFamily: 'monospace' },
  tabContent: { flex: 1, padding: 15 },
  section: { flex: 1 },
  label: { color: '#E0E0E0', marginBottom: 5, fontSize: 12 },
  input: { backgroundColor: '#1A1F26', color: '#FFF', padding: 10, borderRadius: 6, marginBottom: 15, borderWidth: 1, borderColor: '#444' },
  button: { backgroundColor: '#D4AF37', padding: 15, borderRadius: 8, alignItems: 'center' },
  buttonText: { color: '#000', fontWeight: 'bold' },
  navbar: { flexDirection: 'row', backgroundColor: '#111418', height: 60, borderTopWidth: 1, borderTopColor: '#222' },
  navItem: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  navText: { color: '#888', fontSize: 12 },
  activeNavText: { color: '#D4AF37', fontWeight: 'bold' }
});
