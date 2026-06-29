import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_management_models.dart';

class ProjectManagementException implements Exception {
  const ProjectManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProjectManagementRepository {
  ProjectManagementRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const taskAttachmentBucket = 'task-attachments';

  User get _currentUser {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ProjectManagementException('You need to sign in first.');
    }
    return user;
  }

  String get _currentUserId => _currentUser.id;

  String get currentUserId => _currentUserId;

  static const _projectSelect = '''
id,
name,
description,
owner_id,
status,
start_date,
target_end_date,
archived_at,
created_at,
updated_at,
created_by,
updated_by
''';

  static const _taskSelect = '''
id,
project_id,
parent_task_id,
title,
description,
status,
priority,
assignee_id,
reporter_id,
reviewer_id,
assigned_by,
start_date,
due_date,
completed_at,
estimated_minutes,
actual_minutes,
progress_percent,
order_index,
created_at,
updated_at,
created_by,
updated_by,
project_task_label_map!left(
  project_task_labels!inner(id, project_id, name, color_hex)
)
''';

  Never _wrapError(Object error, [String? fallback]) {
    if (error is ProjectManagementException) {
      throw error;
    }
    if (error is PostgrestException) {
      throw ProjectManagementException(error.message);
    }
    if (error is StorageException) {
      throw ProjectManagementException(error.message);
    }
    throw ProjectManagementException(fallback ?? error.toString());
  }

  Future<ProjectModel> createProject({
    required String name,
    String description = '',
    ProjectStatus status = ProjectStatus.planning,
    DateTime? startDate,
    DateTime? targetEndDate,
  }) async {
    try {
      final response = await _client
          .from('projects')
          .insert({
            'name': name.trim(),
            'description': description.trim(),
            'owner_id': _currentUserId,
            'status': projectStatusToValue(status),
            'start_date': _dateOnly(startDate),
            'target_end_date': _dateOnly(targetEndDate),
            'created_by': _currentUserId,
            'updated_by': _currentUserId,
          })
          .select(_projectSelect)
          .single();
      return ProjectModel.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      _wrapError(error, 'Failed to create project.');
    }
  }

  Future<ProjectModel> updateProject({
    required String projectId,
    String? name,
    String? description,
    ProjectStatus? status,
    DateTime? startDate,
    DateTime? targetEndDate,
    String? ownerId,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (name != null) 'name': name.trim(),
        if (description != null) 'description': description.trim(),
        if (status != null) 'status': projectStatusToValue(status),
        if (ownerId != null) 'owner_id': ownerId,
        'updated_by': _currentUserId,
      };
      if (startDate != null) payload['start_date'] = _dateOnly(startDate);
      if (targetEndDate != null) {
        payload['target_end_date'] = _dateOnly(targetEndDate);
      }

      final response = await _client
          .from('projects')
          .update(payload)
          .eq('id', projectId)
          .select(_projectSelect)
          .single();
      return ProjectModel.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      _wrapError(error, 'Failed to update project.');
    }
  }

  Future<ProjectModel> archiveProject(String projectId) async {
    return updateProject(projectId: projectId, status: ProjectStatus.archived);
  }

  Future<void> deleteProject(String projectId) async {
    try {
      await _client.from('projects').delete().eq('id', projectId);
    } catch (error) {
      _wrapError(error, 'Failed to delete project.');
    }
  }

  Future<List<ProjectModel>> getProjectsForCurrentUser({
    bool includeArchived = false,
  }) async {
    try {
      var query = _client.from('projects').select(_projectSelect);
      if (!includeArchived) {
        query = query.isFilter('archived_at', null);
      }
      final response =
          await query.order('updated_at', ascending: false) as List<dynamic>;
      final projects = response
          .map((item) => ProjectModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      final summaries = await Future.wait(
        projects.map((project) => getProjectSummary(project.id)),
      );
      return [
        for (var i = 0; i < projects.length; i++)
          ProjectModel(
            id: projects[i].id,
            name: projects[i].name,
            description: projects[i].description,
            ownerId: projects[i].ownerId,
            status: projects[i].status,
            startDate: projects[i].startDate,
            targetEndDate: projects[i].targetEndDate,
            archivedAt: projects[i].archivedAt,
            createdAt: projects[i].createdAt,
            updatedAt: projects[i].updatedAt,
            createdBy: projects[i].createdBy,
            updatedBy: projects[i].updatedBy,
            summary: summaries[i],
          ),
      ];
    } catch (error) {
      _wrapError(error, 'Failed to load projects.');
    }
  }

  Future<ProjectModel> getProjectDetails(String projectId) async {
    try {
      final response = await _client
          .from('projects')
          .select(_projectSelect)
          .eq('id', projectId)
          .single();
      final project = ProjectModel.fromMap(Map<String, dynamic>.from(response));
      final summary = await getProjectSummary(projectId);
      return ProjectModel(
        id: project.id,
        name: project.name,
        description: project.description,
        ownerId: project.ownerId,
        status: project.status,
        startDate: project.startDate,
        targetEndDate: project.targetEndDate,
        archivedAt: project.archivedAt,
        createdAt: project.createdAt,
        updatedAt: project.updatedAt,
        createdBy: project.createdBy,
        updatedBy: project.updatedBy,
        summary: summary,
      );
    } catch (error) {
      _wrapError(error, 'Failed to load project details.');
    }
  }

  Future<List<UserProfileModel>> searchRegisteredUsersForProjectMemberAdd(
    String query,
  ) async {
    try {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return const [];
      final response = await _client
          .from('profiles')
          .select('id, email, full_name')
          .or('email.ilike.%$trimmed%,full_name.ilike.%$trimmed%')
          .limit(20);
      return (response as List<dynamic>)
          .map(
            (item) => UserProfileModel.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (error) {
      _wrapError(error, 'Failed to search users.');
    }
  }

  Future<ProjectMemberModel> addProjectMember({
    required String projectId,
    required String userId,
    required ProjectMemberRole role,
  }) async {
    try {
      final response = await _client
          .from('project_members')
          .insert({
            'project_id': projectId,
            'user_id': userId,
            'role': projectMemberRoleToValue(role),
            'added_by': _currentUserId,
          })
          .select('id, project_id, user_id, role, joined_at, added_by')
          .single();
      return ProjectMemberModel.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      _wrapError(error, 'Failed to add member.');
    }
  }

  Future<void> removeProjectMember(String membershipId) async {
    try {
      await _client.from('project_members').delete().eq('id', membershipId);
    } catch (error) {
      _wrapError(error, 'Failed to remove member.');
    }
  }

  Future<List<ProjectMemberModel>> getProjectMembers(String projectId) async {
    try {
      final memberResponse = await _client
          .from('project_members')
          .select('id, project_id, user_id, role, joined_at, added_by')
          .eq('project_id', projectId)
          .order('joined_at');
      final memberRows = (memberResponse as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (memberRows.isEmpty) return const [];

      final userIds = memberRows
          .map((member) => member['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final profilesById = <String, Map<String, dynamic>>{};
      if (userIds.isNotEmpty) {
        final profileResponse = await _client
            .from('profiles')
            .select('id, email, full_name')
            .inFilter('id', userIds);
        for (final item in profileResponse as List<dynamic>) {
          final profile = Map<String, dynamic>.from(item);
          final id = profile['id']?.toString();
          if (id != null) profilesById[id] = profile;
        }
      }

      return memberRows.map((member) {
        final profile = profilesById[member['user_id']?.toString()];
        return ProjectMemberModel.fromMap({
          ...member,
          if (profile != null) 'profiles': profile,
        });
      }).toList();
    } catch (error) {
      _wrapError(error, 'Failed to load project members.');
    }
  }

  Future<TaskModel> createTask({
    required String projectId,
    required String title,
    String description = '',
    String? parentTaskId,
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.medium,
    String? assigneeId,
    String? reviewerId,
    DateTime? startDate,
    DateTime? dueDate,
    int? estimatedMinutes,
    int? actualMinutes,
    int progressPercent = 0,
    double? orderIndex,
  }) async {
    try {
      final response = await _client
          .from('project_tasks')
          .insert({
            'project_id': projectId,
            'parent_task_id': parentTaskId,
            'title': title.trim(),
            'description': description.trim(),
            'status': taskStatusToValue(status),
            'priority': taskPriorityToValue(priority),
            'assignee_id': assigneeId,
            'reporter_id': _currentUserId,
            'reviewer_id': reviewerId,
            'start_date': _dateOnly(startDate),
            'due_date': dueDate?.toUtc().toIso8601String(),
            'estimated_minutes': estimatedMinutes,
            'actual_minutes': actualMinutes,
            'progress_percent': progressPercent,
            'order_index': orderIndex,
            'created_by': _currentUserId,
            'updated_by': _currentUserId,
          })
          .select(_taskSelect)
          .single();
      return TaskModel.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      _wrapError(error, 'Failed to create task.');
    }
  }

  Future<TaskModel> updateTask({
    required String taskId,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    String? assigneeId,
    String? reviewerId,
    DateTime? startDate,
    DateTime? dueDate,
    int? estimatedMinutes,
    int? actualMinutes,
    int? progressPercent,
    double? orderIndex,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (title != null) 'title': title.trim(),
        if (description != null) 'description': description.trim(),
        if (status != null) 'status': taskStatusToValue(status),
        if (priority != null) 'priority': taskPriorityToValue(priority),
        if (assigneeId != null) 'assignee_id': assigneeId,
        if (reviewerId != null) 'reviewer_id': reviewerId,
        if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
        if (actualMinutes != null) 'actual_minutes': actualMinutes,
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (orderIndex != null) 'order_index': orderIndex,
        'updated_by': _currentUserId,
      };
      if (startDate != null) payload['start_date'] = _dateOnly(startDate);
      if (dueDate != null) {
        payload['due_date'] = dueDate.toUtc().toIso8601String();
      }

      final response = await _client
          .from('project_tasks')
          .update(payload)
          .eq('id', taskId)
          .select(_taskSelect)
          .single();
      return TaskModel.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      _wrapError(error, 'Failed to update task.');
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _client.from('project_tasks').delete().eq('id', taskId);
    } catch (error) {
      _wrapError(error, 'Failed to delete task.');
    }
  }

  Future<TaskModel> assignTask({
    required String taskId,
    required String? assigneeId,
  }) {
    return updateTask(taskId: taskId, assigneeId: assigneeId);
  }

  Future<TaskModel> moveTaskStatus({
    required String taskId,
    required TaskStatus status,
    required double orderIndex,
  }) {
    return updateTask(taskId: taskId, status: status, orderIndex: orderIndex);
  }

  Future<TaskModel> reorderTask({
    required String taskId,
    required double orderIndex,
  }) {
    return updateTask(taskId: taskId, orderIndex: orderIndex);
  }

  Future<List<TaskModel>> getProjectTasks({
    String? projectId,
    TaskQueryFilter filter = const TaskQueryFilter(),
    String sortBy = 'updated_at',
    bool ascending = false,
  }) async {
    try {
      dynamic query = _client.from('project_tasks').select(_taskSelect);
      final resolvedProjectId = filter.projectId ?? projectId;
      if (resolvedProjectId != null) {
        query = query.eq('project_id', resolvedProjectId);
      }
      if (filter.assigneeId != null) {
        query = query.eq('assignee_id', filter.assigneeId!);
      }
      if (filter.status != null) {
        query = query.eq('status', taskStatusToValue(filter.status!));
      }
      if (filter.priority != null) {
        query = query.eq('priority', taskPriorityToValue(filter.priority!));
      }
      if (filter.overdueOnly) {
        query = query
            .lt('due_date', DateTime.now().toUtc().toIso8601String())
            .neq('status', 'done');
      }
      final response =
          await query.order(sortBy, ascending: ascending) as List<dynamic>;
      return response
          .map((item) => TaskModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (error) {
      _wrapError(error, 'Failed to load tasks.');
    }
  }

  Future<List<TaskModel>> getMyTasks() async {
    try {
      final userId = _currentUserId;
      final response =
          await _client
                  .from('project_tasks')
                  .select(_taskSelect)
                  .or('assignee_id.eq.$userId,reporter_id.eq.$userId')
                  .order('due_date', ascending: true, nullsFirst: false)
                  .order('created_at', ascending: false)
              as List<dynamic>;
      return response
          .map((item) => TaskModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (error) {
      _wrapError(error, 'Failed to load your tasks.');
    }
  }

  Future<Map<TaskStatus, List<TaskModel>>> getBoardData(
    String projectId,
  ) async {
    final tasks = await getProjectTasks(
      projectId: projectId,
      sortBy: 'order_index',
      ascending: true,
    );
    final board = <TaskStatus, List<TaskModel>>{
      for (final status in TaskStatus.values) status: <TaskModel>[],
    };
    for (final task in tasks) {
      board[task.status]!.add(task);
    }
    return board;
  }

  Future<List<TaskModel>> getCalendarTasks({
    required String projectId,
    String? assigneeId,
  }) {
    return getProjectTasks(
      projectId: projectId,
      filter: TaskQueryFilter(projectId: projectId, assigneeId: assigneeId),
      sortBy: 'due_date',
      ascending: true,
    );
  }

  Future<TaskCommentModel> addComment({
    required String taskId,
    required String commentText,
  }) async {
    try {
      final response = await _client
          .from('project_task_comments')
          .insert({
            'task_id': taskId,
            'user_id': _currentUserId,
            'comment_text': commentText.trim(),
            'metadata': {'mentions': <String>[]},
          })
          .select()
          .single();
      return TaskCommentModel.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      _wrapError(error, 'Failed to add comment.');
    }
  }

  Future<List<TaskCommentModel>> getTaskComments(String taskId) async {
    try {
      final response = await _client
          .from('project_task_comments')
          .select()
          .eq('task_id', taskId)
          .order('created_at', ascending: true);
      return (response as List<dynamic>)
          .map(
            (item) => TaskCommentModel.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (error) {
      _wrapError(error, 'Failed to load comments.');
    }
  }

  Future<TaskAttachmentModel> uploadTaskAttachment({
    required String projectId,
    required String taskId,
    required File file,
    String? contentType,
  }) async {
    try {
      final fileName = path.basename(file.path);
      final storagePath =
          '$_currentUserId/$projectId/$taskId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _client.storage
          .from(taskAttachmentBucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: contentType),
          );

      final response = await _client
          .from('project_task_attachments')
          .insert({
            'project_id': projectId,
            'task_id': taskId,
            'bucket_id': taskAttachmentBucket,
            'storage_path': storagePath,
            'file_name': fileName,
            'content_type': contentType,
            'file_size_bytes': await file.length(),
            'uploaded_by': _currentUserId,
            'created_by': _currentUserId,
            'updated_by': _currentUserId,
          })
          .select()
          .single();
      return TaskAttachmentModel.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      _wrapError(error, 'Failed to upload attachment.');
    }
  }

  Future<List<TaskAttachmentModel>> getTaskAttachments(String taskId) async {
    try {
      final response = await _client
          .from('project_task_attachments')
          .select()
          .eq('task_id', taskId)
          .order('created_at', ascending: true);
      return (response as List<dynamic>)
          .map(
            (item) =>
                TaskAttachmentModel.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (error) {
      _wrapError(error, 'Failed to load attachments.');
    }
  }

  Future<List<ActivityLogModel>> getActivityFeed(String projectId) async {
    try {
      final response = await _client
          .from('project_task_activity_logs')
          .select()
          .eq('project_id', projectId)
          .order('created_at', ascending: false)
          .limit(100);
      return (response as List<dynamic>)
          .map(
            (item) => ActivityLogModel.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (error) {
      _wrapError(error, 'Failed to load activity feed.');
    }
  }

  Future<ProjectSummary> getProjectSummary(String projectId) async {
    try {
      final response = await _client.rpc(
        'get_project_summary',
        params: {'p_project_id': projectId},
      );
      final rows = response as List<dynamic>;
      if (rows.isEmpty) {
        return ProjectSummary(
          projectId: projectId,
          totalTasks: 0,
          doneTasks: 0,
          overdueTasks: 0,
          inProgressTasks: 0,
          todoTasks: 0,
          reviewTasks: 0,
          completionPercent: 0,
        );
      }
      return ProjectSummary.fromMap(Map<String, dynamic>.from(rows.first));
    } catch (error) {
      _wrapError(error, 'Failed to load project summary.');
    }
  }

  String? _dateOnly(DateTime? value) =>
      value?.toIso8601String().split('T').first;
}
