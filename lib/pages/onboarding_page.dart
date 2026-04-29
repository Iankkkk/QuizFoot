import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../services/firestore_service.dart';
import 'home_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _loading = false;

  static final _validChars = RegExp(r'^[a-zA-Z0-9_\-àâäéèêëîïôùûüç]+$');

  String? _validate(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Entre un pseudo';
    if (v.length < 2) return 'Minimum 2 caractères';
    if (v.length > 16) return 'Maximum 16 caractères';
    if (!_validChars.hasMatch(v)) return 'Lettres, chiffres, _ et - uniquement';
    return null;
  }

  Future<void> _confirm() async {
    final err = _validate(_ctrl.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _loading = true);
    final pseudo = _ctrl.text.trim();
    final available = await FirestoreService.instance.isPseudoAvailable(pseudo);
    if (!mounted) return;
    if (!available) {
      setState(() {
        _error = 'Ce pseudo est déjà pris';
        _loading = false;
      });
      return;
    }
    await FirestoreService.instance.reservePseudo(pseudo);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pseudo', pseudo);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // Logo + titre
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Image.asset('assets/images/logo.png'),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'TEMPO',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le jeu, dans la tête.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(flex: 2),
              // Pseudo
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choisis ton pseudo',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Il sera visible dans le classement.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: true,
                maxLength: 16,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _confirm(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'ex : Zizou10',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.card,
                  errorText: _error,
                  errorStyle: const TextStyle(
                    color: AppColors.red,
                    fontSize: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.accentBright,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.red, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBright,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Commencer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
