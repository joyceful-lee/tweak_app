import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth.dart';
import '../services/dish_service.dart';
import '../services/note_service.dart';
import '../services/export_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _changeEmail(BuildContext context) async {
    final controller = TextEditingController();
    final newEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Email"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "New Email"),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text("Update")),
        ],
      ),
    );

    if (newEmail != null && newEmail.isNotEmpty) {
      try {
        await updateEmail(newEmail);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Email update initiated. Check your inbox.")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "New Password"),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text("Update")),
        ],
      ),
    );

    if (newPassword != null && newPassword.isNotEmpty) {
      try {
        await updatePassword(newPassword);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Password updated successfully.")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "WARNING: This action is permanent and cannot be undone. All your data will be lost.",
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete Everything"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await deleteAccount();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              title: const Text("Logged in as"),
              subtitle: Text(user.email ?? "Unknown"),
              leading: const Icon(Icons.person_outline),
            ),
          const Divider(),
          ListTile(
            title: const Text("Change Email"),
            leading: const Icon(Icons.email_outlined),
            onTap: () => _changeEmail(context),
          ),
          ListTile(
            title: const Text("Change Password"),
            leading: const Icon(Icons.lock_outline),
            onTap: () => _changePassword(context),
          ),
          ListTile(
            title: const Text("Export Data"),
            leading: const Icon(Icons.download_outlined),
            onTap: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Preparing export...")),
                );
                final supabase = Supabase.instance.client;
                await ExportService.exportAllData(
                  dishService: DishService(supabase),
                  noteService: NoteService(supabase),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Export failed: $e")),
                  );
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            title: const Text("Logout"),
            leading: const Icon(Icons.logout),
            onTap: () => signOut(),
          ),
          ListTile(
            title: const Text("Delete Account"),
            textColor: Colors.red,
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () => _handleDeleteAccount(context),
          ),
        ],
      ),
    );
  }
}
