import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_capsule/capsule_model.dart';

class TimeCapsuleService {
  static const String _capsulesKey = 'time_capsules';
  static const String _voiceNotesDir = 'voice_notes';

  // Singleton pattern
  static final TimeCapsuleService _instance = TimeCapsuleService._internal();
  factory TimeCapsuleService() => _instance;
  TimeCapsuleService._internal();

  // Cache for faster access
  List<TimeCapsule>? _cachedCapsules;

  /// Get all time capsules
  Future<List<TimeCapsule>> getAllCapsules() async {
    if (_cachedCapsules != null) {
      return List.from(_cachedCapsules!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final capsulesJson = prefs.getStringList(_capsulesKey) ?? [];

      final capsules = capsulesJson
          .map((jsonString) {
            try {
              final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
              return TimeCapsule.fromJson(jsonMap);
            } catch (e) {
              return null;
            }
          })
          .where((capsule) => capsule != null)
          .cast<TimeCapsule>()
          .toList();

      // Sort by creation date (newest first)
      capsules.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _cachedCapsules = capsules;
      return List.from(capsules);
    } catch (e) {
      print('Error loading capsules: $e');
      return [];
    }
  }

  /// Save a new time capsule
  Future<void> saveCapsule(TimeCapsule capsule) async {
    try {
      final capsules = await getAllCapsules();
      capsules.add(capsule);
      await _saveCapsules(capsules);
    } catch (e) {
      throw Exception('Failed to save time capsule: $e');
    }
  }

  /// Update existing time capsule
  Future<void> updateCapsule(TimeCapsule updatedCapsule) async {
    try {
      final capsules = await getAllCapsules();
      final index = capsules.indexWhere((c) => c.id == updatedCapsule.id);

      if (index == -1) {
        throw Exception('Time capsule not found');
      }

      capsules[index] = updatedCapsule;
      await _saveCapsules(capsules);
    } catch (e) {
      throw Exception('Failed to update time capsule: $e');
    }
  }

  /// Delete a time capsule
  Future<void> deleteCapsule(String capsuleId) async {
    try {
      final capsules = await getAllCapsules();
      final capsuleToDelete = capsules.firstWhere(
        (c) => c.id == capsuleId,
        orElse: () => throw Exception('Time capsule not found'),
      );

      // Delete associated voice files
      for (final voiceNote in capsuleToDelete.voiceNotes) {
        await _deleteVoiceFile(voiceNote.filePath);
      }

      // Remove from list and save
      capsules.removeWhere((c) => c.id == capsuleId);
      await _saveCapsules(capsules);
    } catch (e) {
      throw Exception('Failed to delete time capsule: $e');
    }
  }

  /// Get time capsule by ID
  Future<TimeCapsule?> getCapsuleById(String id) async {
    try {
      final capsules = await getAllCapsules();
      return capsules.firstWhere(
        (c) => c.id == id,
        orElse: () => throw Exception('Time capsule not found'),
      );
    } catch (e) {
      print('Error getting capsule by ID: $e');
      return null;
    }
  }

  /// Get unlocked time capsules
  Future<List<TimeCapsule>> getUnlockedCapsules() async {
    final capsules = await getAllCapsules();
    final now = DateTime.now();
    return capsules
        .where(
          (c) =>
              c.unlockDate.isBefore(now) || c.unlockDate.isAtSameMomentAs(now),
        )
        .toList();
  }

  /// Get locked time capsules
  Future<List<TimeCapsule>> getLockedCapsules() async {
    final capsules = await getAllCapsules();
    final now = DateTime.now();
    return capsules.where((c) => c.unlockDate.isAfter(now)).toList();
  }

  /// Save voice file and return file path
  Future<String> saveVoiceFile(
    String tempFilePath,
    String capsuleId,
    String voiceNoteId,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final voiceDir = Directory('${directory.path}/$_voiceNotesDir');

      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }

      final fileName = '${capsuleId}_${voiceNoteId}.m4a';
      final finalPath = '${voiceDir.path}/$fileName';

      final tempFile = File(tempFilePath);
      await tempFile.copy(finalPath);

      return finalPath;
    } catch (e) {
      throw Exception('Failed to save voice file: $e');
    }
  }

  /// Delete voice file
  Future<void> _deleteVoiceFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting voice file: $e');
    }
  }

  /// Check if voice file exists
  Future<bool> voiceFileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Get storage usage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final capsules = await getAllCapsules();
      final directory = await getApplicationDocumentsDirectory();
      final voiceDir = Directory('${directory.path}/$_voiceNotesDir');

      int totalVoiceFiles = 0;
      int totalVoiceSize = 0;

      if (await voiceDir.exists()) {
        final files = await voiceDir.list().toList();
        totalVoiceFiles = files.length;

        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            totalVoiceSize += stat.size;
          }
        }
      }

      return {
        'totalCapsules': capsules.length,
        'unlockedCapsules': capsules
            .where((c) => DateTime.now().isAfter(c.unlockDate))
            .length,
        'lockedCapsules': capsules
            .where((c) => DateTime.now().isBefore(c.unlockDate))
            .length,
        'totalNotes': capsules.fold<int>(0, (sum, c) => sum + c.notes.length),
        'totalVoiceNotes': capsules.fold<int>(
          0,
          (sum, c) => sum + c.voiceNotes.length,
        ),
        'totalVoiceFiles': totalVoiceFiles,
        'totalVoiceSizeMB': (totalVoiceSize / (1024 * 1024)).round(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Clear all data (for debugging or reset)
  Future<void> clearAllData() async {
    try {
      // Delete all voice files
      final directory = await getApplicationDocumentsDirectory();
      final voiceDir = Directory('${directory.path}/$_voiceNotesDir');

      if (await voiceDir.exists()) {
        await voiceDir.delete(recursive: true);
      }

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_capsulesKey);

      // Clear cache
      _cachedCapsules = null;
    } catch (e) {
      throw Exception('Failed to clear all data: $e');
    }
  }

  /// Export all data as JSON (for backup)
  Future<String> exportData() async {
    try {
      final capsules = await getAllCapsules();
      final exportData = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'capsules': capsules.map((c) => c.toJson()).toList(),
      };
      return json.encode(exportData);
    } catch (e) {
      throw Exception('Failed to export data: $e');
    }
  }

  /// Search capsules by title or description
  Future<List<TimeCapsule>> searchCapsules(String query) async {
    if (query.trim().isEmpty) {
      return await getAllCapsules();
    }

    final capsules = await getAllCapsules();
    final lowercaseQuery = query.toLowerCase();

    return capsules.where((capsule) {
      return capsule.title.toLowerCase().contains(lowercaseQuery) ||
          capsule.description.toLowerCase().contains(lowercaseQuery) ||
          capsule.notes.any(
            (note) => note.toLowerCase().contains(lowercaseQuery),
          );
    }).toList();
  }

  /// Private method to save all capsules
  Future<void> _saveCapsules(List<TimeCapsule> capsules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final capsulesJson = capsules
          .map((capsule) => json.encode(capsule.toJson()))
          .toList();

      await prefs.setStringList(_capsulesKey, capsulesJson);

      // Update cache
      _cachedCapsules = List.from(capsules);
    } catch (e) {
      throw Exception('Failed to save capsules to storage: $e');
    }
  }

  /// Clear cache (useful for testing or when data changes externally)
  void clearCache() {
    _cachedCapsules = null;
  }

  /// Validate capsule data integrity
  Future<List<String>> validateDataIntegrity() async {
    final issues = <String>[];

    try {
      final capsules = await getAllCapsules();

      for (final capsule in capsules) {
        // Check for empty or invalid IDs
        if (capsule.id.isEmpty) {
          issues.add('Capsule "${capsule.title}" has empty ID');
        }

        // Check for invalid dates
        if (capsule.createdAt.isAfter(DateTime.now())) {
          issues.add('Capsule "${capsule.title}" has future creation date');
        }

        // Check voice files existence
        for (final voiceNote in capsule.voiceNotes) {
          if (!await voiceFileExists(voiceNote.filePath)) {
            issues.add(
              'Voice file missing for "${voiceNote.title}" in capsule "${capsule.title}"',
            );
          }
        }
      }

      // Check for duplicate IDs
      final ids = capsules.map((c) => c.id).toList();
      final uniqueIds = ids.toSet();
      if (ids.length != uniqueIds.length) {
        issues.add('Duplicate capsule IDs found');
      }
    } catch (e) {
      issues.add('Error during validation: $e');
    }

    return issues;
  }
}
