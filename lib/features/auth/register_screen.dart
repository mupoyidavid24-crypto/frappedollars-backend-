import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import 'auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  DateTime? _dateOfBirth;
  bool _isSubmitting = false;

  static const int _minimumAge = 18;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isAdult(DateTime dateOfBirth) {
    final today = DateTime.now();
    final age = today.year - dateOfBirth.year -
        ((today.month < dateOfBirth.month ||
                (today.month == dateOfBirth.month && today.day < dateOfBirth.day))
            ? 1
            : 0);
    return age >= _minimumAge;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final lastAllowedDate = DateTime(now.year - _minimumAge, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: lastAllowedDate,
      firstDate: DateTime(1940),
      lastDate: lastAllowedDate,
    );

    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _handleRegister() async {
    if (_isSubmitting) {
      return;
    }

    final fullName = _fullNameController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (fullName.isEmpty || phoneNumber.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires.')),
      );
      return;
    }

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner votre date de naissance.')),
      );
      return;
    }

    if (!_isAdult(_dateOfBirth!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez avoir au moins 18 ans pour vous inscrire.')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      email: email,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
      dateOfBirth: _dateOfBirth!,
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
    }

    if (!mounted) return;

    if (success) {
      final message = authProvider.registerMessage ?? 'Compte créé ! Veuillez vérifier votre email.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.pop(context); // Retour au login
    } else {
      final errorMessage = authProvider.registerMessage ?? 'Échec de l\'inscription.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading || _isSubmitting;
    final isWideLayout = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Stack(
        children: [
          const _RegistrationBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: isWideLayout
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildHeroPanel(context)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildFormCard(context, isLoading)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildHeroPanel(context),
                            const SizedBox(height: 20),
                            _buildFormCard(context, isLoading),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPanel(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 420),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF128C8A), Color(0xFF0E6F73), Color(0xFF0A4F55)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'web/icons/frappe logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FrappedDollars',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Create your account',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open your account\nin minutes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Register first, access the dashboard, and complete KYC later when you are ready. The app stays usable while the product stabilizes.',
                style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.45),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _Pill(label: 'Fast signup'),
              _Pill(label: 'Dashboard access'),
              _Pill(label: 'KYC later'),
              _Pill(label: 'Mobile friendly'),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Identity verification remains available, but it is no longer mandatory for initial access.',
                    style: TextStyle(color: Colors.white, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign Up',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF18333A)),
          ),
          const SizedBox(height: 6),
          Text(
            'Fill in your details to create the account.',
            style: TextStyle(color: Colors.black.withOpacity(0.62)),
          ),
          const SizedBox(height: 24),
          _buildFieldGroup(
            label: 'Full name',
            child: TextField(
              controller: _fullNameController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                hintText: 'John Doe',
                icon: Icons.badge_outlined,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildFieldGroup(
            label: 'Phone',
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(
                hintText: '+1 555 000 000',
                icon: Icons.phone_outlined,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildFieldGroup(
            label: 'Email',
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(
                hintText: 'you@example.com',
                icon: Icons.email_outlined,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildFieldGroup(
            label: 'Date of birth',
            child: InkWell(
              onTap: _pickDateOfBirth,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: _inputDecoration(
                  hintText: 'Select your date of birth',
                  icon: Icons.cake_outlined,
                ),
                child: Text(
                  _dateOfBirth == null ? 'Select your date of birth' : _formatDate(_dateOfBirth!),
                  style: TextStyle(
                    color: _dateOfBirth == null ? Colors.black45 : const Color(0xFF18333A),
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildFieldGroup(
            label: 'Password',
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _inputDecoration(
                hintText: 'Create a password',
                icon: Icons.lock_outline,
                trailing: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.black45,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildFieldGroup(
            label: 'Confirm password',
            child: TextField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              decoration: _inputDecoration(
                hintText: 'Repeat your password',
                icon: Icons.lock_reset,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'You must be at least $_minimumAge years old. KYC stays optional for now.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.primaryColor),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Already have an account? Sign in',
              style: TextStyle(color: Color(0xFF0E6F73), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldGroup({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF18333A),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({required String hintText, required IconData icon, Widget? trailing}) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: const Color(0xFF0E6F73)),
      suffixIcon: trailing,
      filled: true,
      fillColor: const Color(0xFFF7FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE4EBED)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE4EBED)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF0E6F73), width: 1.4),
      ),
    );
  }
}

class _RegistrationBackdrop extends StatelessWidget {
  const _RegistrationBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3FBFB), Color(0xFFEAF4F4), Color(0xFFF7F9FA)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: _GlowBlob(size: 220, color: Color(0x33128C8A)),
          ),
          Positioned(
            bottom: -70,
            right: -30,
            child: _GlowBlob(size: 180, color: Color(0x1A0E6F73)),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
