import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/game_history_service.dart';

/// Shows a dialog asking the user for a pseudo, then saves it.
/// Returns the pseudo string (never null — user cannot dismiss without entering one).
Future<String> showPseudoDialog(BuildContext context) async {
  String? result;
  while (result == null || result.isEmpty) {
    result = await showDialog<String>(
      context:    context,
      barrierDismissible: false,
      builder:    (_) => const _PseudoDialog(),
    );
  }
  await GameHistoryService.instance.setPseudo(result);
  return result;
}

class _PseudoDialog extends StatefulWidget {
  const _PseudoDialog();

  @override
  State<_PseudoDialog> createState() => _PseudoDialogState();
}

class _PseudoDialogState extends State<_PseudoDialog> {
  final _controller = TextEditingController();
  bool _error = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    if (v.isEmpty) {
      setState(() => _error = true);
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bienvenue ! 👋',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choisis un pseudo pour enregistrer tes scores.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller:    _controller,
              autofocus:     true,
              maxLength:     20,
              style:         const TextStyle(color: AppColors.textPrimary),
              onSubmitted:   (_) => _submit(),
              decoration: InputDecoration(
                hintText:      'Ton pseudo',
                hintStyle:     const TextStyle(color: AppColors.textSecondary),
                counterStyle:  const TextStyle(color: AppColors.textSecondary),
                filled:        true,
                fillColor:     AppColors.bg,
                errorText:     _error ? 'Entre un pseudo pour continuer' : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:   const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:   const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:   const BorderSide(color: AppColors.accentBright, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBright,
                  foregroundColor: Colors.white,
                  padding:         const EdgeInsets.symmetric(vertical: 14),
                  shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation:       0,
                ),
                onPressed: _submit,
                child: const Text(
                  'C\'est parti !',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
