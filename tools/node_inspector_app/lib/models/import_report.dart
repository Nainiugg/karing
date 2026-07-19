import 'node_record.dart';

class ImportIssue {
  const ImportIssue({required this.message, this.item = ''});

  final String item;
  final String message;
}

class ImportReport {
  const ImportReport({
    required this.format,
    required this.nodes,
    required this.issues,
    required this.duplicates,
    this.candidates = 0,
    this.filteredNoise = 0,
  });

  final String format;
  final List<NodeRecord> nodes;
  final List<ImportIssue> issues;
  final int duplicates;
  final int candidates;
  final int filteredNoise;

  int get imported => nodes.length;
}
