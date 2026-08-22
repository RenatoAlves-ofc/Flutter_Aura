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
import 'package:http/http.dart' as http;
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

  /// Que tipo de trabalho era esta sessão — ver [kFocusContexts].
  ///
  /// É o que permite ao app responder *qual tipo de trabalho te esgota*, e não
  /// apenas onde o seu tempo foi. Sessões gravadas antes deste campo existir
  /// caem em `geral`, que é honesto: de fato não se sabe o que elas eram.
  final String contextId;

  /// Nota curta e opcional sobre o que ia ser feito. Sempre pode ser nula: o
  /// campo existe no momento em que a pessoa só quer começar a focar, então
  /// exigir texto ali seria atrito no pior lugar possível.
  final String? note;

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
    this.contextId = kDefaultContextId,
    this.note,
    this.isDemo = false,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'duration': durationMinutes,
        'moodBefore': moodBefore,
        'moodAfter': moodAfter,
        'linkedTaskId': linkedTaskId,
        'methodId': methodId,
        'contextId': contextId,
        'note': note,
        'isDemo': isDemo,
      };

  factory StudySession.fromJson(Map<String, dynamic> j) => StudySession(
        date: DateTime.parse(j['date'] as String),
        durationMinutes: j['duration'] as int,
        moodBefore: j['moodBefore'] as int,
        moodAfter: j['moodAfter'] as int,
        linkedTaskId: j['linkedTaskId'] as String?,
        methodId: j['methodId'] as String? ?? 'pomodoro_classico',
        // Retrocompatível de propósito: quem já tem o app instalado tem sessões
        // gravadas sem estes dois campos, e elas precisam continuar abrindo.
        contextId: j['contextId'] as String? ?? kDefaultContextId,
        note: j['note'] as String?,
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

/// Índigo da marca — o mesmo do ícone do launcher e da tela de abertura.
///
/// **Regra de cor do app**, que vale para toda a interface:
///
/// - **Índigo é a estrutura**: marca, botões, anel do cronômetro, números de
///   insight, aba ativa. Não muda nunca.
/// - **`AuraClimate.accent` é o estado do usuário**: a aura, e só ela.
/// - **Exceção: cores semânticas**, onde a cor *é* a informação e trocá-la
///   apagaria significado — a prioridade das tarefas (`_priorityColor`) e as
///   faces do check de humor (`moodColors`). Não é decoração solta.
///
/// Antes desta regra as duas famílias de cor conviviam sem critério — o ícone e
/// a abertura eram índigo e a interface era verde-azulada, o que fazia o app
/// parecer outro produto depois da tela de abertura.
const Color kBrandIndigo = Color(0xFF6C63FF);

/// O que o usuário declarou sobre si e sobre o que está fazendo.
///
/// Tudo opcional: o app inteiro funciona com o perfil vazio, e é assim que ele
/// abre. Nada aqui sai do aparelho — vale o mesmo que vale para as sessões.
class AuraProfile {
  final String? name;
  final String contextId;

  /// "O que você está focando neste período" — ex.: "TCC sobre visão
  /// computacional". É a resposta a *o que está sendo feito*, num campo só, sem
  /// repetir a aba Tarefas.
  final String? focus;

  const AuraProfile({
    this.name,
    this.contextId = kDefaultContextId,
    this.focus,
  });

  bool get isEmpty =>
      (name == null || name!.isEmpty) && (focus == null || focus!.isEmpty);
}

/// Os tipos de trabalho que uma sessão pode ter.
///
/// Categorizar sessão por tag é comum no mercado — Forest, Toggl e Focus To-Do
/// fazem isso. O que nenhum deles faz é **cruzar a categoria com o humor**:
/// todos respondem "onde foi o meu tempo", e o Aura responde "qual tipo de
/// trabalho te esgota, e por quanto tempo você aguenta cada um". Por isso este
/// campo existe junto do insight que o consome, e não sozinho.
class FocusContext {
  final String id;
  final String name;
  final IconData icon;

  const FocusContext({required this.id, required this.name, required this.icon});
}

const String kDefaultContextId = 'geral';

const List<FocusContext> kFocusContexts = [
  FocusContext(id: 'academico', name: 'Acadêmico', icon: Icons.school_outlined),
  FocusContext(id: 'trabalho', name: 'Trabalho', icon: Icons.work_outline),
  FocusContext(id: 'pessoal', name: 'Pessoal', icon: Icons.self_improvement_outlined),
  FocusContext(id: 'criativo', name: 'Criativo', icon: Icons.brush_outlined),
  FocusContext(id: kDefaultContextId, name: 'Geral', icon: Icons.circle_outlined),
];

/// Um id desconhecido cai em `Geral` em vez de estourar — mesma política de
/// `methodById`, pelo mesmo motivo: dado gravado por outra versão não pode
/// derrubar o app.
FocusContext contextById(String id) => kFocusContexts.firstWhere(
      (c) => c.id == id,
      orElse: () => kFocusContexts.last,
    );

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

/// Duas medidas que um insight pode expor para serem **mostradas**, e não só
/// narradas no texto.
///
/// O app inteiro existe para provar uma correlação, e ela estava sendo contada
/// em prosa no meio de um parágrafo. Duas barras lado a lado entregam a mesma
/// informação antes de a pessoa terminar de ler a frase.
class InsightComparison {
  final String highLabel;
  final double highValue;
  final String lowLabel;
  final double lowValue;
  final String unit;

  const InsightComparison({
    required this.highLabel,
    required this.highValue,
    required this.lowLabel,
    required this.lowValue,
    required this.unit,
  });

  /// Proporção da barra menor em relação à maior, entre 0 e 1.
  ///
  /// Piso de 0.08 para a barra menor nunca sumir: uma barra de largura zero
  /// some da tela e some junto com ela a comparação que a barra existe para
  /// mostrar.
  double get lowRatio =>
      highValue <= 0 ? 0 : (lowValue / highValue).clamp(0.08, 1.0);
}

class Insight {
  final String id;
  final String title;
  final IconData icon;
  final int requiredSessions;
  final int availableSessions;
  final String? headline;
  final String? body;
  final InsightComparison? comparison;

  const Insight({
    required this.id,
    required this.title,
    required this.icon,
    required this.requiredSessions,
    required this.availableSessions,
    this.headline,
    this.body,
    this.comparison,
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
    _insightWeekday(sessions),
    _insightMethod(sessions),
    _insightContext(sessions),
    // Penúltimo de propósito: é o único insight estruturalmente sobre humor,
    // não sobre desempenho — fica atrás dos que vendem rendimento medido.
    // Ver DECISOES.md §25.
    _insightMoodDelta(sessions),
    _insightDurationCeiling(sessions),
  ];
}

/// A descoberta que só o Aura consegue dar.
///
/// Forest, Toggl e Focus To-Do categorizam sessão por tag e respondem "onde foi
/// o meu tempo". Nenhum deles cruza a categoria com o humor, que é o que
/// responde a pergunta útil: **qual tipo de trabalho te esgota, e por quanto
/// tempo você aguenta cada um.**
Insight _insightContext(List<StudySession> sessions) {
  const int required = 8;
  const String title = 'Onde você rende mais';
  const IconData icon = Icons.category_outlined;

  Insight locked() => Insight(
        id: 'context',
        title: title,
        icon: icon,
        requiredSessions: required,
        availableSessions: sessions.length,
      );

  if (sessions.length < required) return locked();

  final porContexto = <String, List<StudySession>>{};
  for (final s in sessions) {
    porContexto.putIfAbsent(s.contextId, () => []).add(s);
  }

  // Dois contextos com 3+ sessões cada: comparar tipos de trabalho com base em
  // uma ou duas tentativas diria mais sobre aqueles dias que sobre a pessoa.
  final elegiveis = porContexto.entries.where((e) => e.value.length >= 3).toList();
  if (elegiveis.length < 2) return locked();

  double duracao(List<StudySession> l) =>
      l.map((s) => s.durationMinutes).reduce((a, b) => a + b) / l.length;
  double humorFinal(List<StudySession> l) =>
      l.map((s) => s.moodAfter).reduce((a, b) => a + b) / l.length;

  elegiveis.sort((a, b) => duracao(b.value).compareTo(duracao(a.value)));
  final maior = elegiveis.first;
  final menor = elegiveis.last;

  final nomeMaior = contextById(maior.key).name;
  final nomeMenor = contextById(menor.key).name;

  return Insight(
    id: 'context',
    title: title,
    icon: icon,
    requiredSessions: required,
    availableSessions: sessions.length,
    headline: nomeMaior,
    body: 'Em $nomeMaior você sustenta ${fmt(duracao(maior.value))} min por '
        'sessão e termina em ${fmt(humorFinal(maior.value))}/5. Em $nomeMenor '
        'são ${fmt(duracao(menor.value))} min, fechando em '
        '${fmt(humorFinal(menor.value))}/5. Não é falta de disciplina: tipos de '
        'trabalho diferentes cobram preços diferentes de você.',
    comparison: InsightComparison(
      highLabel: nomeMaior,
      highValue: duracao(maior.value),
      lowLabel: nomeMenor,
      lowValue: duracao(menor.value),
      unit: 'min',
    ),
  );
}

/// Agrupa `moodBefore` em três faixas legíveis: 1-2 baixo, 3 neutro, 4-5 alto.
int _moodBucket(int mood) {
  if (mood <= 2) return 0;
  if (mood == 3) return 1;
  return 2;
}

const List<String> _bucketNames = [
  'começa em baixa energia (1-2)',
  'começa em energia neutra (3)',
  'começa em alta energia (4-5)',
];

Insight _insightMoodVsDuration(List<StudySession> sessions) {
  const int required = 5;
  const String title = 'Seu estado de entrada prevê seu foco';
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
        '${fmt(averages[worst]!)} min. São ${fmt(diff)} min de rendimento que '
        'variam conforme a condição em que você começa a sessão.',
    comparison: InsightComparison(
      highLabel: _bucketNames[best],
      highValue: averages[best]!,
      lowLabel: _bucketNames[worst],
      lowValue: averages[worst]!,
      unit: 'min',
    ),
  );
}

Insight _insightMoodDelta(List<StudySession> sessions) {
  const int required = 5;
  const String title = 'Efeito colateral do foco';
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
    body: '${methodById(best.key).name} é o que você mais sustenta: rendimento '
        'médio de ${fmt(avgMoodAfter(best.value))}/5 em '
        '${fmt(avgDuration(best.value))} min por sessão. Já '
        '${methodById(worst.key).name} fecha em '
        '${fmt(avgMoodAfter(worst.value))}/5.',
  );
}

/// A quinta descoberta — e a única que **nasce bloqueada** com o dataset de
/// demonstração, de propósito.
///
/// Antes desta, o app não tinha nada apontando para frente: os quatro insights
/// abrem com 5 a 7 sessões e a demonstração tem 22, então ninguém nunca via um
/// cartão trancado. A mecânica de desbloqueio existia no código e era invisível
/// na tela.
///
/// O limiar de 30 não é artificial para criar suspense: uma conclusão sobre
/// *teto* de duração precisa de volume para não ser ruído. Com 22 sessões a
/// demonstração mostra "faltam 8", que é um alvo concreto.
Insight _insightDurationCeiling(List<StudySession> sessions) {
  const int required = 30;
  const String title = 'Seu limite real';
  const IconData icon = Icons.speed;

  Insight locked() => Insight(
        id: 'duration_ceiling',
        title: title,
        icon: icon,
        requiredSessions: required,
        availableSessions: sessions.length,
      );

  if (sessions.length < required) return locked();

  // Faixas de duração, não minutos exatos: agrupar é o que permite comparar
  // humor final entre sessões curtas, médias e longas.
  int band(int minutes) => minutes <= 25
      ? 0
      : minutes <= 50
          ? 1
          : 2;
  const nomes = ['até 25 min', 'de 26 a 50 min', 'acima de 50 min'];

  final porFaixa = <int, List<StudySession>>{};
  for (final s in sessions) {
    porFaixa.putIfAbsent(band(s.durationMinutes), () => []).add(s);
  }

  // Exige as três faixas com 3+ sessões cada: comparar um teto com base numa
  // única sessão longa diria mais sobre aquele dia que sobre a pessoa.
  final elegiveis = porFaixa.entries.where((e) => e.value.length >= 3).toList();
  if (elegiveis.length < 3) return locked();

  double humorFinal(List<StudySession> l) =>
      l.map((s) => s.moodAfter).reduce((a, b) => a + b) / l.length;

  elegiveis.sort((a, b) => humorFinal(b.value).compareTo(humorFinal(a.value)));
  final melhor = elegiveis.first;
  final pior = elegiveis.last;
  final queda = humorFinal(melhor.value) - humorFinal(pior.value);

  return Insight(
    id: 'duration_ceiling',
    title: title,
    icon: icon,
    requiredSessions: required,
    availableSessions: sessions.length,
    headline: nomes[melhor.key],
    body: 'Suas sessões ${nomes[melhor.key]} terminam com humor '
        '${fmt(humorFinal(melhor.value))}/5 — o seu melhor. '
        '${nomes[pior.key][0].toUpperCase()}${nomes[pior.key].substring(1)} '
        'fecham em ${fmt(humorFinal(pior.value))}/5, ${fmt(queda)} ponto a '
        'menos. Focar mais tempo nem sempre é focar melhor.',
    comparison: InsightComparison(
      highLabel: nomes[melhor.key],
      highValue: humorFinal(melhor.value),
      lowLabel: nomes[pior.key],
      lowValue: humorFinal(pior.value),
      unit: '/5',
    ),
  );
}

// ============================================================
// SUGESTÃO ADAPTATIVA DE DURAÇÃO
// ============================================================

/// O que o histórico diz sobre um método, para um humor de partida específico.
class MethodSuggestion {
  final FocusMethod method;

  /// Minutos que o usuário realmente sustentou, em média, nessas condições —
  /// não a duração que o método promete.
  final double avgDuration;
  final double avgMoodAfter;
  final int sampleSize;

  const MethodSuggestion({
    required this.method,
    required this.avgDuration,
    required this.avgMoodAfter,
    required this.sampleSize,
  });
}

/// Sugere o método que historicamente termina melhor para quem começa a sessão
/// com [mood].
///
/// Devolve `null` quando não há evidência suficiente: o app prefere não sugerir
/// nada a sugerir com base em uma tentativa isolada.
///
/// Aplica o mesmo mínimo de 2 sessões por método do insight "o método que mais
/// te sustenta", mas olha só as sessões da mesma faixa de humor — é uma pergunta
/// diferente ("o que funciona quando estou assim?" em vez de "o que funciona no
/// geral?"). Por isso pode haver sugestão aqui enquanto aquele insight ainda
/// está bloqueado, que exige 6 sessões no total.
///
/// Flowtime e Personalizado ficam de fora: um não tem duração alvo e o outro
/// depende do que o usuário configurou, então recomendá-los por duração média
/// prometeria um número que a sessão não vai cumprir.
MethodSuggestion? suggestMethodForMood(List<StudySession> sessions, int mood) {
  final bucket = _moodBucket(mood);

  final byMethod = <String, List<StudySession>>{};
  for (final s in sessions) {
    if (_moodBucket(s.moodBefore) != bucket) continue;
    final method = methodById(s.methodId);
    if (method.isFlowtime || method.isCustom) continue;
    byMethod.putIfAbsent(s.methodId, () => []).add(s);
  }

  final eligible = byMethod.entries.where((e) => e.value.length >= 2).toList();
  if (eligible.isEmpty) return null;

  double avgMoodAfter(List<StudySession> l) =>
      l.map((s) => s.moodAfter).reduce((a, b) => a + b) / l.length;
  double avgDuration(List<StudySession> l) =>
      l.map((s) => s.durationMinutes).reduce((a, b) => a + b) / l.length;

  eligible.sort((a, b) {
    final byMood = avgMoodAfter(b.value).compareTo(avgMoodAfter(a.value));
    // Empate no humor final: fica com o que sustentou mais tempo.
    if (byMood != 0) return byMood;
    return avgDuration(b.value).compareTo(avgDuration(a.value));
  });

  final best = eligible.first;
  return MethodSuggestion(
    method: methodById(best.key),
    avgDuration: avgDuration(best.value),
    avgMoodAfter: avgMoodAfter(best.value),
    sampleSize: best.value.length,
  );
}

// ============================================================
// FICHA DE PERSONAGEM (atributos derivados, nunca inventados)
// ============================================================

/// Um atributo da ficha.
///
/// `value` é só para desenhar a barra. Quem carrega a verdade é `display` — o
/// número real, na unidade real. A barra é leitura rápida; o número é o dado.
class CharacterAttribute {
  final String name;

  /// 0 a 100, para a largura da barra.
  final int value;

  /// O número real, formatado com unidade ("13 dias", "73%", "90 min").
  final String display;

  /// Uma linha dizendo de onde o número saiu.
  final String note;

  const CharacterAttribute({
    required this.name,
    required this.value,
    required this.display,
    required this.note,
  });
}

class CharacterSheet {
  final String className;
  final String tagline;
  final List<CharacterAttribute> attributes;

  /// Vêm do perfil, e todos podem faltar: a ficha funciona anônima, que é como
  /// ela abre antes de a pessoa preencher qualquer coisa.
  final String? name;
  final String? contextName;
  final String? focus;

  /// `false` quando ainda não há sessão nenhuma. A tela mostra o convite em vez
  /// de quatro barras zeradas — o mesmo erro que a tela Resumo já cometeu uma
  /// vez, mostrando "0 dias de sequência" ao lado de "20 sessões totais".
  final bool hasData;

  const CharacterSheet({
    required this.className,
    required this.tagline,
    required this.attributes,
    required this.hasData,
    this.name,
    this.contextName,
    this.focus,
  });
}

/// Monta a ficha a partir **só** do que já foi medido.
///
/// Nenhum ponto de experiência, nenhum nível, nenhuma medalha por existir: a
/// classe sai do método que a pessoa de fato usa, e os quatro atributos saem
/// das mesmas contas que alimentam os insights. É o que separa isto da
/// gamificação genérica — aqui o número **é** o comportamento, não um prêmio
/// pendurado em cima dele.
CharacterSheet buildCharacterSheet(
  List<StudySession> sessions, {
  AuraProfile profile = const AuraProfile(),
}) {
  final nome = (profile.name?.trim().isEmpty ?? true) ? null : profile.name!.trim();
  final foco = (profile.focus?.trim().isEmpty ?? true) ? null : profile.focus!.trim();
  // O contexto "Geral" não vira rótulo: dizer "Ritmista · Geral" não acrescenta
  // nada, e o padrão é justamente quem não escolheu.
  final contexto = profile.contextId == kDefaultContextId
      ? null
      : contextById(profile.contextId).name;

  if (sessions.isEmpty) {
    return CharacterSheet(
      className: 'Sem ficha ainda',
      tagline: 'Conclua uma sessão para o Aura começar a te medir.',
      attributes: const [],
      hasData: false,
      name: nome,
      contextName: contexto,
      focus: foco,
    );
  }

  // ---- Classe: a família de duração do método mais usado ----
  final contagem = <String, int>{};
  for (final s in sessions) {
    contagem[s.methodId] = (contagem[s.methodId] ?? 0) + 1;
  }
  final dominante = contagem.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  final metodo = methodById(dominante);

  String classe;
  String tagline;
  if (metodo.isFlowtime) {
    classe = 'Explorador';
    tagline = 'Você não marca o fim antes de começar.';
  } else {
    final min = metodo.focusMinutes ?? 25;
    if (min >= 50) {
      classe = 'Maratonista';
      tagline = 'Você entra fundo e fica.';
    } else if (min <= 20) {
      classe = 'Sprinter';
      tagline = 'Você rende em investidas curtas.';
    } else {
      classe = 'Ritmista';
      tagline = 'Você trabalha em ciclos constantes.';
    }
  }

  // ---- Constância: a sequência que a regra de perdão sustenta hoje ----
  final sequencia = effectiveStreak(streakFromSessions(sessions), DateTime.now());

  // ---- Recuperação: com que frequência a sessão te devolve melhor ----
  final melhoraram = sessions.where((s) => s.moodAfter > s.moodBefore).length;
  final pctRecuperacao = (melhoraram * 100 / sessions.length).round();

  // ---- Amplitude: quanto o humor inicial move a sua duração ----
  final porFaixa = <int, List<int>>{};
  for (final s in sessions) {
    porFaixa.putIfAbsent(_moodBucket(s.moodBefore), () => []).add(s.durationMinutes);
  }
  double media(List<int> l) => l.reduce((a, b) => a + b) / l.length;
  double amplitude = 0;
  if (porFaixa.length >= 2) {
    final medias = porFaixa.values.map(media).toList()..sort();
    amplitude = medias.last - medias.first;
  }

  // ---- Profundidade: a maior sessão que você sustentou ----
  final maior = sessions.map((s) => s.durationMinutes).reduce(math.max);

  // Os tetos de normalização são alvos declarados, não escalas escondidas: 21
  // dias de sequência, 100% de recuperação, 40 min de amplitude e 90 min de
  // sessão — o Ciclo Ultradiano, o método mais longo do app.
  int pct(num valor, num teto) => ((valor / teto) * 100).clamp(0, 100).round();

  return CharacterSheet(
    className: classe,
    tagline: tagline,
    hasData: true,
    name: nome,
    contextName: contexto,
    focus: foco,
    attributes: [
      CharacterAttribute(
        name: 'Constância',
        value: pct(sequencia, 21),
        display: '$sequencia ${sequencia == 1 ? 'dia' : 'dias'}',
        note: 'sequência atual, com as folgas já descontadas',
      ),
      CharacterAttribute(
        name: 'Recuperação',
        value: pctRecuperacao,
        display: '$pctRecuperacao%',
        note: 'das sessões te devolvem melhor do que te encontraram',
      ),
      CharacterAttribute(
        name: 'Amplitude',
        value: pct(amplitude, 40),
        display: '${fmt(amplitude)} min',
        note: 'quanto o humor inicial move a sua duração',
      ),
      CharacterAttribute(
        name: 'Profundidade',
        value: pct(maior, 90),
        display: '$maior min',
        note: 'a maior sessão que você sustentou',
      ),
    ],
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
// FRASE DO DIA (única chamada de rede do app — ver DECISOES.md §24)
// ============================================================
//
// Todo o resto do Aura é Dart puro, sem rede (ver o banner de MOTOR DE
// INSIGHTS, acima). Esta seção é a única exceção, e existe só para uma frase
// curta de incentivo por dia. O app preferia não precisar dela — a decisão
// registrada em DECISOES.md §24 explica o porquê e o que foi descartado.
//
// Tenta a Groq primeiro; se falhar (limite, timeout, rede fora), tenta a
// Gemini como reserva. As duas são chave de tier gratuito, sem cartão
// vinculado: como o repositório é público, a chave fica exposta a qualquer
// pessoa assim que o commit sai — o pior caso de abuso é a cota estourar e o
// recurso parar de funcionar, nunca uma cobrança.
//
// Nomes de modelo conferidos em 21/08/2026 (os dois trocaram de nome no
// mesmo ano: a Groq descontinuou o Llama 3.1 8B em junho, a Gemini desligou
// o 2.0 Flash no mesmo mês). Se algum dia a chamada parar de funcionar,
// comece verificando se o modelo mudou de novo antes de suspeitar de outra
// coisa — já aconteceu duas vezes este ano.

/// Chave nova da Groq — não reaproveitar nenhuma chave que já tenha
/// circulado fora do repositório (chat, print, etc.). Fica em branco até a
/// chave chegar; enquanto estiver assim, [fetchDailyLine] não tenta nada.
const String _kGroqApiKey = '';

/// Reserva, só entra se a Groq falhar. Em branco desativa a reserva e usa
/// só a Groq.
const String _kGeminiApiKey = '';

/// Desliga a chamada de rede real. A suíte de widgets liga isto antes de
/// pumpar qualquer tela: um `pumpAndSettle` não espera por uma requisição de
/// verdade, e o teste terminaria com ela ainda pendente — o card tentaria um
/// `setState` depois que a árvore já tivesse sido descartada.
bool debugDisableDailyLineNetwork = false;

/// Monta o resumo que vira prompt. Pura, testável sem rede: manda só o que
/// já foi calculado localmente (classe, atributo mais forte, clima,
/// contexto, foco do momento) — nunca o histórico bruto de humor sessão por
/// sessão. É o mínimo que sai do aparelho para a frase continuar pessoal sem
/// expor mais do que precisa.
String buildDailyLinePrompt(
  List<StudySession> sessions,
  AuraProfile profile,
  CharacterSheet sheet,
  AuraClimate climate,
) {
  final partes = <String>[];
  if (sheet.hasData) {
    partes.add('Classe: ${sheet.className}.');
    final destaque =
        sheet.attributes.reduce((a, b) => a.value >= b.value ? a : b);
    partes.add('Ponto forte: ${destaque.name} (${destaque.display}).');
  }
  partes.add('Clima atual: ${climate.name}.');
  if (sheet.contextName != null) {
    partes.add('Contexto principal: ${sheet.contextName}.');
  }
  if (sheet.focus != null) {
    partes.add('Está focando em: ${sheet.focus}.');
  }
  final resumo = partes.join(' ');
  return 'Você escreve uma frase curta de incentivo (máximo 20 palavras, em '
      'português do Brasil, sem emoji, sem aspas) para alguém que usa um app '
      'de foco. Baseie-se só nisto, sem inventar nenhum outro detalhe: '
      '$resumo Responda só com a frase, nada antes nem depois.';
}

/// Extrai o texto de uma resposta da Groq (formato de chat compatível com a
/// API da OpenAI). `null` se o formato não bater com o esperado — o mesmo
/// tratamento de qualquer outra falha, não um caso especial.
String? parseGroqDailyLine(String body) {
  try {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return null;
    final message =
        (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    final texto = (message?['content'] as String?)?.trim();
    return (texto == null || texto.isEmpty) ? null : texto;
  } catch (_) {
    return null;
  }
}

/// Extrai o texto de uma resposta da Gemini — formato próprio, diferente do
/// da Groq. `null` se o formato não bater com o esperado.
String? parseGeminiDailyLine(String body) {
  try {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final content = (candidates.first as Map<String, dynamic>)['content']
        as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;
    final texto =
        ((parts.first as Map<String, dynamic>)['text'] as String?)?.trim();
    return (texto == null || texto.isEmpty) ? null : texto;
  } catch (_) {
    return null;
  }
}

/// Tenta a Groq e, se falhar, tenta a Gemini. `null` se as duas falharem, se
/// nenhuma chave estiver configurada, ou se [debugDisableDailyLineNetwork]
/// estiver ligado — a mesma política de `suggestMethodForMood`: sem
/// evidência, sem frase, nunca uma genérica no lugar.
Future<String?> fetchDailyLine(String prompt) async {
  if (debugDisableDailyLineNetwork) return null;

  if (_kGroqApiKey.isNotEmpty) {
    final texto = await _tryGroq(prompt);
    if (texto != null) return texto;
  }
  if (_kGeminiApiKey.isNotEmpty) {
    final texto = await _tryGemini(prompt);
    if (texto != null) return texto;
  }
  return null;
}

Future<String?> _tryGroq(String prompt) async {
  try {
    final response = await http
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $_kGroqApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'openai/gpt-oss-20b',
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
            'max_tokens': 60,
            'temperature': 0.7,
          }),
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return null;
    return parseGroqDailyLine(response.body);
  } catch (_) {
    return null;
  }
}

Future<String?> _tryGemini(String prompt) async {
  try {
    final response = await http
        .post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/'
            'gemini-2.5-flash:generateContent?key=$_kGeminiApiKey',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return null;
    return parseGeminiDailyLine(response.body);
  } catch (_) {
    return null;
  }
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
  // Gerador separado de propósito. Sortear o contexto do mesmo `rnd` deslocaria
  // toda a sequência seguinte, mudando métodos e durações de todas as sessões —
  // e com elas os números já publicados na documentação e nos prints. Com dois
  // geradores, acrescentar o contexto não altera nada do que já existia.
  final ctxRnd = math.Random(11);
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

  // Contextos por humor inicial. A correlação embutida é deliberada e é a que o
  // insight "onde você rende mais" existe para descobrir: trabalho
  // administrativo aparece nos dias ruins e rende sessões curtas; estudo e
  // trabalho criativo aparecem nos dias bons e sustentam mais tempo.
  const contextByMood = <int, List<String>>{
    1: ['trabalho', 'geral'],
    2: ['trabalho', 'geral'],
    3: ['trabalho', 'pessoal'],
    4: ['academico', 'academico', 'criativo'],
    5: ['academico', 'criativo'],
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

      final contextPool = contextByMood[mood]!;
      final contextId = contextPool[ctxRnd.nextInt(contextPool.length)];

      sessions.add(StudySession(
        date: date,
        durationMinutes: duration,
        moodBefore: mood,
        moodAfter: moodAfter,
        methodId: methodId,
        contextId: contextId,
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
  AuraProfile _profile = const AuraProfile();
  StreakState _streak = const StreakState(
      streak: 0, tokens: 0, runLength: 0, lastActiveDay: null);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _editProfile() async {
    final atualizado = await showModalBottomSheet<AuraProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileSheet(profile: _profile),
    );
    if (atualizado == null || !mounted) return;
    await AuraStore.saveProfile(atualizado);
    if (!mounted) return;
    // Relê do disco em vez de confiar no que foi enviado: o `saveProfile`
    // remove campo vazio, então é a leitura que diz o estado real.
    final profile = await AuraStore.loadProfile();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  Future<void> _loadAll() async {
    try {
      final tasks = await AuraStore.loadTasks();
      var sessions = await AuraStore.loadSessions();
      var points = await AuraStore.loadPoints();
      var streak = await AuraStore.loadStreak();
      final seeded = await AuraStore.demoSeeded();
      final profile = await AuraStore.loadProfile();

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
        _profile = profile;
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
        sessions: _sessions,
        onSessionRecorded: _recordSession,
        defaultContextId: _profile.contextId,
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
        profile: _profile,
        onEditProfile: _editProfile,
      ),
    ];

    // A abertura é contínua de propósito: a tela nativa usa o mesmo índigo da
    // AuraLoadingScreen, que então se dissolve na cor da aura do usuário. Sem
    // isso a sequência era flash branco, spinner e app — três telas
    // desconexas.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _loading
          ? const AuraLoadingScreen()
          : _buildShell(context, climate, pages),
    );
  }

  Widget _buildShell(
    BuildContext context,
    AuraClimate climate,
    List<Widget> pages,
  ) {
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
          // A marca é constante — a mesma forma do ícone do launcher e da tela
          // de abertura. O clima aparece na COR do anel, não trocando o
          // símbolo: antes o app nunca mostrava a própria marca, porque o
          // ícone da AppBar mudava junto com o estado do usuário.
          title: Row(
            children: [
              AuraMark(
                size: 30,
                ringColor: kBrandIndigo,
                glowColor: climate.accent,
                coreColor: kBrandIndigo,
              ),
              const SizedBox(width: 10),
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
                    const Icon(Icons.star_outline,
                        color: kBrandIndigo, size: 18),
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
        // Troca de aba com dissolvência e um deslize curto, para a navegação
        // não ser um corte seco. A duração é curta de propósito: passar de aba
        // precisa continuar parecendo instantâneo.
        body: SafeArea(
          top: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            // A chave é o que faz o AnimatedSwitcher enxergar a troca: sem ela
            // as abas são todas "o mesmo widget" e nada anima.
            child: KeyedSubtree(
              key: ValueKey<int>(_index),
              child: pages[_index],
            ),
          ),
        ),
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

  /// Método que o usuário aceitou da sugestão adaptativa, se aceitou algum.
  final String? applyMethodId;

  /// Tipo de trabalho e nota, preenchidos só no check de **antes** da sessão.
  final String? contextId;
  final String? note;

  const _MoodResult(
    this.mood,
    this.taskId, {
    this.applyMethodId,
    this.contextId,
    this.note,
  });
}

class FocusPage extends StatefulWidget {
  final List<TaskItem> tasks;
  final AuraClimate climate;

  /// Histórico, usado apenas para a sugestão adaptativa no check de humor.
  final List<StudySession> sessions;
  final Future<void> Function(StudySession session) onSessionRecorded;

  /// Contexto do perfil, usado como pré-seleção do check de humor.
  final String defaultContextId;

  const FocusPage({
    super.key,
    required this.tasks,
    required this.climate,
    required this.sessions,
    required this.onSessionRecorded,
    this.defaultContextId = kDefaultContextId,
  });

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage>
    with SingleTickerProviderStateMixin {
  /// Pulsação do halo em volta do anel. Só roda com a sessão em andamento —
  /// é a única animação contínua do app, e deixá-la ligada o tempo todo faria
  /// o `pumpAndSettle` dos testes de interface nunca terminar.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

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
  String _sessionContextId = kDefaultContextId;
  String? _sessionNote;

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
    _breath.dispose();
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

      // O usuário aceitou a sugestão adaptativa: troca o método antes de
      // iniciar. A sessão roda a duração do preset sugerido — o número que o
      // cartão mostra é a média que ele sustentou, não uma nova duração alvo.
      final applyId = result.applyMethodId;
      if (applyId != null) {
        setState(() {
          _methodId = applyId;
          _resetTimerValues();
        });
        await AuraStore.saveSelectedMethod(applyId);
        if (!mounted) return;
      }

      setState(() {
        _moodBefore = result.mood;
        _linkedTaskId = result.taskId;
        _sessionContextId = result.contextId ?? widget.defaultContextId;
        final nota = result.note?.trim();
        _sessionNote = (nota == null || nota.isEmpty) ? null : nota;
      });
    }

    _start();
  }

  void _start() {
    setState(() => _isRunning = true);
    _breath.repeat(reverse: true);
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
    // Parar em vez de só deixar rodar: sessão pausada tem que parecer parada.
    _breath.stop();
    setState(() => _isRunning = false);
  }

  void _reset() {
    _timer?.cancel();
    _breath.stop();
    setState(() {
      _isRunning = false;
      _moodBefore = null;
      _linkedTaskId = null;
      _sessionContextId = widget.defaultContextId;
      _sessionNote = null;
      _resetTimerValues();
    });
  }

  /// Chamado quando um ciclo de duração fixa chega a zero.
  Future<void> _onCycleComplete() async {
    _timer?.cancel();
    _breath.stop();
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
      contextId: _sessionContextId,
      note: _sessionNote,
      methodId: _methodId,
    ));

    if (!mounted) return;
    setState(() {
      _moodBefore = null;
      _linkedTaskId = null;
      _sessionContextId = widget.defaultContextId;
      _sessionNote = null;
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
    _breath.stop();
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
        asksContext: true,
        defaultContextId: widget.defaultContextId,
        title: 'Como você está agora?',
        subtitle: 'Isso é o que permite o Aura descobrir o que realmente '
            'afeta seu foco.',
        linkableTasks: pending,
        sessions: widget.sessions,
        currentMethodId: _methodId,
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

    // O conteúdo desta tela é mais curto que a altura do telefone, e antes
    // ficava empilhado no topo com uns 400 px vazios embaixo. O
    // `ConstrainedBox` com a altura disponível deixa a `Column` distribuir esse
    // resto entre os blocos, em vez de largá-lo todo no fim. Continua rolando
    // normalmente quando o conteúdo passa da tela — em Flowtime, por exemplo.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                  // Mesma cor do anel: o título e o progresso falam da mesma
                  // coisa, e antes o título era verde-água enquanto o anel era
                  // índigo.
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            _isBreak ? const Color(0xFF4DB6AC) : kBrandIndigo,
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
                // Halo que respira enquanto a sessão roda. É a única animação
                // contínua do app: fica só na tela onde o usuário passa mais
                // tempo parado olhando, e some quando ele pausa.
                AnimatedBuilder(
                  animation: _breath,
                  builder: (context, child) {
                    final t = _isRunning ? _breath.value : 0.0;
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            // Zero em repouso, de propósito: a sombra de um
                            // círculo é preenchida, então com o cronômetro
                            // parado ela aparecia como um disco esverdeado no
                            // miolo do anel, brigando com o índigo. Agora o
                            // halo só existe enquanto a sessão roda — que é o
                            // que ele significa.
                            color: (_isBreak
                                    ? const Color(0xFF4DB6AC)
                                    : climate.accent)
                                .withValues(alpha: 0.26 * t),
                            blurRadius: 18 + 26 * t,
                            spreadRadius: 2 + 10 * t,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  // O anel é o elemento herói da tela e estava sendo o mais
                  // apagado dela: trilha em alpha 0.12 sobre cartão quase
                  // branco, praticamente invisível com o cronômetro parado.
                  // A trilha agora se enxerga, o traço é mais grosso e o
                  // progresso usa o índigo da marca — a pausa continua no
                  // verde-água, que é o que distingue foco de descanso.
                  child: CircularPercentIndicator(
                    radius: 120,
                    lineWidth: 18,
                    percent: progress,
                    // Curto de propósito: o anel avança pouquíssimo por segundo,
                    // e uma animação longa manteria quadros agendados o tempo
                    // todo, travando o pumpAndSettle dos testes.
                    animation: true,
                    animateFromLastPercent: true,
                    animationDuration: 300,
                    circularStrokeCap: CircularStrokeCap.round,
                    backgroundColor: kBrandIndigo.withValues(alpha: 0.10),
                    progressColor:
                        _isBreak ? const Color(0xFF4DB6AC) : kBrandIndigo,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTime,
                        style: const TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w700,
                          // Tracking fechado: em número grande o espaçamento
                          // padrão espalha demais os dígitos.
                          letterSpacing: -1.5,
                          height: 1.1,
                        ),
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
        ),
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

  /// Histórico usado para sugerir um método assim que o humor é escolhido.
  /// Vazio no check de humor do fim da sessão, onde sugerir não faz sentido.
  final List<StudySession> sessions;
  final String currentMethodId;

  /// Só o check de **antes** pergunta tipo de trabalho e nota. No de depois, a
  /// pessoa acabou de focar e pedir texto ali é atrito no pior momento.
  final bool asksContext;
  final String defaultContextId;

  const _MoodSheet({
    required this.title,
    required this.subtitle,
    required this.linkableTasks,
    this.sessions = const [],
    this.currentMethodId = '',
    this.asksContext = false,
    this.defaultContextId = kDefaultContextId,
  });

  @override
  State<_MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends State<_MoodSheet> {
  late String _contextId = widget.defaultContextId;
  final TextEditingController _note = TextEditingController();

  int? _selected;
  String? _taskId;

  /// Marcado pelo usuário para trocar de método antes de começar. Fica desligado
  /// por padrão: a sugestão é uma oferta, não uma imposição. Volta a desligar
  /// sempre que o humor muda — a sugestão passa a ser outra, e manter a marca
  /// aplicaria um método que o usuário nunca chegou a ver.
  bool _acceptSuggestion = false;

  MethodSuggestion? get _suggestion {
    final mood = _selected;
    if (mood == null || widget.sessions.isEmpty) return null;
    final s = suggestMethodForMood(widget.sessions, mood);
    // Sugerir o método que já está selecionado seria ruído.
    if (s == null || s.method.id == widget.currentMethodId) return null;
    return s;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

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
      // Rolável desde que os chips de contexto e o campo de nota entraram: com
      // o cartão de sugestão aberto, em 420x940 o conteúdo passa da altura do
      // sheet e sem isto ele estoura com a faixa amarela e preta.
      child: SingleChildScrollView(
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
                  onTap: () => setState(() {
                    _selected = mood;
                    // A sugestão muda junto com o humor: manter a marca faria
                    // o Confirmar aplicar um método que o usuário não escolheu.
                    _acceptSuggestion = false;
                  }),
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
          if (_suggestion != null) ...[
            const SizedBox(height: 20),
            _SuggestionCard(
              suggestion: _suggestion!,
              accepted: _acceptSuggestion,
              onChanged: (v) => setState(() => _acceptSuggestion = v),
            ),
          ],
          if (widget.asksContext) ...[
            const SizedBox(height: 20),
            Text('Que tipo de trabalho é este?',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            // Já vem com o contexto do perfil marcado: quem não quiser mudar
            // não toca em nada, e o atrito continua zero.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kFocusContexts)
                  ChoiceChip(
                    label: Text(c.name),
                    avatar: Icon(c.icon, size: 18),
                    selected: _contextId == c.id,
                    onSelected: (_) => setState(() => _contextId = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLength: 60,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'O que você vai fazer? (opcional)',
                border: OutlineInputBorder(),
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
                      .pop(_MoodResult(
                        _selected!,
                        _taskId,
                        applyMethodId: _acceptSuggestion
                            ? _suggestion?.method.id
                            : null,
                        contextId: widget.asksContext ? _contextId : null,
                        note: widget.asksContext ? _note.text : null,
                      )),
              child: const Text('Confirmar'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// A sugestão adaptativa, mostrada dentro do check de humor.
///
/// Fecha o ciclo do app: o humor que o usuário acabou de informar vira uma
/// recomendação tirada do histórico dele, e não de uma regra genérica.
class _SuggestionCard extends StatelessWidget {
  final MethodSuggestion suggestion;
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const _SuggestionCard({
    required this.suggestion,
    required this.accepted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuraCard(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sugestão para este humor',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sentindo-se assim, você sustentou em média '
            '${fmt(suggestion.avgDuration)} min com o '
            '${suggestion.method.name}, terminando em '
            '${fmt(suggestion.avgMoodAfter)}/5. '
            'Baseado em ${suggestion.sampleSize} sessões suas.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 4),
          // O Material transparente é obrigatório aqui: o ListTile pinta fundo e
          // splash no Material mais próximo, e o AuraCard é um Container com
          // fundo próprio no meio do caminho — sem isto o toque não dá retorno
          // visual nenhum.
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: accepted,
              onChanged: (v) => onChanged(v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              // Sem "desta vez": aceitar troca o método selecionado de verdade,
              // igual a escolhê-lo no seletor, e a escolha fica valendo depois.
              title: Text('Usar ${suggestion.method.name}'),
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
        // As descobertas entram uma após a outra: é a tela que carrega o
        // argumento do app, e vê-la se montar dá mais peso do que encontrá-la
        // pronta.
        ...insights.indexed.map((e) => EntranceFade(
              index: e.$1,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _InsightCard(
                  insight: e.$2,
                  featured: e.$2.unlocked && e.$2.id == insights.firstWhere(
                    (i) => i.unlocked,
                    orElse: () => insights.first,
                  ).id,
                ),
              ),
            )),
        const SizedBox(height: 8),
        EntranceFade(
          index: insights.length,
          child: _MoodDurationChart(sessions: sessions),
        ),
        const SizedBox(height: 12),
        EntranceFade(
          index: insights.length + 1,
          child: _WeeklyFocusChart(sessions: sessions),
        ),
      ],
    );
  }
}

/// Barra proporcional de uma comparação, desenhada com `Container`.
///
/// Sem `fl_chart` de propósito: é a razão entre duas larguras, e trazer um
/// gráfico completo para isso custaria mais tempo de quadro numa tela que já
/// desenha dois gráficos de verdade mais abaixo.
class _ComparisonBars extends StatelessWidget {
  final InsightComparison data;
  final Color color;

  const _ComparisonBars({required this.data, required this.color});

  Widget _row(BuildContext context, String label, double value, double ratio,
      Color barColor) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Text('${value.toStringAsFixed(1)} ${data.unit}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: barColor)),
          ],
        ),
        const SizedBox(height: 4),
        // `FractionallySizedBox` mantém a proporção em qualquer largura de
        // tela, sem precisar medir nada.
        SizedBox(
          height: 10,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 620),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: t,
                    child: Container(
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(context, data.highLabel, data.highValue, 1.0, color),
        const SizedBox(height: 10),
        _row(context, data.lowLabel, data.lowValue, data.lowRatio,
            color.withValues(alpha: 0.38)),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Insight insight;

  /// O primeiro insight desbloqueado carrega a tese do app e ganha destaque.
  /// Sem isso os quatro cartões competiam com peso idêntico e nenhum vencia.
  final bool featured;

  const _InsightCard({required this.insight, this.featured = false});

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
      color: featured ? kBrandIndigo.withValues(alpha: 0.07) : null,
      padding: EdgeInsets.all(featured ? 20 : 16),
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
            SizedBox(height: featured ? 12 : 10),
            Text(
              insight.headline!,
              style: (featured
                      ? theme.textTheme.headlineMedium
                      : theme.textTheme.headlineSmall)
                  ?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
          if (insight.comparison != null) ...[
            const SizedBox(height: 14),
            _ComparisonBars(
              data: insight.comparison!,
              color: theme.colorScheme.primary,
            ),
          ],
          const SizedBox(height: 12),
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
              // As barras crescem ao aparecer em vez de já surgirem prontas —
              // é o gráfico que carrega a tese do app, e vê-lo se formar ajuda
              // a lê-lo.
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeOutCubic,
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
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeOutCubic,
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
  final AuraProfile profile;
  final VoidCallback onEditProfile;

  const SummaryPage({
    super.key,
    required this.points,
    required this.sessions,
    required this.streak,
    required this.climate,
    required this.profile,
    required this.onEditProfile,
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
    final sheet = buildCharacterSheet(sessions, profile: profile);

    // Mesmo caso da aba Foco: o conteúdo não enche a tela e sobrava um bloco
    // vazio no fim. Ver o comentário lá para o porquê do `ConstrainedBox`.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
        child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CharacterSheetCard(sheet: sheet, onEditProfile: onEditProfile),
        const SizedBox(height: 12),
        _DailyLineCard(
          sessions: sessions,
          profile: profile,
          sheet: sheet,
          climate: climate,
        ),
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
                  Icon(Icons.local_fire_department_outlined,
                      color: currentStreak > 0
                          ? kBrandIndigo
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
        // Grade de números. Todos os ícones são outline e seguem a regra de
        // cor: índigo para o que descreve o app, `climate.accent` só para o
        // que descreve o estado do usuário agora — que aqui é "sessões hoje".
        // Antes eram quatro cores (âmbar, dois verdes e um roxo) e dois pesos
        // diferentes numa grade 2x2.
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.star_outline,
                iconColor: kBrandIndigo,
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
                iconColor: kBrandIndigo,
                label: 'Sessões totais',
                value: '${sessions.length}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.hourglass_empty,
                iconColor: kBrandIndigo,
                label: 'Minutos focados',
                value: '$totalMinutes',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AuraCard(
          child: Text(
            'Os pontos são contagem: 10 por sessão, 5 por tarefa. O que '
            'realmente evolui é a sua ficha, e cada atributo dela é medida do '
            'que você fez — não prêmio por ter aberto o app.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        ],
        ),
      ),
      ),
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
                          'O Aura não tem login, não tem servidor e não tem '
                          'feed. Tudo fica no armazenamento local do '
                          'aparelho, e some se você desinstalar o app. Uma '
                          'exceção: a frase do dia manda um resumo curto '
                          '(nunca o humor bruto) para gerar uma frase de '
                          'incentivo — sem internet ou sem resposta, ela '
                          'simplesmente não aparece.',
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

/// Índigo da tela de abertura nativa (Android e iOS). Repetido aqui para que a
/// tela de carregamento comece exatamente na cor em que a nativa termina.
const List<Color> kSplashGradient = [Color(0xFF8B84FF), Color(0xFF4A41C7)];

/// Faz o filho entrar subindo e aparecendo, com atraso proporcional a [index].
///
/// O escalonamento sai de um `Interval` na curva, não de um `Future.delayed`:
/// assim a animação continua sendo **uma só**, finita, e o `pumpAndSettle` dos
/// testes de interface termina normalmente.
class EntranceFade extends StatelessWidget {
  final Widget child;
  final int index;

  const EntranceFade({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    // Teto no atraso: com muitos itens, os últimos não podem ficar esperando.
    final atraso = (index * 0.09).clamp(0.0, 0.55);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Interval(atraso, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// A marca do Aura desenhada em widgets, não como imagem.
///
/// Assim ela acompanha qualquer tamanho sem perder nitidez e não custa nenhum
/// asset no APK — o mesmo motivo pelo qual o app inteiro evita imagens.
class AuraMark extends StatelessWidget {
  final double size;

  /// Cor do anel. No fundo índigo da abertura é o âmbar do ícone; na AppBar
  /// recebe a cor da aura, para a marca sinalizar o clima sem trocar de forma.
  final Color ringColor;

  /// Cor dos halos e do núcleo. Branco sobre o índigo da abertura; sobre fundo
  /// claro precisa ser uma cor com contraste, senão a marca some.
  final Color glowColor;
  final Color coreColor;

  const AuraMark({
    super.key,
    this.size = 132,
    this.ringColor = const Color(0xFFFFD54F),
    this.glowColor = Colors.white,
    this.coreColor = Colors.white,
  });

  Widget _halo(double diameter, double alpha) => Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: glowColor.withValues(alpha: alpha),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _halo(size, 0.14),
          _halo(size * 0.78, 0.20),
          _halo(size * 0.60, 0.28),
          Container(
            width: size * 0.53,
            height: size * 0.53,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: ringColor,
                // Piso de 1.4 para a marca não sumir em tamanho de AppBar: a
                // borda proporcional daria menos de 1 px lógico e some.
                width: math.max(1.4, size * 0.022),
              ),
            ),
          ),
          Container(
            width: size * 0.35,
            height: size * 0.35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: coreColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tela mostrada enquanto o app lê o armazenamento local.
///
/// A animação é **finita** de propósito: um pulsar contínuo faria o
/// `pumpAndSettle` dos testes de interface esperar para sempre.
class AuraLoadingScreen extends StatelessWidget {
  const AuraLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: kSplashGradient,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.86 + 0.14 * t, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AuraMark(),
                const SizedBox(height: 24),
                Text(
                  'Aura',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

/// Onde o perfil é preenchido.
///
/// Três campos, todos opcionais, e nenhum deles sai do aparelho — a mesma
/// promessa que vale para as sessões.
class _ProfileSheet extends StatefulWidget {
  final AuraProfile profile;

  const _ProfileSheet({required this.profile});

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profile.name ?? '');
  late final TextEditingController _focus =
      TextEditingController(text: widget.profile.focus ?? '');
  late String _contextId = widget.profile.contextId;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

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
      child: SingleChildScrollView(
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
            const SizedBox(height: 20),
            Text('Seu perfil', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Tudo opcional, e nada disso sai do seu aparelho.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Como te chamar',
                hintText: 'Seu nome ou apelido',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Text('Seu foco principal', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kFocusContexts)
                  ChoiceChip(
                    label: Text(c.name),
                    avatar: Icon(c.icon, size: 18),
                    selected: _contextId == c.id,
                    onSelected: (_) => setState(() => _contextId = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _focus,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'O que você está focando neste período',
                hintText: 'ex.: TCC sobre visão computacional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  AuraProfile(
                    name: _name.text,
                    contextId: _contextId,
                    focus: _focus.text,
                  ),
                ),
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A ficha na tela.
///
/// Cada barra é o `value` do atributo; ao lado dela vai o número real. As duas
/// coisas juntas de propósito: a barra dá a leitura de relance, o número
/// impede que a barra vire uma escala vaga que não quer dizer nada.
class _CharacterSheetCard extends StatelessWidget {
  final CharacterSheet sheet;
  final VoidCallback onEditProfile;

  const _CharacterSheetCard({required this.sheet, required this.onEditProfile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!sheet.hasData) {
      return AuraCard(
        child: Row(
          children: [
            Icon(Icons.shield_outlined,
                color: theme.colorScheme.outline, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Text(sheet.tagline, style: theme.textTheme.bodyMedium),
            ),
            // Sem sessões a ficha está vazia, mas o perfil já pode ser
            // preenchido — sem este botão não haveria como.
            IconButton(
              tooltip: 'Editar perfil',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: kBrandIndigo,
              onPressed: onEditProfile,
            ),
          ],
        ),
      );
    }

    return AuraCard(
      color: kBrandIndigo.withValues(alpha: 0.07),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: kBrandIndigo),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Sua ficha', style: theme.textTheme.titleMedium),
              ),
              // O perfil se edita a partir da própria ficha, não de uma tela
              // escondida: ele é parte dela, e é aqui que ele aparece.
              IconButton(
                tooltip: 'Editar perfil',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: kBrandIndigo,
                onPressed: onEditProfile,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sheet.name != null)
            Text(
              sheet.name!,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          Text(
            sheet.contextName == null
                ? sheet.className
                : '${sheet.className} · ${sheet.contextName}',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: kBrandIndigo,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(sheet.tagline, style: theme.textTheme.bodySmall),
          if (sheet.focus != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.flag_outlined, size: 16, color: kBrandIndigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sheet.focus!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          for (final a in sheet.attributes) ...[
            _AttributeBar(attribute: a),
            const SizedBox(height: 14),
          ],
          Text(
            'Nenhum destes números é ponto de experiência: todos saem das suas '
            'sessões. A ficha muda quando o seu comportamento muda.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AttributeBar extends StatelessWidget {
  final CharacterAttribute attribute;

  const _AttributeBar({required this.attribute});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(attribute.name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Text(
              attribute.display,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: kBrandIndigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // Mesmo padrão das barras comparativas dos insights: animação finita,
        // sem `fl_chart`. Ver ARQUITETURA §8 para o porquê de nada aqui poder
        // repetir indefinidamente.
        SizedBox(
          height: 8,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: kBrandIndigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: attribute.value / 100),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: t.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: kBrandIndigo,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(attribute.note, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// O cartão da frase do dia. Não aparece nada enquanto carrega nem se as
/// duas chamadas falharem — sem spinner, sem mensagem de erro. Importa em
/// especial no dia da apresentação: sem wifi no local, o app precisa
/// continuar parecendo inteiro, não expor uma falha de rede na tela.
class _DailyLineCard extends StatefulWidget {
  final List<StudySession> sessions;
  final AuraProfile profile;
  final CharacterSheet sheet;
  final AuraClimate climate;

  const _DailyLineCard({
    required this.sessions,
    required this.profile,
    required this.sheet,
    required this.climate,
  });

  @override
  State<_DailyLineCard> createState() => _DailyLineCardState();
}

class _DailyLineCardState extends State<_DailyLineCard> {
  String? _text;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hoje = dayOf(DateTime.now()).toIso8601String();
    final salva = await AuraStore.loadDailyLineFor(hoje);
    if (!mounted) return;
    if (salva != null) {
      setState(() => _text = salva);
      return;
    }
    final prompt = buildDailyLinePrompt(
      widget.sessions,
      widget.profile,
      widget.sheet,
      widget.climate,
    );
    final texto = await fetchDailyLine(prompt);
    if (texto == null) return; // sem evidência, sem frase — fica em silêncio
    await AuraStore.saveDailyLine(hoje, texto);
    if (!mounted) return;
    setState(() => _text = texto);
  }

  @override
  Widget build(BuildContext context) {
    if (_text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AuraCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, color: kBrandIndigo, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _text!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
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
