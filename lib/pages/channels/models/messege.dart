class Message {
  final String senderID;
  final String senderEmail;
  final String message;
  final String timestamp;

  Message({
    required this.senderID,
    required this.senderEmail,
    required this.message,
    required this.timestamp,
  });

  // Convert TO Map (for storing)
  // Map<String, dynamic> toMap() => {
  //   "senderID": senderID,
  //   "senderEmail": senderEmail,
  //   "message": message,
  //   "timestamp": timestamp,
  // };

  // factory Message.fromMap(Map<String, dynamic> map) => Message(
  //   senderID: map["senderID"],
  //   senderEmail: map["senderEmail"],
  //   message: map["message"],
  //   timestamp: map["timestamp"],
  // );
}
