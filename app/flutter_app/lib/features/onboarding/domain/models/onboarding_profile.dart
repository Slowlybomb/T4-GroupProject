class OnboardingProfile {
  // Nullable values preserve compatibility with incremental onboarding rollout.
  final String? gender;
  final int? age;
  final double? weightKg;

  const OnboardingProfile({this.gender, this.age, this.weightKg});
}
