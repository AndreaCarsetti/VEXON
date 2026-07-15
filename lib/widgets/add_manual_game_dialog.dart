import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/vexon_colors.dart';

/// Dialog per aggiungere manualmente un gioco: titolo + percorso
/// dell'eseguibile, quest'ultimo scelto tramite il file picker nativo di
/// Windows (non serve incollare il percorso a mano, anche se il campo di
/// testo resta modificabile per chi preferisce farlo).
///
/// Ritorna una `Map<String, String>` con 'title' ed 'executablePath' se
/// l'utente conferma, `null` se annulla.
class AddManualGameDialog extends StatefulWidget {
  const AddManualGameDialog({super.key});

  @override
  State<AddManualGameDialog> createState() => _AddManualGameDialogState();
}

class _AddManualGameDialogState extends State<AddManualGameDialog> {
  final _titleController = TextEditingController();
  final _pathController = TextEditingController();

  Future<void> _pickExecutable() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['exe'],
      dialogTitle: "Seleziona l'eseguibile del gioco",
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    setState(() {
      _pathController.text = path;
      // Se il titolo è ancora vuoto, propone il nome del file come punto
      // di partenza — l'utente può comunque modificarlo.
      if (_titleController.text.trim().isEmpty) {
        final fileName = result.files.single.name;
        _titleController.text =
            fileName.toLowerCase().endsWith('.exe') ? fileName.substring(0, fileName.length - 4) : fileName;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VexonColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Aggiungi gioco manualmente',
          style: TextStyle(color: VexonColors.textPrimary, fontSize: 18)),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Utile se un gioco non viene rilevato automaticamente da Steam o Epic Games.',
              style: TextStyle(color: VexonColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: VexonColors.textPrimary),
              decoration: _inputDecoration('Titolo'),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    style: const TextStyle(color: VexonColors.textPrimary, fontSize: 12),
                    decoration: _inputDecoration('Percorso eseguibile (.exe)'),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _pickExecutable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VexonColors.surfaceElevated,
                    foregroundColor: VexonColors.textPrimary,
                  ),
                  child: const Text('Sfoglia…'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla', style: TextStyle(color: VexonColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            final title = _titleController.text.trim();
            final path = _pathController.text.trim();
            if (title.isEmpty || path.isEmpty) return;
            Navigator.of(context).pop({'title': title, 'executablePath': path});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: VexonColors.brandRed,
            foregroundColor: Colors.white,
          ),
          child: const Text('Aggiungi'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: VexonColors.textSecondary, fontSize: 12),
      filled: true,
      fillColor: VexonColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}
