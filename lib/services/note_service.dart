import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note.dart';

class NoteService {
  final SupabaseClient supabase;

  NoteService(this.supabase);

  Future<List<Note>> fetchNotes() async {
    final response = await supabase
        .from('notes')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Note.fromMap(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> createNote(String title, String content, List<String> tags) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    await supabase.from('notes').insert({
      'user_id': user.id,
      'title': title,
      'content': content,
      'tags': tags,
    });
  }

  Future<void> updateNote(String id, String title, String content, List<String> tags) async {
    await supabase.from('notes').update({
      'title': title,
      'content': content,
      'tags': tags,
    }).eq('id', id);
  }

  Future<void> deleteNote(String id) async {
    await supabase.from('notes').delete().eq('id', id);
  }
}
