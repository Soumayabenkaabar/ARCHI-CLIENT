class Project {
  final String id;
  final String titre;

  const Project({required this.id, required this.titre});

  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id:    j['id'] as String,
    titre: (j['titre'] as String?) ?? '',
  );
}
