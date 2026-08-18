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
    await tester.pumpAndSettle();

    // Cronômetro rodando: o botão vira Pausar.
    expect(find.text('Pausar'), findsOneWidget);
  });

  testWidgets('a aba Insights renderiza os gráficos com o dataset demo',
      (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('Descobertas'), findsOneWidget);
    expect(find.textContaining('4 de 4 desbloqueadas'), findsOneWidget);

    // Os gráficos ficam abaixo dos cards de insight; a ListView só os constrói
    // ao rolar, então rolar até eles é parte do teste.
    await tester.scrollUntilVisible(
        find.text('Humor inicial × duração do foco'), 300);
    expect(find.byType(BarChart), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Últimos 7 dias'), 300);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('a aba Resumo mostra a aura e a sequência', (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Resumo'));
    await tester.pumpAndSettle();

    expect(find.text('Sua aura hoje'), findsOneWidget);
    expect(find.text('Pontos'), findsOneWidget);
    expect(find.text('Minutos focados'), findsOneWidget);
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
      find.textContaining('Seus dados de humor não saem do seu celular'),
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
