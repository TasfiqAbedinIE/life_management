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
    final userId = _client.auth.currentUser!.id;

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
