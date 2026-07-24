import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

Widget yesNoQuestion({
  required String label,
  required String? value,
  required ValueChanged<String?>? onChanged,
  String yesLabel = '(1) Yes',
  String noLabel = '(2) No',
  String yesValue = '(1) Yes',
  String noValue = '(2) No',
  bool enabled = true,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Row(
        children: [
          formRadioOption(label: yesLabel, value: yesValue, groupValue: value, onChanged: onChanged, enabled: enabled),
          const SizedBox(width: 16),
          formRadioOption(label: noLabel, value: noValue, groupValue: value, onChanged: onChanged, enabled: enabled),
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
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
  bool isActionActive = false, 
}) {
  final bool disableActions = isSaving || isActionActive; 
  final bool disableSubmit = isSaving || !isActionActive;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          offset: const Offset(0, -4),
          blurRadius: 10,
        ),
      ],
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            context,
            label: 'New',
            icon: Icons.add_circle_outline,
            color: Colors.blue.shade700,
            onPressed: disableActions ? null : onNew,
            isHighlighted: isActionActive && !isEditMode,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            context,
            label: 'Save',
            icon: Icons.save_outlined,
            color: Colors.green.shade700,
            onPressed: disableSubmit ? null : onSave,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            context,
            label: 'Edit',
            icon: isEditMode ? Icons.edit : Icons.edit_outlined,
            color: Colors.orange.shade700,
            onPressed: disableActions ? null : onEdit,
            isHighlighted: isActionActive && isEditMode,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            context,
            label: 'Cancel',
            icon: Icons.cancel_outlined,
            color: Colors.red.shade700,
            onPressed: disableSubmit ? null : onCancel,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            context,
            label: 'Exit',
            icon: Icons.exit_to_app_outlined,
            color: Colors.grey.shade700,
            onPressed: isSaving ? null : onExit,
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
  final bool isDisabled = onPressed == null && !isHighlighted;
  final Color activeColor = isHighlighted ? Colors.white : color;

  return OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 20, color: isDisabled ? Colors.grey.shade400 : activeColor),
    label: Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: isDisabled ? Colors.grey.shade400 : (isHighlighted ? Colors.white : Colors.black87),
      ),
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: isHighlighted ? Colors.white : Colors.black87,
      side: BorderSide(color: isDisabled ? Colors.grey.shade300 : (isHighlighted ? color : Colors.grey.shade300), width: isHighlighted ? 2 : 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: isDisabled ? Colors.grey.shade50 : (isHighlighted ? color : Colors.white),
      elevation: isHighlighted ? 4 : 1,
    ),
  );
}

Widget buildCompactRadio({
  required String label,
  required String value,
  required String? groupValue,
  required ValueChanged<String?>? onChanged,
  Color activeColor = Colors.blue,
  bool enabled = true,
}) {
  final bool isSelected = value == groupValue;
  final effectiveOnChanged = !enabled ? null : onChanged;
  return InkWell(
    onTap: effectiveOnChanged == null ? null : () => effectiveOnChanged(value),
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? (enabled ? activeColor : Colors.grey.shade400) : Colors.grey.shade300,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? (enabled ? activeColor.withOpacity(0.05) : Colors.grey.shade100) : Colors.transparent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: effectiveOnChanged == null ? null : (_) {},
              activeColor: activeColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? (enabled ? activeColor : Colors.grey.shade700) : (enabled ? Colors.black87 : Colors.grey.shade600),
            ),
          ),
        ],
      ),
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
  bool isUpperCase = false,
  bool isNumericOnly = false,
  FocusNode? focusNode,
  void Function(String)? onChanged,
  List<TextInputFormatter>? inputFormatters,
  String? Function(String?)? validator,
}) {
  final List<TextInputFormatter> effectiveFormatters = [...?(inputFormatters ?? [])];
  
  if (isUpperCase) {
    effectiveFormatters.add(UpperCaseTextFormatter());
  }
  
  if (isNumericOnly || keyboardType == TextInputType.number) {
    effectiveFormatters.add(FilteringTextInputFormatter.digitsOnly);
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        readOnly: readOnly,
        enabled: enabled,
        focusNode: focusNode,
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
        keyboardType: isNumericOnly ? TextInputType.number : keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        inputFormatters: effectiveFormatters,
        validator: validator,
      ),
    ],
  );
}

Widget formDropdown(
  String label,
  List<String> items,
  String? selectedValue,
  ValueChanged<String?>? onChanged, {
  bool isLoading = false,
  bool enabled = true,
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
          fillColor: enabled ? Colors.white : Colors.grey.shade100,
          filled: true,
        ),
        items: items.toSet().map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: !enabled ? null : onChanged,
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
  Function(String?)? onChanged, {
  Key? key,
  bool isLoading = false,
  bool enabled = true,
  String? hint,
  String? Function(String?)? validator,
}) {
  return FormField<String>(
    key: key ?? ValueKey('$label||${selectedValue ?? ''}'),
    validator: validator,
    initialValue: selectedValue,
    builder: (FormFieldState<String> state) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
          const SizedBox(height: 6),
          Builder(builder: (btnContext) {
            return InkWell(
              onTap: (!enabled || isLoading) ? null : () async {
                FocusScope.of(context).unfocus();
                
                final RenderBox renderBox = btnContext.findRenderObject() as RenderBox;
                final offset = renderBox.localToGlobal(Offset.zero);
                final size = renderBox.size;
                final screenSize = MediaQuery.of(context).size;
                
                double topPadding = offset.dy + size.height;
                bool showAbove = false;
                
                if (topPadding + 280 > screenSize.height) {
                   showAbove = true;
                }

                final String? result = await showGeneralDialog<String>(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: 'Dismiss',
                  barrierColor: Colors.transparent,
                  transitionDuration: const Duration(milliseconds: 150),
                  pageBuilder: (context, anim1, anim2) {
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          behavior: HitTestBehavior.opaque,
                          child: Container(color: Colors.transparent),
                        ),
                        Positioned(
                          left: offset.dx,
                          top: showAbove ? null : offset.dy + size.height,
                          bottom: showAbove ? (screenSize.height - offset.dy + 8) : null,
                          width: size.width,
                          child: FadeTransition(
                            opacity: anim1,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(8),
                              clipBehavior: Clip.antiAlias,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: showAbove ? (offset.dy - MediaQuery.of(context).padding.top - 20).clamp(100.0, 300.0) : 300,
                                ),
                                child: SearchableDropdownMenu(
                                  items: items,
                                  initialValue: state.value,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
                // Dismiss keyboard/focus that may have been restored when dialog closed
                FocusManager.instance.primaryFocus?.unfocus();
                if (result != null) {
                  state.didChange(result);
                  if (onChanged != null) onChanged(result);
                }
              },
              focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
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
                  fillColor: enabled ? Colors.white : Colors.grey.shade100,
                  filled: true,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.value != null && state.value!.isNotEmpty)
                        GestureDetector(
                          onTap: !enabled ? null : () {
                            state.didChange(null);
                            if (onChanged != null) onChanged(null);
                          },
                          child: Icon(Icons.clear, size: 20, color: !enabled ? Colors.grey.shade300 : Colors.grey),
                        ),
                      isLoading 
                        ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator(strokeWidth: 2)))
                        : const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                  errorText: state.errorText,
                ),
                child: Text(
                  (state.value != null && items.contains(state.value)) ? state.value! : (hint ?? '-Select-'),
                  style: TextStyle(
                    fontSize: 14,
                    color: (state.value != null && items.contains(state.value)) 
                      ? (enabled ? Colors.black87 : Colors.grey.shade700) 
                      : Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }),
        ],
      );
    }
  );
}

class SearchableDropdownMenu extends StatefulWidget {
  final List<String> items;
  final String? initialValue;

  const SearchableDropdownMenu({required this.items, this.initialValue});

  @override
  State<SearchableDropdownMenu> createState() => SearchableDropdownMenuState();
}

class SearchableDropdownMenuState extends State<SearchableDropdownMenu> {
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search...',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.blue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                fillColor: Colors.grey.shade50,
                filled: true,
              ),
              onChanged: _filterItems,
            ),
          ),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: filteredItems.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final isSelected = item == widget.initialValue;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          color: isSelected ? Colors.blue.withOpacity(0.08) : null,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected ? Colors.blue.shade700 : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, size: 18, color: Colors.blue.shade600),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
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
  bool readOnly = false,
  bool isUpperCase = true, // always uppercase — used for Family Code across all forms
  FocusNode? focusNode,
  List<TextInputFormatter>? inputFormatters,
  String? Function(String?)? validator,
}) {
  final List<TextInputFormatter> effectiveFormatters = [...?(inputFormatters ?? [])];
  if (isUpperCase) {
    effectiveFormatters.add(UpperCaseTextFormatter());
  }

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
              readOnly: readOnly,
              focusNode: focusNode,
              style: readOnly ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16) : null,
              textCapitalization: isUpperCase ? TextCapitalization.characters : TextCapitalization.none,
              inputFormatters: effectiveFormatters,
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
                fillColor: (enabled == false || readOnly) ? Colors.grey.shade100 : Colors.white,
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

Widget formRadioOption<T>({
  required String label,
  required T value,
  required T? groupValue,
  required ValueChanged<T?>? onChanged,
  bool enabled = true,
}) {
  final bool isSelected = groupValue == value;
  final effectiveOnChanged = !enabled ? null : onChanged;
  return InkWell(
    onTap: effectiveOnChanged == null ? null : () {
      if (isSelected) {
        effectiveOnChanged(null); 
      } else {
        effectiveOnChanged(value);
      }
    },
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IgnorePointer(
          child: Radio<T>(
            value: value,
            groupValue: groupValue,
            onChanged: effectiveOnChanged == null ? null : (_) {},
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label, 
            style: TextStyle(
              fontSize: 14, 
              color: !enabled ? Colors.grey.shade600 : Colors.black87
            )
          )
        ),
      ],
    ),
  );
}

/// Normalises a raw gender string to '(1) Male' or '(0) Female'.
/// Handles personal_details format ('(1) Male'), bare format ('Male'),
/// and old saved records from form pages ('Male'/'Female').
/// Matches [raw] against [list] using: exact → case-insensitive exact → contains.
/// Returns null if [raw] is null/empty or no match found.
String? matchInterviewerName(dynamic raw, List<String> list) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  // 1. Exact match
  if (list.contains(s)) return s;
  // 2. Case-insensitive exact match
  final lower = s.toLowerCase();
  for (final item in list) {
    if (item.toLowerCase() == lower) return item;
  }
  // 3. Case-insensitive contains (handles abbreviated or partial REACH names)
  for (final item in list) {
    if (item.toLowerCase().contains(lower) || lower.contains(item.toLowerCase())) return item;
  }
  // 4. Return the raw value as-is so it isn't silently dropped
  return s;
}

String? normalizeGender(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().toLowerCase().trim();
  if (s.isEmpty) return null;
  if (s.contains('female') || s == '0') return '(0) Female';
  if (s.contains('male') || s == '1') return '(1) Male';
  return raw.toString();
}

Widget adminBulkDeleteBar({
  required bool isAdmin,
  required int totalCount,
  required int selectedCount,
  required VoidCallback onToggleAll,
  required VoidCallback onDeleteSelected,
}) {
  if (!isAdmin || totalCount == 0) return const SizedBox.shrink();
  return Container(
    color: selectedCount > 0 ? Colors.red.shade50 : Colors.grey.shade100,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: [
        Checkbox(
          value: selectedCount == totalCount,
          onChanged: (_) => onToggleAll(),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        GestureDetector(
          onTap: onToggleAll,
          child: Text(
            selectedCount == 0 ? 'Select all' : '$selectedCount of $totalCount selected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selectedCount > 0 ? Colors.red.shade700 : Colors.grey.shade700,
            ),
          ),
        ),
        const Spacer(),
        if (selectedCount > 0)
          ElevatedButton.icon(
            onPressed: onDeleteSelected,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete Selected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ],
    ),
  );
}

Widget reportItemLeading({
  required bool isAdmin,
  required bool isSelected,
  required VoidCallback onToggle,
  required int index,
  required bool needsSync,
}) {
  if (isAdmin) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Checkbox(
        value: isSelected,
        onChanged: (_) => onToggle(),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      Icon(needsSync ? Icons.sync : Icons.cloud_done, color: needsSync ? Colors.orange : Colors.green, size: 14),
    ]);
  }
  return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade500, fontSize: 13)),
    const SizedBox(height: 4),
    Icon(needsSync ? Icons.sync : Icons.cloud_done, color: needsSync ? Colors.orange : Colors.green, size: 16),
  ]);
}

Widget formCheckboxOption({
  required String label,
  required bool value,
  required ValueChanged<bool?>? onChanged,
  bool enabled = true,
}) {
  final effectiveOnChanged = !enabled ? null : onChanged;
  return InkWell(
    onTap: effectiveOnChanged == null ? null : () => effectiveOnChanged(!value),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: effectiveOnChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label, 
            style: TextStyle(
              fontSize: 14, 
              color: !enabled ? Colors.grey.shade600 : Colors.black87
            )
          )
        ),
      ],
    ),
  );
}
