class Post {
  final int id;
  final String title;
  final String body;

  const Post({
    required this.id,
    required this.title,
    required this.body,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'body': body,
      };

  factory Post.fromMap(Map<String, Object?> map) {
    return Post(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
    );
  }
}