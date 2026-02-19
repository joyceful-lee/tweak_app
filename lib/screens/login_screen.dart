import 'dart:ui'; // for ImageFilter.blur
import 'package:flutter/material.dart';
import '../auth.dart';
import 'dish_list.dart';

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

    if (email.isEmpty) {
      setState(() => error = "Enter your email first.");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await sendPasswordResetEmail(email); // found in auth.dart

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password reset email sent to $email")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }


  Future<void> handleAuth() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (isLogin) {
        await signIn(
          emailController.text.trim(),
          passwordController.text.trim(),
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DishListScreen()),
        );
      } else {
        await signUp(emailController.text.trim(), passwordController.text.trim());
        if (!mounted) return;
        setState(() => isLogin = true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    }

    if (!mounted) return;
    setState(() => loading = false);
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
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.onPrimary.withValues(alpha:0.82),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
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
                            onPressed: (loading || !isLogin) ? null : _forgotPassword,
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
                          onPressed: () async {
                            try {
                              await signInWithGoogle();
                            } catch (e) {
                              setState(() => error = e.toString());
                            }
                          },
                          icon: Image.asset('assets/icons/google-icon.png', height: 20),
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
                        const SizedBox(height: 24),

                        Image.asset(
                          'assets/icons/tweak.png',
                          height: 80,
                        ),
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
