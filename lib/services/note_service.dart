import 'backend_client.dart';
import '../models/note.dart';

class NoteService {
  final BackendClient client;
  NoteService([BackendClient? client])
    : client = client ?? BackendClient.instance;
  Future<List<Note>> fetchNotes() async =>
      (await client.request('GET', 'notes') as List)
          .map((value) => Note.fromMap(Map<String, dynamic>.from(value)))
          .toList();
  Future<void> createNote(
    String title,
    String content,
    List<String> tags,
  ) async {
    await client.request(
      'POST',
      'notes',
      body: {'title': title, 'content': content, 'tags': tags},
    );
  }

  Future<void> updateNote(
    String id,
    String title,
    String content,
    List<String> tags,
  ) async {
    await client.request(
      'PATCH',
      'notes/$id',
      body: {'title': title, 'content': content, 'tags': tags},
    );
  }

  Future<void> deleteNote(String id) async {
    await client.request('DELETE', 'notes/$id');
  }
}
