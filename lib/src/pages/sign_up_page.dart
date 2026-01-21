import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sign_in_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.20),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {'full_name': _name.text.trim()},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Please sign in.')),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInPage()),
        (route) => false,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _deco({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.10),
      labelStyle: TextStyle(color: Colors.black.withOpacity(0.85)),
      prefixIconColor: Colors.black.withOpacity(0.90),
      suffixIconColor: Colors.black.withOpacity(0.85),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.38)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topH = mq.size.height * 0.30;

    return Scaffold(
      backgroundColor: const Color(0xFF283593),
      body: Stack(
        children: [
          Container(color: const Color(0xFF283593)),

          // Top white 30% with curve
          SizedBox(
            height: topH,
            width: double.infinity,
            child: ClipPath(
              clipper: _BottomCurveClipper(),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SPARROW',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                color: const Color(0xFF283593),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your Daily Companion.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Form panel
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.98),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 22,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign Up',
                          style: TextStyle(
                            color: const Color(0xFF283593),
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Join SPARROW and stay in control.',
                          style: TextStyle(color: Colors.black),
                        ),
                        const SizedBox(height: 14),

                        if (_error != null) ...[
                          _ErrorBanner(message: _error!),
                          const SizedBox(height: 12),
                        ],

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _name,
                                style: const TextStyle(color: Colors.black),
                                decoration: _deco(
                                  label: 'Full name',
                                  icon: Icons.person_outline,
                                ),
                                validator: (v) {
                                  final t = (v ?? '').trim();
                                  if (t.isEmpty) return 'Name is required';
                                  if (t.length < 2) return 'Enter a valid name';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.black),
                                decoration: _deco(
                                  label: 'Email',
                                  icon: Icons.mail_outline,
                                ),
                                validator: (v) {
                                  final t = (v ?? '').trim();
                                  if (t.isEmpty) return 'Email is required';
                                  if (!t.contains('@')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _password,
                                obscureText: _obscure,
                                style: const TextStyle(color: Colors.black),
                                decoration: _deco(
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  final t = (v ?? '');
                                  if (t.isEmpty) return 'Password is required';
                                  if (t.length < 6) {
                                    return 'Minimum 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _loading ? null : _signUp,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF283593),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Create Account',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Already have an account? ",
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.75),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () {
                                            Navigator.of(
                                              context,
                                            ).pushAndRemoveUntil(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const SignInPage(),
                                              ),
                                              (route) => false,
                                            );
                                          },
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF283593),
                                    ),
                                    child: const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade100, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red.shade50)),
          ),
        ],
      ),
    );
  }
}

class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);

    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.52,
      size.height - 18,
    );
    path.quadraticBezierTo(
      size.width * 0.80,
      size.height - 52,
      size.width,
      size.height - 20,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
