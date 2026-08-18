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
}
