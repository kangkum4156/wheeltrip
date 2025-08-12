import 'package:flutter/material.dart';

class RoadFeedbackOptions extends StatefulWidget {
  final List<String> selectedFeatures;
  final ValueChanged<List<String>> onFeaturesChanged;
  final bool isEditable;

  const RoadFeedbackOptions({
    super.key,
    required this.selectedFeatures,
    required this.onFeaturesChanged,
    required this.isEditable,
  });

  @override
  State<RoadFeedbackOptions> createState() => _RoadFeedbackOptionsState();
}

class _RoadFeedbackOptionsState extends State<RoadFeedbackOptions> {
  final List<Map<String, dynamic>> _defaultOptions = [
    {"label": "경사로", "icon": Icons.terrain},
    {"label": "차도", "icon": Icons.directions_car},
    {"label": "인도", "icon": Icons.directions_walk},
  ];

  List<String> _selected = [];
  List<String> _customOptions = [];

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.selectedFeatures);
    _customOptions = _selected
        .where((f) => !_defaultOptions.any((d) => d['label'] == f))
        .toList();
  }

  void _toggleSelection(String label) {
    if (!widget.isEditable) return;
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else {
        _selected.add(label);
      }
    });
    widget.onFeaturesChanged(List<String>.from(_selected));
  }

  void _addCustomOption() async {
    if (!widget.isEditable) return;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("기타 항목 추가"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "새로운 항목 입력"),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("추가"),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _customOptions.add(result);
        _selected.add(result);
      });
      widget.onFeaturesChanged(List<String>.from(_selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleOptions = widget.isEditable
        ? _defaultOptions.map((d) => d['label']).toList() + _customOptions
        : _selected;

    return Wrap(
      spacing: 8,
      children: [
        ...visibleOptions.map((label) {
          final icon = _defaultOptions
              .firstWhere((d) => d['label'] == label, orElse: () => {})
              .putIfAbsent('icon', () => null);

          if (widget.isEditable) {
            final isSelected = _selected.contains(label);
            return ChoiceChip(
              label: Text(label),
              avatar: icon != null
                  ? Icon(icon, size: 18,
                  color: isSelected ? Colors.white : Colors.grey)
                  : null,
              selected: isSelected,
              selectedColor: Colors.blue,
              onSelected: (_) => _toggleSelection(label),
            );
          } else {
            return Chip(
              label: Text(label),
              avatar: icon != null ? Icon(icon, size: 18) : null,
              backgroundColor: Colors.grey[200],
            );
          }
        }),

        if (widget.isEditable)
          ActionChip(
            label: const Text("+기타"),
            onPressed: _addCustomOption,
          ),
      ],
    );
  }
}
