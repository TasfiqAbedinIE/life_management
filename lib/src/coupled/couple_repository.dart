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

  // ===== TOUR PLANS =====

  Future<List<Map<String, dynamic>>> fetchTourPlans(String coupleId) async {
    final res = await _client
        .from('couple_tour_plans')
        .select()
        .eq('couple_id', coupleId)
        .order('probable_date', ascending: true);

    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<String?> addTourPlan({
    required String coupleId,
    required String title,
    required String description,
    required double? budget,
    required DateTime? probableDate,
    required String status,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return 'Not authenticated';

    try {
      await _client.from('couple_tour_plans').insert({
        'couple_id': coupleId,
        'title': title,
        'description': description,
        'estimated_budget': budget,
        'probable_date': probableDate?.toIso8601String().split('T').first,
        'status': status,
        'created_by': user.id,
      });
      return null;
    } catch (_) {
      return 'Failed to save tour plan';
    }
  }

  Future<String?> updateTourPlan({
    required String planId,
    required String title,
    required String description,
    required double? budget,
    required DateTime? probableDate,
    required String status,
  }) async {
    try {
      await _client
          .from('couple_tour_plans')
          .update({
            'title': title,
            'description': description,
            'estimated_budget': budget,
            'probable_date': probableDate?.toIso8601String().split('T').first,
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', planId);
      return null;
    } catch (_) {
      return 'Failed to update tour plan';
    }
  }

  Future<String?> deleteTourPlan(String planId) async {
    try {
      await _client.from('couple_tour_plans').delete().eq('id', planId);
      return null;
    } catch (_) {
      return 'Failed to delete tour plan';
    }
  }

  // ===== SHOPPING LISTS =====

  Future<List<Map<String, dynamic>>> fetchShoppingLists(String coupleId) async {
    final res = await _client
        .from('shopping_lists')
        .select('id, name, description, created_at, owner_id, couple_id')
        .eq('couple_id', coupleId)
        .order('created_at', ascending: false);

    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<String?> createShoppingList({
    required String coupleId,
    required String name,
    String? description,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return 'Not authenticated';

    try {
      await _client.from('shopping_lists').insert({
        'owner_id': user.id,
        'couple_id': coupleId,
        'name': name,
        'description': description,
        // Kept for backward compatibility with the existing schema.
        'is_shared': true,
      });
      return null;
    } catch (_) {
      return 'Failed to create shopping list';
    }
  }

  Future<Map<String, dynamic>> fetchShoppingList(String listId) async {
    final res = await _client
        .from('shopping_lists')
        .select('id, name, description, owner_id, couple_id')
        .eq('id', listId)
        .single();

    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> fetchShoppingItems(String listId) async {
    final res = await _client
        .from('shopping_items')
        .select(
          'id, name, quantity, tag, target_date, urgency, note, is_done, created_at, created_by',
        )
        .eq('list_id', listId)
        .order('is_done', ascending: true)
        .order('target_date', ascending: true);

    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<Map<String, Map<String, dynamic>>> fetchProfilesByIds(
    Iterable<String> userIds,
  ) async {
    final ids = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};

    final res = await _client
        .from('profiles')
        .select('id, full_name, email')
        .inFilter('id', ids);

    final profiles = List<Map<String, dynamic>>.from(res as List);
    return {for (final p in profiles) p['id'] as String: p};
  }

  Future<String?> setShoppingItemDone({
    required String itemId,
    required bool isDone,
  }) async {
    try {
      await _client
          .from('shopping_items')
          .update({'is_done': isDone})
          .eq('id', itemId);
      return null;
    } catch (_) {
      return 'Failed to update item';
    }
  }

  Future<String?> addShoppingItem({
    required String listId,
    required String name,
    String? quantity,
    required String tag,
    required String urgency,
    String? note,
    DateTime? targetDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return 'Not authenticated';

    try {
      await _client.from('shopping_items').insert({
        'list_id': listId,
        'name': name,
        'quantity': quantity,
        'tag': tag,
        'urgency': urgency,
        'note': note,
        'target_date': targetDate?.toIso8601String().split('T').first,
        'created_by': user.id,
      });
      return null;
    } catch (_) {
      return 'Failed to save item';
    }
  }

  Future<String?> updateShoppingItem({
    required String itemId,
    required String name,
    String? quantity,
    required String tag,
    required String urgency,
    String? note,
    DateTime? targetDate,
  }) async {
    try {
      await _client
          .from('shopping_items')
          .update({
            'name': name,
            'quantity': quantity,
            'tag': tag,
            'urgency': urgency,
            'note': note,
            'target_date': targetDate?.toIso8601String().split('T').first,
          })
          .eq('id', itemId);
      return null;
    } catch (_) {
      return 'Failed to save item';
    }
  }

  Future<String?> deleteShoppingItem(String itemId) async {
    try {
      await _client.from('shopping_items').delete().eq('id', itemId);
      return null;
    } catch (_) {
      return 'Failed to delete item';
    }
  }
}
