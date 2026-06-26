import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('gts.json');
  if (!await file.exists()) {
    print('gts.json not found!');
    return;
  }
  final lines = file.openRead().transform(utf8.decoder).transform(LineSplitter());
  
  Map<String, List<String>> targetWords = {'4': [], '5': [], '6': [], '7': []};
  Map<String, List<String>> validGuesses = {'4': [], '5': [], '6': [], '7': []};
  Map<String, String> definitions = {};
  
  Set<String> excludeTags = {'eskimiş', 'halk ağzı', 'ağızlardan', 'argo', 'tarih', 'yerel', 'yöresel', 'teklifsiz konuşmada'};

  int count = 0;
  await for (var line in lines) {
    if (line.trim().isEmpty) continue;
    try {
      final data = jsonDecode(line);
      String originalWord = data['madde'];
      String word = originalWord
          .replaceAll('â', 'a')
          .replaceAll('î', 'i')
          .replaceAll('û', 'u')
          .replaceAll('Â', 'a')
          .replaceAll('Î', 'i')
          .replaceAll('Û', 'u')
          .toLowerCase();
      
      // Filter words
      if (word.contains(' ') || word.contains('-') || word.contains('\'') || word.contains('^')) continue;
      
      int len = word.length;
      if (len < 4 || len > 7) continue;

      // Check if it's a suffix/prefix etc
      if (data['ozel_mi'] == '1') continue; // exclude proper nouns (özel isimler)

      List<dynamic> anlamlarListe = data['anlamlarListe'] ?? [];
      if (anlamlarListe.isEmpty) continue;

      bool hasValidMeaning = false;
      String primaryDefinition = '';

      for (var anlamObj in anlamlarListe) {
        String anlamText = anlamObj['anlam'] ?? '';
        if (primaryDefinition.isEmpty) primaryDefinition = anlamText;

        List<dynamic> ozelliklerListe = anlamObj['ozelliklerListe'] ?? [];
        bool isObscure = false;
        for (var ozellik in ozelliklerListe) {
          String tamAdi = ozellik['tam_adi']?.toLowerCase() ?? '';
          if (excludeTags.contains(tamAdi)) {
            isObscure = true;
            break;
          }
        }
        
        if (!isObscure) {
          hasValidMeaning = true;
        }
      }

      // Add to valid guesses and definitions
      if (!validGuesses[len.toString()]!.contains(word)) {
        validGuesses[len.toString()]!.add(word);
      }
      
      if (definitions.containsKey(word)) {
        // If word already exists (e.g. hala vs hâlâ), combine their definitions
        if (!definitions[word]!.contains(primaryDefinition)) {
          definitions[word] = definitions[word]! + ' / ' + primaryDefinition;
        }
      } else {
        definitions[word] = primaryDefinition;
      }

      if (hasValidMeaning) {
        if (!targetWords[len.toString()]!.contains(word)) {
          targetWords[len.toString()]!.add(word);
        }
      }

      
      count++;
    } catch (e) {
      print('Error parsing line: $e');
    }
  }

  // Save files
  await Directory('assets/words').create(recursive: true);
  
  await File('assets/words/target_words.json').writeAsString(jsonEncode(targetWords));
  await File('assets/words/valid_guesses.json').writeAsString(jsonEncode(validGuesses));
  await File('assets/words/definitions.json').writeAsString(jsonEncode(definitions));

  print('Done parsing $count valid length words.');
  print('Target words: \n4: ${targetWords['4']!.length}, 5: ${targetWords['5']!.length}, 6: ${targetWords['6']!.length}, 7: ${targetWords['7']!.length}');
  print('Valid guesses: \n4: ${validGuesses['4']!.length}, 5: ${validGuesses['5']!.length}, 6: ${validGuesses['6']!.length}, 7: ${validGuesses['7']!.length}');
}
