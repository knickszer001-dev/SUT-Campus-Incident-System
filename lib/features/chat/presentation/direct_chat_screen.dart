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
import '../data/direct_chat_repository.dart';
import '../../notification/web_notification_watcher.dart';

/// Direct Chat Screen — DM ระหว่าง Dispatcher ↔ Responder
class DirectChatScreen extends ConsumerStatefulWidget {

  final String otherUserId;
  final String otherUserName;
  final String currentUserRole; // 'dispatcher' / 'responder'

  const DirectChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.currentUserRole,
  });

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final DirectChatRepository _chatRepo;
  String _currentUserName = '';
  String _currentUid = '';
  late final String _chatId;
  bool _isUploading = false;
  bool _isSending = false; // EC-1: Debounce

  @override
  void initState() {
    super.initState();
    _chatRepo = DirectChatRepository(firestore: ref.read(firestoreProvider));
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    _currentUid = user.uid;
    _chatId = _chatRepo.getChatId(_currentUid, widget.otherUserId);

    final name = await ref.read(authRepositoryProvider).getCurrentUserName();
    if (mounted) {
      setState(() => _currentUserName = name);
      _markAsRead();
      // Issue #6: Set active DM chat to suppress duplicate notifications
      WebNotificationWatcher.activeDmChatId = _chatId;
    }
  }

  Future<void> _markAsRead() async {
    if (_currentUid.isEmpty) return;
    await _chatRepo.markAsRead(_chatId, _currentUid);
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageUrl == null) return;
    if (_currentUid.isEmpty) return;
    if (_isSending) return; // EC-1: ป้องกันกดซ้ำ

    // EC-2: เก็บข้อความไว้ก่อน clear
    final savedText = _messageController.text;
    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await _chatRepo.sendMessage(
        chatId: _chatId,
        senderId: _currentUid,
        senderName: _currentUserName,
        text: imageUrl != null && text.isEmpty ? '📷 รูปภาพ' : text,
        imageUrl: imageUrl,
        participantIds: [_currentUid, widget.otherUserId],
      );
      _scrollToBottom();
    } catch (e) {
      // EC-2: คืนข้อความกลับ
      if (mounted) {
        _messageController.text = savedText;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งข้อความไม่สำเร็จ กรุณาลองใหม่'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage({required ImageSource source}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 800);
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final fileName = 'dm_${_chatId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
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

  /// UX Review #7: Quick replies ใช้คำกลาง
  List<String> get _quickReplies {
    if (widget.currentUserRole == 'dispatcher') {
      return ['สถานะเป็นอย่างไรบ้าง', 'มีเหตุใหม่', 'ขอบคุณ', 'กรุณาอัปเดตสถานะ'];
    } else {
      return ['พร้อมรับงาน', 'กำลังดำเนินการ', 'เสร็จแล้ว', 'ต้องการสนับสนุน'];
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

  /// โทรหาคู่สนทนา
  Future<void> _callOtherUser() async {
    try {
      final userDoc = await ref.read(firestoreProvider)
          .collection('users').doc(widget.otherUserId).get();
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถโทรออกได้'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    // Issue #6: Clear active DM chat
    WebNotificationWatcher.activeDmChatId = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "💬 แชทกับ ${widget.otherUserName}",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.currentUserRole == 'dispatcher' ? 'ผู้รับเหตุ' : 'ศูนย์รับเหตุ',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          // ปุ่มโทร
          IconButton(
            icon: const Icon(Icons.phone, size: 20),
            tooltip: 'โทรหา ${widget.otherUserName}',
            onPressed: () => _callOtherUser(),
          ),
        ],
      ),

      body: _currentUid.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [
            // Messages
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatRepo.getMessages(_chatId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
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
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text("ยังไม่มีข้อความ — เริ่มพิมพ์เลย!",
                            style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs
                      .map((doc) => ChatMessage.fromFirestore(doc))
                      .toList();

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                    _markAsRead();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == _currentUid;
                      return _buildMessageBubble(msg, isMe);
                    },
                  );
                },
              ),
            ),

            // Quick Replies
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

            // Input bar
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
                    if (!kIsWeb)
                      IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.grey),
                        tooltip: 'ถ่ายรูป',
                        onPressed: _isUploading ? null : () => _pickAndSendImage(source: ImageSource.camera),
                      ),
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

            // Show image if available
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
