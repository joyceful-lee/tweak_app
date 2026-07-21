import 'package:flutter_test/flutter_test.dart';
import 'package:tweak_app/utils/note_diff.dart';

void main() {
  test('diffText marks an inserted word', () {
    final chunks = diffText('Add salt', 'Add sea salt');

    expect(chunks.map((chunk) => chunk.op), [
      DiffOp.equal,
      DiffOp.insert,
      DiffOp.equal,
    ]);
    expect(chunks[1].text, 'sea ');
  });

  test('diffText marks removed text', () {
    final chunks = diffText('Bake for 20 minutes', 'Bake for 15 minutes');

    expect(chunks.any((chunk) => chunk.op == DiffOp.delete), isTrue);
    expect(chunks.any((chunk) => chunk.op == DiffOp.insert), isTrue);
  });
}
