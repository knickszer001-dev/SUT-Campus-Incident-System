import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../core/app_network_image.dart';
import '../../../core/theme.dart';
import '../../../models/chat_message_model.dart';
import '../data/chat_repository.dart';
import '../../notification/web_notification_watcher.dart';

/// Chat Screen — v4: + Camera button + Role-based Quick Replies
class ChatScreen extends ConsumerStatefulWidget {

  final String incidentId;
  final String incidentTitle;
  final bool readOnly; // F7: Dispatcher ดูแชทแบบ read-only
  final String userRole; // v4: role สำหรับ quick replies ('user' / 'responder' / 'dispatcher')

  const ChatScreen({
    super.key,
    required this.incidentId,
    required this.incidentTitle,
    this.readOnly = false,
    this.userRole = 'user',
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatRepository _chatRepo;
  String _currentUserName = '';
  bool _isUploading = false;
  bool _isSending = false; // EC-1: Debounce flag
  late bool _isReadOnly; // Issue #2: สลับได้

  @override
  void initState() {
    super.initState();
    _chatRepo = ChatRepository(firestore: ref.read(firestoreProvider));
    _isReadOnly = widget.readOnly;
    _loadUserName();
    _markChatAsRead();
    // Issue #6: Set active chat to suppress duplicate notifications
    WebNotificationWatcher.activeIncidentChatId = widget.incidentId;
  }

  Future<void> _loadUserName() async {
    final name = await ref.read(authRepositoryProvider).getCurrentUserName();
    if (mounted) {
      setState(() => _currentUserName = name);
    }
  }

  /// F8: Mark as read เมื่อเปิดหน้า chat
  Future<void> _markChatAsRead() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    await _chatRepo.markAsRead(widget.incidentId, user.uid);
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    if (_isReadOnly) return;
    if (_isSending) return; // EC-1: ป้องกันกดซ้ำ

    final text = _messageController.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    // EC-2: เก็บข้อความไว้ก่อน clear ถ้าส่งไม่ผ่านจะคืนกลับ
    final savedText = _messageController.text;
    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await _chatRepo.sendMessage(
        incidentId: widget.incidentId,
        senderId: user.uid,
        senderName: _currentUserName,
        text: imageUrl != null && text.isEmpty ? '📷 รูปภาพ' : text,
        imageUrl: imageUrl,
      );

      _scrollToBottom();
    } catch (e) {
      // EC-2: คืนข้อความกลับเมื่อส่งไม่สำเร็จ
      if (mounted) {
        _messageController.text = savedText;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งข้อความไม่สำเร็จ กรุณาลองใหม่'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// v4: Pick/Capture and upload image — รับ ImageSource เป็น parameter
  Future<void> _pickAndSendImage({required ImageSource source}) async {
    if (_isReadOnly) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 800);
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final fileName = 'chat_${widget.incidentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref('chat_images/$fileName');

      final bytes = await picked.readAsBytes();
      final uploadTask = await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await _sendMessage(imageUrl: downloadUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ กรุณาลองใหม่'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// v4: Quick replies ตาม role
  /// UX Review #7: Quick replies ใช้คำกลาง ไม่มี bias เพศ
  List<String> get _quickReplies {
    switch (widget.userRole) {
      case 'responder':
        return ['กำลังไป', 'ถึงแล้ว', 'รอสักครู่', 'ต้องการข้อมูลเพิ่มเติม', 'เสร็จเรียบร้อย'];
      case 'user':
      default:
        return ['ขอบคุณ', 'ตอนนี้อยู่ตรงไหน', 'ยังไม่มาถึงหรือ', 'เหตุยังอยู่', 'ต้องการความช่วยเหลือเพิ่ม'];
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// โทรหาผู้เกี่ยวข้องในเหตุ
  Future<void> _callParticipant() async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      final incidentDoc = await ref.read(firestoreProvider)
          .collection('incidents').doc(widget.incidentId).get();
      if (!incidentDoc.exists) return;
      final data = incidentDoc.data()!;

      if (widget.userRole == 'dispatcher') {
        // Dispatcher: แสดง dialog เลือกโทรหา reporter หรือ responder
        final reporterId = data['reporterId'] as String?;
        final responderId = data['responderId'] as String?;
        final reporterName = data['reporterName'] as String? ?? 'ผู้แจ้ง';
        final responderName = data['responderName'] as String? ?? 'ผู้รับเหตุ';

        if (!mounted) return;
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('📞 โทรหาใคร?'),
            children: [
              if (reporterId != null)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, reporterId),
                  child: ListTile(
                    leading: const Icon(Icons.person, color: Colors.blue),
                    title: Text(reporterName),
                    subtitle: const Text('ผู้แจ้งเหตุ'),
                  ),
                ),
              if (responderId != null)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, responderId),
                  child: ListTile(
                    leading: const Icon(Icons.support_agent, color: Colors.teal),
                    title: Text(responderName),
                    subtitle: const Text('ผู้รับเหตุ'),
                  ),
                ),
              if (reporterId == null && responderId == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('ไม่พบผู้เกี่ยวข้อง'),
                ),
            ],
          ),
        );
        if (choice == null) return;
        await _makeCall(choice);
      } else if (widget.userRole == 'user') {
        // User: โทรหา Responder
        final responderId = data['responderId'] as String?;
        if (responderId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ยังไม่มีผู้รับเหตุ'), backgroundColor: Colors.orange),
            );
          }
          return;
        }
        await _makeCall(responderId);
      } else {
        // Responder: โทรหา Reporter (ผู้แจ้ง)
        final reporterId = data['reporterId'] as String?;
        if (reporterId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ไม่พบข้อมูลผู้แจ้ง'), backgroundColor: Colors.orange),
            );
          }
          return;
        }
        await _makeCall(reporterId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถโทรออกได้'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _makeCall(String targetUid) async {
    final userDoc = await ref.read(firestoreProvider)
        .collection('users').doc(targetUid).get();
    final phone = userDoc.data()?['phoneNumber'] as String?;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบเบอร์โทรของผู้ใช้'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    await launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  void dispose() {
    // Issue #6: Clear active chat
    WebNotificationWatcher.activeIncidentChatId = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isReadOnly ? "💬 ดูแชท (อ่านอย่างเดียว)" : "💬 แชท",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.incidentTitle,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        // Issue #2: Dispatcher สามารถสลับโหมดจาก read-only เป็น active chat ได้
        actions: [
          // ปุ่มโทร — โทรหาคู่สนทนาในแชท (reporter หรือ responder)
          IconButton(
            icon: const Icon(Icons.phone, size: 20),
            tooltip: 'โทรหาผู้เกี่ยวข้อง',
            onPressed: () => _callParticipant(),
          ),
          if (widget.userRole == 'dispatcher')
            IconButton(
              icon: Icon(_isReadOnly ? Icons.edit : Icons.visibility, size: 20),
              tooltip: _isReadOnly ? 'ร่วมสนทนา' : 'ดูอย่างเดียว',
              onPressed: () {
                setState(() => _isReadOnly = !_isReadOnly);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isReadOnly ? '🔒 โหมดอ่านอย่างเดียว' : '✏️ โหมดร่วมสนทนา'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
        ],
      ),

      body: Column(
        children: [
          // F7: Read-only banner
          if (_isReadOnly)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.visibility, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'โหมดดูอย่างเดียว',
                      style: TextStyle(fontSize: 12, color: Colors.brown),
                    ),
                  ),
                  if (widget.userRole == 'dispatcher')
                    TextButton(
                      onPressed: () => setState(() => _isReadOnly = false),
                      child: const Text('ร่วมสนทนา', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),

          // ส่วนแสดงข้อความ
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatRepo.getMessages(widget.incidentId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // UX Review Bug 4: ข้อความภาษาไทย ไม่แสดง error ดิบ
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          const Text('ไม่สามารถโหลดข้อความได้'),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () { (context as Element).markNeedsBuild(); },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('ลองใหม่'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("ยังไม่มีข้อความ — เริ่มพิมพ์เลย!",
                      style: TextStyle(color: Colors.grey)),
                  );
                }

                final messages = snapshot.data!.docs
                    .map((doc) => ChatMessage.fromFirestore(doc))
                    .toList();

                // F8: mark as read เมื่อมีข้อความใหม่เข้า
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                  _markChatAsRead();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUser?.uid;

                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),

          // #13: Quick Replies — ซ่อนใน readOnly mode
          // v4: Quick Replies ตาม role — ซ่อนใน readOnly mode
          if (!_isReadOnly)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: _quickReplies.map((text) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(text, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      _messageController.text = text;
                      _sendMessage();
                    },
                  ),
                )).toList(),
              ),
            ),

          // ส่วนพิมพ์ข้อความ — ซ่อนใน readOnly mode
          if (!_isReadOnly)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SafeArea(
                child: Row(
                  children: [
                    // v4: Camera Button
                    if (!kIsWeb)
                      IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.grey),
                        tooltip: 'ถ่ายรูป',
                        onPressed: _isUploading ? null : () => _pickAndSendImage(source: ImageSource.camera),
                      ),
                    // v4: Gallery Button
                    IconButton(
                      icon: _isUploading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(kIsWeb ? Icons.add_photo_alternate : Icons.image, color: Colors.grey),
                      tooltip: kIsWeb ? 'แนบรูป / ถ่ายภาพ' : 'เลือกรูปจากแกลเลอรี',
                      onPressed: _isUploading ? null : () => _pickAndSendImage(source: ImageSource.gallery),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: "พิมพ์ข้อความ...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: _isSending ? Colors.grey : AppTheme.primaryOrange,
                      child: IconButton(
                        icon: _isSending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: _isSending ? null : () => _sendMessage(),
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

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryOrange : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            if (!isMe) const SizedBox(height: 2),

            // #17: Show image if available
            if (message.imageUrl != null && message.imageUrl!.isNotEmpty) ...[
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: AppNetworkImage(
                        imageUrl: message.imageUrl!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 180,
                    child: AppNetworkImage(
                      imageUrl: message.imageUrl!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],

            if (message.text.isNotEmpty && message.text != '📷 รูปภาพ')
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 15,
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
