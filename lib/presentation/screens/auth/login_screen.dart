import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../presentation/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();
  bool _isRegister = false;
  bool _obscure     = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final auth = ref.read(authProvider.notifier);
    if (_isRegister) {
      auth.register(_emailCtrl.text.trim(), _passCtrl.text, _nameCtrl.text.trim());
    } else {
      auth.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Navigate on login
    ref.listen(authProvider, (_, next) {
      if (next.isAuthenticated) context.go('/home');
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Logo
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF00ACC1)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.4),
                    blurRadius: 20, offset: const Offset(0, 8),
                  )],
                ),
                child: const Icon(Icons.biotech_rounded, color: Colors.white, size: 44),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

              const SizedBox(height: 24),
              Text(
                _isRegister ? 'Create Account' : 'Welcome Back',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 6),
              Text(
                _isRegister ? 'Sign up to save your scan reports' : 'Sign in to access your reports',
                style: const TextStyle(color: Colors.grey),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 40),

              // Google Sign In
              _GoogleButton(
                isLoading: authState.isLoading,
                onTap: () => ref.read(authProvider.notifier).signInWithGoogle(),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

              const SizedBox(height: 20),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or continue with email',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 20),

              // Form
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16, offset: const Offset(0, 4),
                  )],
                ),
                child: Column(
                  children: [
                    if (_isRegister) ...[  
                      _TextField(ctrl: _nameCtrl, label: 'Full Name', icon: Icons.person_outline),
                      const SizedBox(height: 14),
                    ],
                    _TextField(ctrl: _emailCtrl, label: 'Email', icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _TextField(
                      ctrl: _passCtrl, label: 'Password', icon: Icons.lock_outline,
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                            size: 20, color: Colors.grey),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error
                    if (authState.error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(authState.error!,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 12))),
                        ]),
                      ),

                    if (authState.error != null) const SizedBox(height: 14),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF00ACC1)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                            color: const Color(0xFF1565C0).withOpacity(0.35),
                            blurRadius: 12, offset: const Offset(0, 4),
                          )],
                        ),
                        child: ElevatedButton(
                          onPressed: authState.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: authState.isLoading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(_isRegister ? 'Create Account' : 'Sign In',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => _isRegister = !_isRegister),
                child: Text(
                  _isRegister
                      ? 'Already have an account? Sign in'
                      : "Don't have an account? Sign up",
                  style: const TextStyle(color: Color(0xFF1565C0)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _GoogleButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google 'G' logo using colored text
            const Text('G',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: Color(0xFF4285F4))),
            const SizedBox(width: 12),
            const Text('Continue with Google',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF333333))),
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboard;
  final Widget? suffix;

  const _TextField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboard = TextInputType.text,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
