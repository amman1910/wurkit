import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<int> watchTotalUnreadCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.fold<int>(0, (total, doc) {
            final unreadCounts = _readMap(doc.data()['unreadCounts']);
            final count = unreadCounts[currentUser.uid];
            if (count is int) {
              return total + count;
            }
            if (count is num) {
              return total + count.toInt();
            }

            return total;
          });
        });
  }

  Stream<List<Map<String, dynamic>>> watchUserChats() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs.map((doc) {
            final data = doc.data();
            return <String, dynamic>{
              ...data,
              'chatId': _readString(data, 'chatId', doc.id),
            };
          }).toList();

          chats.sort((a, b) => _sortTime(b).compareTo(_sortTime(a)));
          return chats;
        });
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return <String, dynamic>{
              ...data,
              'messageId': _readString(data, 'messageId', doc.id),
            };
          }).toList();
        });
  }

  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data();

    if (!chatDoc.exists || chatData == null) {
      throw Exception('Chat not found');
    }

    final participants = _readStringList(chatData['participants']);
    if (!participants.contains(currentUser.uid)) {
      throw Exception('You can only send messages in your own chats');
    }

    final receiverId = participants.firstWhere(
      (participantId) => participantId != currentUser.uid,
      orElse: () => '',
    );
    if (receiverId.isEmpty) {
      throw Exception('Message receiver is unavailable');
    }

    final messageRef = chatRef.collection('messages').doc();
    final batch = _firestore.batch();

    batch.set(messageRef, {
      'messageId': messageRef.id,
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'text': trimmedText,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [currentUser.uid],
      'isDeleted': false,
    });

    batch.update(chatRef, {
      'lastMessage': trimmedText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUser.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      FieldPath(['unreadCounts', receiverId]): FieldValue.increment(1),
      FieldPath(['unreadCounts', currentUser.uid]): 0,
    });

    await batch.commit();
  }

  Future<void> markChatAsRead(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    await _firestore.collection('chats').doc(chatId).update({
      FieldPath(['unreadCounts', currentUser.uid]): 0,
    });
  }

  Future<String> getOrCreateChatForApprovedApplication({
    required String jobId,
    required String employeeId,
    required String employerId,
  }) async {
    final existingChat = await _firestore
        .collection('chats')
        .where('jobId', isEqualTo: jobId)
        .where('employeeId', isEqualTo: employeeId)
        .where('employerId', isEqualTo: employerId)
        .limit(1)
        .get();

    if (existingChat.docs.isNotEmpty) {
      final data = existingChat.docs.first.data();
      return _readString(data, 'chatId', existingChat.docs.first.id);
    }

    final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
    final employeeProfileDoc = await _firestore
        .collection('employeeProfiles')
        .doc(employeeId)
        .get();
    final employerProfileDoc = await _firestore
        .collection('employerProfiles')
        .doc(employerId)
        .get();
    final applicationSnapshot = await _firestore
        .collection('applications')
        .where('jobId', isEqualTo: jobId)
        .where('employeeId', isEqualTo: employeeId)
        .where('employerId', isEqualTo: employerId)
        .limit(1)
        .get();

    final jobData = jobDoc.data();
    final employeeProfileData = employeeProfileDoc.data();
    final employerProfileData = employerProfileDoc.data();
    final applicationData = applicationSnapshot.docs.isEmpty
        ? null
        : applicationSnapshot.docs.first.data();

    final employeeName = _readString(
      applicationData,
      'employeeName',
      _readString(employeeProfileData, 'name', 'Worker'),
    );
    final employeeImageUrl = _readString(
      employeeProfileData,
      'profileImageUrl',
      '',
    );
    final employerName = _readString(
      employerProfileData,
      'businessName',
      'Business',
    );
    final employerImageUrl = _readString(
      employerProfileData,
      'businessLogoUrl',
      '',
    );
    final jobTitle = _readString(
      applicationData,
      'jobTitle',
      _readString(jobData, 'title', _readString(jobData, 'jobTitle', 'Job')),
    );

    final chatRef = _firestore.collection('chats').doc();
    await chatRef.set({
      'chatId': chatRef.id,
      'applicationId': applicationSnapshot.docs.isEmpty
          ? null
          : applicationSnapshot.docs.first.id,
      'jobId': jobId,
      'employeeId': employeeId,
      'employerId': employerId,
      'participants': [employeeId, employerId],
      'participantIds': [employeeId, employerId],
      'participantNames': {employeeId: employeeName, employerId: employerName},
      'participantImages': {
        employeeId: employeeImageUrl,
        employerId: employerImageUrl,
      },
      'employeeName': employeeName,
      'employeeImageUrl': employeeImageUrl,
      'employerName': employerName,
      'employerImageUrl': employerImageUrl,
      'jobTitle': jobTitle,
      'lastMessage': '',
      'lastMessageAt': null,
      'lastMessageSenderId': null,
      'unreadCounts': {employeeId: 0, employerId: 0},
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return chatRef.id;
  }

  String getOtherParticipantId(Map<String, dynamic> chat) {
    final currentUser = _auth.currentUser;
    final participants = _readStringList(chat['participants']);
    if (currentUser == null || participants.isEmpty) {
      return '';
    }

    return participants.firstWhere(
      (participantId) => participantId != currentUser.uid,
      orElse: () => participants.first,
    );
  }

  String getOtherParticipantName(Map<String, dynamic> chat) {
    final otherParticipantId = getOtherParticipantId(chat);
    final participantNames = _readMap(chat['participantNames']);

    return _readString(
      participantNames,
      otherParticipantId,
      _readString(
        chat,
        'employerName',
        _readString(chat, 'employeeName', 'Wurkit user'),
      ),
    );
  }

  String getOtherParticipantImage(Map<String, dynamic> chat) {
    final otherParticipantId = getOtherParticipantId(chat);
    final participantImages = _readMap(chat['participantImages']);

    return _readString(
      participantImages,
      otherParticipantId,
      _readString(
        chat,
        'employerImageUrl',
        _readString(chat, 'employeeImageUrl', ''),
      ),
    );
  }

  int getUnreadCount(Map<String, dynamic> chat) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return 0;
    }

    final unreadCounts = _readMap(chat['unreadCounts']);
    final count = unreadCounts[currentUser.uid];
    if (count is int) {
      return count;
    }
    if (count is num) {
      return count.toInt();
    }

    return 0;
  }

  int _sortTime(Map<String, dynamic> chat) {
    final timestamp =
        chat['lastMessageAt'] ?? chat['updatedAt'] ?? chat['createdAt'];
    if (timestamp is Timestamp) {
      return timestamp.millisecondsSinceEpoch;
    }

    return 0;
  }

  String _readString(Map<String, dynamic>? data, String key, String fallback) {
    final value = data?[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  Map<String, dynamic> _readMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  List<String> _readStringList(Object? value) {
    if (value is Iterable) {
      return value.whereType<String>().toList();
    }

    return [];
  }
}
