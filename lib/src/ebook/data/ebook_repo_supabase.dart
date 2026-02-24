import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/ebook.dart';
import 'models/ebook_user_state.dart';

class EbookRepoSupabase {
  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all ebooks
  Future<List<Ebook>> fetchEbooks() async {
    final res = await _client
        .from('ebooks')
        .select()
        .order('created_at', ascending: true);

    return (res as List).map((e) => Ebook.fromMap(e)).toList();
  }

  /// Fetch user states (download/progress)
  Future<Map<String, EbookUserState>> fetchUserStates() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};
    final userId = user.id;

    final res = await _client
        .from('ebook_user_state')
        .select()
        .eq('user_id', userId);

    final Map<String, EbookUserState> map = {};
    for (final row in res) {
      final state = EbookUserState.fromMap(row);
      map[state.ebookId] = state;
    }
    return map;
  }

  Future<void> upsertUserState({
    required String ebookId,
    required bool downloaded,
    required double progress,
    String? localPath,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('ebook_user_state').upsert({
      'user_id': user.id,
      'ebook_id': ebookId,
      'downloaded': downloaded,
      'progress': progress.clamp(0.0, 1.0),
      'local_path': localPath,
    }, onConflict: 'user_id,ebook_id');
  }

  /// Signed URL for ebook file
  Future<String> getSignedEbookUrl(String filePath) async {
    final res = await _client.storage
        .from('ebooks')
        .createSignedUrl(filePath, 3600);
    return res;
  }

  /// Signed URL for cover
  Future<String?> getSignedCoverUrl(String? coverPath) async {
    if (coverPath == null) return null;
    return _client.storage.from('ebooks').createSignedUrl(coverPath, 3600);
  }
}
