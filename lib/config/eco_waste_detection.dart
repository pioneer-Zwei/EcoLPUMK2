class WasteDetection {
  final String name;
  final String category;
  final double confidence;
  final String reasoning;
  final bool isWaste;
  final String? disposalTip;
  final String? recyclingTip;

  WasteDetection({
    required this.name,
    required this.category,
    required this.confidence,
    required this.reasoning,
    required this.isWaste,
    this.disposalTip,
    this.recyclingTip,
  });

  factory WasteDetection.fromJson(Map<String, dynamic> json) {
    return WasteDetection(
      name: json['name'] as String? ?? "Unnamed Item",
      category: (json['category'] as String?)?.toUpperCase() ?? "UNKNOWN",
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reasoning: json['reasoning'] as String? ?? "No reason provided.",
      isWaste: json['is_waste'] as bool? ?? false,
      disposalTip:
          json['disposal_tip'] as String? ?? "No disposal tip available.",
      recyclingTip:
          json['recycling_tip'] as String? ?? "No recycling tip available.",
    );
  }
}