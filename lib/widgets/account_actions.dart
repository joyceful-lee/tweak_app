import 'package:flutter/material.dart';
import '../auth.dart';

Future<void> verifyEmailDialog(
  BuildContext context,
  String email, {
  bool restore = false,
}) async {
  final code = TextEditingController();
  String? error;
  bool busy = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(restore ? 'Restore your recipes' : 'Verify your email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the code sent to $email.'),
            if (restore)
              const Text(
                'This confirms ownership of your previous account and signs out other devices.',
              ),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Verification code'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      if (restore) {
                        await backend.request(
                          'POST',
                          'auth/email-otp/send-verification-otp',
                          body: {'email': email, 'type': 'sign-in'},
                        );
                      } else {
                        await sendVerificationCode(email);
                      }
                      if (context.mounted) {
                        setState(() => error = 'Code sent. Check your email.');
                      }
                    } catch (e) {
                      if (context.mounted) setState(() => error = e.toString());
                    } finally {
                      if (context.mounted) setState(() => busy = false);
                    }
                  },
            child: const Text('Send code'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      if (restore) {
                        await backend.request(
                          'POST',
                          'account/claim',
                          body: {'otp': code.text.trim()},
                        );
                        await backend.refreshSession();
                        backend.notifyAccountChanged();
                      } else {
                        await verifyEmailCode(email, code.text.trim());
                      }
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) setState(() => error = e.toString());
                    } finally {
                      if (context.mounted) setState(() => busy = false);
                    }
                  },
            child: Text(
              busy
                  ? 'Working…'
                  : restore
                  ? 'Restore recipes'
                  : 'Verify',
            ),
          ),
        ],
      ),
    ),
  );
  code.dispose();
}
