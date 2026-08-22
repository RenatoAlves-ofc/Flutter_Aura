part of '../main.dart';

// ============================================================
// PERSISTÊNCIA (shared_preferences)
// ============================================================

class AuraStore {
  static const String kTasks = 'tasks';
  static const String kSessions = 'sessions';
  static const String kPoints = 'points';
  static const String kStreak = 'streak';
  static const String kTokens = 'forgivenessTokens';
  static const String kRunLength = 'streakRunLength';
  static const String kLastActiveDay = 'lastActiveDay';
  static const String kDemoSeeded = 'demoSeeded';
  static const String kSelectedMethod = 'selectedMethodId';
  static const String kCustomFocus = 'customFocusMinutes';
  static const String kCustomBreak = 'customBreakMinutes';
  static const String kProfileName = 'profileName';
  static const String kProfileContext = 'profileContext';
  static const String kProfileFocus = 'profileFocus';
  static const String kDailyLineDate = 'dailyLineDate';
  static const String kDailyLineText = 'dailyLineText';

  /// Lê uma lista salva em JSON, descartando o conteúdo se ele estiver corrompido.
  ///
  /// Sem isto, um único registro malformado no armazenamento local deixaria o app
  /// impossível de abrir para sempre — a exceção subiria durante a inicialização e
  /// o usuário não teria nenhuma saída a não ser reinstalar.
  static Future<List<T>> _loadList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return <T>[];
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error, stack) {
      // Dado ilegível: melhor começar vazio do que não abrir. Mas descartar em
      // silêncio esconderia do usuário que ele acabou de perder dados — o
      // registro faz o motivo aparecer na tela Sobre.
      AuraCrashReport.record(
        'Dado ilegível em "$key" foi descartado do armazenamento local: $error',
        stack,
      );
      await prefs.remove(key);
      return <T>[];
    }
  }

  static Future<List<TaskItem>> loadTasks() =>
      _loadList(kTasks, TaskItem.fromJson);

  static Future<void> saveTasks(List<TaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        kTasks, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  static Future<List<StudySession>> loadSessions() =>
      _loadList(kSessions, StudySession.fromJson);

  static Future<void> saveSessions(List<StudySession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        kSessions, jsonEncode(sessions.map((s) => s.toJson()).toList()));
  }

  static Future<int> loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(kPoints) ?? 0;
  }

  static Future<void> savePoints(int points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPoints, points);
  }

  static Future<StreakState> loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return StreakState(
      streak: prefs.getInt(kStreak) ?? 0,
      tokens: prefs.getInt(kTokens) ?? 0,
      runLength: prefs.getInt(kRunLength) ?? 0,
      lastActiveDay: prefs.getString(kLastActiveDay),
    );
  }

  static Future<void> saveStreak(StreakState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kStreak, s.streak);
    await prefs.setInt(kTokens, s.tokens);
    await prefs.setInt(kRunLength, s.runLength);
    if (s.lastActiveDay != null) {
      await prefs.setString(kLastActiveDay, s.lastActiveDay!);
    }
  }

  static Future<bool> demoSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kDemoSeeded) ?? false;
  }

  static Future<void> setDemoSeeded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDemoSeeded, value);
  }

  static Future<String> loadSelectedMethod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kSelectedMethod) ?? 'pomodoro_classico';
  }

  static Future<void> saveSelectedMethod(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSelectedMethod, id);
  }

  static Future<AuraProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return AuraProfile(
      name: prefs.getString(kProfileName),
      contextId: prefs.getString(kProfileContext) ?? kDefaultContextId,
      focus: prefs.getString(kProfileFocus),
    );
  }

  static Future<void> saveProfile(AuraProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    // Campo apagado é campo removido, não string vazia guardada: assim o
    // `loadProfile` volta ao estado "sem perfil" de verdade.
    Future<void> put(String key, String? value) async {
      final v = value?.trim();
      if (v == null || v.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, v);
      }
    }

    await put(kProfileName, profile.name);
    await put(kProfileFocus, profile.focus);
    await prefs.setString(kProfileContext, profile.contextId);
  }

  static Future<List<int>> loadCustomDurations() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      prefs.getInt(kCustomFocus) ?? 30,
      prefs.getInt(kCustomBreak) ?? 8,
    ];
  }

  static Future<void> saveCustomDurations(int focus, int rest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kCustomFocus, focus);
    await prefs.setInt(kCustomBreak, rest);
  }

  /// `null` se nunca houve frase salva, ou se a salva é de outro dia — nos
  /// dois casos cabe uma tentativa nova. Uma tentativa por dia é o que faz
  /// "juntar Groq e Gemini para não bater limite" valer a pena de verdade:
  /// 50 pessoas somam ~50 chamadas por dia no total, não 50 por abertura de
  /// tela.
  static Future<String?> loadDailyLineFor(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(kDailyLineDate) != dateKey) return null;
    return prefs.getString(kDailyLineText);
  }

  static Future<void> saveDailyLine(String dateKey, String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kDailyLineDate, dateKey);
    await prefs.setString(kDailyLineText, text);
  }
}
