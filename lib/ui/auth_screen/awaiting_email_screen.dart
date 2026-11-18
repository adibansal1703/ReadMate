import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:readmate/core/themes/app_theme.dart';
import 'package:readmate/logic/cubit/auth_cubit.dart';

class AwaitingEmailScreen extends StatefulWidget {
  const AwaitingEmailScreen({super.key});

  @override
  State<AwaitingEmailScreen> createState() => _AwaitingEmailScreenState();
}

class _AwaitingEmailScreenState extends State<AwaitingEmailScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("[AUTH_RESUME] App resumed. Triggering instant email confirmation check...");
      _checkConfirmationStatus(isSilent: true);
    }
  }

  void _checkConfirmationStatus({bool isSilent = true}) {
    final authState = context.read<AuthCubit>().state;
    if (authState is AwaitingEmailConfirmation) {
      context.read<AuthCubit>().signIn(
        identifier: authState.identifier,
        password: authState.password,
        isSilent: isSilent,
      );
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthCubit>().state;

    String email = 'your email';
    if (authState is AwaitingEmailConfirmation) {
      email = authState.identifier;
    }

    return Scaffold(
      body: BlocListener<AuthCubit, AuthCubitState>(
        listener: (context, state) {
          if (state is AuthError) {
            _showSnackBar(context, state.message, Colors.redAccent);
          } else if (state is AwaitingEmailConfirmation && state.message != null) {
            _showSnackBar(context, state.message!, Colors.green);
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  FaIcon(
                    FontAwesomeIcons.envelopeCircleCheck,
                    size: 90,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Confirm your Email',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'We sent a verification link to:\n$email\n\nOnce you click the link in your email, return to this app and you will be logged in automatically.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 48),
                  CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Checking status automatically...',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      context.read<AuthCubit>().resendVerificationCode(email);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Resend Confirmation Link'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      context.read<AuthCubit>().signOut();
                    },
                    child: Text(
                      'Back to Login',
                      style: TextStyle(color: theme.colorScheme.primary, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
