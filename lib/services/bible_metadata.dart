class BibleMetadata {
  BibleMetadata._();

  // Mapa canônico de siglas por livro (nomes principais)
  static const Map<String, String> _canonicalAbbr = {
    'Gênesis': 'Gn', 'Êxodo': 'Ex', 'Levítico': 'Lv', 'Números': 'Nm', 'Deuteronômio': 'Dt',
    'Josué': 'Js', 'Juízes': 'Jz', 'Rute': 'Rt', '1 Samuel': '1Sm', '2 Samuel': '2Sm',
    '1 Reis': '1Rs', '2 Reis': '2Rs', '1 Crônicas': '1Cr', '2 Crônicas': '2Cr', 'Esdras': 'Ed',
    'Neemias': 'Ne', 'Ester': 'Et', 'Jó': 'Jó', 'Salmos': 'Sl', 'Provérbios': 'Pv',
    'Eclesiastes': 'Ec', 'Cantares': 'Ct', 'Isaías': 'Is', 'Jeremias': 'Jr', 'Lamentações': 'Lm',
    'Ezequiel': 'Ez', 'Daniel': 'Dn', 'Oséias': 'Os', 'Joel': 'Jl', 'Amós': 'Am',
    'Obadias': 'Ob', 'Jonas': 'Jn', 'Miquéias': 'Mq', 'Naum': 'Na', 'Habacuque': 'Hc',
    'Sofonias': 'Sf', 'Ageu': 'Ag', 'Zacarias': 'Zc', 'Malaquias': 'Ml',
    'Mateus': 'Mt', 'Marcos': 'Mc', 'Lucas': 'Lc', 'João': 'Jo', 'Atos dos Apóstolos': 'At',
    'Romanos': 'Rm', '1 Coríntios': '1Co', '2 Coríntios': '2Co', 'Gálatas': 'Gl', 'Efésios': 'Ef',
    'Filipenses': 'Fp', 'Colossenses': 'Cl', '1 Tessalonicenses': '1Ts', '2 Tessalonicenses': '2Ts',
    '1 Timóteo': '1Tm', '2 Timóteo': '2Tm', 'Tito': 'Tt', 'Filemom': 'Fm', 'Hebreus': 'Hb',
    'Tiago': 'Tg', '1 Pedro': '1Pe', '2 Pedro': '2Pe', '1 João': '1Jo', '2 João': '2Jo',
    '3 João': '3Jo', 'Judas': 'Jd', 'Apocalipse': 'Ap',
  };

  // Aliases/variações que apontam para o nome canônico
  static const Map<String, String> _aliases = {
    'Genesis': 'Gênesis', 'Ge': 'Gênesis', 'Gn': 'Gênesis',
    'Exodo': 'Êxodo', 'Ex': 'Êxodo',
    'Levitico': 'Levítico', 'Lv': 'Levítico',
    'Numeros': 'Números', 'Nm': 'Números',
    'Deuteronomio': 'Deuteronômio', 'Dt': 'Deuteronômio',
    'Josue': 'Josué', 'Js': 'Josué',
    'Juizes': 'Juízes', 'Jz': 'Juízes',
    'Rt': 'Rute',
    '1Samuel': '1 Samuel', '1 Sm': '1 Samuel', '1Sm': '1 Samuel',
    '2Samuel': '2 Samuel', '2 Sm': '2 Samuel', '2Sm': '2 Samuel',
    '1Reis': '1 Reis', '1 Rs': '1 Reis', '1Rs': '1 Reis',
    '2Reis': '2 Reis', '2 Rs': '2 Reis', '2Rs': '2 Reis',
    '1Cronicas': '1 Crônicas', '1 Cr': '1 Crônicas', '1Cr': '1 Crônicas',
    '2Cronicas': '2 Crônicas', '2 Cr': '2 Crônicas', '2Cr': '2 Crônicas',
    'Ed': 'Esdras',
    'Ne': 'Neemias',
    'Et': 'Ester',
    'Jo': 'João', // ambíguo (Jó/João); prioriza NT para alias puro "Jo"
    'Jó': 'Jó',
    'Sl': 'Salmos',
    'Proverbios': 'Provérbios', 'Pv': 'Provérbios',
    'Ec': 'Eclesiastes',
    'Ct': 'Cantares', 'Cânticos': 'Cantares', 'Canticos': 'Cantares',
    'Isaias': 'Isaías', 'Is': 'Isaías',
    'Jr': 'Jeremias',
    'Lamentacoes': 'Lamentações', 'Lm': 'Lamentações',
    'Ez': 'Ezequiel',
    'Dn': 'Daniel',
    'Oseias': 'Oséias', 'Os': 'Oséias',
    'Jl': 'Joel',
    'Amos': 'Amós', 'Am': 'Amós',
    'Ob': 'Obadias',
    'Jn': 'Jonas',
    'Miqueias': 'Miquéias', 'Mq': 'Miquéias',
    'Na': 'Naum',
    'Hc': 'Habacuque',
    'Sf': 'Sofonias',
    'Ag': 'Ageu',
    'Zc': 'Zacarias',
    'Ml': 'Malaquias',
    'Mt': 'Mateus',
    'Mc': 'Marcos',
    'Lc': 'Lucas',
    'Joao': 'João',
    'Atos': 'Atos dos Apóstolos', 'At': 'Atos dos Apóstolos',
    'Rm': 'Romanos',
    '1Corintios': '1 Coríntios', '1 Co': '1 Coríntios', '1Co': '1 Coríntios',
    '2Corintios': '2 Coríntios', '2 Co': '2 Coríntios', '2Co': '2 Coríntios',
    'Galatas': 'Gálatas', 'Gl': 'Gálatas',
    'Efesios': 'Efésios', 'Ef': 'Efésios',
    'Fp': 'Filipenses',
    'Cl': 'Colossenses',
    '1Tessalonicenses': '1 Tessalonicenses', '1 Ts': '1 Tessalonicenses', '1Ts': '1 Tessalonicenses',
    '2Tessalonicenses': '2 Tessalonicenses', '2 Ts': '2 Tessalonicenses', '2Ts': '2 Tessalonicenses',
    '1Timoteo': '1 Timóteo', '1 Tm': '1 Timóteo', '1Tm': '1 Timóteo',
    '2Timoteo': '2 Timóteo', '2 Tm': '2 Timóteo', '2Tm': '2 Timóteo',
    'Tt': 'Tito',
    'Fm': 'Filemom', 'Filemon': 'Filemom',
    'Hb': 'Hebreus',
    'Tg': 'Tiago',
    '1Pedro': '1 Pedro', '1 Pe': '1 Pedro', '1Pe': '1 Pedro',
    '2Pedro': '2 Pedro', '2 Pe': '2 Pedro', '2Pe': '2 Pedro',
    '1Joao': '1 João', '1 Jo': '1 João', '1Jo': '1 João',
    '2Joao': '2 João', '2 Jo': '2 João', '2Jo': '2 João',
    '3Joao': '3 João', '3 Jo': '3 João', '3Jo': '3 João',
    'Jd': 'Judas',
    'Ap': 'Apocalipse',
  };

  static const Map<String, int> _chapterCount = {
    'Gênesis': 50, 'Êxodo': 40, 'Levítico': 27, 'Números': 36, 'Deuteronômio': 34,
    'Josué': 24, 'Juízes': 21, 'Rute': 4, '1 Samuel': 31, '2 Samuel': 24,
    '1 Reis': 22, '2 Reis': 25, '1 Crônicas': 29, '2 Crônicas': 36, 'Esdras': 10,
    'Neemias': 13, 'Ester': 10, 'Jó': 42, 'Salmos': 150, 'Provérbios': 31,
    'Eclesiastes': 12, 'Cantares': 8, 'Isaías': 66, 'Jeremias': 52, 'Lamentações': 5,
    'Ezequiel': 48, 'Daniel': 12, 'Oséias': 14, 'Joel': 3, 'Amós': 9,
    'Obadias': 1, 'Jonas': 4, 'Miquéias': 7, 'Naum': 3, 'Habacuque': 3,
    'Sofonias': 3, 'Ageu': 2, 'Zacarias': 14, 'Malaquias': 4,
    'Mateus': 28, 'Marcos': 16, 'Lucas': 24, 'João': 21, 'Atos dos Apóstolos': 28,
    'Romanos': 16, '1 Coríntios': 16, '2 Coríntios': 13, 'Gálatas': 6, 'Efésios': 6,
    'Filipenses': 4, 'Colossenses': 4, '1 Tessalonicenses': 5, '2 Tessalonicenses': 3,
    '1 Timóteo': 6, '2 Timóteo': 4, 'Tito': 3, 'Filemom': 1, 'Hebreus': 13,
    'Tiago': 5, '1 Pedro': 5, '2 Pedro': 3, '1 João': 5, '2 João': 1,
    '3 João': 1, 'Judas': 1, 'Apocalipse': 22,
  };

  static const Set<String> _ntBooks = {
    'Mateus','Marcos','Lucas','João','Atos dos Apóstolos','Romanos',
    '1 Coríntios','2 Coríntios','Gálatas','Efésios','Filipenses','Colossenses',
    '1 Tessalonicenses','2 Tessalonicenses','1 Timóteo','2 Timóteo','Tito','Filemom',
    'Hebreus','Tiago','1 Pedro','2 Pedro','1 João','2 João','3 João','Judas','Apocalipse',
  };

  static String normalizeName(String name) {
    // Resolve aliases e mantém capitalização correta
    return _aliases[name] ?? name;
  }

  static String getAbbreviation(String name) {
    final canonical = normalizeName(name);
    return _canonicalAbbr[canonical] ?? '';
  }

  static int getChapterCount(String name) {
    final canonical = normalizeName(name);
    return _chapterCount[canonical] ?? 0;
  }

  static String getTestament(String name) {
    final canonical = normalizeName(name);
    return _ntBooks.contains(canonical) ? 'NT' : 'AT';
  }
}
