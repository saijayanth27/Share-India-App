import 'package:flutter/material.dart';

Widget yesNoQuestion({
  required String label,
  required String? value,
  required ValueChanged<String?> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: RadioListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              title: const Text('Yes'),
              value: 'yes',
              groupValue: value,
              onChanged: onChanged,
            ),
          ),
          Expanded(
            child: RadioListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              title: const Text('No'),
              value: 'no',
              groupValue: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
      const Divider(height: 24),
    ],
  );
} 
Widget buildSectionCard({
  required BuildContext context,
  required String title,
  required List<Widget> children,
  IconData? icon,
}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 24),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    ),
  );
}

Widget buildHeader({
  required BuildContext context,
  required String title,
  required String subtitle,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 24),
    ],
  );
}
