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
    this.assignedTo,
    this.createdBy,
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
  final String? assignedTo;
  final String? createdBy;

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
    String? assignedTo,
    String? createdBy,
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
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy ?? this.createdBy,
    );
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
      'assignedTo': assignedTo,
      'createdBy': createdBy,
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
      supervisor: map['supervisor'] as String?,
      assignedTo: map['assignedTo'] as String?,
      createdBy: map['createdBy'] as String?,
    );
  }
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
