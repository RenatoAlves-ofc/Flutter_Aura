// Testes da lógica pura do Aura: sequência com perdão, motor de insights,
// clima pessoal e dataset de demonstração.
//
// A camada de UI é verificada rodando o app; o que está aqui é o que precisa
// estar certo mesmo sem ninguém olhando a tela.

import 'package:aura/main.dart';
import 'package:flutter_test/flutter_test.dart';

StudySession session({
  required DateTime date,
  required int duration,
  required int before,
  required int after,
  String method = 'pomodoro_classico',
  String context = kDefaultContextId,
}) =>
    StudySession(
      date: date,
      durationMinutes: duration,
      moodBefore: before,
      moodAfter: after,
      methodId: method,
      contextId: context,
    );

void main() {
  group('sequência com perdão', () {
    const fresh = StreakState(
        streak: 0, tokens: 0, runLength: 0, lastActiveDay: null);

    test('primeira sessão começa a sequência em 1', () {
      final s = applyActivity(fresh, DateTime(2026, 8, 18));
      expect(s.streak, 1);
      expect(s.tokens, 0);
    });

    test('duas sessões no mesmo dia não mudam nada', () {
      final first = applyActivity(fresh, DateTime(2026, 8, 18, 9));
      final second = applyActivity(first, DateTime(2026, 8, 18, 20));
      expect(second.streak, 1);
      expect(identical(first, second), isTrue);
    });

    test('dias consecutivos fazem a sequência crescer', () {
      var s = applyActivity(fresh, DateTime(2026, 8, 16));
      s = applyActivity(s, DateTime(2026, 8, 17));
      expect(s.streak, 2);
    });

    test('três dias seguidos rendem um token de folga', () {
      var s = applyActivity(fresh, DateTime(2026, 8, 16));
      s = applyActivity(s, DateTime(2026, 8, 17));
      expect(s.tokens, 0);
      s = applyActivity(s, DateTime(2026, 8, 18));
      expect(s.streak, 3);
      expect(s.tokens, 1);
      expect(s.tokenEarned, isTrue);
      // O contador reinicia: o próximo token exige mais três dias.
      expect(s.runLength, 0);
    });

    test('faltar exatamente um dia com token guardado não quebra a sequência',
        () {
      var s = applyActivity(fresh, DateTime(2026, 8, 16));
      s = applyActivity(s, DateTime(2026, 8, 17));
      s = applyActivity(s, DateTime(2026, 8, 18)); // ganha 1 token
      expect(s.tokens, 1);

      // 19/08 sem sessão nenhuma; volta em 20/08.
      s = applyActivity(s, DateTime(2026, 8, 20));
      expect(s.streak, 4, reason: 'a sequência sobrevive ao dia perdido');
      expect(s.tokens, 0, reason: 'o token foi gasto no perdão');
      expect(s.tokenSpent, isTrue);
    });

    test('faltar um dia sem token reinicia a sequência', () {
      var s = applyActivity(fresh, DateTime(2026, 8, 16));
      s = applyActivity(s, DateTime(2026, 8, 17)); // streak 2, sem token ainda
      expect(s.tokens, 0);

      s = applyActivity(s, DateTime(2026, 8, 19));
      expect(s.streak, 1);
    });

    test('faltar mais de um dia quebra mesmo com token', () {
      var s = applyActivity(fresh, DateTime(2026, 8, 14));
      s = applyActivity(s, DateTime(2026, 8, 15));
      s = applyActivity(s, DateTime(2026, 8, 16)); // 1 token
      expect(s.tokens, 1);

      s = applyActivity(s, DateTime(2026, 8, 20)); // 3 dias perdidos
      expect(s.streak, 1);
      expect(s.tokens, 1, reason: 'não gasta token num buraco grande demais');
    });

    test('os tokens têm teto', () {
      var s = applyActivity(fresh, DateTime(2026, 8, 1));
      for (var day = 2; day <= 31; day++) {
        s = applyActivity(s, DateTime(2026, 8, day));
      }
      expect(s.tokens, lessThanOrEqualTo(StreakState.maxTokens));
      expect(s.streak, 31);
    });
  });

  group('sequência mostrada na tela', () {
    test('some quando o usuário passou dos dias de graça', () {
      const s = StreakState(
          streak: 9, tokens: 0, runLength: 1, lastActiveDay: '2026-08-10');
      expect(effectiveStreak(s, DateTime(2026, 8, 18)), 0);
    });

    test('continua de pé no dia seguinte', () {
      const s = StreakState(
          streak: 9, tokens: 0, runLength: 1, lastActiveDay: '2026-08-17');
      expect(effectiveStreak(s, DateTime(2026, 8, 18)), 9);
    });

    test('ainda é salvável com um dia perdido e um token na mão', () {
      const s = StreakState(
          streak: 9, tokens: 1, runLength: 1, lastActiveDay: '2026-08-16');
      expect(effectiveStreak(s, DateTime(2026, 8, 18)), 9);
    });
  });

  group('motor de insights', () {
    test('tudo fica bloqueado sem dados', () {
      final insights = buildInsights([]);
      expect(insights.length, 6);
      expect(insights.every((i) => !i.unlocked), isTrue);
      expect(insights.first.missing, greaterThan(0));
    });

    test('humor × duração expõe as duas médias para serem mostradas', () {
      final base = DateTime(2026, 8, 10);
      final sessions = [
        session(date: base, duration: 40, before: 5, after: 5),
        session(date: base, duration: 40, before: 5, after: 4),
        session(date: base, duration: 40, before: 4, after: 4),
        session(date: base, duration: 10, before: 1, after: 2),
        session(date: base, duration: 10, before: 2, after: 2),
      ];

      final c = buildInsights(sessions).first.comparison;
      expect(c, isNotNull, reason: 'a tese do app precisa poder ser desenhada');
      expect(c!.highValue, greaterThan(c.lowValue));
      expect(c.highValue, closeTo(40, 0.01));
      expect(c.lowValue, closeTo(10, 0.01));
      expect(c.unit, 'min');
      // 10/40 = 0.25, acima do piso de 0.08.
      expect(c.lowRatio, closeTo(0.25, 0.001));
    });

    test('a barra menor nunca some, mesmo com diferença extrema', () {
      const c = InsightComparison(
        highLabel: 'alto',
        highValue: 100,
        lowLabel: 'baixo',
        lowValue: 1,
        unit: 'min',
      );
      // Sem piso seria 0.01 — uma barra de largura invisível, que apagaria da
      // tela justamente a comparação que ela existe para mostrar.
      expect(c.lowRatio, 0.08);
    });

    test('insight bloqueado não carrega comparação para desenhar', () {
      expect(buildInsights([]).first.comparison, isNull);
    });

    test('humor × duração desbloqueia e aponta a direção certa', () {
      final base = DateTime(2026, 8, 10);
      final sessions = [
        session(date: base, duration: 50, before: 5, after: 5),
        session(date: base, duration: 52, before: 5, after: 4),
        session(date: base, duration: 48, before: 4, after: 5),
        session(date: base, duration: 15, before: 1, after: 2),
        session(date: base, duration: 18, before: 2, after: 2),
        session(date: base, duration: 16, before: 1, after: 1),
      ];

      final insight =
          buildInsights(sessions).firstWhere((i) => i.id == 'mood_duration');
      expect(insight.unlocked, isTrue);
      expect(insight.body, contains('começa animado'));
      expect(insight.body, contains('começa pra baixo'));
    });

    test('humor antes × depois reconhece melhora', () {
      final base = DateTime(2026, 8, 10);
      final sessions = List.generate(
        6,
        (i) => session(date: base, duration: 25, before: 2, after: 4),
      );

      final insight =
          buildInsights(sessions).firstWhere((i) => i.id == 'mood_delta');
      expect(insight.unlocked, isTrue);
      expect(insight.headline, contains('+2'));
      expect(insight.body, contains('6 de 6'));
    });

    test('dia da semana exige 7 sessões', () {
      final base = DateTime(2026, 8, 10);
      final six = List.generate(
          6, (i) => session(date: base, duration: 25, before: 3, after: 3));
      expect(
        buildInsights(six).firstWhere((i) => i.id == 'weekday').unlocked,
        isFalse,
      );

      final seven = [
        ...six,
        session(date: base, duration: 25, before: 3, after: 3),
      ];
      expect(
        buildInsights(seven).firstWhere((i) => i.id == 'weekday').unlocked,
        isTrue,
      );
    });

    test('método × desempenho não elege vencedor com uma única tentativa', () {
      final base = DateTime(2026, 8, 10);
      // Seis sessões, mas o segundo método aparece só uma vez.
      final sessions = [
        ...List.generate(
            5,
            (i) => session(
                date: base, duration: 25, before: 3, after: 3,
                method: 'pomodoro_classico')),
        session(
            date: base,
            duration: 90,
            before: 5,
            after: 5,
            method: 'ciclo_ultradiano'),
      ];

      expect(
        buildInsights(sessions).firstWhere((i) => i.id == 'method').unlocked,
        isFalse,
      );
    });

    test('método × desempenho desbloqueia com dois métodos repetidos', () {
      final base = DateTime(2026, 8, 10);
      final sessions = [
        ...List.generate(
            3,
            (i) => session(
                date: base, duration: 20, before: 2, after: 2,
                method: 'sessao_curta')),
        ...List.generate(
            3,
            (i) => session(
                date: base, duration: 50, before: 4, after: 5,
                method: 'pomodoro_longo')),
      ];

      final insight =
          buildInsights(sessions).firstWhere((i) => i.id == 'method');
      expect(insight.unlocked, isTrue);
      expect(insight.headline, 'Pomodoro Longo');
    });
  });

  group('sugestão adaptativa de duração', () {
    final base = DateTime(2026, 8, 10);

    test('não sugere nada sem histórico', () {
      expect(suggestMethodForMood([], 3), isNull);
    });

    test('não sugere com base numa única tentativa', () {
      // Uma sessão só não é evidência — o mesmo critério do insight de método.
      final sessions = [
        session(
            date: base,
            duration: 90,
            before: 5,
            after: 5,
            method: 'ciclo_ultradiano'),
      ];
      expect(suggestMethodForMood(sessions, 5), isNull);
    });

    test('sugere o método que termina melhor naquela faixa de humor', () {
      final sessions = [
        // Humor alto: o Pomodoro Longo é o que fecha melhor.
        ...List.generate(
            3,
            (i) => session(
                date: base, duration: 50, before: 4, after: 5,
                method: 'pomodoro_longo')),
        ...List.generate(
            3,
            (i) => session(
                date: base, duration: 40, before: 4, after: 3,
                method: '40_20')),
      ];

      final s = suggestMethodForMood(sessions, 4);
      expect(s, isNotNull);
      expect(s!.method.id, 'pomodoro_longo');
      expect(s.avgDuration, 50);
      expect(s.avgMoodAfter, 5);
      expect(s.sampleSize, 3);
    });

    test('olha só a faixa de humor pedida, não o histórico inteiro', () {
      final sessions = [
        // Humor baixo: micro-sessões funcionam.
        ...List.generate(
            2,
            (i) => session(
                date: base, duration: 15, before: 1, after: 3,
                method: 'micro_sessao')),
        // Humor alto: sessões longas funcionam — não deve vazar para a faixa baixa.
        ...List.generate(
            2,
            (i) => session(
                date: base, duration: 90, before: 5, after: 5,
                method: 'ciclo_ultradiano')),
      ];

      expect(suggestMethodForMood(sessions, 2)!.method.id, 'micro_sessao');
      expect(suggestMethodForMood(sessions, 5)!.method.id, 'ciclo_ultradiano');
    });

    test('empate no humor final fica com quem sustentou mais tempo', () {
      final sessions = [
        ...List.generate(
            2,
            (i) => session(
                date: base, duration: 20, before: 3, after: 4,
                method: 'sessao_curta')),
        ...List.generate(
            2,
            (i) => session(
                date: base, duration: 50, before: 3, after: 4,
                method: 'pomodoro_longo')),
      ];

      expect(suggestMethodForMood(sessions, 3)!.method.id, 'pomodoro_longo');
    });

    test('nunca sugere Flowtime nem Personalizado', () {
      // Um não tem duração alvo e o outro depende do que o usuário configurou:
      // recomendá-los por duração média prometeria um número que a sessão não
      // cumpre.
      final sessions = [
        ...List.generate(
            4,
            (i) => session(
                date: base, duration: 70, before: 4, after: 5,
                method: 'flowtime')),
        ...List.generate(
            4,
            (i) => session(
                date: base, duration: 30, before: 4, after: 5,
                method: 'personalizado')),
      ];

      expect(suggestMethodForMood(sessions, 4), isNull);
    });

    test('trocar de humor pede uma sugestão diferente', () {
      final sessions = [
        ...List.generate(
            2,
            (i) => session(
                date: base, duration: 15, before: 1, after: 3,
                method: 'micro_sessao')),
        ...List.generate(
            2,
            (i) => session(
                date: base, duration: 50, before: 5, after: 5,
                method: 'pomodoro_longo')),
      ];

      final baixo = suggestMethodForMood(sessions, 1)!.method.id;
      final alto = suggestMethodForMood(sessions, 5)!.method.id;
      expect(baixo, isNot(alto));
    });

    test('não contradiz o insight de método no dataset de demonstração', () {
      // Os dois usam o mesmo critério; divergir confundiria o usuário.
      final demo = buildDemoSessions();
      for (var mood = 1; mood <= 5; mood++) {
        final s = suggestMethodForMood(demo, mood);
        if (s == null) continue;
        expect(s.sampleSize, greaterThanOrEqualTo(2));
        expect(s.avgDuration, greaterThan(0));
      }
    });
  });

  group('contexto de foco', () {
    test('sessão gravada por versão anterior continua abrindo', () {
      // Este é o risco real desta mudança: quem já tem o app instalado tem
      // sessões no formato antigo, sem contextId e sem note. Se o fromJson
      // estourasse aqui, o app não abriria mais para essas pessoas.
      final antiga = StudySession.fromJson({
        'date': '2026-08-10T14:30:00.000',
        'duration': 25,
        'moodBefore': 3,
        'moodAfter': 4,
        'linkedTaskId': null,
        'methodId': 'pomodoro_classico',
        'isDemo': false,
      });

      expect(antiga.contextId, kDefaultContextId);
      expect(antiga.note, isNull);
      expect(antiga.durationMinutes, 25);
    });

    test('contexto e nota sobrevivem à ida e volta do JSON', () {
      final s = StudySession(
        date: DateTime(2026, 8, 10, 14, 30),
        durationMinutes: 50,
        moodBefore: 4,
        moodAfter: 5,
        methodId: 'pomodoro_longo',
        contextId: 'academico',
        note: 'Cap. 4 de Cálculo',
      );
      final volta = StudySession.fromJson(s.toJson());
      expect(volta.contextId, 'academico');
      expect(volta.note, 'Cap. 4 de Cálculo');
    });

    test('id de contexto desconhecido cai em Geral em vez de estourar', () {
      expect(contextById('inexistente').id, kDefaultContextId);
      expect(contextById('academico').name, 'Acadêmico');
    });

    test('não compara tipos de trabalho sem repetição suficiente', () {
      final base = DateTime(2026, 8, 10);
      // 8 sessões, mas um dos contextos aparece só duas vezes.
      final sessions = [
        for (var i = 0; i < 6; i++)
          session(date: base, duration: 40, before: 4, after: 4, context: 'academico'),
        for (var i = 0; i < 2; i++)
          session(date: base, duration: 15, before: 2, after: 2, context: 'trabalho'),
      ];
      final insight = buildInsights(sessions).firstWhere((i) => i.id == 'context');
      expect(insight.unlocked, isFalse,
          reason: 'dois pontos não descrevem um tipo de trabalho');
    });

    test('aponta o tipo de trabalho que sustenta mais tempo', () {
      final base = DateTime(2026, 8, 10);
      final sessions = [
        for (var i = 0; i < 4; i++)
          session(date: base, duration: 50, before: 4, after: 5, context: 'academico'),
        for (var i = 0; i < 4; i++)
          session(date: base, duration: 15, before: 3, after: 2, context: 'trabalho'),
      ];
      final insight = buildInsights(sessions).firstWhere((i) => i.id == 'context');

      expect(insight.unlocked, isTrue);
      expect(insight.headline, 'Acadêmico');
      expect(insight.comparison, isNotNull);
      expect(insight.comparison!.highValue, closeTo(50, 0.01));
      expect(insight.comparison!.lowValue, closeTo(15, 0.01));
    });

    test('a demonstração carrega a correlação entre tipo de trabalho e humor',
        () {
      final insight =
          buildInsights(buildDemoSessions()).firstWhere((i) => i.id == 'context');
      expect(insight.unlocked, isTrue,
          reason: 'sem isto o diferencial não aparece na apresentação');
    });
  });

  group('perfil', () {
    test('a ficha funciona anônima, que é como o app abre', () {
      final f = buildCharacterSheet(buildDemoSessions());
      expect(f.name, isNull);
      expect(f.focus, isNull);
      expect(f.contextName, isNull, reason: 'Geral não vira rótulo');
      expect(f.className, isNotEmpty);
    });

    test('nome, contexto e foco chegam à ficha', () {
      final f = buildCharacterSheet(
        buildDemoSessions(),
        profile: const AuraProfile(
          name: '  Renato  ',
          contextId: 'academico',
          focus: 'TCC sobre visão computacional',
        ),
      );
      expect(f.name, 'Renato', reason: 'espaço em branco é aparado');
      expect(f.contextName, 'Acadêmico');
      expect(f.focus, 'TCC sobre visão computacional');
    });

    test('campo em branco conta como ausente, não como texto vazio', () {
      final f = buildCharacterSheet(
        buildDemoSessions(),
        profile: const AuraProfile(name: '   ', focus: ''),
      );
      expect(f.name, isNull);
      expect(f.focus, isNull);
    });
  });

  group('ficha de personagem', () {
    test('sem sessões, a ficha diz isso em vez de mostrar zeros', () {
      final f = buildCharacterSheet([]);
      expect(f.hasData, isFalse);
      expect(f.attributes, isEmpty,
          reason: 'quatro barras zeradas mentem sobre não haver dado nenhum');
    });

    test('a classe sai do método que a pessoa de fato usa', () {
      final base = DateTime(2026, 8, 10);
      CharacterSheet comMetodo(String id, int duracao) => buildCharacterSheet([
            session(date: base, duration: duracao, before: 4, after: 4, method: id),
            session(date: base, duration: duracao, before: 4, after: 4, method: id),
            session(date: base, duration: duracao, before: 4, after: 4, method: id),
          ]);

      expect(comMetodo('ciclo_ultradiano', 90).className, 'Maratonista');
      expect(comMetodo('micro_sessao', 15).className, 'Sprinter');
      expect(comMetodo('pomodoro_classico', 25).className, 'Ritmista');
      expect(comMetodo('flowtime', 42).className, 'Explorador');
    });

    test('todo atributo cabe na barra, de 0 a 100', () {
      final f = buildCharacterSheet(buildDemoSessions());
      expect(f.attributes.length, 4);
      for (final a in f.attributes) {
        expect(a.value, inInclusiveRange(0, 100), reason: a.name);
        expect(a.display, isNotEmpty, reason: a.name);
      }
    });

    test('o valor extremo satura em 100 em vez de estourar a barra', () {
      final base = DateTime(2026, 8, 10);
      final f = buildCharacterSheet([
        // 240 min é muito acima do teto de 90 usado na normalização.
        session(date: base, duration: 240, before: 4, after: 5),
      ]);
      final profundidade =
          f.attributes.firstWhere((a) => a.name == 'Profundidade');
      expect(profundidade.value, 100);
      expect(profundidade.display, '240 min',
          reason: 'a barra satura, mas o número real continua sendo dito');
    });

    test('recuperação conta as sessões que terminam melhor do que começaram',
        () {
      final base = DateTime(2026, 8, 10);
      final f = buildCharacterSheet([
        session(date: base, duration: 25, before: 2, after: 4),
        session(date: base, duration: 25, before: 3, after: 5),
        session(date: base, duration: 25, before: 4, after: 4),
        session(date: base, duration: 25, before: 4, after: 2),
      ]);
      // 2 de 4 melhoraram.
      expect(f.attributes.firstWhere((a) => a.name == 'Recuperação').value, 50);
    });
  });

  group('clima pessoal', () {
    final base = DateTime(2026, 8, 10);

    test('sem sessões a aura fica neutra', () {
      expect(resolveClimate([]).id, 'neutro');
    });

    test('sessões terminando muito bem deixam a aura radiante', () {
      final sessions = List.generate(
          3, (i) => session(date: base.add(Duration(days: i)),
              duration: 50, before: 4, after: 5));
      expect(resolveClimate(sessions).id, 'radiante');
    });

    test('sessões terminando mal deixam a aura recolhida', () {
      final sessions = List.generate(
          3, (i) => session(date: base.add(Duration(days: i)),
              duration: 15, before: 2, after: 1));
      expect(resolveClimate(sessions).id, 'recolhido');
    });

    test('a aura olha as sessões recentes, não a média histórica', () {
      final sessions = [
        // Passado ruim...
        ...List.generate(
            10,
            (i) => session(
                date: base.add(Duration(days: i)),
                duration: 15,
                before: 1,
                after: 1)),
        // ...mas as três últimas foram ótimas.
        ...List.generate(
            3,
            (i) => session(
                date: base.add(Duration(days: 20 + i)),
                duration: 50,
                before: 4,
                after: 5)),
      ];
      expect(resolveClimate(sessions).id, 'radiante');
    });
  });

  group('dataset de demonstração', () {
    final demo = buildDemoSessions();

    test('abre cinco descobertas e deixa uma trancada, de propósito', () {
      final insights = buildInsights(demo);
      expect(demo.length, 22, reason: 'valor citado no README');

      final trancadas = insights.where((i) => !i.unlocked).toList();

      // As cinco primeiras abrem: nenhuma tela pode aparecer vazia na
      // apresentação.
      expect(insights.where((i) => i.unlocked).length, 5);

      // E exatamente uma fica trancada — sem isso o app não teria nada
      // apontando para frente, que era o defeito que ela veio corrigir.
      expect(trancadas.length, 1);
      expect(trancadas.single.id, 'duration_ceiling');
      expect(trancadas.single.missing, 8,
          reason: '30 exigidas menos as 22 da demonstração');
    });

    test('vem todo marcado como demonstração, para poder ser removido', () {
      expect(demo.every((s) => s.isDemo), isTrue);
    });

    test('carrega a correlação que o app promete descobrir', () {
      int total(Iterable<StudySession> list) =>
          list.map((s) => s.durationMinutes).fold(0, (a, b) => a + b);

      final low = demo.where((s) => s.moodBefore <= 2);
      final high = demo.where((s) => s.moodBefore >= 4);
      final avgLow = total(low) / low.length;
      final avgHigh = total(high) / high.length;

      expect(avgHigh, greaterThan(avgLow),
          reason: 'quem começa melhor sustenta sessões mais longas');
    });

    test('é determinístico, para a apresentação ser sempre igual', () {
      final again = buildDemoSessions();
      expect(again.length, demo.length);
      for (var i = 0; i < demo.length; i++) {
        expect(again[i].durationMinutes, demo[i].durationMinutes);
        expect(again[i].moodBefore, demo[i].moodBefore);
        expect(again[i].methodId, demo[i].methodId);
      }
    });

    test('usa vários métodos, senão o insight de método nunca abre', () {
      expect(demo.map((s) => s.methodId).toSet().length,
          greaterThanOrEqualTo(2));
    });

    test('inclui sessões de hoje', () {
      // Sem isto o app abre dizendo "0 sessões hoje" e "0 dias de sequência"
      // ao lado do total de sessões, e o gráfico da semana termina em zero.
      final hoje = dayOf(DateTime.now());
      expect(
        demo.any((s) => dayOf(s.date).isAtSameMomentAs(hoje)),
        isTrue,
      );
    });

    test('mostra o humor melhorando na maioria das sessões', () {
      // O insight "focar muda seu humor" é uma das quatro descobertas: se o
      // dataset não sustentar a afirmação, o card abre dizendo quase nada.
      final melhoraram =
          demo.where((s) => s.moodAfter > s.moodBefore).length;
      expect(melhoraram / demo.length, greaterThan(0.6));

      final delta = demo
              .map((s) => s.moodAfter - s.moodBefore)
              .reduce((a, b) => a + b) /
          demo.length;
      expect(delta, greaterThan(0.5));
    });
  });

  group('estado derivado das sessões', () {
    test('a sequência do dataset de demonstração está viva hoje', () {
      final demo = buildDemoSessions();
      final streak = streakFromSessions(demo);

      // O Resumo não pode abrir com "0 dias de sequência" ao lado de
      // "22 sessões totais".
      expect(effectiveStreak(streak, DateTime.now()), greaterThan(0));
    });

    test('os pontos acompanham as sessões', () {
      final demo = buildDemoSessions();
      expect(pointsFromSessions(demo), demo.length * 10);
    });

    test('sem sessões, não há sequência nem pontos', () {
      expect(streakFromSessions([]).streak, 0);
      expect(streakFromSessions([]).lastActiveDay, isNull);
      expect(pointsFromSessions([]), 0);
    });

    test('reconstrói a sequência aplicando a mesma regra de dia a dia', () {
      final base = DateTime(2026, 8, 10);
      final sessions = [
        // Três dias seguidos, e duas sessões num mesmo dia não contam duas vezes.
        session(date: base, duration: 25, before: 3, after: 4),
        session(date: base.add(const Duration(hours: 6)),
            duration: 25, before: 3, after: 4),
        session(
            date: base.add(const Duration(days: 1)),
            duration: 25,
            before: 3,
            after: 4),
        session(
            date: base.add(const Duration(days: 2)),
            duration: 25,
            before: 3,
            after: 4),
      ];

      final streak = streakFromSessions(sessions);
      expect(streak.streak, 3);
      expect(streak.tokens, 1, reason: 'três dias seguidos rendem uma folga');
    });
  });

  group('serialização', () {
    test('a sessão sobrevive à ida e volta do JSON', () {
      final original = StudySession(
        date: DateTime(2026, 8, 18, 14, 30),
        durationMinutes: 52,
        moodBefore: 3,
        moodAfter: 5,
        linkedTaskId: 'task_1',
        methodId: '52_17',
      );
      final copy = StudySession.fromJson(original.toJson());

      expect(copy.date, original.date);
      expect(copy.durationMinutes, 52);
      expect(copy.moodBefore, 3);
      expect(copy.moodAfter, 5);
      expect(copy.linkedTaskId, 'task_1');
      expect(copy.methodId, '52_17');
      expect(copy.isDemo, isFalse);
    });

    test('sessão antiga sem methodId cai no Pomodoro Clássico', () {
      final copy = StudySession.fromJson({
        'date': '2026-08-18T14:30:00.000',
        'duration': 25,
        'moodBefore': 3,
        'moodAfter': 4,
        'linkedTaskId': null,
      });
      expect(copy.methodId, 'pomodoro_classico');
    });

    test('tarefa salva antes do campo id ganha um id na leitura', () {
      final task = TaskItem.fromJson({
        'title': 'Estudar Flutter',
        'priority': 'Alta',
        'done': false,
      });
      expect(task.id, isNotEmpty);
      expect(task.title, 'Estudar Flutter');
    });
  });

  group('métodos de foco', () {
    test('são os 11 prometidos', () {
      expect(focusMethods.length, 11);
    });

    test('só o Flowtime não tem duração fixa', () {
      final semDuracao =
          focusMethods.where((m) => m.focusMinutes == null).toList();
      expect(semDuracao.map((m) => m.id).toSet(),
          {'flowtime', 'personalizado'});
      expect(focusMethods.where((m) => m.isFlowtime).length, 1);
      expect(focusMethods.where((m) => m.isCustom).length, 1);
    });

    test('um id desconhecido cai no default em vez de estourar', () {
      expect(methodById('metodo_que_nao_existe').id, 'pomodoro_classico');
    });
  });
}
