import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:time_capsule/add_capsule_screen.dart';
import 'package:time_capsule/capsule_model.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

import 'package:time_capsule/capsule_services.dart';

class CapsuleDetailsScreen extends StatefulWidget {
  final TimeCapsule capsule;

  CapsuleDetailsScreen({required this.capsule});

  @override
  _CapsuleDetailsScreenState createState() => _CapsuleDetailsScreenState();
}

class _CapsuleDetailsScreenState extends State<CapsuleDetailsScreen>
    with TickerProviderStateMixin {
  final TimeCapsuleService _service = TimeCapsuleService();
  FlutterSoundPlayer? _audioPlayer;
  bool _isPlaying = false;
  String? _currentPlayingId;
  late AnimationController _unlockAnimationController;
  late Animation<double> _unlockAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAudio();
  }

  void _initializeAnimations() {
    _unlockAnimationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _unlockAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _unlockAnimationController,
      curve: Curves.elasticOut,
    ));

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    final isUnlocked = DateTime.now().isAfter(widget.capsule.unlockDate);
    if (isUnlocked) {
      _unlockAnimationController.forward();
    }
    _fadeController.forward();
  }

  Future<void> _initializeAudio() async {
    _audioPlayer = FlutterSoundPlayer();
    await _audioPlayer!.openPlayer();
  }

  @override
  void dispose() {
    _unlockAnimationController.dispose();
    _fadeController.dispose();
    _audioPlayer?.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUnlocked = DateTime.now().isAfter(widget.capsule.unlockDate);
    
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isUnlocked),
          SliverPadding(
            padding: EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      if (!isUnlocked) _buildLockedContent(),
                      if (isUnlocked) ...[
                        _buildUnlockedHeader(),
                        SizedBox(height: 24),
                        if (widget.capsule.description.isNotEmpty) ...[
                          _buildDescriptionCard(),
                          SizedBox(height: 24),
                        ],
                        if (widget.capsule.notes.isNotEmpty) ...[
                          _buildNotesCard(),
                          SizedBox(height: 24),
                        ],
                        if (widget.capsule.voiceNotes.isNotEmpty) ...[
                          _buildVoiceNotesCard(),
                          SizedBox(height: 24),
                        ],
                        _buildMetadataCard(),
                        SizedBox(height: 100),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: isUnlocked ? _buildFloatingActionButtons() : null,
    );
  }

  Widget _buildSliverAppBar(bool isUnlocked) {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(
          HugeIcons.strokeRoundedArrowLeft01,
          color: Colors.white,
          size: 30,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.capsule.title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isUnlocked 
                  ? [Color(0xFF10B981), Color(0xFF059669)]
                  : [Color(0xFFF59E0B), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: AnimatedBuilder(
              animation: _unlockAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_unlockAnimation.value * 0.2),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      isUnlocked      ? HugeIcons.strokeRoundedSquareUnlock01
                                  :HugeIcons.strokeRoundedSquareLock02,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      actions: [
        if (isUnlocked)
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            icon: Icon(
              HugeIcons.strokeRoundedMoreVertical,
              color: Colors.white,
              size: 30,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(HugeIcons.strokeRoundedEdit02, color: Color(0xFF1A73E8), size: 18),
                    SizedBox(width: 12),
                    Text(
                      'Edit',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(HugeIcons.strokeRoundedShare08, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 12),
                    Text(
                      'Share',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(HugeIcons.strokeRoundedDelete01, color: Colors.red[600], size: 18),
                    SizedBox(width: 12),
                    Text(
                      'Delete',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: Colors.red[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLockedContent() {
    final timeUntilUnlock = _getTimeUntilUnlock();
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              HugeIcons.strokeRoundedTime04,
              size: 50,
              color: Color(0xFFF59E0B),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Capsule Locked',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'This time capsule will unlock on:',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatDateTime(widget.capsule.unlockDate),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF59E0B),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 20),
          Text(
            timeUntilUnlock,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          _buildPreviewInfo(),
        ],
      ),
    );
  }

  Widget _buildPreviewInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          _buildPreviewRow(
            HugeIcons.strokeRoundedNote,
            '${widget.capsule.notes.length} text notes',
            Color(0xFF1A73E8),
          ),
          SizedBox(height: 12),
          _buildPreviewRow(
            HugeIcons.strokeRoundedMic01,
            '${widget.capsule.voiceNotes.length} voice notes',
            Color(0xFFF59E0B),
          ),
          if (widget.capsule.description.isNotEmpty) ...[
            SizedBox(height: 12),
            _buildPreviewRow(
              HugeIcons.strokeRoundedFileAttachment,
              'Has description',
              Color(0xFF10B981),
            ),
          ],
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  HugeIcons.strokeRoundedCalendar01,
                  size: 16,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 8),
                Text(
                  'Created: ${_formatDate(widget.capsule.createdAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        SizedBox(width: 12),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockedHeader() {
    return AnimatedBuilder(
      animation: _unlockAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _unlockAnimation.value,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                   HugeIcons.strokeRoundedSquareUnlock01,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Capsule Unlocked!',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your memories from ${_formatDate(widget.capsule.createdAt)} await you',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                      HugeIcons.strokeRoundedFileImport,
                       
                  color: Color(0xFF10B981),
                  size: 18,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Description',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.capsule.description,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
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
                  size: 18,
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
                  color: Color(0xFF1A73E8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.capsule.notes.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A73E8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ...List.generate(
            widget.capsule.notes.length,
            (index) => _buildNoteItem(widget.capsule.notes[index], index),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(String note, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1A73E8).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF1A73E8).withOpacity(0.1), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(0xFF1A73E8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              note,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceNotesCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
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
                  size: 18,
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
                  color: Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.capsule.voiceNotes.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ...List.generate(
            widget.capsule.voiceNotes.length,
            (index) => _buildVoiceNoteItem(widget.capsule.voiceNotes[index], index),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceNoteItem(VoiceNote voiceNote, int index) {
    final isCurrentlyPlaying = _currentPlayingId == voiceNote.id && _isPlaying;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFF59E0B).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFF59E0B).withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isCurrentlyPlaying ? Color(0xFF10B981) : Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: (isCurrentlyPlaying ? Color(0xFF10B981) : Color(0xFFF59E0B)).withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () => _playVoiceNote(voiceNote),
              icon: Icon(
                isCurrentlyPlaying ? HugeIcons.strokeRoundedPause : HugeIcons.strokeRoundedPlay,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voiceNote.title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(HugeIcons.strokeRoundedTime04, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 6),
                    Text(
                      voiceNote.formattedDuration,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 16),
                    Icon(HugeIcons.strokeRoundedCalendar01, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 6),
                    Text(
                      _formatDate(voiceNote.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  HugeIcons.strokeRoundedInformationCircle,
                  color: Colors.grey[600],
                  size: 18,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Information',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildInfoRow('Created', _formatDateTime(widget.capsule.createdAt)),
          _buildInfoRow('Unlocked', _formatDateTime(widget.capsule.unlockDate)),
          _buildInfoRow('Time Locked', _getTimeLocked()),
          _buildInfoRow('Text Notes', '${widget.capsule.notes.length}'),
          _buildInfoRow('Voice Notes', '${widget.capsule.voiceNotes.length}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Color(0xFF1A73E8),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF1A73E8).withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: 'edit',
            onPressed: _editCapsule,
            child: Icon(HugeIcons.strokeRoundedEdit02, color: Colors.white),
            backgroundColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFF10B981),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF10B981).withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: 'share',
            onPressed: _shareCapsule,
            child: Icon(HugeIcons.strokeRoundedShare08, color: Colors.white),
            backgroundColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  // Event handlers
  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _editCapsule();
        break;
      case 'share':
        _shareCapsule();
        break;
      case 'delete':
        _showDeleteDialog();
        break;
    }
  }

  Future<void> _editCapsule() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateCapsuleScreen(editingCapsule: widget.capsule),
      ),
    );
    
    if (result == true) {
      Navigator.pop(context, true);
    }
  }

  void _shareCapsule() async {
    try {
      final shareText = _buildShareText();
      await Share.share(shareText, subject: 'My Time Capsule: ${widget.capsule.title}');
    } catch (e) {
      _showErrorSnackBar('Error sharing capsule: $e');
    }
  }

  String _buildShareText() {
    final buffer = StringBuffer();
    buffer.writeln('🕰️ Time Capsule: ${widget.capsule.title}');
    buffer.writeln();
    
    if (widget.capsule.description.isNotEmpty) {
      buffer.writeln('📝 Description:');
      buffer.writeln(widget.capsule.description);
      buffer.writeln();
    }
    
    if (widget.capsule.notes.isNotEmpty) {
      buffer.writeln('📋 Notes:');
      for (int i = 0; i < widget.capsule.notes.length; i++) {
        buffer.writeln('${i + 1}. ${widget.capsule.notes[i]}');
      }
      buffer.writeln();
    }
    
    buffer.writeln('📅 Created: ${_formatDateTime(widget.capsule.createdAt)}');
    buffer.writeln('🔓 Unlocked: ${_formatDateTime(widget.capsule.unlockDate)}');
    buffer.writeln();
    buffer.writeln('Created with Time Capsules App by Atif Anayat');
    
    return buffer.toString();
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                HugeIcons.strokeRoundedAlertCircle,
                color: Colors.red[600],
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Capsule',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${widget.capsule.title}"? This action cannot be undone and all voice recordings will be permanently deleted.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
              color: Colors.red[600],
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteCapsule();
              },
              child: Text(
                'Delete',
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

  Future<void> _deleteCapsule() async {
    try {
      await _service.deleteCapsule(widget.capsule.id);
      _showSuccessSnackBar('Time capsule deleted successfully');
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackBar('Error deleting capsule: $e');
    }
  }

  void _playVoiceNote(VoiceNote voiceNote) async {
    try {
      if (_isPlaying && _currentPlayingId == voiceNote.id) {
        await _audioPlayer!.stopPlayer();
        setState(() {
          _isPlaying = false;
          _currentPlayingId = null;
        });
      } else {
        if (_isPlaying) {
          await _audioPlayer!.stopPlayer();
        }
        
        if (await File(voiceNote.filePath).exists()) {
          await _audioPlayer!.startPlayer(
            fromURI: voiceNote.filePath,
            whenFinished: () {
              if (mounted) {
                setState(() {
                  _isPlaying = false;
                  _currentPlayingId = null;
                });
              }
            },
          );
          
          setState(() {
            _isPlaying = true;
            _currentPlayingId = voiceNote.id;
          });
          
          _showSuccessSnackBar('Playing "${voiceNote.title}"');
        } else {
          _showErrorSnackBar('Voice file not found');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error playing voice note: $e');
      setState(() {
        _isPlaying = false;
        _currentPlayingId = null;
      });
    }
  }

  // Helper methods
  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getTimeUntilUnlock() {
    final now = DateTime.now();
    final difference = widget.capsule.unlockDate.difference(now);
    
    if (difference.isNegative) {
      return 'This capsule is now unlocked!';
    }
    
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    
    if (days > 0) {
      return 'Unlocks in $days days, $hours hours, and $minutes minutes';
    } else if (hours > 0) {
      return 'Unlocks in $hours hours and $minutes minutes';
    } else {
      return 'Unlocks in $minutes minutes';
    }
  }

  String _getTimeLocked() {
    final difference = widget.capsule.unlockDate.difference(widget.capsule.createdAt);
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    
    if (days > 0) {
      return '$days days and $hours hours';
    } else {
      return '$hours hours';
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