import 'package:flutter/material.dart';

class ProfileConfirmationDialog extends StatefulWidget {
  const ProfileConfirmationDialog({
    super.key,
    required this.name,
    required this.reset,
    required this.requiredText,
  });
  final String name, requiredText;
  final bool reset;
  @override
  State<ProfileConfirmationDialog> createState() =>
      _ProfileConfirmationDialogState();
}

class _ProfileConfirmationDialogState extends State<ProfileConfirmationDialog> {
  final entry = TextEditingController();
  @override
  void dispose() {
    entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.reset ? 'Сбросить демо?' : 'Удалить профиль?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.name}: ${widget.reset ? 'результаты демо удалятся, игра начнётся заново' : 'профиль и его прогресс будут удалены'}. Другие профили останутся.',
          ),
          TextField(
            key: const ValueKey('destructive-confirmation'),
            controller: entry,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Напиши ${widget.requiredText}',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: entry.text == widget.requiredText
            ? () => Navigator.pop(context, true)
            : null,
        child: Text(
          widget.reset ? 'Подтвердить сброс' : 'Подтвердить удаление',
        ),
      ),
    ],
  );
}
