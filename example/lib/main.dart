import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vault_kit/vault_kit.dart';

void main() => runApp(const VaultKitExampleApp());

class VaultKitExampleApp extends StatelessWidget {
  const VaultKitExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VaultKit Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const VaultKitExampleScreen(),
    );
  }
}

class VaultKitExampleScreen extends StatefulWidget {
  const VaultKitExampleScreen({super.key});

  @override
  State<VaultKitExampleScreen> createState() => _VaultKitExampleScreenState();
}

class _VaultKitExampleScreenState extends State<VaultKitExampleScreen> {
  final _vault = VaultKit();

  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();

  String _log = 'Logs will appear here...';
  bool _hasToken = false;
  bool _hasPassword = false;

  @override
  void initState() {
    super.initState();
    _checkStoredValues();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
  // 🔍 Check stored values on launch
  // -------------------------------------------------------

  Future<void> _checkStoredValues() async {
    final hasToken = await _vault.has(key: 'auth_token');
    final hasPassword = await _vault.has(key: 'user_password');
    setState(() {
      _hasToken = hasToken;
      _hasPassword = hasPassword;
    });
  }

  // -------------------------------------------------------
  // 💾 Save
  // -------------------------------------------------------

  Future<void> _saveToken() async {
    final value = _tokenController.text.trim();
    if (value.isEmpty) {
      _appendLog('❌ Token field is empty');
      return;
    }
    try {
      await _vault.save(key: 'auth_token', value: value);
      _appendLog('✅ Token saved successfully');
      _tokenController.clear();
      await _checkStoredValues();
    } on PlatformException catch (e) {
      _appendLog('❌ [${e.code}] ${e.message}');
    }
  }

  Future<void> _savePassword() async {
    final value = _passwordController.text.trim();
    if (value.isEmpty) {
      _appendLog('❌ Password field is empty');
      return;
    }
    try {
      await _vault.save(key: 'user_password', value: value);
      _appendLog('✅ Password saved successfully');
      _passwordController.clear();
      await _checkStoredValues();
    } on PlatformException catch (e) {
      _appendLog('❌ [${e.code}] ${e.message}');
    }
  }

  // -------------------------------------------------------
  // 📦 Fetch
  // -------------------------------------------------------

  Future<void> _fetchToken() async {
    try {
      final token = await _vault.fetch<String>(key: 'auth_token');
      _appendLog(token != null ? '🔓 Token: $token' : '⚠️ No token stored');
    } on PlatformException catch (e) {
      _appendLog('❌ [${e.code}] ${e.message}');
    }
  }

  Future<void> _fetchPassword() async {
    try {
      final password = await _vault.fetch<String>(key: 'user_password');
      _appendLog(password != null
          ? '🔓 Password: $password'
          : '⚠️ No password stored');
    } on PlatformException catch (e) {
      _appendLog('❌ [${e.code}] ${e.message}');
    }
  }

  // -------------------------------------------------------
  // 🗑 Delete
  // -------------------------------------------------------

  Future<void> _deleteToken() async {
    try {
      await _vault.delete(key: 'auth_token');
      _appendLog('🗑 Token deleted');
      await _checkStoredValues();
    } on PlatformException catch (e) {
      _appendLog('❌ [${e.code}] ${e.message}');
    }
  }

  Future<void> _deletePassword() async {
    try {
      await _vault.delete(key: 'user_password');
      _appendLog('🗑 Password deleted');
      await _checkStoredValues();
    } on PlatformException catch (e) {
      _appendLog('❌ [${e.code}] ${e.message}');
    }
  }

  // -------------------------------------------------------
  // 🧹 Clear All
  // -------------------------------------------------------

  Future<void> _clearAll() async {
    try {
      await _vault.clearAll();
      _appendLog('🧹 All credentials cleared');
      await _checkStoredValues();
    } on PlatformException catch (e) {
      _appendLog('❌ [${e.code}] ${e.message}');
    }
  }

  // -------------------------------------------------------
  // 🛠 Helpers
  // -------------------------------------------------------

  void _appendLog(String message) {
    setState(() {
      _log =
          '${DateTime.now().toLocal().toString().substring(11, 19)} — $message\n$_log';
    });
  }

  // -------------------------------------------------------
  // 🎨 UI
  // -------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔐 VaultKit Example'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Token Section ──
            _SectionCard(
              title: '🪙 Auth Token',
              stored: _hasToken,
              child: Column(
                children: [
                  TextField(
                    controller: _tokenController,
                    decoration: const InputDecoration(
                      labelText: 'Enter token',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.token),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saveToken,
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _fetchToken,
                          icon: const Icon(Icons.download),
                          label: const Text('Fetch'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _deleteToken,
                        icon: const Icon(Icons.delete),
                        color: Colors.white,
                        style:
                            IconButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Password Section ──
            _SectionCard(
              title: '🔑 User Password',
              stored: _hasPassword,
              child: Column(
                children: [
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Enter password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _savePassword,
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _fetchPassword,
                          icon: const Icon(Icons.download),
                          label: const Text('Fetch'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _deletePassword,
                        icon: const Icon(Icons.delete),
                        color: Colors.white,
                        style:
                            IconButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Clear All ──
            FilledButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear All — Simulate Logout'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 24),

            // ── Log Output ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '📋 Logs',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _log = 'Logs cleared.'),
                        child: const Text(
                          'Clear logs',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _log,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------
// 🎨 Section Card Widget
// -------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final bool stored;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.stored,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        stored ? Colors.green.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    stored ? '✅ Stored' : '⚪ Empty',
                    style: TextStyle(
                      fontSize: 12,
                      color: stored ? Colors.green.shade800 : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
