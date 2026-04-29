class Pet {
  final int id;
  final String name;
  final String? photoUrl;
  final bool isDeceased;

  Pet({required this.id, required this.name, this.photoUrl, this.isDeceased = false});
}
