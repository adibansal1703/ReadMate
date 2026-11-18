import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readmate/generated/locale_keys.g.dart';
import 'package:readmate/logic/bloc/theme_bloc/theme_bloc.dart';
import 'package:readmate/logic/cubit/auth_cubit.dart';
import 'package:readmate/ui/settings_screen/settings_apperance_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:settings_ui/settings_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  SettingsTile _buildBasicSetting({
    required String title,
    String? description,
    IconData? iconData,
    required BuildContext context,
  }) {
    return SettingsTile(
      title: Text(title, style: const TextStyle(fontSize: 16)),
      leading: (iconData == null) ? null : Icon(iconData),
      description: (description != null)
          ? Text(description, style: const TextStyle())
          : null,
    );
  }

  SettingsTile _buildAppearanceSetting(BuildContext context) {
    return SettingsTile.navigation(
      title: Text(
        LocaleKeys.apperance.tr(),
        style: const TextStyle(fontSize: 16),
      ),
      leading: const Icon(Icons.color_lens),
      onPressed: (context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsApperanceScreen(),
          ),
        );
      },
    );
  }

  Future<String> _getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    return packageInfo.version;
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              context.read<AuthCubit>().signOut();
              Navigator.pop(context); // Go back to Home
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action is PERMANENT. All your books, ratings, and profile data will be erased forever.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            const Text('Please enter your password to confirm:'),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Password',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final password = passwordController.text.trim();
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password is required to delete account.')),
                );
                return;
              }
              Navigator.pop(context);
              context.read<AuthCubit>().deleteAccount(password);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE EVERYTHING'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.settings.tr(),
          style: const TextStyle(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _getAppVersion(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final version = snapshot.data;

              return BlocBuilder<ThemeBloc, ThemeState>(
                builder: (context, state) {
                  late final bool amoledDark;

                  if (state is SetThemeState) {
                    amoledDark = state.amoledDark;
                  } else {
                    amoledDark = false;
                  }

                  return SettingsList(
                    contentPadding: const EdgeInsets.only(top: 10),
                    darkTheme: SettingsThemeData(
                      settingsListBackground: amoledDark
                          ? Colors.black
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerLowest,
                    ),
                    lightTheme: SettingsThemeData(
                      settingsListBackground:
                          Theme.of(context).colorScheme.surfaceContainerLowest,
                    ),
                    sections: [
                      SettingsSection(
                        title: const Text('Account'),
                        tiles: [
                          SettingsTile(
                            title: const Text('Sign Out'),
                            leading: const Icon(Icons.logout, color: Colors.red),
                            onPressed: (context) {
                              _showSignOutDialog(context);
                            },
                          ),
                          SettingsTile(
                            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                            leading: const Icon(Icons.delete_forever, color: Colors.red),
                            onPressed: (context) {
                              _showDeleteAccountDialog(context);
                            },
                          ),
                        ],
                      ),
                      SettingsSection(
                        title: Text(
                          LocaleKeys.about.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        tiles: <SettingsTile>[
                          _buildBasicSetting(
                            title: LocaleKeys.version.tr(),
                            description: version,
                            iconData: Icons.rocket_launch,
                            context: context,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            } else {
              return const SizedBox();
            }
          },
        ),
      ),
    );
  }
}

