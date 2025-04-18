import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/config/language_controller.dart';
import 'package:cb_file_manager/config/translation_helper.dart';
import 'package:cb_file_manager/ui/screens/language_test_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserPreferences _preferences = UserPreferences();
  final LanguageController _languageController = LanguageController();
  late ThemePreference _themePreference;
  late String _currentLanguageCode;
  late bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    await _preferences.init();
    setState(() {
      _themePreference = _preferences.getThemePreference();
      _currentLanguageCode = _languageController.currentLocale.languageCode;
      _isLoading = false;
    });
  }

  Future<void> _updateThemePreference(ThemePreference preference) async {
    await _preferences.setThemePreference(preference);
    setState(() {
      _themePreference = preference;
    });

    // No need for the snackbar message since the theme change will be immediately visible
    // Instead, we can add a subtle visual feedback
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.save),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 160,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _updateLanguage(String languageCode) async {
    await _languageController.changeLanguage(languageCode);
    setState(() {
      _currentLanguageCode = languageCode;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.language + ' ' + context.tr.save),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 200,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: context.tr.settings,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 16),
                _buildLanguageSection(context),
                const Divider(),
                _buildThemeSection(context),
                const Divider(),
                // Test language section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LanguageTestScreen(),
                        ),
                      );
                    },
                    child: Text('Test Language Translations'),
                  ),
                ),
                // Other settings sections can be added here
              ],
            ),
    );
  }

  Widget _buildLanguageSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.language, size: 24),
                const SizedBox(width: 16),
                Text(
                  context.tr.language,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Text(
              'Choose your preferred language',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildLanguageOption(
            title: 'Tiếng Việt',
            value: LanguageController.vietnamese,
            icon: Icons.language,
            flagEmoji: '🇻🇳',
          ),
          _buildLanguageOption(
            title: 'English',
            value: LanguageController.english,
            icon: Icons.language,
            flagEmoji: '🇬🇧',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            context.tr.theme,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Choose how the app looks',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        _buildThemeOption(
          title: context.tr.systemMode,
          subtitle: 'Follow system theme settings',
          value: ThemePreference.system,
          icon: Icons.brightness_auto,
        ),
        _buildThemeOption(
          title: context.tr.lightMode,
          subtitle: 'Light theme for all screens',
          value: ThemePreference.light,
          icon: Icons.light_mode,
        ),
        _buildThemeOption(
          title: context.tr.darkMode,
          subtitle: 'Dark theme for all screens',
          value: ThemePreference.dark,
          icon: Icons.dark_mode,
        ),
      ],
    );
  }

  Widget _buildLanguageOption({
    required String title,
    required String value,
    required IconData icon,
    required String flagEmoji,
  }) {
    final isSelected = _currentLanguageCode == value;

    return ListTile(
      title: Row(
        children: [
          Text(flagEmoji),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
          : null,
      onTap: () => _updateLanguage(value),
      selected: isSelected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required ThemePreference value,
    required IconData icon,
  }) {
    final isSelected = _themePreference == value;

    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Icon(icon),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
          : null,
      onTap: () => _updateThemePreference(value),
      selected: isSelected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
