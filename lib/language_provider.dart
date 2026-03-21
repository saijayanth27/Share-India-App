import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider {
  LanguageProvider._();

  static final LanguageProvider instance = LanguageProvider._();
  static const _storageKey = 'selected_language_code';
  static const supportedLocales = [Locale('en'), Locale('te')];

  final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('en'));
  final ValueNotifier<bool> isTeluguNotifier = ValueNotifier<bool>(false);

  final Map<String, Map<String, String>> _catalogCache = {};
  Map<String, String> _englishCatalog = const {};
  Map<String, String> _activeCatalog = const {};
  bool _isInitialized = false;

  bool get isTelugu => isTeluguNotifier.value;

  static bool supports(Locale locale) =>
      supportedLocales.any((item) => item.languageCode == locale.languageCode);

  Future<void> init() async {
    if (_isInitialized) return;

    await _loadCatalog('en');
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_storageKey) ?? 'en';
    final initialLocale = supports(Locale(savedCode))
        ? Locale(savedCode)
        : const Locale('en');

    await ensureLocaleLoaded(initialLocale);
    _setActiveLocale(initialLocale);
    _isInitialized = true;
  }

  Future<void> ensureLocaleLoaded(Locale locale) async {
    await _loadCatalog('en');
    await _loadCatalog(locale.languageCode);
    _englishCatalog = _catalogCache['en'] ?? const {};
    _activeCatalog = _catalogCache[locale.languageCode] ?? _englishCatalog;
  }

  Future<void> toggle() async {
    await setLocale(isTelugu ? const Locale('en') : const Locale('te'));
  }

  Future<void> setLocale(Locale locale) async {
    final normalized = supports(locale) ? locale : const Locale('en');
    await ensureLocaleLoaded(normalized);
    _setActiveLocale(normalized);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, normalized.languageCode);
  }

  String translate(String text) {
    if (_activeCatalog.isEmpty) return text;
    return _activeCatalog[text] ?? _englishCatalog[text] ?? text;
  }

  Future<void> _loadCatalog(String languageCode) async {
    if (_catalogCache.containsKey(languageCode)) return;
    final raw = await rootBundle.loadString('assets/i18n/$languageCode.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    _catalogCache[languageCode] = decoded.map(
      (key, value) => MapEntry(key, value.toString()),
    );
  }

  void _setActiveLocale(Locale locale) {
    localeNotifier.value = locale;
    isTeluguNotifier.value = locale.languageCode == 'te';
  }
}

String tr(String text) => LanguageProvider.instance.translate(text);

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageProvider.instance.localeNotifier,
      builder: (context, locale, _) {
        final isTelugu = locale.languageCode == 'te';
        return GestureDetector(
          onTap: () => LanguageProvider.instance.toggle(),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isTelugu
                  ? Colors.orange.shade600
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white54, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  isTelugu ? 'తెలుగు' : 'ENG',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Rebuilds its child subtree whenever the app locale changes.
///
/// This app uses `tr()` (a global lookup) for most strings, so we need an
/// explicit rebuild trigger when language changes to update already-mounted
/// pages in the navigation stack.
class LocalizedBuilder extends StatelessWidget {
  const LocalizedBuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageProvider.instance.localeNotifier,
      builder: (context, _, __) => builder(context),
    );
  }
}
