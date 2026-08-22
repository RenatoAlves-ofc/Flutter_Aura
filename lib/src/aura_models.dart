part of '../main.dart';

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
