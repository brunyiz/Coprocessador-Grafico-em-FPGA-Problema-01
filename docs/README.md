# Coprocessador-Grafico-em-FPGA-Problema-01

Núcleo de coprocessador gráfico dedicado implementado em Verilog na plataforma Terasic DE1-SoC (Intel/Altera Cyclone V), capaz de gerar de forma autônoma um sinal de vídeo VGA de 640×480 @ ~60 Hz a partir de uma resolução lógica interna de 320×240, compondo três camadas gráficas independentes: background (tilemap), sprites e polígonos rasterizados.

Projeto desenvolvido para a disciplina **TEC499 — Sistemas Digitais** (Problema 01, semestre 2026.2), sob orientação do professor Angelo Duarte.

---

## Sumário

- [Requisitos](#requisitos)
- [Arquitetura](#arquitetura)
- [Hardware e Ferramentas](#hardware-e-ferramentas)
- [Estrutura do Repositório](#estrutura-do-repositório)
- [Módulos do Sistema](#módulos-do-sistema)
- [Modos de Operação](#modos-de-operação)
- [Memórias](#memórias)
- [Pinagem](#pinagem)
- [Compilação e Programação](#compilação-e-programação)
- [Testes](#testes)
- [Resultados e Análise](#resultados-e-análise)
- [Limitações e Trabalhos Futuros](#limitações-e-trabalhos-futuros)
- [Autores](#autores)

---

## Requisitos

### Requisitos Funcionais

- Saída de vídeo VGA em 640×480 a aproximadamente 60 Hz, com resolução lógica interna de 320×240 e ampliação 2×2 de cada pixel lógico.
- Camada de background baseada em tilemap de 40×30 posições, com tiles de 8×8 pixels (256 padrões disponíveis) e rolagem horizontal/vertical circular.
- Até 32 sprites de 16×16 pixels com posição, padrão gráfico, habilitação, espelhamento horizontal/vertical e transparência configuráveis.
- Rasterização de retângulos e triângulos preenchidos, com captura interativa de vértices.
- Composição das três camadas com prioridade fixa: Polígono > Sprite > Background.
- Conversão de índice de cor de 8 bits para RGB de 24 bits.
- Controle em tempo real por chaves e botões da placa (modo demonstração).

### Requisitos Não Funcionais

- Descrição integral em Verilog, com arquitetura modular (controle, datapath, memórias, motores gráficos e saída de vídeo separados).
- Todos os registradores e memórias com estratégia de reinicialização ou inicialização definida.
- Ausência de instabilidade visual, perda de sincronismo ou pixels indefinidos após a inicialização.
- Uso de memórias em bloco M10K sintetizadas a partir de IPs gerados pelo Quartus.

---

## Arquitetura

A arquitetura segue três princípios de projeto de motores gráficos em hardware:

- **Datapath vs. Controle**: o datapath de vídeo (contadores de varredura, cálculo de endereços e comparação de coordenadas) opera continuamente, pixel a pixel, enquanto a lógica de controle (FSM de modos) responde apenas a eventos das chaves e botões.
- **ROM vs. RAM**: dados visuais fixos (padrões de tiles e sprites) residem em ROMs geradas a partir de arquivos `.mif` e sintetizadas como blocos M10K. Dados que mudam em tempo de execução (posição e atributos dos sprites, deslocamento do cenário, vértices dos polígonos) ficam em registradores internos.
- **Sincronismo de vídeo**: a base de tempo de 25 MHz é obtida dividindo por 2 o clock de 50 MHz da placa. Como a resolução lógica é metade da física, cada pixel lógico é exibido como um bloco 2×2, obtido por simples descarte do bit menos significativo das coordenadas.

### Diagrama de Blocos

```
        SW[9:0]  KEY[3:0]              CLOCK_50MHZ
            |         |                     |
            v         v                     v
       +-----------------+          +---------------+
       |   FSM_CONTROLE  |<---------|  CLOCK_RESET  |
       +-----------------+          +---------------+
            |     |     |                   |
            v     v     v                   v
     +----------+ +-----------+ +------------------+  +------------------+
     |  MOTOR   | |  MOTOR    | |  RASTERIZADOR    |  |  CONTROLADOR_VGA |
     |BACKGROUND| | SPRITES   | |   POLIGONOS      |  |                  |
     +----------+ +-----------+ +------------------+  +------------------+
            |           |                |                    |
            +-----------+----------------+                    |
                        |                                     |
                        v                                     v
                  +-----------+      +-------------+     (sincronismo)
                  |COMPOSITOR |----->| RAM_PALETA  |-----> VGA (RGB + HS/VS)
                  +-----------+      +-------------+
```

---

## Hardware e Ferramentas

| Item | Especificação |
|---|---|
| Placa | Terasic DE1-SoC (Intel/Altera Cyclone V SoC) |
| FPGA | Cyclone V (5CSEMA5F31C6) |
| Ferramenta de síntese | Intel Quartus Prime Lite 25.1std |
| Linguagem de descrição | Verilog-2001 |
| Saída de vídeo | VGA 640×480 @ ~60 Hz via DAC ADV7123 |
| Clock de entrada | 50 MHz (pino `CLOCK_50`) |
| Clock de pixel | 25 MHz (divisão por 2 do clock da placa) |
| Modo de operação | Demonstração via chaves e botões físicos |

---

## Estrutura do Repositório

```
.
├── DE1_SOC_golden_top.v        # Top-level físico da placa (padrão Terasic)
├── main.v                       # Núcleo do coprocessador gráfico
├── clock_reset.v                # Divisor de clock e sincronizador de reset
├── controlador_vga.v            # Gerador de sincronismo VGA 640×480
├── fsm_controle.v               # Máquina de estados de modos
├── motor_background.v           # Motor de tilemap com scroll
├── motor_sprites.v              # Motor de 32 sprites 16×16
├── rasterizador_poligonos.v     # Rasterizador de retângulos e triângulos
├── compositor.v                 # Compositor de prioridade entre camadas
├── ram_paleta.v                 # Decodificador RGB332 → RGB888
├── decodificador_hex.v          # Conversor para displays de 7 segmentos
├── gerador_comandos_demo.v      # Gerador de comandos de 32 bits (demo)
├── decodificador_comandos.v     # Decodificador de comandos de 32 bits
├── mapa_rom.v                   # ROM do tilemap (1200 × 8 bits)
├── tile_rom.v                   # ROM de padrões de tiles (16384 × 8 bits)
├── sprite_rom.v                 # ROM de padrões de sprites (8192 × 8 bits)
├── tile_pattern_rom.v           # ROM alternativa de tiles (não sintetizada)
├── *.mif                        # Arquivos de inicialização das ROMs
└── PBL_1-SD_grupo_4.qsf         # Arquivo de projeto Quartus
```

---

## Módulos do Sistema

### `clock_reset.v`

Divide o clock de 50 MHz da placa por 2, gerando o clock de pixel de 25 MHz, e sincroniza o reset físico (KEY0, ativo em nível baixo) para o domínio de 25 MHz por meio de uma fila de dois flip-flops.

### `controlador_vga.v`

Gera os pulsos de sincronismo HSYNC/VSYNC e o sinal de área visível (`o_blank_n`), além de exportar as coordenadas físicas do pixel (0–639, 0–479). Os parâmetros de temporização seguem o padrão VGA 640×480 @ 60 Hz.

| Parâmetro | Horizontal (pixels) | Vertical (linhas) |
|---|---|---|
| Área ativa | 640 | 480 |
| Front porch | 16 | 10 |
| Pulso de sincronismo | 96 | 2 |
| Back porch | 48 | 33 |
| Total | 800 | 525 |

Com 800 × 525 = 420.000 ciclos de clock por quadro a 25 MHz, a taxa de atualização resultante é de aproximadamente 59,5 Hz.

### `fsm_controle.v`

Seleciona o modo de demonstração a partir de SW[9:8] e isola quais sinais físicos chegam a cada motor gráfico. Os motores não selecionados continuam sendo calculados a cada pixel; apenas deixam de receber novas entradas de chave.

| SW9 | SW8 | Estado |
|---|---|---|
| 0 | 0 | Background |
| 0 | 1 | Sprites |
| 1 | 1 | Polígonos |
| 1 | 0 | Não mapeado (reproduz Background) |

### `motor_background.v`

Cenário implementado como tilemap lógico de 40×30 posições, cada uma com um tile de 8×8 pixels. Utiliza duas ROMs:

- `mapa_rom`: 1200 × 8 bits, armazena o identificador do tile de cada posição do mapa.
- `tile_rom`: 16384 × 8 bits, armazena o desenho de 256 tiles de 64 pixels cada.

O endereço do mapa é calculado como `tile_y * 40 + tile_x`. O endereço do tile é `{tile_id, pixel_y, pixel_x}` (14 bits). Como a leitura de `mapa_rom` introduz 1 ciclo de latência, as coordenadas `pixel_x` e `pixel_y` são atrasadas em um registrador para realinhamento.

A rolagem é feita inteiramente em hardware, com um contador de 20 bits gerando um pulso periódico (a cada 400.000 ciclos de 25 MHz, ≈ 62,5 Hz) que incrementa ou decrementa os registradores `scroll_h` e `scroll_v`, com aritmética de wrap-around circular.

### `motor_sprites.v`

Controla até 32 entidades simultâneas de 16×16 pixels. Os atributos residem em vetores de registradores internos (não em RAM de bloco): `sprite_x`, `sprite_y`, `sprite_pat`, `sprite_en`, `sprite_mirror_h`, `sprite_mirror_v`, `sprite_transp`, cada um com 32 posições.

A imagem de cada sprite vem de uma ROM dedicada `sprite_rom` (8192 × 8 bits, inicializada por `sprite_patterns.mif`), que armazena 32 padrões de 256 pixels cada. O endereço de leitura é `{pat_local, py_local, px_local}`.

**Prioridade**: o primeiro sprite habilitado cuja área de 16×16 contém a coordenada (X, Y) é o que vence. A prioridade é fixa pela ordem do vetor, com o índice 0 tendo prioridade máxima.

### `rasterizador_poligonos.v`

Permite desenhar retângulos ou triângulos preenchidos, definidos por 2 ou 3 vértices capturados interativamente. Um cursor lógico independente percorre a tela a partir de (160, 120) a ~100 atualizações por segundo, podendo mover-se na diagonal.

- **Retângulo**: teste de bounding-box com min/max de X e Y entre os dois vértices.
- **Triângulo**: teste por funções de aresta (edge functions) com aritmética inteira com sinal.

O tipo de polígono é travado (`tipo_latched`) no instante em que o primeiro vértice é marcado, evitando corrupção da forma em construção.

| Elemento | Índice | Cor resultante (RGB332) |
|---|---|---|
| Cursor | 255 | Branco — RGB(255, 255, 255) |
| Preenchimento do retângulo | 100 | Laranja escuro/marrom — RGB(109, 36, 0) |
| Preenchimento do triângulo | 224 | Vermelho puro — RGB(255, 0, 0) |

### `compositor.v`

Bloco puramente combinacional que aplica prioridade fixa entre as três camadas: **Polígono > Sprite > Background**. Os índices de cor 0 vindos do sprite e do polígono são tratados como transparentes; o background nunca é transparente.

### `ram_paleta.v`

Apesar do nome herdado, não contém memória. É um decodificador síncrono que fatia o índice de 8 bits em três campos — 3 bits de vermelho, 3 de verde e 2 de azul (RGB332) — e expande cada campo para 8 bits por replicação de bits, registrando o resultado de 24 bits a cada ciclo de clock de pixel.

### `decodificador_hex.v`

Converte um valor hexadecimal de 4 bits para os segmentos físicos de um display de 7 segmentos (catodo comum, ativo em nível baixo). Instanciado seis vezes no topo (`HEX0`–`HEX5`).

### `gerador_comandos_demo.v` e `decodificador_comandos.v`

Interface de comandos de 32 bits, sintetizada mas **desconectada do caminho de renderização** na versão atual. O `gerador_comandos_demo` emite um comando a cada ~0,5 segundo, alternando ciclicamente pelos opcodes `OP_CONFIG_BG`, `OP_SET_TILE`, `OP_CONFIG_SPR`, `OP_RASTER_POLY` e `OP_WRITE_PAL`. O `decodificador_comandos` fatia e registra internamente o opcode e os parâmetros, mas não expõe saídas. Representa uma estrutura preparada para integração futura com um processador externo (HPS/ARM).

---

## Modos de Operação

### Estado A — Background (`SW9 = 0`, `SW8 = 0`)

| Entrada | Função |
|---|---|
| SW3 | Rola o cenário para a esquerda |
| SW2 | Rola o cenário para baixo |
| SW1 | Rola o cenário para cima |
| SW0 | Rola o cenário para a direita |
| KEY0 | Reset do sistema |

### Estado B — Sprites (`SW9 = 0`, `SW8 = 1`)

| Entrada | Função |
|---|---|
| SW[4:0] | Seleção do sprite (0 a 31) |
| SW7 | Transparência do sprite selecionado |
| SW6 / SW5 | Espelhamento horizontal / vertical |
| KEY1 | Alterna o par de direções controladas por KEY3/KEY2 |
| KEY3 / KEY2 | Movimentam o sprite selecionado (~70 Hz) |
| KEY0 | Reset do sistema |

### Estado C — Polígonos (`SW9 = 1`, `SW8 = 1`)

| Entrada | Função |
|---|---|
| SW7 | Tipo: 0 = triângulo, 1 = retângulo |
| SW[3:0] | Move o cursor (esquerda, baixo, cima, direita) |
| KEY3 | Marca a posição atual do cursor como vértice |
| KEY0 | Reset do sistema |

---

## Memórias

| Memória | Tipo | Tamanho | Conteúdo | Módulo que usa |
|---|---|---|---|---|
| `mapa_rom` | ROM | 1200 × 8 bits | ID do tile (0–255) em cada posição do mapa 40×30 | `motor_background` |
| `tile_rom` | ROM | 16384 × 8 bits | Índices de cor de 256 tiles de 8×8 pixels | `motor_background` |
| `sprite_rom` | ROM | 8192 × 8 bits | Índices de cor de 32 padrões de sprite de 16×16 pixels | `motor_sprites` |
| Vetores de atributos de sprite | Registradores | 32 posições por vetor | x, y, padrão, ativo, espelho H/V, transparência | `motor_sprites` |
| `tile_pattern_rom` | ROM (não sintetizada) | 16384 × 8 bits | Padrões alternativos de tile | Nenhum (fora do `.qsf`) |

Todas as ROMs foram geradas pela IP "ROM: 1-PORT" (megafunção `altsyncram`), sintetizadas em blocos M10K com leitura síncrona de 1 porta.

---

## Pinagem

| Sinal | Pino físico | Função |
|---|---|---|
| `CLOCK_50` | PIN_AF14 | Clock de 50 MHz da placa |
| `KEY[0]` | PIN_AA14 | Reset físico do sistema (ativo em nível baixo) |
| `KEY[1]` | PIN_AA15 | Depende do modo |
| `KEY[2]` / `KEY[3]` | PIN_W15 / PIN_Y16 | Dependem do modo |
| `SW[9:8]` | (ver `.qsf`) | Seleção do modo de operação |
| `SW[7:0]` | (ver `.qsf`) | Função dependente do modo |
| `LEDR[9:0]` | (ver `.qsf`) | Depuração |
| `HEX0`–`HEX5` | (ver `.qsf`) | Depuração (X, Y e estado da FSM) |
| `VGA_R/G/B`, `VGA_HS/VS`, `VGA_CLK`, `VGA_BLANK_N`, `VGA_SYNC_N` | (ver `.qsf`) | Saída de vídeo VGA |

O topo físico `DE1_SOC_golden_top.v` é o modelo padrão da Terasic. Apenas `CLOCK_50`, `KEY`, `SW`, `LEDR`, `HEX0`–`HEX5` e o barramento VGA são efetivamente usados pelo coprocessador gráfico.

**Depuração nos displays**:
- `HEX2`, `HEX1`, `HEX0`: coordenada X em hexadecimal.
- `HEX4`, `HEX3`: coordenada Y em hexadecimal.
- `HEX5`: estado atual da FSM.

---

## Compilação e Programação

1. Abra o projeto `PBL_1-SD_grupo_4.qpf` no Intel Quartus Prime Lite 25.1std.
2. Verifique se os arquivos `.mif` (`background_map.mif`, `background_tiles.mif`, `sprite_patterns.mif`) estão no diretório do projeto.
3. Execute **Processing → Start Compilation** (Ctrl+L).
4. Conecte a placa DE1-SoC via USB-Blaster.
5. Abra o **Programmer** (Tools → Programmer), carregue o arquivo `.sof` gerado e pressione **Start**.
6. Conecte um monitor VGA à saída de vídeo da placa.

---

## Testes

Cenários de verificação previstos para o projeto:

| Cenário | Descrição |
|---|---|
| Transparência | Confirmar que o índice de cor 0 em sprites e polígonos deixa a camada inferior aparecer |
| Espelhamento | Verificar espelhamento horizontal e vertical individual de cada sprite |
| Sobreposição | Validar que o compositor resolve corretamente pixeis com múltiplas camadas ativas |
| Prioridade | Confirmar a regra fixa Polígono > Sprite > Background |
| Troca de buffers | Não aplicável a esta versão (não há framebuffer) |
| Comandos inválidos | Verificar robustez da FSM a combinações não mapeadas de SW[9:8] |

---

## Resultados e Análise

### O que está implementado e em uso na demonstração

Toda a cadeia de sinal desde as chaves e botões físicos até a saída VGA: `clock_reset`, `controlador_vga`, `fsm_controle`, `motor_background` (com `mapa_rom` e `tile_rom`), `motor_sprites` (com `sprite_rom`), `rasterizador_poligonos`, `compositor`, `ram_paleta` e `decodificador_hex`.

### O que está implementado mas não é exercido

`gerador_comandos_demo` e `decodificador_comandos` — a interface de comandos de 32 bits está sintetizada, mas sem conexão com as camadas gráficas.

### O que está presente no repositório mas não é sintetizado

`tile_pattern_rom.v` e `background2.mif` — ROM alternativa de tiles, fora do arquivo `.qsf`.

### Limitação observável

O background foi desenhado originalmente em cores livres de 24 bits e precisou ser convertido para índices de 8 bits no padrão RGB332 (256 cores disponíveis). Algumas cores do desenho original não têm correspondência exata nesse espaço e precisam ser aproximadas, gerando diferenças visuais perceptíveis entre a arte de referência e o resultado exibido.

### Ausência de alteração de cor dos sprites

Não há alteração de cor dos sprites ao serem selecionados. O desenho de cada sprite é sempre lido diretamente de `sprite_rom`, independentemente da seleção. O mecanismo existente é apenas de transparência, controlado por SW7 e pelo índice de cor 0.

---

## Limitações e Trabalhos Futuros

- **Espaço de cores RGB332**: ampliar o formato de índice para permitir mais cores, ou implementar uma paleta programável real de 256 entradas.
- **Conexão da interface de comandos**: conectar as saídas de `decodificador_comandos.v` aos registradores de scroll do background, aos atributos dos sprites e aos vértices do rasterizador, permitindo controle por software via HPS/ARM.
- **Framebuffer/troca de buffers**: não implementado nesta versão.
- **Testbench de integração**: desenvolver testbench único para validar toda a cadeia de renderização.

---

## Autores

- **Bruna de Almeida Nascimento**
- **Carlos Daniel da Silva Jesus**
- **Diego Mercês Almeida**

Bacharelado em Engenharia de Computação
Universidade Estadual de Feira de Santana (UEFS)

Disciplina: TEC499 — Sistemas Digitais
Professor: Angelo Duarte

---

## Referências

DAUM, Michael. **Terasic DE1-SoC Development and Education Board**. RocketBoards, 2016. Disponível em: https://www.rocketboards.org/foswiki/Documentation/TerasicDE1SoCDevelopmentAndEducationBoard.

TERASIC. **DE1-SoC User Manual**, rev. F. Terasic Technologies Inc., 2018.
```
