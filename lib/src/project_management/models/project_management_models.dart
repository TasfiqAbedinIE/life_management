enum ProjectStatus { planning, active, onHold, completed, archived }

enum ProjectMemberRole { owner, admin, member, viewer }

enum TaskStatus { todo, inProgress, review, done }

enum TaskPriority { low, medium, high, urgent }

String projectStatusToValue(ProjectStatus value) => switch (value) {
  ProjectStatus.planning => 'planning',
  ProjectStatus.active => 'active',
  ProjectStatus.onHold => 'on_hold',
  ProjectStatus.completed => 'completed',
  ProjectStatus.archived => 'archived',
};

ProjectStatus projectStatusFromValue(String value) => switch (value) {
  'planning' => ProjectStatus.planning,
  'active' => ProjectStatus.active,
  'on_hold' => ProjectStatus.onHold,
  'completed' => ProjectStatus.completed,
  'archived' => ProjectStatus.archived,
  _ => ProjectStatus.planning,
};

String projectMemberRoleToValue(ProjectMemberRole value) => value.name;

ProjectMemberRole projectMemberRoleFromValue(String value) => switch (value) {
  'owner' => ProjectMemberRole.owner,
  'admin' => ProjectMemberRole.admin,
  'member' => ProjectMemberRole.member,
  'viewer' => ProjectMemberRole.viewer,
  _ => ProjectMemberRole.member,
};

String taskStatusToValue(TaskStatus value) => switch (value) {
  TaskStatus.todo => 'todo',
  TaskStatus.inProgress => 'in_progress',
  TaskStatus.review => 'review',
  TaskStatus.done => 'done',
};

TaskStatus taskStatusFromValue(String value) => switch (value) {
  'todo' => TaskStatus.todo,
  'in_progress' => TaskStatus.inProgress,
  'review' => TaskStatus.review,
  'done' => TaskStatus.done,
  _ => TaskStatus.todo,
};

String taskPriorityToValue(TaskPriority value) => value.name;

TaskPriority taskPriorityFromValue(String value) => switch (value) {
  'low' => TaskPriority.low,
  'medium' => TaskPriority.medium,
  'high' => TaskPriority.high,
  'urgent' => TaskPriority.urgent,
  _ => TaskPriority.medium,
};

class ProjectSummary {
  const ProjectSummary({
    required this.projectId,
    required this.totalTasks,
    required this.doneTasks,
    required this.overdueTasks,
    required this.inProgressTasks,
    required this.todoTasks,
    required this.reviewTasks,
    required this.completionPercent,
  });

  final String projectId;
  final int totalTasks;
  final int doneTasks;
  final int overdueTasks;
  final int inProgressTasks;
  final int todoTasks;
  final int reviewTasks;
  final double completionPercent;

  factory ProjectSummary.fromMap(Map<String, dynamic> map) {
    return ProjectSummary(
      projectId: '${map['project_id'] ?? ''}',
      totalTasks: (map['total_tasks'] as num?)?.toInt() ?? 0,
      doneTasks: (map['done_tasks'] as num?)?.toInt() ?? 0,
      overdueTasks: (map['overdue_tasks'] as num?)?.toInt() ?? 0,
      inProgressTasks: (map['in_progress_tasks'] as num?)?.toInt() ?? 0,
      todoTasks: (map['todo_tasks'] as num?)?.toInt() ?? 0,
      reviewTasks: (map['review_tasks'] as num?)?.toInt() ?? 0,
      completionPercent: ((map['completion_percent'] as num?) ?? 0).toDouble(),
    );
  }
}

class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.status,
    required this.startDate,
    required this.targetEndDate,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.summary,
  });

  final String id;
  final String name;
  final String description;
  final String ownerId;
  final ProjectStatus status;
  final DateTime? startDate;
  final DateTime? targetEndDate;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final ProjectSummary? summary;

  bool get isArchived => archivedAt != null || status == ProjectStatus.archived;

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    final summaryMap = map['project_progress_summaries'];
    return ProjectModel(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      description: '${map['description'] ?? ''}',
      ownerId: '${map['owner_id'] ?? ''}',
      status: projectStatusFromValue('${map['status'] ?? 'planning'}'),
      startDate: _parseDateTime(map['start_date']),
      targetEndDate: _parseDateTime(map['target_end_date']),
      archivedAt: _parseDateTime(map['archived_at']),
      createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updated_at']) ?? DateTime.now(),
      createdBy: '${map['created_by'] ?? ''}',
      updatedBy: '${map['updated_by'] ?? ''}',
      summary: summaryMap is Map<String, dynamic>
          ? ProjectSummary.fromMap(summaryMap)
          : null,
    );
  }
}

class ProjectMemberModel {
  const ProjectMemberModel({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.addedBy,
    this.profile,
  });

  final String id;
  final String projectId;
  final String userId;
  final ProjectMemberRole role;
  final DateTime joinedAt;
  final String addedBy;
  final UserProfileModel? profile;

  factory ProjectMemberModel.fromMap(Map<String, dynamic> map) {
    return ProjectMemberModel(
      id: '${map['id'] ?? ''}',
      projectId: '${map['project_id'] ?? ''}',
      userId: '${map['user_id'] ?? ''}',
      role: projectMemberRoleFromValue('${map['role'] ?? 'member'}'),
      joinedAt: _parseDateTime(map['joined_at']) ?? DateTime.now(),
      addedBy: '${map['added_by'] ?? ''}',
      profile: map['profiles'] is Map<String, dynamic>
          ? UserProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TaskLabelModel {
  const TaskLabelModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.colorHex,
  });

  final String id;
  final String projectId;
  final String name;
  final String colorHex;

  factory TaskLabelModel.fromMap(Map<String, dynamic> map) {
    return TaskLabelModel(
      id: '${map['id'] ?? ''}',
      projectId: '${map['project_id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      colorHex: '${map['color_hex'] ?? '#4F62D8'}',
    );
  }
}

class TaskModel {
  const TaskModel({
    required this.id,
    required this.projectId,
    required this.parentTaskId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.assigneeId,
    required this.reporterId,
    required this.reviewerId,
    required this.assignedBy,
    required this.startDate,
    required this.dueDate,
    required this.completedAt,
    required this.estimatedMinutes,
    required this.actualMinutes,
    required this.progressPercent,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.labels = const [],
  });

  final String id;
  final String projectId;
  final String? parentTaskId;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final String? assigneeId;
  final String reporterId;
  final String? reviewerId;
  final String? assignedBy;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final int? estimatedMinutes;
  final int? actualMinutes;
  final int progressPercent;
  final double? orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final List<TaskLabelModel> labels;

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != TaskStatus.done;

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    final rawLabels = map['project_task_label_map'];
    return TaskModel(
      id: '${map['id'] ?? ''}',
      projectId: '${map['project_id'] ?? ''}',
      parentTaskId: map['parent_task_id']?.toString(),
      title: '${map['title'] ?? ''}',
      description: '${map['description'] ?? ''}',
      status: taskStatusFromValue('${map['status'] ?? 'todo'}'),
      priority: taskPriorityFromValue('${map['priority'] ?? 'medium'}'),
      assigneeId: map['assignee_id']?.toString(),
      reporterId: '${map['reporter_id'] ?? ''}',
      reviewerId: map['reviewer_id']?.toString(),
      assignedBy: map['assigned_by']?.toString(),
      startDate: _parseDateTime(map['start_date']),
      dueDate: _parseDateTime(map['due_date']),
      completedAt: _parseDateTime(map['completed_at']),
      estimatedMinutes: (map['estimated_minutes'] as num?)?.toInt(),
      actualMinutes: (map['actual_minutes'] as num?)?.toInt(),
      progressPercent: (map['progress_percent'] as num?)?.toInt() ?? 0,
      orderIndex: (map['order_index'] as num?)?.toDouble(),
      createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updated_at']) ?? DateTime.now(),
      createdBy: '${map['created_by'] ?? ''}',
      updatedBy: '${map['updated_by'] ?? ''}',
      labels: rawLabels is List
          ? rawLabels
                .map(
                  (item) =>
                      item is Map<String, dynamic> &&
                          item['project_task_labels'] is Map<String, dynamic>
                      ? TaskLabelModel.fromMap(
                          item['project_task_labels'] as Map<String, dynamic>,
                        )
                      : null,
                )
                .whereType<TaskLabelModel>()
                .toList()
          : const [],
    );
  }
}

class TaskCommentModel {
  const TaskCommentModel({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.commentText,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String taskId;
  final String userId;
  final String commentText;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TaskCommentModel.fromMap(Map<String, dynamic> map) {
    return TaskCommentModel(
      id: '${map['id'] ?? ''}',
      taskId: '${map['task_id'] ?? ''}',
      userId: '${map['user_id'] ?? ''}',
      commentText: '${map['comment_text'] ?? ''}',
      createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updated_at']) ?? DateTime.now(),
    );
  }
}

class TaskAttachmentModel {
  const TaskAttachmentModel({
    required this.id,
    required this.projectId,
    required this.taskId,
    required this.bucketId,
    required this.storagePath,
    required this.fileName,
    required this.uploadedBy,
    required this.createdAt,
    this.contentType,
    this.fileSizeBytes,
  });

  final String id;
  final String projectId;
  final String taskId;
  final String bucketId;
  final String storagePath;
  final String fileName;
  final String uploadedBy;
  final DateTime createdAt;
  final String? contentType;
  final int? fileSizeBytes;

  factory TaskAttachmentModel.fromMap(Map<String, dynamic> map) {
    return TaskAttachmentModel(
      id: '${map['id'] ?? ''}',
      projectId: '${map['project_id'] ?? ''}',
      taskId: '${map['task_id'] ?? ''}',
      bucketId: '${map['bucket_id'] ?? ''}',
      storagePath: '${map['storage_path'] ?? ''}',
      fileName: '${map['file_name'] ?? ''}',
      uploadedBy: '${map['uploaded_by'] ?? ''}',
      createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
      contentType: map['content_type']?.toString(),
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt(),
    );
  }
}

class ActivityLogModel {
  const ActivityLogModel({
    required this.id,
    required this.projectId,
    required this.taskId,
    required this.actorId,
    required this.actionType,
    required this.createdAt,
    required this.oldValue,
    required this.newValue,
  });

  final String id;
  final String projectId;
  final String? taskId;
  final String actorId;
  final String actionType;
  final DateTime createdAt;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;

  factory ActivityLogModel.fromMap(Map<String, dynamic> map) {
    return ActivityLogModel(
      id: '${map['id'] ?? ''}',
      projectId: '${map['project_id'] ?? ''}',
      taskId: map['task_id']?.toString(),
      actorId: '${map['actor_id'] ?? ''}',
      actionType: '${map['action_type'] ?? ''}',
      createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
      oldValue: map['old_value'] is Map<String, dynamic>
          ? map['old_value'] as Map<String, dynamic>
          : null,
      newValue: map['new_value'] is Map<String, dynamic>
          ? map['new_value'] as Map<String, dynamic>
          : null,
    );
  }
}

class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
  });

  final String id;
  final String? email;
  final String? fullName;

  String get memberName =>
      (fullName?.trim().isNotEmpty ?? false) ? fullName!.trim() : 'Member';

  String get displayName => (fullName?.trim().isNotEmpty ?? false)
      ? fullName!.trim()
      : (email ?? 'User');

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      id: '${map['id'] ?? ''}',
      email: map['email']?.toString(),
      fullName: map['full_name']?.toString(),
    );
  }
}

class TaskQueryFilter {
  const TaskQueryFilter({
    this.projectId,
    this.assigneeId,
    this.status,
    this.priority,
    this.overdueOnly = false,
  });

  final String? projectId;
  final String? assigneeId;
  final TaskStatus? status;
  final TaskPriority? priority;
  final bool overdueOnly;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
