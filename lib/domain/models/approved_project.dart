/// An Approved (contractor) Project: groups standard sale invoices issued
/// to one approved party for one specific project location.
class ApprovedProject {
  final int? id;
  final int clientId;
  final String clientName;
  final String location;
  final String notes;
  final DateTime createdAt;

  const ApprovedProject({
    this.id,
    required this.clientId,
    required this.clientName,
    this.location = '',
    this.notes = '',
    required this.createdAt,
  });

  ApprovedProject copyWith({
    int? id,
    int? clientId,
    String? clientName,
    String? location,
    String? notes,
    DateTime? createdAt,
  }) {
    return ApprovedProject(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'client_id': clientId,
      'client_name': clientName,
      'location': location,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ApprovedProject.fromMap(Map<String, dynamic> map) {
    return ApprovedProject(
      id: map['id'] as int?,
      clientId: map['client_id'] as int? ?? 0,
      clientName: map['client_name'] as String? ?? '',
      location: map['location'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
