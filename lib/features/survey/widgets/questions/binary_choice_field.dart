import 'package:flutter/material.dart';

class BinaryChoiceField extends StatelessWidget {
  const BinaryChoiceField({
    super.key,
    required this.label,
    required this.positiveLabel,
    required this.negativeLabel,
    required this.isRequired,
    required this.value,
    required this.onChanged,
    this.showLabels = true,
  });

  final String label;
  final String positiveLabel;
  final String negativeLabel;
  final bool isRequired;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: value,
      validator: (String? current) {
        if (isRequired && (current == null || current.isEmpty)) {
          return 'Champ requis';
        }
        return null;
      },
      builder: (FormFieldState<String> field) {
        final String? currentValue = field.value ?? value;
        void handleTap(String candidate) {
          final String? nextValue =
              currentValue == candidate ? null : candidate;
          field.didChange(nextValue);
          onChanged(nextValue);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                _ThumbButton(
                  icon: Icons.thumb_up,
                  label: positiveLabel,
                  showLabel: showLabels,
                  selected: currentValue == positiveLabel,
                  onPressed: () => handleTap(positiveLabel),
                ),
                const SizedBox(width: 12),
                _ThumbButton(
                  icon: Icons.thumb_down,
                  label: negativeLabel,
                  showLabel: showLabels,
                  selected: currentValue == negativeLabel,
                  onPressed: () => handleTap(negativeLabel),
                ),
              ],
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThumbButton extends StatelessWidget {
  const _ThumbButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.showLabel,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color backgroundColor =
        selected ? scheme.primary : scheme.surfaceContainerHigh;
    final Color foregroundColor =
        selected ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            if (showLabel) ...[
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center),
            ],
          ],
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
      ),
    );
  }
}
