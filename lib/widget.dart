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
