import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/canvas_settings.dart';
import '../../core/ink_style.dart';

/// Opens the "Canvas & Pen Settings" bottom sheet. Changes apply as soon as
/// they're made; there is no Save button.
Future<void> showCanvasSettingsSheet(
  BuildContext context, {
  required ValueListenable<CanvasSettings> settings,
  required ValueChanged<InkColor> onInkColorChanged,
  required ValueChanged<PaperBackground> onPaperChanged,
  required ValueChanged<bool> onShowPenTipChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => CanvasSettingsSheet(
      settings: settings,
      onInkColorChanged: onInkColorChanged,
      onPaperChanged: onPaperChanged,
      onShowPenTipChanged: onShowPenTipChanged,
    ),
  );
}

/// The content of the "Canvas & Pen Settings" bottom sheet.
class CanvasSettingsSheet extends StatelessWidget {
  const CanvasSettingsSheet({
    super.key,
    required this.settings,
    required this.onInkColorChanged,
    required this.onPaperChanged,
    required this.onShowPenTipChanged,
  });

  final ValueListenable<CanvasSettings> settings;
  final ValueChanged<InkColor> onInkColorChanged;
  final ValueChanged<PaperBackground> onPaperChanged;
  final ValueChanged<bool> onShowPenTipChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: ValueListenableBuilder(
          valueListenable: settings,
          builder: (context, settings, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Canvas & Pen Settings',
                  style: textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Ink colour'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final inkColor in InkColor.values)
                    _InkSwatch(
                      key: ValueKey(inkColor),
                      inkColor: inkColor,
                      selected: inkColor == settings.inkColor,
                      onTap: () => onInkColorChanged(inkColor),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Paper background'),
              SegmentedButton<PaperBackground>(
                segments: const [
                  ButtonSegment(
                    value: PaperBackground.blank,
                    label: Text('Blank'),
                    icon: Icon(Icons.crop_square),
                  ),
                  ButtonSegment(
                    value: PaperBackground.dotGrid,
                    label: Text('Dot grid'),
                    icon: Icon(Icons.grid_on),
                  ),
                ],
                selected: {settings.paper},
                onSelectionChanged: (selection) =>
                    onPaperChanged(selection.single),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Display & Coordinates'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Pen Tip Indicator'),
                value: settings.showPenTip,
                onChanged: onShowPenTipChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }
}

/// A round ink-colour choice with a 48 dp touch target. The selected one
/// shows a check mark, so the choice isn't shown by colour alone.
class _InkSwatch extends StatelessWidget {
  const _InkSwatch({
    super.key,
    required this.inkColor,
    required this.selected,
    required this.onTap,
  });

  final InkColor inkColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Ink colour, ${InkStyle.name(inkColor)}',
      // The swatch's own tap handler is excluded below, so give screen
      // readers the action here.
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 48,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? ring : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: InkStyle.color(inkColor),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 32,
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
