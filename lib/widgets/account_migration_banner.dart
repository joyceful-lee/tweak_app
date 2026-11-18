import 'package:flutter/material.dart';
import '../auth.dart';
import 'account_actions.dart';

class AccountMigrationBanner extends StatefulWidget {
  const AccountMigrationBanner({super.key});
  @override
  State<AccountMigrationBanner> createState() => _AccountMigrationBannerState();
}

class _AccountMigrationBannerState extends State<AccountMigrationBanner> {
  late Future<dynamic> _status;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _status = backend.request('GET', 'account');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _status,
    builder: (context, snapshot) {
      if (!snapshot.hasData || snapshot.data['restoreAvailable'] != true) {
        return const SizedBox.shrink();
      }
      final verified = snapshot.data['emailVerified'] == true;
      return MaterialBanner(
        content: Text(
          verified
              ? 'Your previous recipes are ready to restore.'
              : 'Verify your email to restore your previous recipes.',
        ),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await verifyEmailDialog(
                        context,
                        backend.currentUser?.email ?? '',
                        restore: true,
                      );
                      if (mounted) {
                        setState(() => _status = backend.request('GET', 'account'));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(
              _busy
                  ? 'Working…'
                  : verified
                  ? 'Restore recipes'
                  : 'Verify email',
            ),
          ),
        ],
      );
    },
  );
}
