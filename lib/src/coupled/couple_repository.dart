import 'package:supabase_flutter/supabase_flutter.dart';

class CoupleRepository {
  final SupabaseClient _client;

  CoupleRepository(this._client);

  /// Check if the current user already has a couple record (pending/active).
  Future<Map<String, dynamic>?> fetchExistingCouple() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final res = await _client
        .from('couples')
        .select()
        .or('user1_id.eq.${user.id},user2_id.eq.${user.id}')
        .neq('status', 'rejected')
        .neq('status', 'cancelled')
        .order('created_at', ascending: false)
        .limit(1);

    if (res is List && res.isNotEmpty) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    return null;
  }

  /// Send couple request by email, only if that email exists in `profiles`.
  /// Returns `null` on success, or error message on failure.
  Future<String?> sendCoupleRequest(String invitedEmail) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return 'You need to be logged in.';
    }

    invitedEmail = invitedEmail.trim();
    if (invitedEmail.isEmpty) {
      return 'Please enter your partner\'s email.';
    }
    if (!invitedEmail.contains('@')) {
      return 'Please enter a valid email address.';
    }

    // 1) Check if email exists in profiles table
    final profileRes = await _client
        .from('profiles')
        .select('id')
        .eq('email', invitedEmail)
        .limit(1);

    if (profileRes is! List || profileRes.isEmpty) {
      return 'This email is not registered in the app yet.\n'
          'Ask your partner to sign up first 💌';
    }

    final targetUser = profileRes.first as Map;
    final String targetUserId = targetUser['id'] as String;

    // Prevent sending request to yourself
    if (targetUserId == user.id) {
      return 'You cannot send a couple request to yourself 😅';
    }

    // 2) Check if current user already has a couple (pending/active)
    final existingCouple = await fetchExistingCouple();
    if (existingCouple != null) {
      final status = existingCouple['status'] as String? ?? '';
      if (status == 'pending') {
        return 'You already sent a love request. 💌';
      }
      if (status == 'active') {
        return 'You\'re already coupled with someone. 💖';
      }
    }

    // 3) Check if there is already a relation between these two users
    final pairCheck = await _client
        .from('couples')
        .select('id, status')
        .or(
          'and(user1_id.eq.${user.id},user2_id.eq.$targetUserId),'
          'and(user1_id.eq.$targetUserId,user2_id.eq.${user.id})',
        )
        .neq('status', 'rejected')
        .neq('status', 'cancelled');

    if (pairCheck is List && pairCheck.isNotEmpty) {
      final status = pairCheck.first['status'] as String? ?? '';
      if (status == 'pending') {
        return 'There is already a pending request between you two 💕';
      }
      if (status == 'active') {
        return 'You are already coupled with this person 💞';
      }
    }

    // 4) Insert new couple request, now with user2_id set
    try {
      await _client.from('couples').insert({
        'user1_id': user.id,
        'user2_id': targetUserId,
        'invited_email': invitedEmail,
        'status': 'pending',
      });

      return null; // success
    } catch (e) {
      return 'Something went wrong while sending your love request.';
    }
  }

  /// Accept a couple request WITH an anniversary date.
  /// Sets status='active' and relationship_date.
  Future<String?> acceptRequestWithDate({
    required String coupleId,
    required DateTime anniversaryDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return 'You need to be logged in.';

    try {
      final dateStr = anniversaryDate.toIso8601String().split('T').first;

      await _client
          .from('couples')
          .update({'status': 'active', 'relationship_date': dateStr})
          .eq('id', coupleId);

      return null;
    } catch (e) {
      return 'Failed to accept the request. Please try again.';
    }
  }

  /// Decline a couple request.
  Future<String?> declineRequest(String coupleId) async {
    final user = _client.auth.currentUser;
    if (user == null) return 'You need to be logged in.';

    try {
      await _client
          .from('couples')
          .update({'status': 'rejected'})
          .eq('id', coupleId);

      return null;
    } catch (e) {
      return 'Failed to decline the request. Please try again.';
    }
  }
}
