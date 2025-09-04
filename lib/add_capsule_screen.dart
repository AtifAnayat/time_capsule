import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:time_capsule/capsule_model.dart';
import 'package:time_capsule/capsule_services.dart';

class CreateCapsuleScreen extends StatefulWidget {
  final TimeCapsule? editingCapsule;

  const CreateCapsuleScreen({super.key, this.editingCapsule});

  @override
  _CreateCapsuleScreenState createState() => _CreateCapsuleScreenState();
}

class _CreateCapsuleScreenState extends State<CreateCapsuleScreen>
    with TickerProviderStateMixin {
  final TimeCapsuleService _service = TimeCapsuleService();
  final _formKey = GlobalKey<FormState>();
  FlutterSoundRecorder? _audioRecorder;
  FlutterSoundPlayer? _audioPlayer;

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();
  final _voiceTitleController = TextEditingController();

  // Data
  List<String> _notes = [];
  List<VoiceNote> _voiceNotes = [];
  DateTime? _unlockDate;

  // Recording state
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentRecordingPath;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // UI state
  bool _isLoading = false;
  late AnimationController _recordingAnimationController;
  late Animation<double> _recordingAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAudio();
    _loadEditingData();
  }

  void _initializeAnimations() {
    _recordingAnimationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _recordingAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _recordingAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _initializeAudio() async {
    _audioRecorder = FlutterSoundRecorder();
    _audioPlayer = FlutterSoundPlayer();

    await _audioRecorder!.openRecorder();
    await _audioPlayer!.openPlayer();
  }

  void _loadEditingData() {
    if (widget.editingCapsule != null) {
      final capsule = widget.editingCapsule!;
      _titleController.text = capsule.title;
      _descriptionController.text = capsule.description;
      _notes = List.from(capsule.notes);
      _voiceNotes = List.from(capsule.voiceNotes);
      _unlockDate = capsule.unlockDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    _voiceTitleController.dispose();
    _recordingTimer?.cancel();
    _recordingAnimationController.dispose();
    _audioRecorder?.closeRecorder();
    _audioPlayer?.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingState() : _buildForm(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(
          HugeIcons.strokeRoundedArrowLeft01,
          color: Colors.black87,
          size: 30,
        ),
      ),
      title: Text(
        widget.editingCapsule != null ? 'Edit Capsule' : 'Create Capsule',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      actions: [
        Container(
          margin: EdgeInsets.only(right: 16),
          child: TextButton(
            onPressed: _isLoading ? null : _saveCapsule,
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey[200]),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Color(0xFF1A73E8).withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
                strokeWidth: 3,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Saving your capsule...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBasicInfoSection(),
            SizedBox(height: 24),
            _buildUnlockDateSection(),
            SizedBox(height: 24),
            _buildNotesSection(),
            SizedBox(height: 24),
            _buildVoiceNotesSection(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF1A73E8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  HugeIcons.strokeRoundedEdit02,
                  color: Color(0xFF1A73E8),
                  size: 16,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Basic Information',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: 'Give your capsule a memorable name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF1A73E8), width: 2),
              ),
              labelStyle: GoogleFonts.inter(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
              contentPadding: EdgeInsets.all(16),
            ),
            style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Describe what this capsule contains',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF1A73E8), width: 2),
              ),
              labelStyle: GoogleFonts.inter(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
              contentPadding: EdgeInsets.all(16),
            ),
            style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockDateSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 159, 11, 245).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  HugeIcons.strokeRoundedCalendar01,
                  color: Color.fromARGB(255, 159, 11, 245),
                  size: 16,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Unlock Date & Time',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          GestureDetector(
            onTap: _selectUnlockDate,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 1),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: Row(
                children: [
                  Icon(
                    HugeIcons.strokeRoundedCalendar01,
                    color: _unlockDate != null
                        ? Color(0xFF1A73E8)
                        : Colors.grey[500],
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _unlockDate != null
                              ? _formatDateTime(_unlockDate!)
                              : 'Select when to unlock this capsule',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: _unlockDate != null
                                ? Colors.black87
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_unlockDate != null) ...[
                          SizedBox(height: 4),
                          Text(
                            _getTimeUntilUnlock(),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    HugeIcons.strokeRoundedArrowRight01,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF1A73E8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  HugeIcons.strokeRoundedNote,
                  color: Color(0xFF1A73E8),
                  size: 16,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Text Notes',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_notes.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: 'Write a note to your future self...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color(0xFF1A73E8),
                        width: 2,
                      ),
                    ),
                    hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                    contentPadding: EdgeInsets.all(16),
                  ),
                  style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
                  maxLines: 2,
                  onFieldSubmitted: (_) => _addNote(),
                ),
              ),
              SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF1A73E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _addNote,
                  icon: Icon(
                    HugeIcons.strokeRoundedAdd01,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.all(16),
                ),
              ),
            ],
          ),
          if (_notes.isNotEmpty) ...[
            SizedBox(height: 20),
            ...List.generate(
              _notes.length,
              (index) => _buildNoteItem(_notes[index], index),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteItem(String note, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Color(0xFF1A73E8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              note,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _removeNote(index),
            icon: Icon(
              HugeIcons.strokeRoundedDelete01,
              color: Colors.red[600],
              size: 18,
            ),
            padding: EdgeInsets.all(4),
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceNotesSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  HugeIcons.strokeRoundedMic01,
                  color: Color(0xFFF59E0B),
                  size: 16,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Voice Notes',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_voiceNotes.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildRecordingControls(),
          if (_voiceNotes.isNotEmpty) ...[
            SizedBox(height: 20),
            ...List.generate(
              _voiceNotes.length,
              (index) => _buildVoiceNoteItem(_voiceNotes[index], index),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isRecording ? Colors.red[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isRecording ? Colors.red[200]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          if (_isRecording) ...[
            Text(
              'Recording...',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _formatDuration(_recordingSeconds),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.red[700],
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(height: 20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _recordingAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isRecording ? _recordingAnimation.value : 1.0,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? Colors.red[600]
                            : Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isRecording
                                        ? Colors.red[600]!
                                        : Color(0xFFF59E0B))
                                    .withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _isRecording
                            ? _stopRecording
                            : _startRecording,
                        icon: Icon(
                          _isRecording
                              ? HugeIcons.strokeRoundedStop
                              : HugeIcons.strokeRoundedMic01,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          if (!_isRecording) ...[
            SizedBox(height: 12),
            Text(
              'Tap to start recording',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoiceNoteItem(VoiceNote voiceNote, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              HugeIcons.strokeRoundedMic01,
              color: Color(0xFFF59E0B),
              size: 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voiceNote.title.isNotEmpty
                      ? voiceNote.title
                      : 'Voice Note ${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Duration: ${voiceNote.formattedDuration}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => _playVoiceNote(voiceNote),
                  icon: Icon(
                    HugeIcons.strokeRoundedPlay,
                    color: Colors.white,
                    size: 16,
                  ),
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
              SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => _removeVoiceNote(index),
                  icon: Icon(
                    HugeIcons.strokeRoundedDelete01,
                    color: Colors.white,
                    size: 16,
                  ),
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Event handlers
  void _selectUnlockDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _unlockDate ?? DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Color(0xFF1A73E8)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(primary: Color(0xFF1A73E8)),
            ),
            child: child!,
          );
        },
      );

      if (timePicked != null) {
        setState(() {
          _unlockDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
        });
      }
    }
  }

  void _addNote() {
    final note = _noteController.text.trim();
    if (note.isNotEmpty) {
      setState(() {
        _notes.add(note);
        _noteController.clear();
      });
    }
  }

  void _removeNote(int index) {
    setState(() {
      _notes.removeAt(index);
    });
  }

  Future<void> _startRecording() async {
    try {
      final permission = await Permission.microphone.request();
      if (permission != PermissionStatus.granted) {
        _showErrorSnackBar(
          'Microphone permission is required to record voice notes',
        );
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final tempFile =
          '${directory.path}/temp_recording_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _audioRecorder!.startRecorder(
        toFile: tempFile,
        codec: Codec.aacADTS,
      );

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _currentRecordingPath = tempFile;
      });

      _recordingAnimationController.repeat(reverse: true);

      _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _recordingSeconds++;
        });
      });
    } catch (e) {
      _showErrorSnackBar('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder!.stopRecorder();
      _recordingTimer?.cancel();
      _recordingAnimationController.stop();

      setState(() {
        _isRecording = false;
      });

      if (path != null && path.isNotEmpty) {
        _showVoiceNoteTitleDialog(path, _recordingSeconds);
      } else {
        _showErrorSnackBar('Recording failed - no file created');
      }
    } catch (e) {
      _showErrorSnackBar('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  void _showVoiceNoteTitleDialog(String filePath, int duration) {
    _voiceTitleController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Text(
          'Voice Note Title',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        content: TextField(
          controller: _voiceTitleController,
          decoration: InputDecoration(
            labelText: 'Enter title (optional)',
            hintText: 'Voice Note ${_voiceNotes.length + 1}',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF1A73E8), width: 2),
            ),
            labelStyle: GoogleFonts.inter(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
            contentPadding: EdgeInsets.all(16),
          ),
          style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              File(filePath).deleteSync();
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF1A73E8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveVoiceNote(filePath, duration);
              },
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveVoiceNote(String tempPath, int duration) async {
    try {
      final title = _voiceTitleController.text.trim().isEmpty
          ? 'Voice Note ${_voiceNotes.length + 1}'
          : _voiceTitleController.text.trim();

      final voiceNoteId = DateTime.now().millisecondsSinceEpoch.toString();
      final capsuleId =
          widget.editingCapsule?.id ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final savedPath = await _service.saveVoiceFile(
        tempPath,
        capsuleId,
        voiceNoteId,
      );

      final voiceNote = VoiceNote(
        id: voiceNoteId,
        title: title,
        filePath: savedPath,
        createdAt: DateTime.now(),
        durationInSeconds: duration,
      );

      setState(() {
        _voiceNotes.add(voiceNote);
      });

      await File(tempPath).delete();
    } catch (e) {
      _showErrorSnackBar('Error saving voice note: $e');
    }
  }

  void _playVoiceNote(VoiceNote voiceNote) async {
    try {
      if (_isPlaying) {
        await _audioPlayer!.stopPlayer();
        setState(() => _isPlaying = false);
      } else {
        if (await File(voiceNote.filePath).exists()) {
          await _audioPlayer!.startPlayer(
            fromURI: voiceNote.filePath,
            whenFinished: () {
              setState(() => _isPlaying = false);
            },
          );
          setState(() => _isPlaying = true);

          _showSuccessSnackBar('Playing "${voiceNote.title}"');
        } else {
          _showErrorSnackBar('Voice file not found');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error playing voice note: $e');
      setState(() => _isPlaying = false);
    }
  }

  void _removeVoiceNote(int index) {
    setState(() {
      _voiceNotes.removeAt(index);
    });
  }

  Future<void> _saveCapsule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_unlockDate == null) {
      _showErrorSnackBar('Please select an unlock date');
      return;
    }

    if (_notes.isEmpty && _voiceNotes.isEmpty) {
      _showErrorSnackBar('Please add at least one note or voice note');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final builder = TimeCapsuleBuilder()
          .setTitle(_titleController.text.trim())
          .setDescription(_descriptionController.text.trim())
          .setUnlockDate(_unlockDate!)
          .addNotes(_notes)
          .addVoiceNotes(_voiceNotes);

      if (widget.editingCapsule != null) {
        final updatedCapsule = widget.editingCapsule!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          unlockDate: _unlockDate!,
          notes: List.from(_notes),
          voiceNotes: List.from(_voiceNotes),
        );
        await _service.updateCapsule(updatedCapsule);
        _showSuccessSnackBar('Time capsule updated successfully!');
      } else {
        final capsule = builder.build();
        await _service.saveCapsule(capsule);
        _showSuccessSnackBar('Time capsule created successfully!');
      }

      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackBar('Error saving time capsule: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper methods
  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _getTimeUntilUnlock() {
    if (_unlockDate == null) return '';

    final now = DateTime.now();
    final difference = _unlockDate!.difference(now);

    if (difference.isNegative) {
      return 'This capsule will be unlocked immediately';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;

    if (days > 0) {
      return 'Unlocks in $days days and $hours hours';
    } else if (hours > 0) {
      return 'Unlocks in $hours hours';
    } else {
      return 'Unlocks in ${difference.inMinutes} minutes';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }
}
