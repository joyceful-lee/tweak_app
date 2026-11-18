import 'dart:ui'; // for ImageFilter.blur
import 'package:flutter/material.dart';
import '../auth.dart';
import 'reset_password_screen.dart';
import '../widgets/account_actions.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLogin = true; // toggle between login and signup
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// ------------------------------
  /// TODO: didn't complete yet
  /// ------------------------------
  Future<void> _forgotPassword() async {
    final email = emailController.text.trim();

    if (!_isValidEmail(email)) {
      setState(() => error = 'Enter a valid email address first.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await sendPasswordResetEmail(email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("A password reset code was requested for $email"),
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => error = 'Unable to send the reset email. Please try again.',
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> handleAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (!_isValidEmail(email)) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }

    if (password.isEmpty) {
      setState(() => error = 'Enter your password.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (isLogin) {
        await signIn(email, password);
      } else {
        await signUp(email, password);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Account created! Check your email if verification is enabled.",
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await signInWithGoogle();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'Google sign-in could not be started. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _BackgroundDecoration(imagePath: 'assets/images/login_bg.jpg'),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _LoginHeader(isLogin: isLogin),

                  const SizedBox(height: 24),

                  Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.onPrimary.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Returning after the update? Create a new login using your previous email, then restore your recipes in Settings.'),
                        const SizedBox(height:16),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: "Email",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          autofillHints: isLogin
                              ? const [AutofillHints.password]
                              : const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!loading) handleAuth();
                          },
                          decoration: InputDecoration(
                            labelText: "Password",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: (loading || !isLogin)
                                ? null
                                : _forgotPassword,
                            child: const Text("Forgot password?"),
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (error != null)
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        if (error != null) const SizedBox(height: 12),

                        ElevatedButton(
                          onPressed: loading ? null : handleAuth,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(isLogin ? "Login" : "Sign Up"),
                        ),
                        const SizedBox(height: 12),

                        ElevatedButton.icon(
                          onPressed: loading ? null : _continueWithGoogle,
                          icon: Image.asset(
                            'assets/icons/google-icon.png',
                            height: 20,
                          ),
                          label: const Text("Continue with Google"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: loading
                              ? null
                              : () {
                                  if (!mounted) return;
                                  setState(() => isLogin = !isLogin);
                                },
                          child: Text(
                            isLogin
                                ? "Need an account? Sign up"
                                : "Already have an account? Login",
                          ),
                        ),
                        TextButton(
                          onPressed: loading
                              ? null
                              : () {
                                  final email = emailController.text.trim();
                                  if (_isValidEmail(email)) {
                                    verifyEmailDialog(context, email);
                                  } else {
                                    setState(
                                      () => error =
                                          'Enter a valid email address first.',
                                    );
                                  }
                                },
                          child: const Text('Verify email with a code'),
                        ),
                        const SizedBox(height: 24),

                        Image.asset('assets/icons/tweak.png', height: 80),
                        const SizedBox(height: 0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ------------------------------
/// to help blur bg
/// ------------------------------
class _BackgroundDecoration extends StatelessWidget {
  final String imagePath;
  const _BackgroundDecoration({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Image.asset(
            imagePath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                // color: Colors.black.withOpacity(0.3), // couldn't decide if i wanted a tint
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ------------------------------
/// Login Header
/// ------------------------------
class _LoginHeader extends StatelessWidget {
  final bool isLogin;
  const _LoginHeader({required this.isLogin});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 70),
        Text(
          isLogin ? "Tweak" : "Create Account",
          style: const TextStyle(
            fontFamily: 'Noot',
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
