import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

Widget formActionButtons({
  required BuildContext context,
  required bool isEditMode,
  required VoidCallback onNew,
  required VoidCallback onSave,
  required VoidCallback onEdit,
  required VoidCallback onCancel,
  required VoidCallback onExit,
  bool isSaving = false,
}) {
  return Container(
    padding: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionButton(
            context,
            label: 'New',
            icon: Icons.add_circle_outline,
            color: Colors.blue.shade700,
            onPressed: onNew,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            context,
            label: 'Save',
            icon: Icons.save_outlined,
            color: Colors.green.shade700,
            onPressed: isSaving ? null : onSave,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            context,
            label: 'Edit',
            icon: isEditMode ? Icons.edit : Icons.edit_outlined,
            color: Colors.orange.shade700,
            onPressed: onEdit,
            isHighlighted: isEditMode,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            context,
            label: 'Cancel',
            icon: Icons.cancel_outlined,
            color: Colors.red.shade700,
            onPressed: onCancel,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            context,
            label: 'Exit',
            icon: Icons.exit_to_app_outlined,
            color: Colors.grey.shade700,
            onPressed: onExit,
          ),
        ],
      ),
    ),
  );
}

Widget _buildActionButton(
  BuildContext context, {
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback? onPressed,
  bool isHighlighted = false,
}) {
  return OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 20, color: isHighlighted ? Colors.white : color),
    label: Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: isHighlighted ? Colors.white : Colors.black87,
      ),
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: isHighlighted ? Colors.white : Colors.black87,
      side: BorderSide(color: isHighlighted ? color : Colors.grey.shade300, width: isHighlighted ? 2 : 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: isHighlighted ? color : Colors.white,
      elevation: isHighlighted ? 4 : 1,
    ),
  );
}

Widget formTextField(
  String label,
  TextEditingController controller, {
  TextInputType keyboardType = TextInputType.text,
  String? hint,
  String? helper,
  int maxLines = 1,
  bool readOnly = false,
  bool? enabled,
  void Function(String)? onChanged,
  List<TextInputFormatter>? inputFormatters,
  String? Function(String?)? validator,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        readOnly: readOnly,
        enabled: enabled,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          hintText: hint,
          helperText: helper,
          fillColor: (readOnly || enabled == false) ? Colors.grey.shade100 : Colors.white,
          filled: true,
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        inputFormatters: inputFormatters,
        validator: validator,
      ),
    ],
  );
}

Widget formDropdown(
  String label,
  List<String> items,
  String? selectedValue,
  Function(String?) onChanged, {
  bool isLoading = false,
  String? hint,
  String? Function(String?)? validator,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        menuMaxHeight: 300,
        value: (selectedValue != null && items.contains(selectedValue)) ? selectedValue : null,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          suffixIcon: isLoading ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
          fillColor: Colors.white,
          filled: true,
        ),
        items: items.toSet().map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
        validator: validator,
        hint: Text(hint ?? '-Select-', style: const TextStyle(fontSize: 14)),
      ),
    ],
  );
}

Widget formSearchableDropdown(
  BuildContext context,
  String label,
  List<String> items,
  String? selectedValue,
  Function(String?) onChanged, {
  bool isLoading = false,
  String? hint,
  String? Function(String?)? validator,
}) {
  return FormField<String>(
    validator: validator,
    initialValue: selectedValue,
    builder: (FormFieldState<String> state) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
          const SizedBox(height: 6),
          InkWell(
            onTap: isLoading ? null : () async {
              // Dismiss keyboard before opening dialog to prevent focus jumps
              FocusScope.of(context).unfocus();
              
              final String? result = await showDialog<String>(
                context: context,
                builder: (context) => _SearchableDialog(
                  title: label,
                  items: items,
                  initialValue: state.value,
                ),
              );
              if (result != null) {
                state.didChange(result);
                onChanged(result);
              }
            },
            focusNode: FocusNode(canRequestFocus: false),
            child: InputDecorator(
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: state.hasError ? Colors.red : Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: state.hasError ? Colors.red : Colors.blue, width: 2),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.value != null && state.value!.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          state.didChange(null);
                          onChanged(null);
                        },
                        child: const Icon(Icons.clear, size: 20, color: Colors.grey),
                      ),
                    isLoading 
                      ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator(strokeWidth: 2)))
                      : const Icon(Icons.arrow_drop_down),
                  ],
                ),
                fillColor: Colors.white,
                filled: true,
                errorText: state.errorText,
              ),
              child: Text(
                (state.value != null && items.contains(state.value)) ? state.value! : (hint ?? '-Select-'),
                style: TextStyle(
                  fontSize: 14,
                  color: (state.value != null && items.contains(state.value)) ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      );
    }
  );
}

class _SearchableDialog extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? initialValue;

  const _SearchableDialog({
    required this.title,
    required this.items,
    this.initialValue,
  });

  @override
  State<_SearchableDialog> createState() => _SearchableDialogState();
}

class _SearchableDialogState extends State<_SearchableDialog> {
  late List<String> filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredItems = widget.items;
  }

  void _filterItems(String query) {
    setState(() {
      filteredItems = widget.items
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80), // More like a popup
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Select ${widget.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search...',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: _filterItems,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Scrollbar(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final isSelected = item == widget.initialValue;
                    return ListTile(
                      title: Text(item, style: TextStyle(fontSize: 14, color: isSelected ? Colors.blue : Colors.black87)),
                      dense: true,
                      selected: isSelected,
                      selectedTileColor: Colors.blue.withOpacity(0.05),
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
Widget formSearchField(
  String label,
  TextEditingController controller, {
  required VoidCallback onSearch,
  String? hint,
  bool isLoading = false,
  bool enabled = true,
  String? Function(String?)? validator,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                hintText: hint ?? 'Enter $label',
                fillColor: enabled ? Colors.white : Colors.grey.shade100,
                filled: true,
              ),
              onFieldSubmitted: (_) => onSearch(),
              validator: validator,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 45,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
            ),
          ),
        ],
      ),
    ],
  );
}
