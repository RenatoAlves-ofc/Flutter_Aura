// Smoke test da interface: garante que o app sobe, semeia o dataset de
// demonstração e que cada aba constrói sem exceção — inclusive as que
// renderizam gráficos, que são as mais frágeis.

import 'package:aura/main.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // AuraCrashReport é estado global: sem limpar, o erro registrado por um
    // teste vaza para o seguinte e o card da tela Sobre aparece onde não devia.
    AuraCrashReport.clear();
    // Sem isto, a aba Resumo dispararia uma chamada de rede de verdade em
    // todo teste que passa por ela. `pumpAndSettle` não espera por uma
    // requisição — o teste terminaria com ela pendente, e o card tentaria um
    // `setState` depois que a árvore já tivesse sido descartada.
    debugDisableDailyLineNetwork = true;
  });

  /// O viewport padrão do teste (800x600) é mais baixo que qualquer celular e
  /// esconde os botões atrás da barra de navegação. Usamos uma tela de
  /// telefone para o teste refletir o uso real.
  Future<void> bootApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 940);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AuraApp());
    await tester.pumpAndSettle();
  }

  testWidgets('o app abre na aba Foco com o método padrão', (tester) async {
    await bootApp(tester);

    expect(find.text('Aura'), findsOneWidget);
    expect(find.text('Método de foco'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
  });

  testWidgets('tocar em Iniciar pede o humor antes de rodar o cronômetro',
      (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();

    expect(find.text('Como você está agora?'), findsOneWidget);
    // O botão de confirmar só libera depois de escolher um humor.
    final confirmar = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirmar'),
    );
    expect(confirmar.onPressed, isNull);

    await tester.tap(find.text('Ótimo'));
    await tester.pumpAndSettle();

    final habilitado = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirmar'),
    );
    expect(habilitado.onPressed, isNotNull);

    await tester.tap(find.text('Confirmar'));
    // pump com duração em vez de pumpAndSettle: com a sessão em andamento o
    // halo do anel fica respirando, e pumpAndSettle esperaria essa animação
    // contínua terminar — ou seja, para sempre.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Cronômetro rodando: o botão vira Pausar.
    expect(find.text('Pausar'), findsOneWidget);
  });

  testWidgets('trocar de aba não cancela uma sessão em andamento',
      (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ótimo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Pausar'), findsOneWidget);

    await tester.tap(find.text('Tarefas'));
    // Mesmo motivo do comentário acima, e é justamente o que o `IndexedStack`
    // mudou: a aba Foco **continua montada** fora da tela, com o halo ainda
    // respirando. `IndexedStack` envolve cada filho em `Visibility.maintain`,
    // que tem `maintainSize: true` e por isso nunca aplica `TickerMode` — o
    // ticker do halo segue vivo mesmo com a aba escondida. Um `pumpAndSettle`
    // aqui espera para sempre: falhava com "pumpAndSettle timed out".
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Pausar'), findsNothing,
        reason: 'a aba Foco fica fora da tela quando Tarefas está selecionada');
    expect(find.textContaining('Nenhuma tarefa ainda'), findsOneWidget);

    await tester.tap(find.text('Foco'));
    await tester.pump();

    expect(find.text('Pausar'), findsOneWidget,
        reason: 'a sessão em andamento precisa sobreviver à troca de aba');
  });

  testWidgets('a aba Descobertas renderiza os gráficos com o dataset demo',
      (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Descobertas').last);
    await tester.pumpAndSettle();

    // Duas ocorrências de propósito: o título da página já dizia "Descobertas"
    // desde sempre — o rótulo da aba é que estava em inglês ("Insights") e foi
    // traduzido para a mesma palavra. Agora as duas coincidem.
    expect(find.text('Descobertas'), findsNWidgets(2));
    expect(find.textContaining('5 de 6 desbloqueadas'), findsOneWidget);

    // Os gráficos ficam abaixo dos cards de insight; a ListView só os constrói
    // ao rolar, então rolar até eles é parte do teste.
    await tester.scrollUntilVisible(
        find.text('Humor inicial × duração do foco'), 300);
    expect(find.byType(BarChart), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Últimos 7 dias'), 300);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('a aba Ficha mostra a aura e a sequência', (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Ficha'));
    await tester.pumpAndSettle();

    expect(find.text('Sua aura hoje'), findsOneWidget);
    expect(find.text('Pontos'), findsOneWidget);
    expect(find.text('Minutos focados'), findsOneWidget);
  });

  testWidgets('o check de humor pergunta o tipo de trabalho', (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();

    expect(find.text('Que tipo de trabalho é este?'), findsOneWidget);
    for (final c in const ['Acadêmico', 'Trabalho', 'Criativo']) {
      expect(find.text(c), findsOneWidget, reason: c);
    }
    // Opcional de propósito: quem só quer começar a focar não precisa digitar.
    expect(find.text('O que você vai fazer? (opcional)'), findsOneWidget);
  });

  testWidgets('o perfil pode ser aberto a partir da própria ficha',
      (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Ficha'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Seu perfil'), findsOneWidget);
    expect(find.text('Tudo opcional, e nada disso sai do seu aparelho.'),
        findsOneWidget);
  });

  testWidgets('a aba Ficha abre pela ficha, com os quatro atributos',
      (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Ficha'));
    await tester.pumpAndSettle();

    expect(find.text('Sua ficha'), findsOneWidget);
    for (final atributo in const [
      'Constância',
      'Recuperação',
      'Amplitude',
      'Profundidade',
    ]) {
      expect(find.text(atributo), findsOneWidget, reason: atributo);
    }
  });

  testWidgets('a descoberta mais exigente aparece trancada, com o quanto falta',
      (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Descobertas'));
    await tester.pumpAndSettle();

    // O ponto desta descoberta é ser vista trancada: sem isso o app não mostra
    // nenhuma progressão para quem abre pela primeira vez.
    await tester.scrollUntilVisible(find.text('Seu limite real'), 300);
    expect(find.text('Seu limite real'), findsOneWidget);
    expect(find.textContaining('Faltam 8'), findsOneWidget);
  });

  testWidgets('a aba Tarefas aceita uma tarefa nova', (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Tarefas'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma tarefa ainda.\n'
        'Tarefas podem ser vinculadas às sessões de foco.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Terminar o slide');
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pumpAndSettle();

    expect(find.text('Terminar o slide'), findsOneWidget);
  });

  testWidgets('a tela Sobre traz a mensagem de privacidade e o botão de demo',
      (tester) async {
    await bootApp(tester);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('Privacidade'), findsOneWidget);
    expect(
      find.textContaining('O Aura não tem login, não tem servidor'),
      findsOneWidget,
    );
    expect(find.text('Remover dados de demonstração'), findsOneWidget);
  });

  testWidgets('trocar para Flowtime muda o cronômetro para contagem crescente',
      (tester) async {
    await bootApp(tester);

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();

    await tester.tap(
        find.text('Flowtime/Flowmodoro · contagem progressiva').last);
    await tester.pumpAndSettle();

    expect(find.text('Flowtime'), findsOneWidget);
    expect(find.text('Sem alvo. Pare quando o foco acabar.'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
  });

  group('animação', () {
    testWidgets('o halo respira durante a sessão e para ao pausar',
        (tester) async {
      await bootApp(tester);

      // Nada animando com o app parado — é o que permite os outros testes
      // usarem pumpAndSettle sem travar.
      expect(tester.hasRunningAnimations, isFalse);

      await tester.tap(find.text('Iniciar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ótimo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.hasRunningAnimations, isTrue,
          reason: 'o halo respira enquanto a sessão roda');

      await tester.tap(find.text('Pausar'));
      await tester.pump();
      // Generoso de propósito: o que ainda anima aqui não é o halo, é o splash
      // de tinta do próprio botão que acabou de ser tocado.
      await tester.pump(const Duration(seconds: 2));

      expect(tester.hasRunningAnimations, isFalse,
          reason: 'sessão pausada tem que parecer parada');
    });

    testWidgets('a tela de carregamento não deixa animação presa',
        (tester) async {
      // Se a abertura tivesse uma animação contínua, todo pumpAndSettle da
      // suíte travaria — este teste é o que trava esse regresso.
      tester.view.physicalSize = const Size(420, 940);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Sem pump extra: o armazenamento é mockado e resolve tão rápido que um
      // segundo quadro já mostraria o app montado.
      await tester.pumpWidget(const AuraApp());
      expect(find.byType(AuraLoadingScreen), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(AuraLoadingScreen), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('sugestão adaptativa', () {
    testWidgets('aparece no check de humor, com o histórico da demo',
        (tester) async {
      await bootApp(tester);

      await tester.tap(find.text('Iniciar'));
      await tester.pumpAndSettle();

      // Antes de escolher o humor não há o que sugerir.
      expect(find.text('Sugestão para este humor'), findsNothing);

      await tester.tap(find.text('Ótimo'));
      await tester.pumpAndSettle();

      expect(find.text('Sugestão para este humor'), findsOneWidget);
      expect(find.textContaining('você sustentou em média'), findsOneWidget);
    });

    testWidgets('aceitar a sugestão troca o método antes de iniciar',
        (tester) async {
      await bootApp(tester);

      await tester.tap(find.text('Iniciar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ótimo'));
      await tester.pumpAndSettle();

      // O rótulo do checkbox nomeia o método sugerido.
      final checkbox = find.byType(CheckboxListTile);
      expect(checkbox, findsOneWidget);
      final label = tester.widget<CheckboxListTile>(checkbox).title! as Text;
      final sugerido = label.data!.replaceAll('Usar ', '');

      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      // Sessão em andamento: ver o comentário sobre o halo que respira.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // O seletor de método passou a mostrar o método aceito.
      expect(find.textContaining(sugerido), findsWidgets);
      expect(find.text('Pausar'), findsOneWidget, reason: 'a sessão começou');
    });

    testWidgets('sem histórico nenhum, não sugere nada', (tester) async {
      // Demo já semeada e removida: o app fica sem sessões de verdade.
      SharedPreferences.setMockInitialValues({
        'demoSeeded': true,
        'sessions': '[]',
      });
      await bootApp(tester);

      await tester.tap(find.text('Iniciar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ótimo'));
      await tester.pumpAndSettle();

      expect(find.text('Sugestão para este humor'), findsNothing);
    });
  });

  // Regressão: um APK que instala mas quebra ao abrir não deixa rastro nenhum —
  // o Android só diz "este app tem um bug". Estes testes garantem que dado
  // corrompido no armazenamento local não derruba mais o app na inicialização.
  group('resiliência da carga inicial', () {
    testWidgets('abre normalmente com sessões corrompidas no armazenamento',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'sessions': 'isto não é json {{{',
      });

      await bootApp(tester);

      // Abriu na interface normal, não numa tela de erro.
      expect(find.text('Método de foco'), findsOneWidget);
      expect(find.textContaining('não conseguiu'), findsNothing);
    });

    testWidgets('abre normalmente com tarefas corrompidas no armazenamento',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'tasks': '[{"sem_os_campos_esperados": true}]',
      });

      await bootApp(tester);

      await tester.tap(find.text('Tarefas'));
      await tester.pumpAndSettle();

      // A lista volta vazia em vez de estourar na desserialização.
      expect(find.textContaining('Nenhuma tarefa ainda'), findsOneWidget);
    });

    testWidgets('descarta o dado ilegível em vez de tropeçar nele de novo',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'sessions': 'lixo',
      });

      await bootApp(tester);

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('sessions');
      // O valor inválido foi removido; o que sobrou é o dataset de demonstração,
      // que já é JSON válido.
      expect(saved, isNot('lixo'));
    });

    testWidgets('registra a corrupção em vez de engolir em silêncio',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'sessions': 'lixo',
      });

      await bootApp(tester);

      // O app abriu, mas o usuário perdeu dados: isso não pode passar batido.
      expect(AuraCrashReport.lastError, isNotNull);
      expect(AuraCrashReport.lastError.toString(), contains('sessions'));
    });

    testWidgets('a tela Sobre mostra o erro registrado', (tester) async {
      SharedPreferences.setMockInitialValues({
        'sessions': 'lixo',
      });

      await bootApp(tester);
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
          find.text('Último erro registrado'), 300);
      expect(find.text('Último erro registrado'), findsOneWidget);
    });

    testWidgets('sem erro nenhum, a tela Sobre não mostra o card de erro',
        (tester) async {
      await bootApp(tester);
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text('Último erro registrado'), findsNothing);
    });
  });

  group('tela de erro', () {
    testWidgets('mostra a mensagem e permite copiar o texto', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AuraErrorScreen(
            title: 'O Aura não conseguiu iniciar',
            error: 'FormatException: teste',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('O Aura não conseguiu iniciar'), findsOneWidget);
      // Selecionável de propósito: é como o erro sai de dentro do celular.
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.textContaining('FormatException: teste'), findsOneWidget);
    });

    // Ela também é usada como ErrorWidget.builder, que pode ser chamado acima do
    // MaterialApp — sem Directionality, MediaQuery nem Material. Se ela
    // dependesse desses ancestrais, lançaria ao desenhar e viraria um laço
    // infinito de erro, escondendo justamente o erro que veio mostrar.
    testWidgets('desenha sem MaterialApp em volta', (tester) async {
      await tester.pumpWidget(
        const AuraErrorScreen(
          title: 'Algo quebrou ao desenhar a tela',
          error: 'StateError: teste sem ancestrais',
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Algo quebrou ao desenhar a tela'), findsOneWidget);
      expect(
        find.textContaining('StateError: teste sem ancestrais'),
        findsOneWidget,
      );
    });

    testWidgets('mostra o topo do stack quando ele existe', (tester) async {
      await tester.pumpWidget(
        AuraErrorScreen(
          title: 'Falhou',
          error: 'erro',
          stack: StackTrace.fromString(
            List.generate(40, (i) => '#$i  frame numero $i').join('\n'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('#0  frame numero 0'), findsOneWidget);
      // Só os primeiros quadros: o resto não caberia na tela de um celular.
      expect(find.textContaining('#39  frame numero 39'), findsNothing);
    });
  });
}
