// Aura — um Pomodoro que aprende com você.
//
// Em vez de só contar minutos, o Aura cruza como você está se sentindo com
// quanto tempo você realmente consegue manter o foco, e devolve isso como
// descobertas pessoais. Tudo local, sem login, sem feed.
//
// Arquivo único por restrição do FlutLab (sem imports relativos).

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Sem isto, qualquer exceção na inicialização derruba o app e o Android mostra
  // apenas "o app tem um bug", sem dizer qual. Num aparelho sem cabo e sem logcat
  // — que é o caso de quem só recebeu o APK por QR Code — isso é um beco sem
  // saída. Aqui o erro é capturado e mostrado na tela, para poder ser lido.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AuraCrashReport.record(details.exception, details.stack);
  };

  ErrorWidget.builder = (details) => AuraErrorScreen(
        title: 'Algo quebrou ao desenhar a tela',
        error: details.exception,
        stack: details.stack,
      );

  runZonedGuarded(
    () {
      final binding = WidgetsFlutterBinding.ensureInitialized();
      // Erros assíncronos que não passam pelo FlutterError.onError.
      binding.platformDispatcher.onError = (error, stack) {
        AuraCrashReport.record(error, stack);
        return true;
      };
      runApp(const AuraApp());
    },
    (error, stack) {
      AuraCrashReport.record(error, stack);
      // O app pode ter morrido antes de qualquer tela existir. Subir uma tela de
      // erro é a única forma de o problema ficar visível no aparelho.
      runApp(AuraApp(fatalError: error, fatalStack: stack));
    },
  );
}

/// Guarda a última exceção vista, para a tela de erro poder exibi-la.
class AuraCrashReport {
  static Object? lastError;
  static StackTrace? lastStack;

  static void record(Object error, StackTrace? stack) {
    lastError = error;
    lastStack = stack;
  }

  /// Usado quando o usuário apaga os dados locais: manter o erro anterior faria
  /// a tela Sobre denunciar um problema que já não existe.
  static void clear() {
    lastError = null;
    lastStack = null;
  }
}

class AuraApp extends StatelessWidget {
  /// Preenchidos apenas quando o app morreu antes de conseguir subir. Nesse caso
  /// a tela de erro entra no lugar da interface normal.
  final Object? fatalError;
  final StackTrace? fatalStack;

  const AuraApp({super.key, this.fatalError, this.fatalStack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6C63FF),
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: fatalError == null
          ? const HomeShell()
          : AuraErrorScreen(
              title: 'O Aura não conseguiu iniciar',
              error: fatalError!,
              stack: fatalStack,
            ),
    );
  }
}

/// Tela de erro legível, no lugar da tela vermelha/cinza padrão do Flutter.
///
/// O texto é selecionável de propósito: num aparelho sem cabo, copiar ou
/// fotografar esta tela é a única forma de tirar o erro de dentro do celular.
class AuraErrorScreen extends StatelessWidget {
  final String title;
  final Object error;
  final StackTrace? stack;
  final VoidCallback? onRetry;
  final Future<void> Function()? onResetData;

  const AuraErrorScreen({
    super.key,
    required this.title,
    required this.error,
    this.stack,
    this.onRetry,
    this.onResetData,
  });

  @override
  Widget build(BuildContext context) {
    // Esta tela também é usada como ErrorWidget.builder, que pode ser chamado em
    // qualquer ponto da árvore — inclusive acima do MaterialApp, onde não existe
    // Directionality, MediaQuery nem Material. Por isso ela traz os próprios
    // ancestrais e evita Scaffold/SafeArea: uma tela de erro que depende de
    // contexto pode lançar ao ser desenhada e virar um laço infinito de erro.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F2FB), Color(0xFFE8E5F6)],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: ListView(
            // Margem generosa no topo no lugar do SafeArea, que exige MediaQuery.
            padding: const EdgeInsets.fromLTRB(20, 64, 20, 32),
            children: [
              const SizedBox(height: 12),
              const Icon(Icons.error_outline,
                  size: 48, color: Color(0xFFB3261E)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mostre esta tela para quem estiver mantendo o app — o texto '
                'abaixo diz exatamente o que falhou.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),
              AuraCard(
                child: SelectableText(
                  error.toString(),
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12, height: 1.4),
                ),
              ),
              if (stack != null) ...[
                const SizedBox(height: 12),
                AuraCard(
                  child: SelectableText(
                    // Só o topo do stack: é onde está a informação útil, e o
                    // resto não caberia na tela de um celular.
                    stack.toString().split('\n').take(12).join('\n'),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 10, height: 1.4),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar de novo'),
                ),
              if (onResetData != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onResetData,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Limpar dados locais e reabrir'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MODELOS
// ============================================================

/// Tarefa da lista. O [id] existe para que uma sessão de foco possa apontar
/// para a tarefa em que o usuário estava trabalhando (`linkedTaskId`).
class TaskItem {
  final String id;
  String title;
  String priority; // 'Alta', 'Média', 'Baixa'
  bool done;

  TaskItem({
    required this.id,
    required this.title,
    required this.priority,
    this.done = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'priority': priority,
        'done': done,
      };

  /// Tarefas salvas por versões anteriores não têm `id`; geramos um na leitura
  /// para não perder os dados de quem já usava o app.
  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String? ??
            'task_${DateTime.now().microsecondsSinceEpoch}_${json['title']}',
        title: json['title'] as String,
        priority: json['priority'] as String,
        done: json['done'] as bool? ?? false,
      );
}

/// Uma sessão de foco concluída — a unidade de dado que alimenta todo o motor
/// de correlação do Aura.
class StudySession {
  final DateTime date;
  final int durationMinutes;
  final int moodBefore; // escala 1-5
  final int moodAfter; // escala 1-5
  final String? linkedTaskId;
  final String methodId;

  /// Marca as sessões do dataset de demonstração, para que possam ser
  /// removidas sem levar junto as sessões reais do usuário.
  final bool isDemo;

  StudySession({
    required this.date,
    required this.durationMinutes,
    required this.moodBefore,
    required this.moodAfter,
    this.linkedTaskId,
    required this.methodId,
    this.isDemo = false,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'duration': durationMinutes,
        'moodBefore': moodBefore,
        'moodAfter': moodAfter,
        'linkedTaskId': linkedTaskId,
        'methodId': methodId,
        'isDemo': isDemo,
      };

  factory StudySession.fromJson(Map<String, dynamic> j) => StudySession(
        date: DateTime.parse(j['date'] as String),
        durationMinutes: j['duration'] as int,
        moodBefore: j['moodBefore'] as int,
        moodAfter: j['moodAfter'] as int,
        linkedTaskId: j['linkedTaskId'] as String?,
        methodId: j['methodId'] as String? ?? 'pomodoro_classico',
        isDemo: j['isDemo'] as bool? ?? false,
      );
}

/// Um método de foco. Os 11 métodos são dados, não telas — todos reaproveitam
/// o mesmo temporizador.
class FocusMethod {
  final String id;
  final String name;
  final int? focusMinutes; // null = sem duração fixa ou definida em runtime
  final int? breakMinutes;
  final bool isCustom;
  final bool isFlowtime;

  const FocusMethod({
    required this.id,
    required this.name,
    this.focusMinutes,
    this.breakMinutes,
    this.isCustom = false,
    this.isFlowtime = false,
  });
}

const List<FocusMethod> focusMethods = [
  FocusMethod(
      id: 'pomodoro_classico',
      name: 'Pomodoro Clássico',
      focusMinutes: 25,
      breakMinutes: 5),
  FocusMethod(
      id: 'pomodoro_longo',
      name: 'Pomodoro Longo',
      focusMinutes: 50,
      breakMinutes: 10),
  FocusMethod(id: '52_17', name: '52/17', focusMinutes: 52, breakMinutes: 17),
  FocusMethod(
      id: 'ciclo_ultradiano',
      name: 'Ciclo Ultradiano',
      focusMinutes: 90,
      breakMinutes: 20),
  FocusMethod(
      id: 'meia_hora_cheia',
      name: 'Meia Hora Cheia',
      focusMinutes: 45,
      breakMinutes: 15),
  FocusMethod(
      id: 'sessao_curta',
      name: 'Sessão Curta',
      focusMinutes: 20,
      breakMinutes: 5),
  FocusMethod(
      id: 'hora_cheia', name: 'Hora Cheia', focusMinutes: 60, breakMinutes: 10),
  FocusMethod(
      id: 'micro_sessao',
      name: 'Micro-sessão',
      focusMinutes: 15,
      breakMinutes: 5),
  FocusMethod(id: '40_20', name: '40/20', focusMinutes: 40, breakMinutes: 20),
  FocusMethod(
      id: 'flowtime', name: 'Flowtime/Flowmodoro', isFlowtime: true),
  FocusMethod(id: 'personalizado', name: 'Personalizado', isCustom: true),
];

FocusMethod methodById(String id) => focusMethods.firstWhere(
      (m) => m.id == id,
      orElse: () => focusMethods.first,
    );

// ============================================================
// CONSTANTES DE APOIO
// ============================================================

/// Índice 1..5 — o índice 0 fica vazio de propósito para a escala bater com o
/// valor guardado em `moodBefore` / `moodAfter`.
const List<String> moodLabels = [
  '',
  'Exausto',
  'Cansado',
  'Neutro',
  'Bem',
  'Ótimo',
];

const List<IconData> moodIcons = [
  Icons.help_outline,
  Icons.sentiment_very_dissatisfied,
  Icons.sentiment_dissatisfied,
  Icons.sentiment_neutral,
  Icons.sentiment_satisfied,
  Icons.sentiment_very_satisfied,
];

const List<Color> moodColors = [
  Color(0xFF9E9E9E),
  Color(0xFFE57373),
  Color(0xFFFFB74D),
  Color(0xFFFFD54F),
  Color(0xFF81C784),
  Color(0xFF4DB6AC),
];

const List<String> weekdayShort = ['', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

const List<String> weekdayLong = [
  '',
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];

/// Chave de dia (sem hora) usada pela lógica de sequência.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

int daysBetweenKeys(String from, String to) {
  final a = DateTime.parse(from);
  final b = DateTime.parse(to);
  return b.difference(a).inDays;
}

/// Formata um double sem o `.0` inútil ("25" em vez de "25.0").
String fmt(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

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
}

// ============================================================
// SEQUÊNCIA COM PERDÃO (regra fixa)
// ============================================================

/// Estado da sequência de dias com foco.
///
/// [runLength] conta os dias consecutivos acumulados desde o último token
/// ganho — a cada 3, o usuário ganha um "token de folga".
class StreakState {
  final int streak;
  final int tokens;
  final int runLength;
  final String? lastActiveDay;
  final bool tokenSpent;
  final bool tokenEarned;

  const StreakState({
    required this.streak,
    required this.tokens,
    required this.runLength,
    required this.lastActiveDay,
    this.tokenSpent = false,
    this.tokenEarned = false,
  });

  static const int maxTokens = 3;
  static const int daysPerToken = 3;
}

/// Regra de sequência aplicada quando o usuário conclui uma sessão em [now].
///
/// - mesmo dia: nada muda (a sequência conta dias, não sessões)
/// - dia seguinte: sequência cresce
/// - faltou exatamente um dia e há token: o token é gasto e a sequência sobrevive
/// - qualquer outro buraco: a sequência recomeça do 1
StreakState applyActivity(StreakState prev, DateTime now) {
  final today = dayKey(now);
  if (prev.lastActiveDay == today) return prev;

  int streak;
  int tokens = prev.tokens;
  int runLength;
  bool tokenSpent = false;

  if (prev.lastActiveDay == null) {
    streak = 1;
    runLength = 1;
  } else {
    final gap = daysBetweenKeys(prev.lastActiveDay!, today);
    if (gap == 1) {
      streak = prev.streak + 1;
      runLength = prev.runLength + 1;
    } else if (gap == 2 && tokens > 0) {
      // Faltou um único dia e havia folga guardada: a sequência é perdoada.
      tokens -= 1;
      tokenSpent = true;
      streak = prev.streak + 1;
      runLength = prev.runLength + 1;
    } else {
      streak = 1;
      runLength = 1;
    }
  }

  bool tokenEarned = false;
  if (runLength >= StreakState.daysPerToken && tokens < StreakState.maxTokens) {
    tokens += 1;
    runLength = 0;
    tokenEarned = true;
  } else if (runLength >= StreakState.daysPerToken) {
    runLength = 0; // já está no teto de tokens, apenas reinicia a contagem
  }

  return StreakState(
    streak: streak,
    tokens: tokens,
    runLength: runLength,
    lastActiveDay: today,
    tokenSpent: tokenSpent,
    tokenEarned: tokenEarned,
  );
}

/// Sequência que deve aparecer na tela hoje. Guardar o número no disco não
/// basta: se o usuário sumiu por vários dias, a sequência já está quebrada
/// mesmo sem nenhuma sessão nova ter sido registrada.
int effectiveStreak(StreakState s, DateTime now) {
  if (s.lastActiveDay == null) return 0;
  final gap = daysBetweenKeys(s.lastActiveDay!, dayKey(now));
  if (gap <= 1) return s.streak;
  if (gap == 2 && s.tokens > 0) return s.streak; // ainda salvável hoje
  return 0;
}

/// Reconstrói a sequência a partir de uma lista de sessões, aplicando dia a dia
/// a mesma regra de [applyActivity] usada quando uma sessão real é registrada.
///
/// Existe para manter a tela Resumo coerente: sem isto, o app abre exibindo
/// "0 dias de sequência" e "0 pontos" ao lado de "20 sessões totais", porque o
/// dataset de demonstração gravava as sessões sem gravar o estado que elas
/// implicam.
StreakState streakFromSessions(List<StudySession> sessions) {
  final days = sessions.map((s) => dayOf(s.date)).toSet().toList()..sort();
  var state = const StreakState(
      streak: 0, tokens: 0, runLength: 0, lastActiveDay: null);
  for (final day in days) {
    state = applyActivity(state, day);
  }
  return state;
}

/// Pontuação equivalente às sessões: os mesmos 10 pontos por sessão concluída
/// que o app credita em uso normal.
int pointsFromSessions(List<StudySession> sessions) => sessions.length * 10;

// ============================================================
// MOTOR DE INSIGHTS (Dart puro, sem IA e sem API)
// ============================================================

class Insight {
  final String id;
  final String title;
  final IconData icon;
  final int requiredSessions;
  final int availableSessions;
  final String? headline;
  final String? body;

  const Insight({
    required this.id,
    required this.title,
    required this.icon,
    required this.requiredSessions,
    required this.availableSessions,
    this.headline,
    this.body,
  });

  bool get unlocked => body != null;
  int get missing => math.max(0, requiredSessions - availableSessions);
}

/// As quatro comparações do MVP. Cada uma tem um volume mínimo de dados —
/// abaixo dele o card aparece bloqueado, o que é justamente a mecânica de
/// "insight desbloqueável".
List<Insight> buildInsights(List<StudySession> sessions) {
  return [
    _insightMoodVsDuration(sessions),
    _insightMoodDelta(sessions),
    _insightWeekday(sessions),
    _insightMethod(sessions),
  ];
}

/// Agrupa `moodBefore` em três faixas legíveis: 1-2 baixo, 3 neutro, 4-5 alto.
int _moodBucket(int mood) {
  if (mood <= 2) return 0;
  if (mood == 3) return 1;
  return 2;
}

const List<String> _bucketNames = [
  'começa pra baixo (1-2)',
  'começa neutro (3)',
  'começa animado (4-5)',
];

Insight _insightMoodVsDuration(List<StudySession> sessions) {
  const int required = 5;
  const String title = 'Seu humor prevê seu foco';
  const IconData icon = Icons.insights;

  final buckets = <int, List<int>>{};
  for (final s in sessions) {
    buckets.putIfAbsent(_moodBucket(s.moodBefore), () => []).add(s.durationMinutes);
  }

  if (sessions.length < required || buckets.length < 2) {
    return Insight(
      id: 'mood_duration',
      title: title,
      icon: icon,
      requiredSessions: required,
      availableSessions: sessions.length,
    );
  }

  final averages = <int, double>{};
  buckets.forEach((bucket, durations) {
    averages[bucket] =
        durations.reduce((a, b) => a + b) / durations.length;
  });

  final ordered = averages.keys.toList()
    ..sort((a, b) => averages[b]!.compareTo(averages[a]!));
  final best = ordered.first;
  final worst = ordered.last;
  final diff = averages[best]! - averages[worst]!;

  return Insight(
    id: 'mood_duration',
    title: title,
    icon: icon,
    requiredSessions: required,
    availableSessions: sessions.length,
    headline: '${fmt(diff)} min de diferença',
    body: 'Quando você ${_bucketNames[best]}, suas sessões duram em média '
        '${fmt(averages[best]!)} min. Quando ${_bucketNames[worst]}, caem para '
        '${fmt(averages[worst]!)} min. São ${fmt(diff)} min de foco que dependem '
        'de como você chega, não de força de vontade.',
  );
}

Insight _insightMoodDelta(List<StudySession> sessions) {
  const int required = 5;
  const String title = 'Focar muda seu humor';
  const IconData icon = Icons.trending_up;

  if (sessions.length < required) {
    return Insight(
      id: 'mood_delta',
      title: title,
      icon: icon,
      requiredSessions: required,
      availableSessions: sessions.length,
    );
  }

  final deltas = sessions.map((s) => s.moodAfter - s.moodBefore).toList();
  final avg = deltas.reduce((a, b) => a + b) / deltas.length;
  final improved = deltas.where((d) => d > 0).length;
  final percent = (improved / deltas.length * 100).round();

  final String direction;
  if (avg > 0.15) {
    direction = 'Seu humor sobe em média ${fmt(avg)} ponto '
        'depois de uma sessão.';
  } else if (avg < -0.15) {
    direction = 'Seu humor cai em média ${fmt(avg.abs())} ponto '
        'depois de uma sessão — vale olhar se as sessões não estão longas demais.';
  } else {
    direction = 'Seu humor termina praticamente igual ao que começou '
        '(variação média de ${fmt(avg)}).';
  }

  return Insight(
    id: 'mood_delta',
    title: title,
    icon: icon,
    requiredSessions: required,
    availableSessions: sessions.length,
    headline: '${avg >= 0 ? '+' : ''}${fmt(avg)} no humor',
    body: '$direction Em $improved de ${deltas.length} sessões ($percent%) '
        'você terminou melhor do que começou.',
  );
}

Insight _insightWeekday(List<StudySession> sessions) {
  const int required = 7;
  const String title = 'Seu melhor dia da semana';
  const IconData icon = Icons.calendar_today;

  if (sessions.length < required) {
    return Insight(
      id: 'weekday',
      title: title,
      icon: icon,
      requiredSessions: required,
      availableSessions: sessions.length,
    );
  }

  final totals = <int, int>{};
  final counts = <int, int>{};
  for (final s in sessions) {
    totals[s.date.weekday] = (totals[s.date.weekday] ?? 0) + s.durationMinutes;
    counts[s.date.weekday] = (counts[s.date.weekday] ?? 0) + 1;
  }

  final ordered = totals.keys.toList()
    ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
  final best = ordered.first;
  final worst = ordered.last;
  final bestAvg = totals[best]! / counts[best]!;

  final String comparison = ordered.length > 1
      ? ' O mais fraco é ${weekdayLong[worst]}, com ${totals[worst]} min.'
      : '';

  return Insight(
    id: 'weekday',
    title: title,
    icon: icon,
    requiredSessions: required,
    availableSessions: sessions.length,
    headline: weekdayShort[best],
    body: 'Seu dia mais produtivo é ${weekdayLong[best]}: ${totals[best]} min '
        'de foco no total, média de ${fmt(bestAvg)} min por sessão.$comparison',
  );
}

Insight _insightMethod(List<StudySession> sessions) {
  const int required = 6;
  const String title = 'O método que mais te sustenta';
  const IconData icon = Icons.tune;

  final byMethod = <String, List<StudySession>>{};
  for (final s in sessions) {
    byMethod.putIfAbsent(s.methodId, () => []).add(s);
  }

  if (sessions.length < required || byMethod.length < 2) {
    return Insight(
      id: 'method',
      title: title,
      icon: icon,
      requiredSessions: required,
      availableSessions: sessions.length,
    );
  }

  // Só considera métodos com pelo menos 2 sessões, para não eleger um vencedor
  // com base numa única tentativa.
  final eligible = byMethod.entries.where((e) => e.value.length >= 2).toList();
  if (eligible.length < 2) {
    return Insight(
      id: 'method',
      title: title,
      icon: icon,
      requiredSessions: required,
      availableSessions: sessions.length,
    );
  }

  double avgMoodAfter(List<StudySession> list) =>
      list.map((s) => s.moodAfter).reduce((a, b) => a + b) / list.length;
  double avgDuration(List<StudySession> list) =>
      list.map((s) => s.durationMinutes).reduce((a, b) => a + b) / list.length;

  eligible.sort((a, b) => avgMoodAfter(b.value).compareTo(avgMoodAfter(a.value)));
  final best = eligible.first;
  final worst = eligible.last;

  return Insight(
    id: 'method',
    title: title,
    icon: icon,
    requiredSessions: required,
    availableSessions: sessions.length,
    headline: methodById(best.key).name,
    body: '${methodById(best.key).name} é o que te deixa melhor no fim: humor '
        'final médio de ${fmt(avgMoodAfter(best.value))}/5 em '
        '${fmt(avgDuration(best.value))} min por sessão. Já '
        '${methodById(worst.key).name} fecha em '
        '${fmt(avgMoodAfter(worst.value))}/5.',
  );
}

// ============================================================
// CLIMA PESSOAL (a "aura")
// ============================================================

class AuraClimate {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final Color accent;

  const AuraClimate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.accent,
  });
}

const AuraClimate _climateNeutral = AuraClimate(
  id: 'neutro',
  name: 'Aura em branco',
  description: 'Ainda não há sessões suficientes para ler seu clima. '
      'Conclua uma sessão para a aura ganhar cor.',
  icon: Icons.blur_on,
  gradient: [Color(0xFFF4F2FB), Color(0xFFE8E5F6)],
  accent: Color(0xFF6C63FF),
);

const AuraClimate _climateRadiante = AuraClimate(
  id: 'radiante',
  name: 'Radiante',
  description: 'Suas últimas sessões terminaram muito bem. '
      'É o momento de encarar o que você vem adiando.',
  icon: Icons.wb_sunny,
  gradient: [Color(0xFFFFF6DE), Color(0xFFFFE0C2)],
  accent: Color(0xFFEF9A2E),
);

const AuraClimate _climateFluindo = AuraClimate(
  id: 'fluindo',
  name: 'Fluindo',
  description: 'Você está terminando as sessões melhor do que começa. '
      'Ritmo sustentável — mantenha.',
  icon: Icons.waves,
  gradient: [Color(0xFFE1F5F1), Color(0xFFDCE6FF)],
  accent: Color(0xFF2A9D8F),
);

const AuraClimate _climateNublado = AuraClimate(
  id: 'nublado',
  name: 'Nublado',
  description: 'As sessões recentes terminaram mornas. '
      'Talvez valha encurtar o método por hoje.',
  icon: Icons.cloud_queue,
  gradient: [Color(0xFFEDF0F4), Color(0xFFDCE2EA)],
  accent: Color(0xFF5C6B7A),
);

const AuraClimate _climateRecolhido = AuraClimate(
  id: 'recolhido',
  name: 'Recolhido',
  description: 'Você vem terminando as sessões cansado. '
      'Micro-sessões contam — e a folga de sequência existe para isso.',
  icon: Icons.nights_stay,
  gradient: [Color(0xFFEAE6F2), Color(0xFFD9D3E8)],
  accent: Color(0xFF6D5B9E),
);

/// O clima olha só para as sessões mais recentes: a aura reflete o estado
/// atual, não a média histórica.
AuraClimate resolveClimate(List<StudySession> sessions) {
  if (sessions.isEmpty) return _climateNeutral;

  final sorted = List<StudySession>.from(sessions)
    ..sort((a, b) => b.date.compareTo(a.date));
  final recent = sorted.take(3).toList();

  final avgAfter =
      recent.map((s) => s.moodAfter).reduce((a, b) => a + b) / recent.length;

  if (avgAfter >= 4.2) return _climateRadiante;
  if (avgAfter >= 3.4) return _climateFluindo;
  if (avgAfter >= 2.4) return _climateNublado;
  return _climateRecolhido;
}

// ============================================================
// DATASET DE DEMONSTRAÇÃO
// ============================================================

/// Sessões fictícias dos últimos 14 dias, geradas com semente fixa para que a
/// apresentação seja sempre igual. Os dados carregam de propósito um padrão
/// descobrível: quem chega melhor escolhe métodos mais longos e termina ainda
/// melhor — é isso que os insights vão encontrar.
List<StudySession> buildDemoSessions() {
  final rnd = math.Random(7);
  final today = dayOf(DateTime.now());
  final sessions = <StudySession>[];

  // Métodos plausíveis para cada humor inicial.
  const poolByMood = <int, List<String>>{
    1: ['micro_sessao', 'sessao_curta'],
    2: ['micro_sessao', 'sessao_curta'],
    3: ['pomodoro_classico', '40_20'],
    4: ['pomodoro_classico', 'pomodoro_longo', '52_17'],
    5: ['pomodoro_longo', '52_17', 'ciclo_ultradiano'],
  };

  // Humor de cada dia (índice = dias atrás). Os dias 6 e 2 ficam vazios de
  // propósito, para a sequência ter buracos como na vida real.
  //
  // O humor inicial 5 aparece pouco de propósito: quem já começa no máximo não
  // tem para onde melhorar, e a escala trunca o ganho. Com muitos 5 aqui, o
  // insight "focar muda seu humor" ficava artificialmente fraco.
  const moodByDayAgo = <int, List<int>>{
    14: [3, 4],
    13: [4],
    12: [2, 3],
    11: [4, 4],
    10: [3],
    9: [4, 5],
    8: [2],
    7: [3, 4],
    5: [5, 4],
    4: [3],
    3: [4, 3],
    1: [4, 3],
    // Hoje: sem isto, o app abre dizendo "0 sessões hoje" e "0 dias de
    // sequência" logo ao lado de "20 sessões totais", e o gráfico da semana
    // termina em zero.
    0: [3, 4],
  };

  moodByDayAgo.forEach((daysAgo, moods) {
    for (var i = 0; i < moods.length; i++) {
      final mood = moods[i];
      final pool = poolByMood[mood]!;
      final methodId = pool[rnd.nextInt(pool.length)];
      final method = methodById(methodId);
      final planned = method.focusMinutes ?? 25;

      // Uma em cada quatro sessões é interrompida antes do fim.
      final duration = rnd.nextInt(4) == 0
          ? math.max(10, planned - 5 - rnd.nextInt(8))
          : planned;

      // O foco costuma melhorar o humor, às vezes bastante, mas nem sempre.
      final roll = rnd.nextInt(10);
      final delta = roll < 6
          ? 1
          : roll < 8
              ? 2
              : (roll == 8 ? 0 : -1);
      final moodAfter = (mood + delta).clamp(1, 5);

      final date = today.subtract(Duration(days: daysAgo)).add(
            Duration(hours: 9 + i * 5, minutes: rnd.nextInt(50)),
          );

      sessions.add(StudySession(
        date: date,
        durationMinutes: duration,
        moodBefore: mood,
        moodAfter: moodAfter,
        methodId: methodId,
        isDemo: true,
      ));
    }
  });

  sessions.sort((a, b) => a.date.compareTo(b.date));
  return sessions;
}

// ============================================================
// SHELL PRINCIPAL
// ============================================================

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _loading = true;

  /// Falha durante a carga inicial. Enquanto não for nulo, o app mostra a tela
  /// de erro em vez de abrir com estado pela metade.
  Object? _loadError;
  StackTrace? _loadStack;

  List<StudySession> _sessions = [];
  List<TaskItem> _tasks = [];
  int _points = 0;
  StreakState _streak = const StreakState(
      streak: 0, tokens: 0, runLength: 0, lastActiveDay: null);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final tasks = await AuraStore.loadTasks();
      var sessions = await AuraStore.loadSessions();
      var points = await AuraStore.loadPoints();
      var streak = await AuraStore.loadStreak();
      final seeded = await AuraStore.demoSeeded();

      // Nenhuma tela pode aparecer vazia na primeira abertura.
      if (sessions.isEmpty && !seeded) {
        sessions = buildDemoSessions();
        // A sequência e os pontos são derivados das próprias sessões: gravar só
        // as sessões deixaria o Resumo dizendo "0 dias de sequência" e
        // "0 pontos" logo ao lado do total de sessões e minutos.
        streak = streakFromSessions(sessions);
        points = pointsFromSessions(sessions);

        await AuraStore.saveSessions(sessions);
        await AuraStore.saveStreak(streak);
        await AuraStore.savePoints(points);
        await AuraStore.setDemoSeeded(true);
      }

      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _sessions = sessions;
        _points = points;
        _streak = streak;
        _loading = false;
        _loadError = null;
        _loadStack = null;
      });
    } catch (error, stack) {
      // Falhar aqui é o pior momento possível: o app morreria antes de desenhar
      // qualquer coisa. Em vez disso, mostramos o que aconteceu.
      AuraCrashReport.record(error, stack);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
        _loadStack = stack;
      });
    }
  }

  Future<void> _retryLoad() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _loadStack = null;
    });
    await _loadAll();
  }

  /// Última saída quando o armazenamento local ficou num estado que impede o app
  /// de abrir — evita que a única solução seja reinstalar.
  ///
  /// Apaga tudo, inclusive sessões reais, então pede confirmação: quem chegou
  /// nesta tela por um erro passageiro não pode perder o histórico por um toque.
  Future<void> _resetLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar dados locais?'),
        content: const Text(
          'Isto apaga todas as suas sessões, tarefas e pontos deste aparelho. '
          'Não dá para desfazer. Use só se o app não estiver abrindo de jeito '
          'nenhum.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Este é o caminho de recuperação de último recurso: se ele próprio lançar,
    // o usuário fica preso sem nenhuma saída. Por isso a falha vira a mesma tela
    // de erro controlada, em vez de derrubar o app ou sumir em silêncio.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      AuraCrashReport.clear();
    } catch (error, stack) {
      AuraCrashReport.record(error, stack);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
        _loadStack = stack;
      });
      return;
    }

    await _retryLoad();
  }

  Future<void> _addPoints(int amount) async {
    final updated = _points + amount;
    setState(() => _points = updated);
    await AuraStore.savePoints(updated);
  }

  /// Ponto único de entrada de uma sessão concluída: guarda a sessão, credita
  /// os pontos e atualiza a sequência.
  Future<void> _recordSession(StudySession session) async {
    final updated = List<StudySession>.from(_sessions)..add(session);
    final newStreak = applyActivity(_streak, session.date);

    setState(() {
      _sessions = updated;
      _streak = newStreak;
    });

    await AuraStore.saveSessions(updated);
    await AuraStore.saveStreak(newStreak);
    await _addPoints(10); // 10 pontos por sessão de foco concluída

    if (!mounted) return;
    final messages = <String>['Sessão registrada · +10 pts'];
    if (newStreak.tokenSpent) {
      messages.add('uma folga foi usada para salvar sua sequência');
    }
    if (newStreak.tokenEarned) {
      messages.add('você ganhou um token de folga');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(messages.join(' · '))),
    );
  }

  Future<void> _addTask(String title, String priority) async {
    final task = TaskItem(
      id: 'task_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      priority: priority,
    );
    final updated = List<TaskItem>.from(_tasks)..add(task);
    setState(() => _tasks = updated);
    await AuraStore.saveTasks(updated);
  }

  Future<void> _toggleTask(String id) async {
    final updated = List<TaskItem>.from(_tasks);
    final index = updated.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final wasDone = updated[index].done;
    updated[index].done = !wasDone;
    setState(() => _tasks = updated);
    await AuraStore.saveTasks(updated);

    // Só pontua ao marcar como concluída, nunca ao desmarcar.
    if (!wasDone) await _addPoints(5);
  }

  Future<void> _removeTask(String id) async {
    final updated = List<TaskItem>.from(_tasks)..removeWhere((t) => t.id == id);
    setState(() => _tasks = updated);
    await AuraStore.saveTasks(updated);
  }

  Future<void> _clearDemoData() async {
    await _applySessions(_sessions.where((s) => !s.isDemo).toList());
  }

  Future<void> _restoreDemoData() async {
    final real = _sessions.where((s) => !s.isDemo).toList();
    await _applySessions([...buildDemoSessions(), ...real]
      ..sort((a, b) => a.date.compareTo(b.date)));
  }

  /// Troca o conjunto de sessões e recalcula o que depende dele.
  ///
  /// Ligar ou desligar o dataset de demonstração muda quantas sessões existem,
  /// então sequência e pontos precisam acompanhar — senão o Resumo passa a
  /// exibir uma sequência apoiada em sessões que não estão mais lá.
  Future<void> _applySessions(List<StudySession> sessions) async {
    final streak = streakFromSessions(sessions);
    final points = pointsFromSessions(sessions);

    setState(() {
      _sessions = sessions;
      _streak = streak;
      _points = points;
    });

    await AuraStore.saveSessions(sessions);
    await AuraStore.saveStreak(streak);
    await AuraStore.savePoints(points);
  }

  bool get _hasDemoData => _sessions.any((s) => s.isDemo);

  @override
  Widget build(BuildContext context) {
    // A carga inicial falhou: mostrar o motivo, em vez de abrir quebrado.
    if (_loadError != null) {
      return AuraErrorScreen(
        title: 'O Aura não conseguiu carregar seus dados',
        error: _loadError!,
        stack: _loadStack,
        onRetry: _retryLoad,
        onResetData: _resetLocalData,
      );
    }

    final climate = resolveClimate(_sessions);

    final pages = <Widget>[
      FocusPage(
        tasks: _tasks,
        climate: climate,
        onSessionRecorded: _recordSession,
      ),
      TaskListPage(
        tasks: _tasks,
        onAdd: _addTask,
        onToggle: _toggleTask,
        onRemove: _removeTask,
      ),
      InsightsPage(sessions: _sessions),
      SummaryPage(
        points: _points,
        sessions: _sessions,
        streak: _streak,
        climate: climate,
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: climate.gradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            children: [
              Icon(climate.icon, color: climate.accent),
              const SizedBox(width: 8),
              const Text('Aura',
                  style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
            ],
          ),
          actions: [
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text('$_points',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Sobre o Aura',
              icon: const Icon(Icons.info_outline),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AboutPage(
                    hasDemoData: _hasDemoData,
                    onClearDemo: _clearDemoData,
                    onRestoreDemo: _restoreDemoData,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(top: false, child: pages[_index]),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white.withValues(alpha: 0.85),
          indicatorColor: climate.accent.withValues(alpha: 0.18),
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Foco'),
            NavigationDestination(
                icon: Icon(Icons.checklist_outlined), label: 'Tarefas'),
            NavigationDestination(
                icon: Icon(Icons.auto_graph_outlined), label: 'Insights'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Resumo'),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TELA 1: FOCO (temporizador + método + check de humor)
// ============================================================

/// O que o usuário respondeu antes de começar a sessão.
class _MoodResult {
  final int mood;
  final String? taskId;
  const _MoodResult(this.mood, this.taskId);
}

class FocusPage extends StatefulWidget {
  final List<TaskItem> tasks;
  final AuraClimate climate;
  final Future<void> Function(StudySession session) onSessionRecorded;

  const FocusPage({
    super.key,
    required this.tasks,
    required this.climate,
    required this.onSessionRecorded,
  });

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  String _methodId = 'pomodoro_classico';
  int _customFocus = 30;
  int _customBreak = 8;

  int _totalSeconds = 25 * 60;
  int _secondsLeft = 25 * 60;
  int _elapsedSeconds = 0; // usado apenas pelo Flowtime (contagem progressiva)
  bool _isRunning = false;
  bool _isBreak = false;
  Timer? _timer;

  int? _moodBefore;
  String? _linkedTaskId;

  /// Pausa calculada ao fim de uma sessão de Flowtime, que não tem pausa fixa.
  int? _flowtimeBreakSuggestion;

  FocusMethod get _method => methodById(_methodId);

  /// Minutos de foco do método atual — o Personalizado usa o valor escolhido
  /// pelo usuário; o Flowtime não tem alvo.
  int get _focusMinutes =>
      _method.isCustom ? _customFocus : (_method.focusMinutes ?? 25);

  int get _breakMinutes =>
      _method.isCustom ? _customBreak : (_method.breakMinutes ?? 5);

  /// A pausa que o cronômetro vai realmente usar. No Flowtime ela é calculada
  /// a partir do tempo trabalhado, então não pode vir do preset.
  int get _effectiveBreakMinutes =>
      _method.isFlowtime ? (_flowtimeBreakSuggestion ?? 5) : _breakMinutes;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final methodId = await AuraStore.loadSelectedMethod();
    final custom = await AuraStore.loadCustomDurations();
    if (!mounted) return;
    setState(() {
      _methodId = methodId;
      _customFocus = custom[0];
      _customBreak = custom[1];
      _resetTimerValues();
    });
  }

  void _resetTimerValues() {
    _isBreak = false;
    _elapsedSeconds = 0;
    _flowtimeBreakSuggestion = null;
    _totalSeconds = _focusMinutes * 60;
    _secondsLeft = _totalSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------- controle do temporizador ----------

  Future<void> _onPrimaryPressed() async {
    if (_isRunning) {
      _pause();
      return;
    }

    // O check de humor acontece antes de qualquer ciclo de foco novo.
    if (!_isBreak && _moodBefore == null) {
      final result = await _askMoodBefore();
      if (!mounted || result == null) return;
      setState(() {
        _moodBefore = result.mood;
        _linkedTaskId = result.taskId;
      });
    }

    _start();
  }

  void _start() {
    setState(() => _isRunning = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_method.isFlowtime && !_isBreak) {
        setState(() => _elapsedSeconds++);
        return;
      }
      if (_secondsLeft <= 1) {
        _onCycleComplete();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _moodBefore = null;
      _linkedTaskId = null;
      _resetTimerValues();
    });
  }

  /// Chamado quando um ciclo de duração fixa chega a zero.
  Future<void> _onCycleComplete() async {
    _timer?.cancel();
    if (_isBreak) {
      // Fim da pausa: volta para o foco sem registrar nada.
      setState(() {
        _isRunning = false;
        _resetTimerValues();
      });
      return;
    }
    setState(() => _isRunning = false);
    await _finishFocus(_focusMinutes);
  }

  /// Fim de uma sessão de foco: pergunta o humor e persiste a sessão.
  Future<void> _finishFocus(int minutes) async {
    final moodAfter = await _askMoodAfter();
    if (!mounted) return;

    // Se o usuário fechar o check final, a sessão não é descartada — ela é
    // registrada com o humor de entrada repetido, para não perder o dado.
    final after = moodAfter ?? _moodBefore ?? 3;

    await widget.onSessionRecorded(StudySession(
      date: DateTime.now(),
      durationMinutes: minutes,
      moodBefore: _moodBefore ?? 3,
      moodAfter: after,
      linkedTaskId: _linkedTaskId,
      methodId: _methodId,
    ));

    if (!mounted) return;
    setState(() {
      _moodBefore = null;
      _linkedTaskId = null;
      _isRunning = false;
      _isBreak = true;
      _elapsedSeconds = 0;
      _totalSeconds = _effectiveBreakMinutes * 60;
      _secondsLeft = _totalSeconds;
    });
  }

  /// Flowtime não termina sozinho — o usuário decide a hora de parar.
  Future<void> _finishFlowtime() async {
    _timer?.cancel();
    setState(() => _isRunning = false);

    final minutes = _elapsedSeconds ~/ 60;
    if (minutes < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sessão curta demais para registrar (mínimo 1 min).')),
      );
      return;
    }

    // A pausa sugerida cresce com o tempo trabalhado (regra do Flowmodoro).
    setState(() {
      _flowtimeBreakSuggestion = math.max(5, (minutes / 5).round());
    });
    await _finishFocus(minutes);
  }

  // ---------- check de humor ----------

  Future<_MoodResult?> _askMoodBefore() {
    final pending = widget.tasks.where((t) => !t.done).toList();
    return showModalBottomSheet<_MoodResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MoodSheet(
        title: 'Como você está agora?',
        subtitle: 'Isso é o que permite o Aura descobrir o que realmente '
            'afeta seu foco.',
        linkableTasks: pending,
      ),
    );
  }

  Future<int?> _askMoodAfter() async {
    final result = await showModalBottomSheet<_MoodResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _MoodSheet(
        title: 'E agora, como você está?',
        subtitle: 'Sessão concluída. O contraste entre antes e depois é o '
            'coração dos seus insights.',
        linkableTasks: [],
      ),
    );
    return result?.mood;
  }

  // ---------- seleção de método ----------

  Future<void> _onMethodChanged(String? id) async {
    if (id == null) return;
    setState(() {
      _methodId = id;
      _resetTimerValues();
    });
    await AuraStore.saveSelectedMethod(id);
  }

  Future<void> _editCustomDurations() async {
    var focus = _customFocus;
    var rest = _customBreak;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: const Text('Método personalizado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MinuteStepper(
                label: 'Foco',
                value: focus,
                min: 5,
                max: 180,
                step: 5,
                onChanged: (v) => setDialog(() => focus = v),
              ),
              const SizedBox(height: 12),
              _MinuteStepper(
                label: 'Pausa',
                value: rest,
                min: 1,
                max: 60,
                step: 1,
                onChanged: (v) => setDialog(() => rest = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || saved != true) return;
    setState(() {
      _customFocus = focus;
      _customBreak = rest;
      _resetTimerValues();
    });
    await AuraStore.saveCustomDurations(focus, rest);
  }

  // ---------- build ----------

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Busca explícita em vez de `firstOrNull`, que depende de extensão de
  /// coleção e nem sempre está disponível em SDKs mais antigos.
  TaskItem? _findLinkedTask() {
    if (_linkedTaskId == null) return null;
    for (final task in widget.tasks) {
      if (task.id == _linkedTaskId) return task;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final climate = widget.climate;
    final isFlowtime = _method.isFlowtime;

    final double progress = isFlowtime && !_isBreak
        ? 1.0 // sem alvo: o anel fica cheio, o número é que conta
        : (_totalSeconds == 0
            ? 0
            : (1 - (_secondsLeft / _totalSeconds)).clamp(0.0, 1.0));

    final displayTime = isFlowtime && !_isBreak
        ? _formatTime(_elapsedSeconds)
        : _formatTime(_secondsLeft);

    final linkedTask = _findLinkedTask();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MethodSelector(
            methodId: _methodId,
            enabled: !_isRunning,
            focusMinutes: _focusMinutes,
            breakMinutes: _breakMinutes,
            onChanged: _onMethodChanged,
            onEditCustom: _editCustomDurations,
          ),
          const SizedBox(height: 24),
          AuraCard(
            child: Column(
              children: [
                Text(
                  _isBreak ? 'Pausa' : (isFlowtime ? 'Flowtime' : 'Foco'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: climate.accent,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isBreak
                      ? 'Respire. A pausa faz parte do método.'
                      : (isFlowtime
                          ? 'Sem alvo. Pare quando o foco acabar.'
                          : '$_focusMinutes min de foco · $_breakMinutes min de pausa'),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                CircularPercentIndicator(
                  radius: 108,
                  lineWidth: 14,
                  percent: progress,
                  circularStrokeCap: CircularStrokeCap.round,
                  backgroundColor: climate.accent.withValues(alpha: 0.12),
                  progressColor: _isBreak ? const Color(0xFF4DB6AC) : climate.accent,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTime,
                        style: const TextStyle(
                            fontSize: 40, fontWeight: FontWeight.bold),
                      ),
                      if (_moodBefore != null && !_isBreak)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(moodIcons[_moodBefore!],
                                size: 16, color: moodColors[_moodBefore!]),
                            const SizedBox(width: 4),
                            Text(moodLabels[_moodBefore!],
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                    ],
                  ),
                ),
                if (linkedTask != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.link, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          linkedTask.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                // Wrap em vez de Row: em telas estreitas os rótulos longos
                // ("Iniciar pausa") não cabem lado a lado e quebram a linha
                // em vez de estourar.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _onPrimaryPressed,
                      icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(_isRunning
                          ? 'Pausar'
                          : (_isBreak ? 'Iniciar pausa' : 'Iniciar')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reiniciar'),
                    ),
                  ],
                ),
                if (isFlowtime && !_isBreak && _elapsedSeconds > 0) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _finishFlowtime,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Concluir sessão'),
                  ),
                ],
                if (_isBreak && _flowtimeBreakSuggestion != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Pausa sugerida pelo Flowtime: $_flowtimeBreakSuggestion min '
                    '(proporcional ao tempo que você sustentou)',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AuraCard(
            child: Row(
              children: [
                Icon(Icons.favorite_outline, color: climate.accent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'O Aura pergunta seu humor antes e depois de cada sessão. '
                    'É desse contraste que saem os insights — sem isso, é só '
                    'mais um cronômetro.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seletor de método — os 11 métodos são uma lista de dados, não 11 telas.
class _MethodSelector extends StatelessWidget {
  final String methodId;
  final bool enabled;
  final int focusMinutes;
  final int breakMinutes;
  final ValueChanged<String?> onChanged;
  final VoidCallback onEditCustom;

  const _MethodSelector({
    required this.methodId,
    required this.enabled,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.onChanged,
    required this.onEditCustom,
  });

  String _subtitle(FocusMethod m) {
    if (m.isFlowtime) return 'contagem progressiva';
    if (m.isCustom) return '$focusMinutes / $breakMinutes min';
    return '${m.focusMinutes} / ${m.breakMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final method = methodById(methodId);
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Método de foco',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          // DropdownButton simples (em vez de DropdownButtonFormField) porque a
          // API dele é estável entre versões do SDK — o FlutLab nem sempre roda
          // a mais recente.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: methodId,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: focusMethods
                  .map((m) => DropdownMenuItem<String>(
                        value: m.id,
                        child: Text('${m.name} · ${_subtitle(m)}',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
          if (!enabled)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Pause a sessão para trocar de método.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (method.isCustom)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: enabled ? onEditCustom : null,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Ajustar durações'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Stepper simples de minutos usado pelo método Personalizado.
class _MinuteStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _MinuteStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed:
              value - step >= min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 56,
          child: Text('$value min',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        IconButton(
          onPressed:
              value + step <= max ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

/// Folha de check de humor (1-5), com vínculo opcional a uma tarefa.
class _MoodSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<TaskItem> linkableTasks;

  const _MoodSheet({
    required this.title,
    required this.subtitle,
    required this.linkableTasks,
  });

  @override
  State<_MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends State<_MoodSheet> {
  int? _selected;
  String? _taskId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(widget.subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final mood = i + 1;
              final selected = _selected == mood;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selected = mood),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? moodColors[mood].withValues(alpha: 0.25)
                                : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? moodColors[mood]
                                  : theme.colorScheme.outlineVariant,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Icon(moodIcons[mood],
                              color: moodColors[mood], size: 28),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          moodLabels[mood],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          if (widget.linkableTasks.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Vincular a uma tarefa (opcional)',
                style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String?>(
                value: _taskId,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Nenhuma')),
                  ...widget.linkableTasks.map(
                    (t) => DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(t.title, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _taskId = v),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context)
                      .pop(_MoodResult(_selected!, _taskId)),
              child: const Text('Confirmar'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TELA 2: TAREFAS
// ============================================================

class TaskListPage extends StatefulWidget {
  final List<TaskItem> tasks;
  final Future<void> Function(String title, String priority) onAdd;
  final Future<void> Function(String id) onToggle;
  final Future<void> Function(String id) onRemove;

  const TaskListPage({
    super.key,
    required this.tasks,
    required this.onAdd,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final _controller = TextEditingController();
  String _priority = 'Média';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    _controller.clear();
    await widget.onAdd(title, _priority);
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'Alta':
        return Colors.red;
      case 'Baixa':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: AuraCard(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addTask(),
                    decoration: const InputDecoration(
                      hintText: 'Nova tarefa...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _priority,
                  underline: const SizedBox.shrink(),
                  items: const ['Alta', 'Média', 'Baixa']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                ),
                IconButton(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add_circle, size: 30),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? const _EmptyState(
                  icon: Icons.checklist,
                  message: 'Nenhuma tarefa ainda.\n'
                      'Tarefas podem ser vinculadas às sessões de foco.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AuraCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Checkbox(
                            value: task.done,
                            onChanged: (_) => widget.onToggle(task.id),
                          ),
                          title: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _priorityColor(task.priority),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    decoration: task.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(task.priority),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => widget.onRemove(task.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ============================================================
// TELA 3: INSIGHTS (motor de correlação + gráficos)
// ============================================================

class InsightsPage extends StatelessWidget {
  final List<StudySession> sessions;

  const InsightsPage({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final insights = buildInsights(sessions);
    final unlocked = insights.where((i) => i.unlocked).length;

    if (sessions.isEmpty) {
      return const _EmptyState(
        icon: Icons.auto_graph,
        message: 'Nenhuma sessão registrada ainda.\n'
            'Conclua uma sessão de foco para o Aura começar a comparar.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text('Descobertas',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
        const SizedBox(height: 4),
        Text(
          '$unlocked de ${insights.length} desbloqueadas · '
          '${sessions.length} sessões registradas',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        ...insights.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InsightCard(insight: i),
            )),
        const SizedBox(height: 8),
        _MoodDurationChart(sessions: sessions),
        const SizedBox(height: 12),
        _WeeklyFocusChart(sessions: sessions),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Insight insight;

  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!insight.unlocked) {
      return AuraCard(
        color: Colors.white.withValues(alpha: 0.45),
        child: Row(
          children: [
            Icon(Icons.lock_outline,
                color: theme.colorScheme.outline, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.missing > 0
                        ? 'Faltam ${insight.missing} '
                            '${insight.missing == 1 ? 'sessão' : 'sessões'} para desbloquear.'
                        : 'Precisa de mais variedade de dados para desbloquear.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(insight.icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(insight.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (insight.headline != null) ...[
            const SizedBox(height: 10),
            Text(
              insight.headline!,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(insight.body!, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }
}

/// O gráfico de correlação exigido pelo MVP: duração média de foco por humor
/// inicial. É a leitura visual do diferencial do app.
class _MoodDurationChart extends StatelessWidget {
  final List<StudySession> sessions;

  const _MoodDurationChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totals = <int, int>{};
    final counts = <int, int>{};
    for (final s in sessions) {
      totals[s.moodBefore] = (totals[s.moodBefore] ?? 0) + s.durationMinutes;
      counts[s.moodBefore] = (counts[s.moodBefore] ?? 0) + 1;
    }

    final averages = <int, double>{};
    for (var mood = 1; mood <= 5; mood++) {
      if (counts.containsKey(mood)) {
        averages[mood] = totals[mood]! / counts[mood]!;
      }
    }

    if (averages.isEmpty) return const SizedBox.shrink();

    final maxValue =
        averages.values.reduce((a, b) => a > b ? a : b);
    final maxY = ((maxValue / 15).ceil() * 15).toDouble() + 15;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Humor inicial × duração do foco',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('minutos médios por sessão',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: const BarTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 15,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 15,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) {
                        final mood = value.toInt();
                        if (mood < 1 || mood > 5) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(moodIcons[mood],
                                  size: 18, color: moodColors[mood]),
                              Text(moodLabels[mood],
                                  style: const TextStyle(fontSize: 9)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: averages.entries
                    .map((e) => BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value,
                              width: 22,
                              color: moodColors[e.key],
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6)),
                            ),
                          ],
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minutos de foco nos últimos 7 dias — leitura rápida do ritmo recente.
class _WeeklyFocusChart extends StatelessWidget {
  final List<StudySession> sessions;

  const _WeeklyFocusChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = dayOf(DateTime.now());

    final minutesPerDay = List<double>.filled(7, 0);
    for (final s in sessions) {
      final diff = today.difference(dayOf(s.date)).inDays;
      if (diff >= 0 && diff < 7) {
        minutesPerDay[6 - diff] += s.durationMinutes.toDouble();
      }
    }

    final maxValue = minutesPerDay.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 60.0 : ((maxValue / 30).ceil() * 30).toDouble();

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Últimos 7 dias',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('minutos de foco por dia', style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                minX: 0,
                maxX: 6,
                lineTouchData: const LineTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final offset = 6 - value.toInt();
                        final day = today.subtract(Duration(days: offset));
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            weekdayShort[day.weekday],
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      7,
                      (i) => FlSpot(i.toDouble(), minutesPerDay[i]),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.25,
                    barWidth: 3,
                    color: theme.colorScheme.primary,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TELA 4: RESUMO
// ============================================================

class SummaryPage extends StatelessWidget {
  final int points;
  final List<StudySession> sessions;
  final StreakState streak;
  final AuraClimate climate;

  const SummaryPage({
    super.key,
    required this.points,
    required this.sessions,
    required this.streak,
    required this.climate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = dayOf(now);

    final sessionsToday = sessions
        .where((s) => dayOf(s.date).isAtSameMomentAs(today))
        .length;
    final totalMinutes = sessions.isEmpty
        ? 0
        : sessions.map((s) => s.durationMinutes).reduce((a, b) => a + b);
    final currentStreak = effectiveStreak(streak, now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(climate.icon, size: 32, color: climate.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sua aura hoje',
                            style: theme.textTheme.bodySmall),
                        Text(
                          climate.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: climate.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(climate.description, style: const TextStyle(height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AuraCard(
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department,
                      color: currentStreak > 0
                          ? Colors.deepOrange
                          : theme.colorScheme.outline,
                      size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentStreak == 1
                              ? '1 dia de sequência'
                              : '$currentStreak dias de sequência',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          streak.tokens == 1
                              ? '1 folga guardada'
                              : '${streak.tokens} folgas guardadas',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: List.generate(
                      StreakState.maxTokens,
                      (i) => Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          Icons.shield,
                          size: 20,
                          color: i < streak.tokens
                              ? climate.accent
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'A cada ${StreakState.daysPerToken} dias seguidos você ganha uma '
                'folga. Se faltar um dia, ela é gasta automaticamente e sua '
                'sequência continua de pé.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.star,
                iconColor: Colors.amber,
                label: 'Pontos',
                value: '$points',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.timer_outlined,
                iconColor: climate.accent,
                label: 'Sessões hoje',
                value: '$sessionsToday',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.check_circle_outline,
                iconColor: const Color(0xFF4DB6AC),
                label: 'Sessões totais',
                value: '${sessions.length}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.hourglass_bottom,
                iconColor: const Color(0xFF6D5B9E),
                label: 'Minutos focados',
                value: '$totalMinutes',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AuraCard(
          child: Text(
            'Cada sessão de foco concluída gera 10 pontos e cada tarefa '
            'concluída gera 5. Mas o que importa mesmo são as descobertas na '
            'aba Insights — os pontos são só o combustível.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TELA: SOBRE
// ============================================================

class AboutPage extends StatefulWidget {
  final bool hasDemoData;
  final Future<void> Function() onClearDemo;
  final Future<void> Function() onRestoreDemo;

  const AboutPage({
    super.key,
    required this.hasDemoData,
    required this.onClearDemo,
    required this.onRestoreDemo,
  });

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late bool _hasDemo = widget.hasDemoData;

  static const List<String> _roadmap = [
    'Ritual Semanal de fechamento ("Encontro de Domingo")',
    'Modo Provas (tema sazonal)',
    'Arco fechado por temporada, com retrospectiva',
    'Sugestão adaptativa de duração de sessão',
    'Compartilhamento opcional de cartões de insight',
    'Onboarding com quiz de expectativa',
  ];

  Future<void> _toggleDemo() async {
    if (_hasDemo) {
      await widget.onClearDemo();
    } else {
      await widget.onRestoreDemo();
    }
    if (!mounted) return;
    setState(() => _hasDemo = !_hasDemo);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_hasDemo
            ? 'Dados de demonstração restaurados.'
            : 'Dados de demonstração removidos.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4F2FB), Color(0xFFE8E5F6)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Sobre o Aura'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aura',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Um Pomodoro que aprende com você. Em vez de só contar '
                    'minutos, o Aura cruza como você está se sentindo com '
                    'quanto tempo você realmente consegue manter o foco — e '
                    'devolve isso como descobertas pessoais, não como pontos '
                    'genéricos. Sua aura muda com seu estado real.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AuraCard(
              color: const Color(0xFFE8F5E9).withValues(alpha: 0.9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Privacidade',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2E7D32),
                            )),
                        const SizedBox(height: 6),
                        const Text(
                          'Seus dados de humor não saem do seu celular. '
                          'O Aura não tem login, não tem servidor e não tem '
                          'feed. Tudo fica no armazenamento local do aparelho, '
                          'e some se você desinstalar o app.',
                          style: TextStyle(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dados de demonstração',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    _hasDemo
                        ? 'O app veio com sessões fictícias para que os '
                            'insights e os gráficos tenham o que mostrar desde '
                            'a primeira abertura. Remova-as quando quiser ver '
                            'só os seus dados reais.'
                        : 'Você está vendo apenas as suas sessões reais.',
                    style: const TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _toggleDemo,
                      icon: Icon(_hasDemo
                          ? Icons.delete_outline
                          : Icons.restore_outlined),
                      label: Text(_hasDemo
                          ? 'Remover dados de demonstração'
                          : 'Restaurar dados de demonstração'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No roadmap (fora do MVP)',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ..._roadmap.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6, right: 8),
                            child: Icon(Icons.circle, size: 6),
                          ),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Erros assíncronos e falhas de desenho não derrubam mais o app, mas
            // por isso mesmo passariam despercebidos. Este cartão só aparece se
            // algo tiver falhado, e dá ao usuário o texto exato para reportar.
            if (AuraCrashReport.lastError != null) ...[
              const SizedBox(height: 12),
              AuraCard(
                color: const Color(0xFFFDECEA).withValues(alpha: 0.95),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bug_report_outlined,
                            color: Color(0xFFB3261E)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Último erro registrado',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFB3261E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'O app continuou funcionando, mas algo falhou nesta '
                      'sessão. Copie o texto abaixo ao relatar o problema.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      AuraCrashReport.lastError.toString(),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11, height: 1.4),
                    ),
                    if (AuraCrashReport.lastStack != null) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        // Poucos quadros: o suficiente para localizar a origem
                        // sem transformar a tela Sobre num despejo de log.
                        AuraCrashReport.lastStack
                            .toString()
                            .split('\n')
                            .take(6)
                            .join('\n'),
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 10, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WIDGETS COMPARTILHADOS
// ============================================================

/// Cartão padrão do app.
///
/// Usa `Container` + `BoxDecoration` em vez de `Card`/`CardTheme` por
/// incompatibilidade conhecida do `CardThemeData` com o SDK do FlutLab.
class AuraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const AuraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, height: 1.1)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
