import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  // get instance of firestore
  // do flutter pub add cloud_firestore to get it
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // get user stream
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        // go through each individual user
        final user = doc.data();

        // return user
        return user;
      }).toList();
    });
  }

  // send message

  // get message
}

/* A map is like this
  {
    'email' : person@carsu.edu.ph
    'id' : 231231somethin
  }
  {
    'email' : person@carsu.edu.ph
    'id' : 231231somethin
  }
    which is how your databse looks like
   */
