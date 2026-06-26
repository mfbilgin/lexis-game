import 'dart:io'; import 'dart:convert'; void main() { var d = jsonDecode(File('assets/words/definitions.json').readAsStringSync()); print('SALA: ' + (d['sala'] ?? d['SALA'] ?? 'Not Found')); }
