// gerador_comandos_demo.v
// Gerador de comandos de demonstração para simular o envio de instruções de 32 bits pelo ARM.
// Envia periodicamente comandos para configurar o background, sprites, polígonos ou paleta.

module gerador_comandos_demo (
   input  wire        clk,        // Clock do sistema (25 MHz)
   input  wire        reset_n,    // Reset ativo em baixo
   input  wire        habilitado, // Sinal de habilitação geral
   output reg  [31:0] comando,    // Comando gráfico de 32 bits gerado
   output reg         valido      // Pulso indicador de comando válido (strobe de escrita)
);

    // Contador de tempo para envio periódico
    reg [23:0] contador_tempo;
    reg [3:0]  indice_comando;

   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         contador_tempo  <= 24'd0;
         indice_comando  <= 4'd0;
         comando         <= 32'd0;
         valido          <= 1'b0;
      end else if (habilitado) begin
         valido <= 1'b0; // Por padrão, o comando é inválido (pulso único)
            
         // Incrementa o contador de tempo (envia a cada 0.5 segundos @ 25 MHz)
         if (contador_tempo >= 24'd12_500_000) begin
            contador_tempo <= 24'd0;
            valido         <= 1'b1; // Envia pulso de comando válido
                
            // Seleciona qual comando de demonstração enviar
            case (indice_comando)
               // Configuração: Op_code [31:28], Param_A [27:20], Param_B [19:12], Param_C [11:0]
                    
               // 0: Configura deslocamento (scroll) do Background
               4'd0: begin
                  comando <= {4'b0000, 8'd0, 8'd10, 12'd15}; 
                  indice_comando <= 4'd1;
               end
                    
               // 1: Atualiza um tile específico no tilemap
               4'd1: begin
                  comando <= {4'b0001, 8'd5, 8'd12, 12'd4}; 
                  indice_comando <= 4'd2;
               end
                    
               // 2: Configura atributos do Sprite (ex: Sprite 0 na posição X=100, Y=80)
               4'd2: begin
                  comando <= {4'b0010, 8'd0, 8'd100, 12'd80}; 
                  indice_comando <= 4'd3;
               end
                    
               // 3: Rasterização de Polígono (retângulo ou triângulo)
               4'd3: begin
                  comando <= {4'b0011, 8'd1, 8'd50, 12'd120}; 
                  indice_comando <= 4'd4;
               end
                    
               // 4: Escreve uma cor na RAM de paleta (ex: Cor 255 é Branca)
               4'd4: begin
                  comando <= {4'b0100, 8'd255, 8'd255, 12'd4095}; 
                  indice_comando <= 4'd0; // Recomeça a sequência de demonstração
               end
                    
               default: begin
                  indice_comando <= 4'd0;
               end
            endcase
         end else begin
            contador_tempo <= contador_tempo + 1'b1;
         end
      end
   end

endmodule