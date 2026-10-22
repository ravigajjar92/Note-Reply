/// The ink colours offered in the settings sheet.
enum InkColor { black, blue, red, green, purple }

/// The paper drawn behind the ink.
enum PaperBackground { blank, dotGrid }

/// How the replay canvas looks. Shared by every note.
final class CanvasSettings {
  const CanvasSettings({
    this.inkColor = InkColor.black,
    this.paper = PaperBackground.blank,
    this.showPenTip = true,
  });

  final InkColor inkColor;
  final PaperBackground paper;

  /// Whether to draw a dot at the pen position while the pen is down.
  final bool showPenTip;

  CanvasSettings copyWith({
    InkColor? inkColor,
    PaperBackground? paper,
    bool? showPenTip,
  }) => CanvasSettings(
    inkColor: inkColor ?? this.inkColor,
    paper: paper ?? this.paper,
    showPenTip: showPenTip ?? this.showPenTip,
  );

  @override
  bool operator ==(Object other) =>
      other is CanvasSettings &&
      other.inkColor == inkColor &&
      other.paper == paper &&
      other.showPenTip == showPenTip;

  @override
  int get hashCode => Object.hash(inkColor, paper, showPenTip);

  @override
  String toString() => 'CanvasSettings($inkColor, $paper, $showPenTip)';
}
