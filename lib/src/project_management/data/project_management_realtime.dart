import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectRealtimeSubscriptions {
  ProjectRealtimeSubscriptions({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  RealtimeChannel subscribeToTaskComments({
    required String taskId,
    required void Function(PostgresChangePayload payload) onEvent,
  }) {
    final channel = _client.channel('pm-comments-$taskId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_task_comments',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'task_id',
        value: taskId,
      ),
      callback: onEvent,
    );
    channel.subscribe();
    return channel;
  }

  RealtimeChannel subscribeToTaskUpdates({
    required String projectId,
    required void Function(PostgresChangePayload payload) onEvent,
  }) {
    final channel = _client.channel('pm-project-tasks-$projectId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_tasks',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'project_id',
        value: projectId,
      ),
      callback: onEvent,
    );
    channel.subscribe();
    return channel;
  }

  RealtimeChannel subscribeToBoardRefresh({
    required String projectId,
    required void Function(PostgresChangePayload payload) onEvent,
  }) {
    return subscribeToTaskUpdates(projectId: projectId, onEvent: onEvent);
  }

  RealtimeChannel subscribeToActivityFeed({
    required String projectId,
    required void Function(PostgresChangePayload payload) onEvent,
  }) {
    final channel = _client.channel('pm-activity-$projectId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'project_task_activity_logs',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'project_id',
        value: projectId,
      ),
      callback: onEvent,
    );
    channel.subscribe();
    return channel;
  }

  Future<void> disposeChannel(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
