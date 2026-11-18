import 'package:flutter/material.dart';
import '../auth.dart';
import '../services/dish_service.dart';
import '../services/note_service.dart';
import '../services/export_service.dart';
import '../widgets/account_actions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _password() async {
    final old = TextEditingController(), next = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: old,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (save == true) {
      await _run(
        () => updatePassword(next.text, currentPassword: old.text),
        'Password updated.',
      );
    }
    old.dispose();
    next.dispose();
  }

  Future<void> _email() async {
    final email = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change email'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'New email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (save == true) {
      await _run(
        () => updateEmail(email.text.trim()),
        'Check your email to confirm the change.',
      );
    }
    email.dispose();
  }

  Future<void> _restore() async {
    await verifyEmailDialog(
      context,
      backend.currentUser?.email ?? '',
      restore: true,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Signed in as'),
          subtitle: Text(backend.currentUser?.email ?? ''),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.mark_email_read_outlined),
          title: const Text('Verify email'),
          subtitle: const Text(
            'Required to restore recipes from your previous account.',
          ),
          onTap: _busy
              ? null
              : () async {
                  await verifyEmailDialog(
                    context,
                    backend.currentUser?.email ?? '',
                  );
                  if (mounted) setState(() {});
                },
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Restore imported recipes'),
          subtitle: const Text(
            'Use the same verified email as your previous account.',
          ),
          onTap: _busy ? null : _restore,
        ),
        ListTile(
          leading: const Icon(Icons.email_outlined),
          title: const Text('Change email'),
          onTap: _busy ? null : _email,
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change password'),
          onTap: _busy ? null : _password,
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Export data'),
          onTap: _busy
              ? null
              : () => _run(
                  () => ExportService.exportAllData(
                    dishService: DishService(backend),
                    noteService: NoteService(backend),
                  ),
                  'Export prepared.',
                ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: _busy ? null : () => _run(signOut, 'Signed out.'),
        ),
        if (_busy) const LinearProgressIndicator(),
      ],
    ),
  );
}
