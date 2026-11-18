import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readmate/core/themes/app_theme.dart';
import 'package:readmate/logic/cubit/auth_cubit.dart';

class SignupScreen extends StatefulWidget {
  final String? initialUsername;
  const SignupScreen({super.key, this.initialUsername});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late final TextEditingController _usernameController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername ?? '');
  }

  static final _reservedUsernames = {
    'admin', 'root', 'support', 'api', 'null', 'undefined', 'login', 'help',
    'system', 'superuser', 'owner', 'readmate', 'administrator', 'mod', 'moderator'
  };

  String? _validateUsername(String username) {
    if (username.isEmpty) return 'Username cannot be empty';
    if (username.length < 2 || username.length > 15) {
      return 'Username must be between 2 and 15 characters';
    }
    if (username.contains(' ')) {
      return 'Username cannot contain spaces';
    }
    if (username.length == 1 && !RegExp(r'^[a-zA-Z0-9]$').hasMatch(username)) {
      return 'Username must be a letter or number';
    }
    if (username.length > 1 && (!RegExp(r'^[a-zA-Z0-9]').hasMatch(username) || !RegExp(r'[a-zA-Z0-9]$').hasMatch(username))) {
      return 'Username must start and end with a letter or number';
    }
    if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, _, -, and .';
    }
    if (RegExp(r'([._-]{2,})').hasMatch(username)) {
      return 'Username cannot contain consecutive special characters';
    }
    if (_reservedUsernames.contains(username.toLowerCase())) {
      return 'The username "$username" is reserved and cannot be used';
    }
    return null;
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Email address cannot be empty';
    if (email.length > 254) return 'Email address is too long (max 254 characters)';
    if (email.contains(' ')) return 'Email address cannot contain spaces';

    final atParts = email.split('@');
    if (atParts.length != 2) return 'Email address must contain exactly one "@" symbol';

    final localPart = atParts[0];
    final domainPart = atParts[1];

    if (localPart.isEmpty) return 'Email username (before @) cannot be empty';
    if (domainPart.isEmpty) return 'Email domain (after @) cannot be empty';
    if (localPart.length > 64) return 'Email username cannot exceed 64 characters';

    if (localPart.startsWith('.') || localPart.endsWith('.')) {
      return 'Email username cannot start or end with a dot';
    }
    if (localPart.contains('..')) {
      return 'Email address cannot contain consecutive dots';
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+$').hasMatch(localPart)) {
      return 'Email username contains invalid characters';
    }

    if (!domainPart.contains('.')) {
      return 'Email domain must contain a dot (e.g. .com)';
    }

    final domainLabels = domainPart.split('.');
    final tld = domainLabels.last;
    if (tld.length < 2) {
      return 'Email domain extension (e.g. .com, .io) must be at least 2 characters';
    }

    for (final label in domainLabels) {
      if (label.isEmpty) return 'Email domain contains invalid empty labels';
      if (label.length > 63) return 'Email domain label exceeds 63 characters';
      if (label.startsWith('-') || label.endsWith('-')) {
        return 'Email domain label cannot start or end with a hyphen';
      }
      if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(label)) {
        return 'Email domain contains invalid characters';
      }
    }

    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Password cannot be empty';
    if (password.length < 6) return 'Password must be at least 6 characters long';
    if (password.contains(' ')) return 'Password cannot contain spaces';

    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);

    if (!hasLetter || !hasDigit) {
      return 'Password must contain both letters and numbers';
    }

    return null;
  }

  void _onSignupPressed() {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final usernameErr = _validateUsername(username);
    if (usernameErr != null) {
      _showFriendlyError(usernameErr);
      return;
    }

    final emailErr = _validateEmail(email);
    if (emailErr != null) {
      _showFriendlyError(emailErr);
      return;
    }

    final passwordErr = _validatePassword(password);
    if (passwordErr != null) {
      _showFriendlyError(passwordErr);
      return;
    }

    context.read<AuthCubit>().signUp(
          email: email,
          password: password,
          username: username,
        );
  }

  void _showFriendlyError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: BlocListener<AuthCubit, AuthCubitState>(
        listener: (context, state) {
          if (state is Authenticated) {
            Navigator.popUntil(context, (route) => route.isFirst);
          } else if (state is AwaitingEmailConfirmation) {
            Navigator.pop(context);
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join the ReadMate community',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 48),
                  _buildTextField(
                    controller: _usernameController,
                    hint: 'Username',
                    icon: Icons.alternate_email,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    hint: 'Email Address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    hint: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 32),
                  BlocBuilder<AuthCubit, AuthCubitState>(
                    builder: (context, state) {
                      if (state is AuthLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ElevatedButton(
                        onPressed: _onSignupPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff00BFA6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(cornerRadius),
                          ),
                        ),
                        child: const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Already have an account? Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
