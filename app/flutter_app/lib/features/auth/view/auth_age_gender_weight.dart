import 'package:flutter/material.dart';
import '../widgets/dynamic_scale_picker.dart';

class AgePickerScreen extends StatelessWidget {
  final VoidCallback onNext, onBack;
  const AgePickerScreen({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return DynamicScalePicker(
      title: "How Old Are You", min: 12, max: 90, initial: 20,
      onNext: onNext, onBack: onBack,
    );
  }
}

class WeightPickerScreen extends StatelessWidget {
  final VoidCallback onNext, onBack;
  const WeightPickerScreen({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return DynamicScalePicker(
      title: "What is your weight", min: 30, max: 200, initial: 70, unit: "kg",
      onNext: onNext, onBack: onBack,
    );
  }
}