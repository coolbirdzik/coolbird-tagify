import 'package:flutter/material.dart';
import 'package:cb_file_manager/config/language_controller.dart';
import 'package:cb_file_manager/config/translation_helper.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';

class LanguageTestScreen extends StatefulWidget {
  const LanguageTestScreen({Key? key}) : super(key: key);

  @override
  State<LanguageTestScreen> createState() => _LanguageTestScreenState();
}

class _LanguageTestScreenState extends State<LanguageTestScreen> {
  final LanguageController _languageController = LanguageController();

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: context.tr.language,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Language: ${_languageController.getLanguageName(_languageController.currentLocale.languageCode)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('App Title: ${context.tr.appTitle}'),
                  const SizedBox(height: 8),
                  Text('Home: ${context.tr.home}'),
                  const SizedBox(height: 8),
                  Text('Settings: ${context.tr.settings}'),
                  const SizedBox(height: 8),
                  Text('Search: ${context.tr.search}'),
                  const SizedBox(height: 8),
                  Text('File: ${context.tr.file}'),
                  const SizedBox(height: 8),
                  Text('Folder: ${context.tr.folder}'),
                  const SizedBox(height: 8),
                  Text('Delete: ${context.tr.delete}'),
                  const SizedBox(height: 8),
                  Text('Cancel: ${context.tr.cancel}'),
                  const SizedBox(height: 8),
                  Text('OK: ${context.tr.ok}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Switch Language',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLanguageOption(
                    title: 'Tiếng Việt',
                    value: LanguageController.vietnamese,
                  ),
                  _buildLanguageOption(
                    title: 'English',
                    value: LanguageController.english,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required String title,
    required String value,
  }) {
    final isSelected = _languageController.currentLocale.languageCode == value;

    return ListTile(
      title: Text(title),
      leading: const Icon(Icons.language),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
          : null,
      onTap: () async {
        await _languageController.changeLanguage(value);
        setState(() {});
      },
      selected: isSelected,
    );
  }
}
