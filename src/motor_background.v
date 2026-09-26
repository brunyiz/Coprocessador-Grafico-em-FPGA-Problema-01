// motor_background.v
// Background baseado em duas ROMs geradas no Quartus:
//   1) mapa_rom : 1200 x 8  -> cada posicao do mapa guarda um tile_id
//   2) tile_rom : 16384 x 8 -> 256 tiles x 64 pixels por tile
//
// Fluxo:
// x/y -> scroll -> endereco do mapa -> mapa_rom -> tile_id
//     -> {tile_id, pixel_y, pixel_x} -> tile_rom -> indice_cor
//
// Como as ROMs internas do Cyclone V sao sincronas, o pixel_x/pixel_y
// e atrasado em 1 ciclo para ficar alinhado ao tile_id retornado pela mapa_rom.

module motor_background (
    input  wire        clk,
    input  wire        reset_n,
    input  wire [8:0]  x_logico,        // 0..319
    input  wire [7:0]  y_logico,        // 0..239
    input  wire [3:0]  controle_sw,     // SW3=esq, SW2=baixo, SW1=cima, SW0=dir
    output wire [7:0]  indice_cor
);

    // ============================================================
    // SCROLL
    // ============================================================

    reg [8:0] scroll_h;
    reg [7:0] scroll_v;

    reg [19:0] contador_velocidade;
    wire pulso_rolagem = (contador_velocidade == 20'd400_000);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            contador_velocidade <= 20'd0;
        else if (pulso_rolagem)
            contador_velocidade <= 20'd0;
        else
            contador_velocidade <= contador_velocidade + 20'd1;
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            scroll_h <= 9'd0;
            scroll_v <= 8'd0;
        end
        else if (pulso_rolagem) begin
            // esquerda
            if (controle_sw[3]) begin
                if (scroll_h == 9'd0)
                    scroll_h <= 9'd319;
                else
                    scroll_h <= scroll_h - 9'd1;
            end
            // direita
            else if (controle_sw[0]) begin
                if (scroll_h == 9'd319)
                    scroll_h <= 9'd0;
                else
                    scroll_h <= scroll_h + 9'd1;
            end

            // cima
            if (controle_sw[1]) begin
                if (scroll_v == 8'd0)
                    scroll_v <= 8'd239;
                else
                    scroll_v <= scroll_v - 8'd1;
            end
            // baixo
            else if (controle_sw[2]) begin
                if (scroll_v == 8'd239)
                    scroll_v <= 8'd0;
                else
                    scroll_v <= scroll_v + 8'd1;
            end
        end
    end

    // ============================================================
    // COORDENADA DA CENA COM WRAP
    // ============================================================

    wire [9:0] soma_x = {1'b0, x_logico} + {1'b0, scroll_h};
    wire [8:0] soma_y = {1'b0, y_logico} + {1'b0, scroll_v};

    wire [8:0] abs_x = (soma_x >= 10'd320) ?
                       (soma_x - 10'd320) : soma_x[8:0];

    wire [7:0] abs_y = (soma_y >= 9'd240) ?
                       (soma_y - 9'd240) : soma_y[7:0];

    // ============================================================
    // POSICAO NO MAPA 40 x 30
    // ============================================================

    wire [5:0] tile_x = abs_x[8:3]; // 0..39
    wire [4:0] tile_y = abs_y[7:3]; // 0..29

    // endereco = tile_y * 40 + tile_x
    // 40 = 32 + 8
    wire [10:0] linha_x40 =
        ({6'd0, tile_y} << 5) + ({6'd0, tile_y} << 3);

    wire [10:0] endereco_mapa = linha_x40 + {5'd0, tile_x};

    // Posicao do pixel dentro do tile 8x8
    wire [2:0] pixel_x = abs_x[2:0];
    wire [2:0] pixel_y = abs_y[2:0];

    // ============================================================
    // ROM 1: MAPA 1200 x 8
    // ============================================================
    // background_map.mif:
    // cada word guarda o ID (0..255) do tile daquela posicao.

    wire [7:0] tile_id;

    mapa_rom ROM_MAPA (
        .address (endereco_mapa),
        .clock   (clk),
        .rden    (1'b1),
        .q       (tile_id)
    );

    // ============================================================
    // ALINHAMENTO DE 1 CICLO
    // ============================================================
    // A mapa_rom e sincrona. Quando tile_id aparece na saida,
    // precisamos usar o pixel_x/pixel_y pertencente ao mesmo acesso.

    reg [2:0] pixel_x_d1;
    reg [2:0] pixel_y_d1;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pixel_x_d1 <= 3'd0;
            pixel_y_d1 <= 3'd0;
        end
        else begin
            pixel_x_d1 <= pixel_x;
            pixel_y_d1 <= pixel_y;
        end
    end

    // ============================================================
    // ROM 2: PADROES DOS TILES 16384 x 8
    // ============================================================
    // 256 tiles * 64 pixels = 16384 words.
    //
    // endereco = tile_id * 64 + pixel_y * 8 + pixel_x
    //          = {tile_id, pixel_y, pixel_x}

    wire [13:0] endereco_tile = {tile_id, pixel_y_d1, pixel_x_d1};
    wire [7:0] cor_tile;

    tile_rom ROM_TILES (
        .address (endereco_tile),
        .clock   (clk),
        .rden    (1'b1),
        .q       (cor_tile)
    );

    // Saida para compositor/paleta
    assign indice_cor = cor_tile;

endmodule
