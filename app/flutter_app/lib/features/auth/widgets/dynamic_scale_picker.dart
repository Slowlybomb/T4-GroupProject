import 'package:flutter/material.dart';
import '../../../core/widgets/navigation_row.dart';

class DynamicScalePicker extends StatefulWidget {
  final String title, unit;
  final int min, max, initial;
  final VoidCallback onNext, onBack;

  const DynamicScalePicker({
    super.key,
    required this.title,
    required this.min,
    required this.max,
    required this.initial,
    required this.onNext,
    required this.onBack,
    this.unit = "",
  });

  @override
  State<DynamicScalePicker> createState() => _DynamicScalePickerState();
}

class _DynamicScalePickerState extends State<DynamicScalePicker> {
  late FixedExtentScrollController _controller;
  final double itemHeight = 70.0;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: widget.initial - widget.min,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      body: Column(
        children: [
          const SizedBox(height: 80),
          Text(
            widget.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: itemHeight,
              physics: const FixedExtentScrollPhysics(),
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  return Center(
                    child: Text(
                      "${widget.min + index} ${widget.unit}",
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
                childCount: widget.max - widget.min + 1,
              ),
            ),
          ),
          NavigationRow(onBack: widget.onBack, onNext: widget.onNext),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
