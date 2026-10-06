import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  FLEET CHAT PAGE — rider ↔ agency, in-app, replacing the
//  WhatsApp workaround. One thread per rider per agency, doc id
//  "{agencyId}_{riderId}" — same shape as agencySupportChats.
// ═══════════════════════════════════════════════════════════════

class FleetChatPage extends StatefulWidget {
  final String agencyId;
  final String riderId;
  final String agencyName;

  const FleetChatPage({
    super.key,
    required this.agencyId,
    required this.riderId,
    required this.agencyName,
  });

  @override
  State<FleetChatPage> createState() => _FleetChatPageState();
}

class _FleetChatPageState extends State<FleetChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  String get _chatId => '${widget.agencyId}_${widget.riderId}';

  Future<void> _ensureThreadExists() async {
    final ref = FirebaseFirestore.instance.collection('fleetRiderChats').doc(_chatId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'agencyId': widget.agencyId,
        'riderId': widget.riderId,
        'lastMessage': null,
        'lastMessageAt': null,
        'unreadByAgency': 0,
        'unreadByRider': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      await _ensureThreadExists();
      final chatRef = FirebaseFirestore.instance.collection('fleetRiderChats').doc(_chatId);

      await chatRef.collection('messages').add({
        'senderId': uid,
        'senderRole': 'rider',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await chatRef.update({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadByAgency': FieldValue.increment(1),
      });

      HapticFeedback.lightImpact();
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to send. Try again.'),
          backgroundColor: AppTheme.redFor(Theme.of(context).brightness == Brightness.dark),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureThreadExists();
    // Clear the rider's own unread badge the moment they open the thread.
    FirebaseFirestore.instance.collection('fleetRiderChats').doc(_chatId).update({
      'unreadByRider': 0,
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bg(isDark),
      appBar: AppBar(
        title: Text(widget.agencyName),
        backgroundColor: AppTheme.surface(isDark),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('fleetRiderChats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Message your agency here',
                      style: TextStyle(color: AppTheme.textTertiary(isDark), fontSize: 13),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final m = docs[i].data() as Map<String, dynamic>;
                    final isMe = m['senderId'] == uid;
                    final text = m['text'] as String? ?? '';
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.blueFor(isDark) : AppTheme.surface2(isDark),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isMe ? Colors.white : AppTheme.textPrimary(isDark),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: AppTheme.surface(isDark),
                border: Border(top: BorderSide(color: AppTheme.border(isDark))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface2(isDark),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        minLines: 1,
                        maxLines: 4,
                        style: TextStyle(color: AppTheme.textPrimary(isDark), fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Message your agency…',
                          hintStyle: TextStyle(color: AppTheme.textTertiary(isDark)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.blueFor(isDark),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
