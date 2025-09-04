
class TimeCapsule {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime unlockDate;
  final List<String> notes;
  final List<VoiceNote> voiceNotes;

  TimeCapsule({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.unlockDate,
    required this.notes,
    required this.voiceNotes,
  });

  // Convert to JSON for SharedPreferences storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'unlockDate': unlockDate.toIso8601String(),
      'notes': notes,
      'voiceNotes': voiceNotes.map((v) => v.toJson()).toList(),
    };
  }

  // Create from JSON
  factory TimeCapsule.fromJson(Map<String, dynamic> json) {
    return TimeCapsule(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      unlockDate: DateTime.parse(json['unlockDate']),
      notes: List<String>.from(json['notes'] ?? []),
      voiceNotes: (json['voiceNotes'] as List<dynamic>? ?? [])
          .map((v) => VoiceNote.fromJson(v))
          .toList(),
    );
  }

  // Create copy with updated fields
  TimeCapsule copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? unlockDate,
    List<String>? notes,
    List<VoiceNote>? voiceNotes,
  }) {
    return TimeCapsule(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      unlockDate: unlockDate ?? this.unlockDate,
      notes: notes ?? this.notes,
      voiceNotes: voiceNotes ?? this.voiceNotes,
    );
  }

  @override
  String toString() {
    return 'TimeCapsule(id: $id, title: $title, unlockDate: $unlockDate)';
  }
}

class VoiceNote {
  final String id;
  final String title;
  final String filePath;
  final DateTime createdAt;
  final int durationInSeconds;

  VoiceNote({
    required this.id,
    required this.title,
    required this.filePath,
    required this.createdAt,
    required this.durationInSeconds,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'durationInSeconds': durationInSeconds,
    };
  }

  // Create from JSON
  factory VoiceNote.fromJson(Map<String, dynamic> json) {
    return VoiceNote(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      filePath: json['filePath'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      durationInSeconds: json['durationInSeconds'] ?? 0,
    );
  }

  // Create copy with updated fields
  VoiceNote copyWith({
    String? id,
    String? title,
    String? filePath,
    DateTime? createdAt,
    int? durationInSeconds,
  }) {
    return VoiceNote(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
    );
  }

  // Format duration for display
  String get formattedDuration {
    final minutes = durationInSeconds ~/ 60;
    final seconds = durationInSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'VoiceNote(id: $id, title: $title, duration: ${formattedDuration})';
  }
}

// Helper class for managing time capsule creation
class TimeCapsuleBuilder {
  String _title = '';
  String _description = '';
  DateTime? _unlockDate;
  List<String> _notes = [];
  List<VoiceNote> _voiceNotes = [];

  TimeCapsuleBuilder setTitle(String title) {
    _title = title;
    return this;
  }

  TimeCapsuleBuilder setDescription(String description) {
    _description = description;
    return this;
  }

  TimeCapsuleBuilder setUnlockDate(DateTime date) {
    _unlockDate = date;
    return this;
  }

  TimeCapsuleBuilder addNote(String note) {
    if (note.trim().isNotEmpty) {
      _notes.add(note.trim());
    }
    return this;
  }

  TimeCapsuleBuilder addNotes(List<String> notes) {
    _notes.addAll(notes.where((note) => note.trim().isNotEmpty));
    return this;
  }

  TimeCapsuleBuilder addVoiceNote(VoiceNote voiceNote) {
    _voiceNotes.add(voiceNote);
    return this;
  }

  TimeCapsuleBuilder addVoiceNotes(List<VoiceNote> voiceNotes) {
    _voiceNotes.addAll(voiceNotes);
    return this;
  }

  TimeCapsuleBuilder removeNote(int index) {
    if (index >= 0 && index < _notes.length) {
      _notes.removeAt(index);
    }
    return this;
  }

  TimeCapsuleBuilder removeVoiceNote(int index) {
    if (index >= 0 && index < _voiceNotes.length) {
      _voiceNotes.removeAt(index);
    }
    return this;
  }

  bool get isValid {
    return _title.trim().isNotEmpty &&
           _unlockDate != null &&
           _unlockDate!.isAfter(DateTime.now()) &&
           (_notes.isNotEmpty || _voiceNotes.isNotEmpty);
  }

  String? get validationError {
    if (_title.trim().isEmpty) {
      return 'Title is required';
    }
    if (_unlockDate == null) {
      return 'Unlock date is required';
    }
    if (_unlockDate!.isBefore(DateTime.now())) {
      return 'Unlock date must be in the future';
    }
    if (_notes.isEmpty && _voiceNotes.isEmpty) {
      return 'At least one note or voice note is required';
    }
    return null;
  }

  TimeCapsule build() {
    if (!isValid) {
      throw Exception('TimeCapsule is not valid: ${validationError}');
    }

    return TimeCapsule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _title.trim(),
      description: _description.trim(),
      createdAt: DateTime.now(),
      unlockDate: _unlockDate!,
      notes: List.from(_notes),
      voiceNotes: List.from(_voiceNotes),
    );
  }

  // Clear all data
  void clear() {
    _title = '';
    _description = '';
    _unlockDate = null;
    _notes.clear();
    _voiceNotes.clear();
  }
}