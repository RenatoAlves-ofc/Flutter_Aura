// Aura — um Pomodoro que aprende com você.
//
// Em vez de só contar minutos, o Aura cruza como você está se sentindo com
// quanto tempo você realmente consegue manter o foco, e devolve isso como
// descobertas pessoais. Tudo local, sem login, sem feed.
//
// Entrada principal. A lógica foi separada em parts para reduzir o arquivo sem alterar a API pública.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:percent_indicator/percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';


part 'src/aura_models.dart';
part 'src/aura_store.dart';
part 'src/aura_logic.dart';

/// Altura mínima dos sheets, como fração da tela.
///
/// Sem isto os sheets abriam **baixo demais**: com `isScrollControlled: true`
/// eles *podem* ocupar a tela toda, mas só crescem até o tamanho do conteúdo —
/// e o conteúdo é uma `Column(mainAxisSize: min)`. O resultado era um sheet
/// encolhido, colado no rodapé, com a metade de cima da tela vazia.
///
/// Quem passa disto continua rolando normalmente: o conteúdo já vive dentro de
/// um `SingleChildScrollView`.
const double kSheetMinHeightFactor = 0.58;

/// Restrição de altura mínima para `showModalBottomSheet`, calculada da tela.
BoxConstraints sheetConstraints(BuildContext context) => BoxConstraints(
      minHeight: MediaQuery.of(context).size.height * kSheetMinHeightFactor,
    );

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
      useSafeArea: true,
      constraints: sheetConstraints(context),
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
        // As abas ficam montadas para preservar o estado interno delas. Isso é
        // crítico para a aba Foco: trocar para Tarefas/Insights não pode cancelar
        // o Timer nem esquecer humor inicial, tarefa vinculada, contexto e nota da
        // sessão em andamento.
        body: SafeArea(
          top: false,
          child: IndexedStack(
            index: _index,
            children: pages,
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
                icon: Icon(Icons.auto_graph_outlined), label: 'Descobertas'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Ficha'),
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
      useSafeArea: true,
      constraints: sheetConstraints(context),
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
      useSafeArea: true,
      constraints: sheetConstraints(context),
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
                              // Índigo, não a cor do humor. A altura da barra
                              // representa a DURAÇÃO, não o estado de entrada —
                              // quem diz o estado é o eixo, embaixo, onde as
                              // faces seguem coloridas porque ali a cor É a
                              // informação (ARQUITETURA.md §7). Pintar a barra
                              // por humor codificava a mesma coisa duas vezes,
                              // e era só isso que punha verde ao lado do roxo.
                              color: kBrandIndigo,
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
