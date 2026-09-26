// decodificador_comandos.v
// Decodificador de comandos gráficos de 32 bits enviados pelo processador central.
// Fatiará e interpretará as instruções para configurar os registradores dos motores gráficos.

module decodificador_comandos (
   input  wire        clk,        // Clock de controle de escrita (25 MHz)
   input  wire        reset_n,    // Reset ativo em nível baixo
   input  wire [31:0] comando,    // Instrução de 32 bits vinda do processador
   input  wire        valido      // Sinalizador de comando válido (strobe de escrita)
);

	// Definição dos Opcodes das instruções de 32 bits
	localparam OP_CONFIG_BG    = 4'b0000; // Configura deslocamento (scroll) do Background
	localparam OP_SET_TILE     = 4'b0001; // Atualiza um tile específico no tilemap
	localparam OP_CONFIG_SPR   = 4'b0010; // Escreve na memória de atributos do Sprite
	localparam OP_RASTER_POLY  = 4'b0011; // Envia comando de rasterização de polígono
	localparam OP_WRITE_PAL    = 4'b0100; // Escreve uma cor na RAM de paleta

	// Registradores internos do decodificador para depuração e controle
	reg [3:0]  opcode_atual;
	reg [7:0]  parametro_a;
	reg [7:0]  parametro_b;
	reg [11:0] parametro_c;

   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         opcode_atual <= 4'd0;
         parametro_a  <= 8'd0;
         parametro_b  <= 8'd0;
         parametro_c  <= 12'd0;
      end else if (valido) begin
         // Fatiamento da instrução de 32 bits
         opcode_atual <= comando[31:28]; // Bits mais significativos definem a operação
         parametro_a  <= comando[27:20]; // Parâmetro A (ex: ID do Sprite ou endereço)
         parametro_b  <= comando[19:12]; // Parâmetro B (ex: Coordenada X ou índice do tile)
         parametro_c  <= comando[11:0];  // Parâmetro C (ex: Coordenada Y ou cor RGB)
      end
   end

endmodule