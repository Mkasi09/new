import 'package:flutter/material.dart';

enum Priority {
  critical('Critical'),
  high('High'),
  low('Low');

  const Priority(this.label);
  final String label;

  static Priority fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'critical':
        return Priority.critical;
      case 'low':
        return Priority.low;
      case 'high':
      default:
        return Priority.high;
    }
  }
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.site,
    required this.address,
    required this.scope,
    required this.sla,
    required this.siteCode,
    required this.status,
    required this.priority,
    this.dueAt,
    this.arrivedAt,
    this.submittedAt,
    this.approvedAt,
    this.declinedAt,
    this.closedAt,
    this.declineReason,
    this.arrivalVerified = false,
    this.evidenceUploaded = false,
    this.evidenceSlots = const [],
    this.evidencePhotos = const {},
    this.technicianNotes,
    this.issueReport,
    this.customerName,
    this.customerSignature,
    this.reviewed = false,
    this.reviewedAt,
    this.supervisor,
    this.supervisorId,
    this.assignedTo,
    this.assignedTechnicians = const [],
    this.assignedTechnicianIds = const [],
    this.isOpen = true,
    this.createdBy,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageBy,
    this.chatMessageCount = 0,
  });

  final String id;
  final String site;
  final String address;
  final String scope;
  final String sla;
  final String siteCode;
  final String status;
  final Priority priority;
  final DateTime? dueAt;
  final DateTime? arrivedAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime? declinedAt;
  final DateTime? closedAt;
  final String? declineReason;
  final bool arrivalVerified;
  final bool evidenceUploaded;
  final List<String> evidenceSlots;
  final Map<String, String> evidencePhotos;
  final String? technicianNotes;
  final String? issueReport;
  final String? customerName;
  final String? customerSignature;
  final bool reviewed;
  final DateTime? reviewedAt;
  final String? supervisor;
  final String? supervisorId;
  final String? assignedTo;
  final List<String> assignedTechnicians;
  final List<String> assignedTechnicianIds;
  final bool isOpen;
  final String? createdBy;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageBy;
  final int chatMessageCount;

  WorkOrder copyWith({
    String? id,
    String? site,
    String? address,
    String? scope,
    String? sla,
    String? siteCode,
    String? status,
    Priority? priority,
    DateTime? dueAt,
    DateTime? arrivedAt,
    DateTime? submittedAt,
    DateTime? approvedAt,
    DateTime? declinedAt,
    DateTime? closedAt,
    String? declineReason,
    bool? arrivalVerified,
    bool? evidenceUploaded,
    List<String>? evidenceSlots,
    Map<String, String>? evidencePhotos,
    String? technicianNotes,
    String? issueReport,
    String? customerName,
    String? customerSignature,
    bool? reviewed,
    DateTime? reviewedAt,
    String? supervisor,
    String? supervisorId,
    String? assignedTo,
    List<String>? assignedTechnicians,
    List<String>? assignedTechnicianIds,
    bool? isOpen,
    String? createdBy,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageBy,
    int? chatMessageCount,
  }) {
    return WorkOrder(
      id: id ?? this.id,
      site: site ?? this.site,
      address: address ?? this.address,
      scope: scope ?? this.scope,
      sla: sla ?? this.sla,
      siteCode: siteCode ?? this.siteCode,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      declinedAt: declinedAt ?? this.declinedAt,
      closedAt: closedAt ?? this.closedAt,
      declineReason: declineReason ?? this.declineReason,
      arrivalVerified: arrivalVerified ?? this.arrivalVerified,
      evidenceUploaded: evidenceUploaded ?? this.evidenceUploaded,
      evidenceSlots: evidenceSlots ?? this.evidenceSlots,
      evidencePhotos: evidencePhotos ?? this.evidencePhotos,
      technicianNotes: technicianNotes ?? this.technicianNotes,
      issueReport: issueReport ?? this.issueReport,
      customerName: customerName ?? this.customerName,
      customerSignature: customerSignature ?? this.customerSignature,
      reviewed: reviewed ?? this.reviewed,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      supervisor: supervisor ?? this.supervisor,
      supervisorId: supervisorId ?? this.supervisorId,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedTechnicians: assignedTechnicians ?? this.assignedTechnicians,
      assignedTechnicianIds:
          assignedTechnicianIds ?? this.assignedTechnicianIds,
      isOpen: isOpen ?? this.isOpen,
      createdBy: createdBy ?? this.createdBy,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageBy: lastMessageBy ?? this.lastMessageBy,
      chatMessageCount: chatMessageCount ?? this.chatMessageCount,
    );
  }

  List<String> get technicianNames {
    if (assignedTechnicians.isNotEmpty) {
      return assignedTechnicians.map(displayPersonName).toList();
    }
    final assigned = assignedTo?.trim();
    if (assigned == null || assigned.isEmpty) return const [];
    return assigned
        .split(RegExp(r'[,;]'))
        .map(displayPersonName)
        .where((name) => name.isNotEmpty)
        .toList();
  }

  String? get technicianLabel {
    final names = technicianNames;
    if (names.isEmpty) return null;
    return names.join(', ');
  }

  Map<String, Object?> toMap() {
    return {
      'site': site,
      'address': address,
      'scope': scope,
      'sla': sla,
      'siteCode': siteCode,
      'status': status,
      'priority': priority.name,
      'dueAt': dueAt?.toIso8601String(),
      'arrivedAt': arrivedAt?.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'declinedAt': declinedAt?.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'declineReason': declineReason,
      'arrivalVerified': arrivalVerified,
      'evidenceUploaded': evidenceUploaded,
      'evidenceSlots': evidenceSlots,
      'evidencePhotos': evidencePhotos,
      'technicianNotes': technicianNotes,
      'issueReport': issueReport,
      'customerName': customerName,
      'customerSignature': customerSignature,
      'reviewed': reviewed,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'supervisor': supervisor,
      'supervisorId': supervisorId,
      'assignedTo': assignedTo,
      'assignedTechnicians': assignedTechnicians,
      'assignedTechnicianIds': assignedTechnicianIds,
      'isOpen': isOpen,
      'createdBy': createdBy,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastMessageBy': lastMessageBy,
      'chatMessageCount': chatMessageCount,
    };
  }

  factory WorkOrder.fromMap(String id, Map<String, dynamic> map) {
    return WorkOrder(
      id: id,
      site: map['site'] as String? ?? 'Unknown site',
      address: map['address'] as String? ?? 'Address pending',
      scope: map['scope'] as String? ?? 'No scope captured',
      sla: _friendlyDueText(map['sla'] as String?),
      siteCode: map['siteCode'] as String? ?? 'SITE-PENDING',
      status: map['status'] as String? ?? 'New',
      priority: Priority.fromString(map['priority'] as String?),
      dueAt:
          _dateTimeFromMapValue(map['dueAt']) ??
          _dueAtFromFriendlyText(map['sla'] as String?),
      arrivedAt: _dateTimeFromMapValue(map['arrivedAt']),
      submittedAt: _dateTimeFromMapValue(map['submittedAt']),
      approvedAt: _dateTimeFromMapValue(map['approvedAt']),
      declinedAt: _dateTimeFromMapValue(map['declinedAt']),
      closedAt: _dateTimeFromMapValue(map['closedAt']),
      declineReason: map['declineReason'] as String?,
      arrivalVerified: map['arrivalVerified'] as bool? ?? false,
      evidenceUploaded: map['evidenceUploaded'] as bool? ?? false,
      evidenceSlots:
          (map['evidenceSlots'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      evidencePhotos:
          (map['evidencePhotos'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          const {},
      technicianNotes: map['technicianNotes'] as String?,
      issueReport: map['issueReport'] as String?,
      customerName: map['customerName'] as String?,
      customerSignature: map['customerSignature'] as String?,
      reviewed: map['reviewed'] as bool? ?? false,
      reviewedAt: _dateTimeFromMapValue(map['reviewedAt']),
      supervisor: displayPersonName(map['supervisor'] as String?),
      supervisorId: map['supervisorId'] as String?,
      assignedTo: map['assignedTo'] as String?,
      assignedTechnicians:
          (map['assignedTechnicians'] as List<dynamic>?)
              ?.whereType<String>()
              .map(displayPersonName)
              .where((name) => name.isNotEmpty)
              .toList() ??
          const [],
      assignedTechnicianIds:
          (map['assignedTechnicianIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      isOpen:
          map['isOpen'] as bool? ??
          (map['status'] as String? ?? 'New') != 'Approved',
      createdBy: map['createdBy'] as String?,
      lastMessage: map['lastMessage'] as String?,
      lastMessageAt: _dateTimeFromMapValue(map['lastMessageAt']),
      lastMessageBy: displayPersonName(map['lastMessageBy'] as String?),
      chatMessageCount: (map['chatMessageCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class JobChatMessage {
  const JobChatMessage({
    required this.id,
    required this.workOrderId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String workOrderId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String message;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'workOrderId': workOrderId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory JobChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return JobChatMessage(
      id: id,
      workOrderId: map['workOrderId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: displayPersonName(map['senderName'] as String?),
      senderRole: map['senderRole'] as String? ?? 'user',
      message: map['message'] as String? ?? '',
      createdAt: _dateTimeFromMapValue(map['createdAt']) ?? DateTime.now(),
    );
  }
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.senderEmail,
    required this.message,
    required this.source,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String senderEmail;
  final String message;
  final String source;
  final DateTime createdAt;
  final String status;

  bool get sentViaSupport => source == 'support';

  factory SupportMessage.fromMap(String id, Map<String, dynamic> map) {
    return SupportMessage(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      senderName: displayPersonName(map['senderName'] as String?),
      senderRole: map['senderRole'] as String? ?? 'User',
      senderEmail: map['senderEmail'] as String? ?? '',
      message: map['message'] as String? ?? '',
      source: map['source'] as String? ?? 'support',
      createdAt: _dateTimeFromMapValue(map['createdAt']) ?? DateTime.now(),
      status: map['status'] as String? ?? 'new',
    );
  }
}

String displayPersonName(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return '';
  if (!raw.contains('@')) return raw;
  final localPart = raw.split('@').first.trim();
  if (localPart.isEmpty) return raw;
  return localPart
      .split(RegExp(r'[._-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

DateTime? _dateTimeFromMapValue(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  final dynamic dynamicValue = value;
  try {
    final DateTime date = dynamicValue.toDate() as DateTime;
    return date;
  } catch (_) {
    return null;
  }
}

String _friendlyDueText(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return 'Due in 24 hours';

  final compactHours = RegExp(r'^(\d+)h left$').firstMatch(raw.toLowerCase());
  if (compactHours != null) {
    final hours = int.tryParse(compactHours.group(1) ?? '') ?? 24;
    return hours == 1 ? 'Due in 1 hour' : 'Due in $hours hours';
  }

  return raw;
}

DateTime? _dueAtFromFriendlyText(String? value) {
  final raw = value?.trim().toLowerCase();
  if (raw == null || raw.isEmpty) return null;

  final dueInHours = RegExp(r'^due in (\d+) hours?$').firstMatch(raw);
  if (dueInHours == null) return null;

  final hours = int.tryParse(dueInHours.group(1) ?? '');
  if (hours == null) return null;
  return DateTime.now().add(Duration(hours: hours));
}

class Metric {
  const Metric(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class JobStep {
  const JobStep(this.title, this.icon, this.detail);

  final String title;
  final IconData icon;
  final String detail;
}

class MaterialLine {
  const MaterialLine(
    this.name,
    this.serial,
    this.action,
    this.state,
    this.color,
  );

  final String name;
  final String serial;
  final String action;
  final String state;
  final Color color;
}
