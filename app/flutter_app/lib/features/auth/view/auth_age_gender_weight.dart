import 'package:flutter/material.dart';
import '../widgets/dynamic_scale_picker.dart';
import '../../../core/widgets/primarybutton.dart';
import '../../../core/theme/app_colour_theme.dart';
class AgePickerScreen extends StatelessWidget {
  final VoidCallback  onBack;
  final ValueChanged<int> onNext;
  const AgePickerScreen({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return DynamicScalePicker(
      title: "How Old Are You", min: 12, max: 90, initial: 20,
      onNext: onNext, 
      onBack: onBack,
    );
  }
}

class WeightPickerScreen extends StatelessWidget {
  final VoidCallback onBack;
  final ValueChanged<int> onNext;
  const WeightPickerScreen({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return DynamicScalePicker(
      title: "What is your weight", min: 30, max: 200, initial: 70, unit: "kg",
      onNext: onNext, 
      onBack: onBack,
    );
  }
}
class GenderScreen extends StatefulWidget {
  final Function(String) onNext; // Updated to pass back the gender
  const GenderScreen({super.key, required this.onNext});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String? selectedGender;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Step 1 of 3", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              const Text("What's your gender?", 
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              
              _genderTile("Male", Icons.male),
              const SizedBox(height: 20),
              _genderTile("Female", Icons.female),
              const SizedBox(height: 20),
              _genderTile("Other", Icons.person_outline),
              
              const Spacer(),
              Center(
                child: PrimaryButton(
                  text: "Next",
                  // Pass the selected gender back to the parent
                  onPressed: selectedGender != null 
                    ? () => widget.onNext(selectedGender!)
                    : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _genderTile(String gender, IconData icon) {
    bool isSelected = selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => selectedGender = gender),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryRed : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black),
            const SizedBox(width: 20),
            Text(gender, 
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w500
              )),
          ],
        ),
      ),
    );
  }
}