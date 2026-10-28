import 'dart:ui';

class TextClue {
  const TextClue(this.text, this.box);
  final String text;
  final Rect box;
  double get area => box.width * box.height;
}

/// OCR candidates are informational. Text presence alone never means findability.
class SceneTextClues {
  const SceneTextClues({this.lines = const [], this.processingMs = 0});
  final List<TextClue> lines;
  final double processingMs;

  static SceneTextClues parse(dynamic value) {
    if (value is! Map ||
        value['status'] != 'available' ||
        value['ageMs'] is num && (value['ageMs'] as num) > 1500) {
      return const SceneTextClues();
    }
    final lines = <TextClue>[];
    for (final line in (value['lines'] as List? ?? [])) {
      if (line is! Map || line['text'] is! String || line['box'] is! List) {
        continue;
      }
      final text = (line['text'] as String).trim();
      if (text
              .toUpperCase()
              .replaceAll('Ü', 'U')
              .replaceAll(RegExp(r'[\s._-]'), '') ==
          'UMALL') {
        continue;
      }
      final coords = line['box'] as List;
      final confidence = line['confidence'];
      if ((text.length < 2 && !RegExp(r'^[0-9]$').hasMatch(text)) ||
          text.length > 32 ||
          coords.length != 4 ||
          coords.any((n) => n is! num || !n.isFinite) ||
          confidence is num && (!confidence.isFinite || confidence < .45)) {
        continue;
      }
      final b = coords.cast<num>().map((n) => n.toDouble()).toList();
      final box = Rect.fromLTRB(
        b[0],
        b[1],
        b[2],
        b[3],
      ).intersect(const Rect.fromLTWH(0, 0, 1, 1));
      if (box.width <= 0 || box.height < .012) continue;
      lines.add(TextClue(text, box));
    }
    lines.sort((a, b) => b.area.compareTo(a.area));
    final unique = <String>{};
    return SceneTextClues(
      lines: lines.where((line) => unique.add(line.text)).take(3).toList(),
      processingMs: value['processingMs'] is num
          ? (value['processingMs'] as num).toDouble()
          : 0,
    );
  }

  Map<String, Object> toJson() => {
    'scope': 'possible text clues; not verified location',
    'processingMs': processingMs,
    'lines': lines
        .map(
          (l) => {
            'text': l.text,
            'box': [l.box.left, l.box.top, l.box.right, l.box.bottom],
          },
        )
        .toList(),
  };
}
