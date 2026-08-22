// Captura os prints de docs/img/ a partir do build web.
//
// ⚠️ NÃO FUNCIONA EM CONTAINER HEADLESS SEM GPU — leia antes de rodar.
//
// O que foi verificado em 22/08, neste container:
//
//   1. `flutter build web --release` sozinho não abre: o carregador busca o
//      CanvasKit em `gstatic.com`, que o proxy bloqueia
//      (`ERR_TUNNEL_CONNECTION_FAILED`). A correção é buildar com
//      **`--no-web-resources-cdn`**, que ativa `useLocalCanvasKit: true` e faz
//      o app usar a cópia em `build/web/canvaskit/`.
//
//   2. Com isso todos os recursos passam a carregar (200 em canvaskit.wasm,
//      main.dart.js, fontes) e o motor Flutter sobe — os elementos `flt-*`
//      aparecem no DOM. **Mas nenhuma `flutter-view` é criada e a tela sai
//      branca.** O CanvasKit não consegue contexto WebGL no headless, e falha
//      em silêncio: sem erro no console, sem requisição falhando.
//
//   3. Tentado também com `--use-gl=angle --use-angle=swiftshader
//      --enable-unsafe-swiftshader`: mesmo resultado.
//
// Ou seja: **este script gera PNGs em branco neste ambiente**, e por isso ele
// escreve num diretório temporário, nunca em `docs/img/`. Já quase destruiu os
// prints bons uma vez.
//
// Onde ele deve funcionar: máquina com GPU/navegador real. Alternativa melhor
// para a entrega — tirar os prints **no próprio celular**, com o APK instalado,
// que é evidência mais forte que um build web.
//
// Uso:
//   flutter build web --release --no-web-resources-cdn
//   (servir build/web em :8899)
//   node tool/captura_prints.mjs
//   # confira os PNGs em /tmp/aura-prints/ e só então copie para docs/img/

import { chromium } from 'playwright';
import { mkdirSync } from 'fs';

const BASE = process.env.AURA_URL || 'http://127.0.0.1:8899';
// Nunca escreve direto em docs/img/: um print em branco passa despercebido.
const OUT = process.env.AURA_OUT || '/tmp/aura-prints';
mkdirSync(OUT, { recursive: true });

const shot = async (page, nome) => {
  await page.screenshot({ path: `${OUT}/${nome}.png` });
  console.log(`  ✓ ${nome}.png`);
};

// O Flutter web desenha em canvas: esperar por seletor não basta e o texto não
// existe no DOM. A espera é por tempo, e os cliques são por coordenada.
const settle = (page, ms = 1200) => page.waitForTimeout(ms);

const run = async () => {
  const browser = await chromium.launch({
    executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const context = await browser.newContext({
    viewport: { width: 420, height: 940 },
    deviceScaleFactor: 2,
    // O service worker guarda o build anterior e mascara o que mudou.
    serviceWorkers: 'block',
  });
  const page = await context.newPage();

  console.log(`Abrindo ${BASE} ...`);
  await page.goto(BASE, { waitUntil: 'domcontentloaded' });
  await settle(page, 6000);

  // Trava cedo se a tela estiver em branco, em vez de gerar 9 PNGs inúteis.
  const montou = await page.evaluate(
    () => document.querySelectorAll('flutter-view, flt-glass-pane').length,
  );
  if (montou === 0) {
    console.error(
      '\n✗ O app não montou (nenhuma flutter-view). Provavelmente é o\n' +
        '  CanvasKit sem WebGL no headless — ver o comentário no topo deste\n' +
        '  arquivo. Abortando para não gerar prints em branco.',
    );
    await browser.close();
    process.exit(1);
  }

  await shot(page, '01-foco');

  // --- Check de humor ---
  // Coordenadas precisam ser reconferidas a cada mudança de layout. Cada print
  // é para ser OLHADO, não só gerado.
  await page.mouse.click(210, 762);
  await settle(page);
  await shot(page, '02-humor');

  await page.mouse.click(355, 470);
  await settle(page);
  await shot(page, '03-humor-sugestao');

  await page.keyboard.press('Escape');
  await settle(page, 900);

  // --- Abas: Foco · Tarefas · Descobertas · Ficha ---
  const abas = { tarefas: 157, descobertas: 262, ficha: 367 };
  const yAba = 905;

  await page.mouse.click(abas.tarefas, yAba);
  await settle(page);
  await shot(page, '04-tarefas');

  await page.mouse.click(abas.descobertas, yAba);
  await settle(page);
  await shot(page, '05-insights');

  await page.mouse.wheel(0, 2200);
  await settle(page);
  await shot(page, '06-graficos');

  await page.mouse.click(abas.ficha, yAba);
  await settle(page);
  await shot(page, '07-resumo');

  await page.mouse.click(390, 60);
  await settle(page);
  await shot(page, '08-sobre');

  await browser.close();
  console.log(`\nPronto em ${OUT}. CONFIRA CADA UM antes de copiar para docs/img/.`);
};

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
