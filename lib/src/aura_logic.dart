part of '../main.dart';

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
