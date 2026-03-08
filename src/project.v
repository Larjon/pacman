`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);

  // ============================================================
  // VGA
  // ============================================================
  wire hsync, vsync;
  wire video_active;
  wire [9:0] pix_x, pix_y;
  reg  [1:0] R, G, B;

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;
  wire _unused_ok = &{ena, uio_in};

  hvsync_generator hvsync_gen (
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // ============================================================
  // Controls
  // ui[4] = left
  // ui[5] = right
  // ui[0] = up
  // ui[1] = down
  // ui[2] = restart
  // ============================================================
  wire btn_up      = ui_in[0];
  wire btn_down    = ui_in[1];
  wire btn_restart = ui_in[2];
  wire btn_left    = ui_in[4];
  wire btn_right   = ui_in[5];

  // ============================================================
  // Frame tick
  // ============================================================
  wire frame_tick = (pix_x == 10'd0) && (pix_y == 10'd0);

  // ============================================================
  // Board layout
  // ============================================================
  localparam [9:0] BOARD_X = 10'd192;
  localparam [9:0] BOARD_Y = 10'd112;

  // ============================================================
  // Game state
  // ============================================================
  reg [3:0] pac_x;
  reg [3:0] pac_y;
  reg [1:0] pac_dir;
  reg [1:0] want_dir;
  reg [2:0] move_div;
  reg [7:0] score;

  reg [3:0] ghost_x;
  reg [3:0] ghost_y;
  reg [1:0] ghost_dir;
  reg [2:0] ghost_div;

  reg game_over;
  reg win;

  reg [15:0] dots_row0;
  reg [15:0] dots_row1;
  reg [15:0] dots_row2;
  reg [15:0] dots_row3;
  reg [15:0] dots_row4;
  reg [15:0] dots_row5;
  reg [15:0] dots_row6;
  reg [15:0] dots_row7;
  reg [15:0] dots_row8;
  reg [15:0] dots_row9;
  reg [15:0] dots_row10;
  reg [15:0] dots_row11;
  reg [15:0] dots_row12;
  reg [15:0] dots_row13;
  reg [15:0] dots_row14;
  reg [15:0] dots_row15;

  // ============================================================
  // Wall map
  // ============================================================
  function wall_at;
    input [3:0] tx;
    input [3:0] ty;
    begin
      case (ty)
        4'd0:  wall_at = (tx == 4'd0)  || (tx == 4'd1)  || (tx == 4'd2)  || (tx == 4'd3)  ||
                          (tx == 4'd4)  || (tx == 4'd5)  || (tx == 4'd6)  || (tx == 4'd7)  ||
                          (tx == 4'd8)  || (tx == 4'd9)  || (tx == 4'd10) || (tx == 4'd11) ||
                          (tx == 4'd12) || (tx == 4'd13) || (tx == 4'd14) || (tx == 4'd15);

        4'd1:  wall_at = (tx == 4'd0)  || (tx == 4'd15) ||
                          (tx == 4'd4)  || (tx == 4'd5)  || (tx == 4'd10) || (tx == 4'd11);

        4'd2:  wall_at = (tx == 4'd0)  || (tx == 4'd2)  || (tx == 4'd3)  ||
                          (tx == 4'd7)  || (tx == 4'd8)  ||
                          (tx == 4'd12) || (tx == 4'd13) || (tx == 4'd15);

        4'd3:  wall_at = (tx == 4'd0)  || (tx == 4'd2)  ||
                          (tx == 4'd7)  || (tx == 4'd8)  ||
                          (tx == 4'd13) || (tx == 4'd15);

        4'd4:  wall_at = (tx == 4'd0)  || (tx == 4'd2)  || (tx == 4'd3)  || (tx == 4'd4) ||
                          (tx == 4'd5)  ||
                          (tx == 4'd10) || (tx == 4'd11) || (tx == 4'd12) || (tx == 4'd13) ||
                          (tx == 4'd15);

        4'd5:  wall_at = (tx == 4'd0)  || (tx == 4'd15);

        4'd6:  wall_at = (tx == 4'd0)  || (tx == 4'd1)  || (tx == 4'd2)  ||
                          (tx == 4'd6)  || (tx == 4'd7)  || (tx == 4'd8)  || (tx == 4'd9)  ||
                          (tx == 4'd13) || (tx == 4'd14) || (tx == 4'd15);

        4'd7:  wall_at = (tx == 4'd0)  || (tx == 4'd6)  || (tx == 4'd9)  || (tx == 4'd15);

        4'd8:  wall_at = (tx == 4'd0)  || (tx == 4'd6)  || (tx == 4'd9)  || (tx == 4'd15);

        4'd9:  wall_at = (tx == 4'd0)  || (tx == 4'd1)  || (tx == 4'd2)  ||
                          (tx == 4'd6)  || (tx == 4'd7)  || (tx == 4'd8)  || (tx == 4'd9)  ||
                          (tx == 4'd13) || (tx == 4'd14) || (tx == 4'd15);

        4'd10: wall_at = (tx == 4'd0)  || (tx == 4'd15);

        4'd11: wall_at = (tx == 4'd0)  || (tx == 4'd2)  || (tx == 4'd3)  || (tx == 4'd4) ||
                          (tx == 4'd5)  ||
                          (tx == 4'd10) || (tx == 4'd11) || (tx == 4'd12) || (tx == 4'd13) ||
                          (tx == 4'd15);

        4'd12: wall_at = (tx == 4'd0)  || (tx == 4'd2)  ||
                          (tx == 4'd7)  || (tx == 4'd8)  ||
                          (tx == 4'd13) || (tx == 4'd15);

        4'd13: wall_at = (tx == 4'd0)  || (tx == 4'd2)  || (tx == 4'd3)  ||
                          (tx == 4'd7)  || (tx == 4'd8)  ||
                          (tx == 4'd12) || (tx == 4'd13) || (tx == 4'd15);

        4'd14: wall_at = (tx == 4'd0)  || (tx == 4'd15) ||
                          (tx == 4'd4)  || (tx == 4'd5)  || (tx == 4'd10) || (tx == 4'd11);

        default: wall_at = 1'b1;
      endcase
    end
  endfunction

  // ============================================================
  // Dot read helper
  // ============================================================
  function dot_at;
    input [3:0] tx;
    input [3:0] ty;
    begin
      case (ty)
        4'd0:  dot_at = dots_row0[tx];
        4'd1:  dot_at = dots_row1[tx];
        4'd2:  dot_at = dots_row2[tx];
        4'd3:  dot_at = dots_row3[tx];
        4'd4:  dot_at = dots_row4[tx];
        4'd5:  dot_at = dots_row5[tx];
        4'd6:  dot_at = dots_row6[tx];
        4'd7:  dot_at = dots_row7[tx];
        4'd8:  dot_at = dots_row8[tx];
        4'd9:  dot_at = dots_row9[tx];
        4'd10: dot_at = dots_row10[tx];
        4'd11: dot_at = dots_row11[tx];
        4'd12: dot_at = dots_row12[tx];
        4'd13: dot_at = dots_row13[tx];
        4'd14: dot_at = dots_row14[tx];
        default: dot_at = dots_row15[tx];
      endcase
    end
  endfunction

  // ============================================================
  // Pac-Man movement helpers
  // ============================================================
  reg [3:0] try_x;
  reg [3:0] try_y;
  reg [3:0] step_x;
  reg [3:0] step_y;

  always @(*) begin
    if (btn_left)       want_dir = 2'd0;
    else if (btn_right) want_dir = 2'd1;
    else if (btn_up)    want_dir = 2'd2;
    else if (btn_down)  want_dir = 2'd3;
    else                want_dir = pac_dir;
  end

  always @(*) begin
    try_x = pac_x;
    try_y = pac_y;

    case (want_dir)
      2'd0: if (pac_x != 4'd0)  try_x = pac_x - 4'd1;
      2'd1: if (pac_x != 4'd15) try_x = pac_x + 4'd1;
      2'd2: if (pac_y != 4'd0)  try_y = pac_y - 4'd1;
      default: if (pac_y != 4'd15) try_y = pac_y + 4'd1;
    endcase
  end

  always @(*) begin
    step_x = pac_x;
    step_y = pac_y;

    case (pac_dir)
      2'd0: if (pac_x != 4'd0)  step_x = pac_x - 4'd1;
      2'd1: if (pac_x != 4'd15) step_x = pac_x + 4'd1;
      2'd2: if (pac_y != 4'd0)  step_y = pac_y - 4'd1;
      default: if (pac_y != 4'd15) step_y = pac_y + 4'd1;
    endcase
  end

  wire want_ok = !wall_at(try_x, try_y);
  wire step_ok = !wall_at(step_x, step_y);

  // ============================================================
  // Ghost movement helpers
  // ============================================================
  reg [3:0] g_left_x,  g_left_y;
  reg [3:0] g_right_x, g_right_y;
  reg [3:0] g_up_x,    g_up_y;
  reg [3:0] g_down_x,  g_down_y;

  wire g_left_ok;
  wire g_right_ok;
  wire g_up_ok;
  wire g_down_ok;

  reg [1:0] ghost_pref0, ghost_pref1, ghost_pref2, ghost_pref3;
  reg [3:0] ghost_next_x, ghost_next_y;
  reg [1:0] ghost_next_dir;

  always @(*) begin
    g_left_x  = ghost_x; g_left_y  = ghost_y;
    g_right_x = ghost_x; g_right_y = ghost_y;
    g_up_x    = ghost_x; g_up_y    = ghost_y;
    g_down_x  = ghost_x; g_down_y  = ghost_y;

    if (ghost_x != 4'd0)  g_left_x  = ghost_x - 4'd1;
    if (ghost_x != 4'd15) g_right_x = ghost_x + 4'd1;
    if (ghost_y != 4'd0)  g_up_y    = ghost_y - 4'd1;
    if (ghost_y != 4'd15) g_down_y  = ghost_y + 4'd1;
  end

  assign g_left_ok  = !wall_at(g_left_x,  g_left_y);
  assign g_right_ok = !wall_at(g_right_x, g_right_y);
  assign g_up_ok    = !wall_at(g_up_x,    g_up_y);
  assign g_down_ok  = !wall_at(g_down_x,  g_down_y);

  // Proste AI:
  // wybierz najpierw oś, w której Pac-Man jest dalej
  always @(*) begin
    if ((pac_x > ghost_x ? (pac_x - ghost_x) : (ghost_x - pac_x)) >=
        (pac_y > ghost_y ? (pac_y - ghost_y) : (ghost_y - pac_y))) begin

      // priorytet poziomy
      if (pac_x > ghost_x) begin
        ghost_pref0 = 2'd1; // right
        ghost_pref1 = (pac_y > ghost_y) ? 2'd3 : 2'd2; // down/up
        ghost_pref2 = (pac_y > ghost_y) ? 2'd2 : 2'd3; // up/down
        ghost_pref3 = 2'd0; // left
      end else begin
        ghost_pref0 = 2'd0; // left
        ghost_pref1 = (pac_y > ghost_y) ? 2'd3 : 2'd2;
        ghost_pref2 = (pac_y > ghost_y) ? 2'd2 : 2'd3;
        ghost_pref3 = 2'd1; // right
      end

    end else begin
      // priorytet pionowy
      if (pac_y > ghost_y) begin
        ghost_pref0 = 2'd3; // down
        ghost_pref1 = (pac_x > ghost_x) ? 2'd1 : 2'd0; // right/left
        ghost_pref2 = (pac_x > ghost_x) ? 2'd0 : 2'd1; // left/right
        ghost_pref3 = 2'd2; // up
      end else begin
        ghost_pref0 = 2'd2; // up
        ghost_pref1 = (pac_x > ghost_x) ? 2'd1 : 2'd0;
        ghost_pref2 = (pac_x > ghost_x) ? 2'd0 : 2'd1;
        ghost_pref3 = 2'd3; // down
      end
    end
  end

  always @(*) begin
    ghost_next_dir = ghost_dir;
    ghost_next_x   = ghost_x;
    ghost_next_y   = ghost_y;

    case (ghost_pref0)
      2'd0: if (g_left_ok)  begin ghost_next_dir = 2'd0; ghost_next_x = g_left_x;  ghost_next_y = g_left_y;  end
      2'd1: if (g_right_ok) begin ghost_next_dir = 2'd1; ghost_next_x = g_right_x; ghost_next_y = g_right_y; end
      2'd2: if (g_up_ok)    begin ghost_next_dir = 2'd2; ghost_next_x = g_up_x;    ghost_next_y = g_up_y;    end
      2'd3: if (g_down_ok)  begin ghost_next_dir = 2'd3; ghost_next_x = g_down_x;  ghost_next_y = g_down_y;  end
    endcase

    if ((ghost_next_x == ghost_x) && (ghost_next_y == ghost_y)) begin
      case (ghost_pref1)
        2'd0: if (g_left_ok)  begin ghost_next_dir = 2'd0; ghost_next_x = g_left_x;  ghost_next_y = g_left_y;  end
        2'd1: if (g_right_ok) begin ghost_next_dir = 2'd1; ghost_next_x = g_right_x; ghost_next_y = g_right_y; end
        2'd2: if (g_up_ok)    begin ghost_next_dir = 2'd2; ghost_next_x = g_up_x;    ghost_next_y = g_up_y;    end
        2'd3: if (g_down_ok)  begin ghost_next_dir = 2'd3; ghost_next_x = g_down_x;  ghost_next_y = g_down_y;  end
      endcase
    end

    if ((ghost_next_x == ghost_x) && (ghost_next_y == ghost_y)) begin
      case (ghost_pref2)
        2'd0: if (g_left_ok)  begin ghost_next_dir = 2'd0; ghost_next_x = g_left_x;  ghost_next_y = g_left_y;  end
        2'd1: if (g_right_ok) begin ghost_next_dir = 2'd1; ghost_next_x = g_right_x; ghost_next_y = g_right_y; end
        2'd2: if (g_up_ok)    begin ghost_next_dir = 2'd2; ghost_next_x = g_up_x;    ghost_next_y = g_up_y;    end
        2'd3: if (g_down_ok)  begin ghost_next_dir = 2'd3; ghost_next_x = g_down_x;  ghost_next_y = g_down_y;  end
      endcase
    end

    if ((ghost_next_x == ghost_x) && (ghost_next_y == ghost_y)) begin
      case (ghost_pref3)
        2'd0: if (g_left_ok)  begin ghost_next_dir = 2'd0; ghost_next_x = g_left_x;  ghost_next_y = g_left_y;  end
        2'd1: if (g_right_ok) begin ghost_next_dir = 2'd1; ghost_next_x = g_right_x; ghost_next_y = g_right_y; end
        2'd2: if (g_up_ok)    begin ghost_next_dir = 2'd2; ghost_next_x = g_up_x;    ghost_next_y = g_up_y;    end
        2'd3: if (g_down_ok)  begin ghost_next_dir = 2'd3; ghost_next_x = g_down_x;  ghost_next_y = g_down_y;  end
      endcase
    end
  end

  // ============================================================
  // Any dots left?
  // ============================================================
  wire any_dots =
    (|dots_row0)  || (|dots_row1)  || (|dots_row2)  || (|dots_row3)  ||
    (|dots_row4)  || (|dots_row5)  || (|dots_row6)  || (|dots_row7)  ||
    (|dots_row8)  || (|dots_row9)  || (|dots_row10) || (|dots_row11) ||
    (|dots_row12) || (|dots_row13) || (|dots_row14) || (|dots_row15);

  // ============================================================
  // Collision
  // ============================================================
  wire hit_ghost = (pac_x == ghost_x) && (pac_y == ghost_y);

  // ============================================================
  // Main game logic
  // ============================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pac_x    <= 4'd1;
      pac_y    <= 4'd1;
      pac_dir  <= 2'd1;
      move_div <= 3'd0;
      score    <= 8'd0;

      ghost_x   <= 4'd14;
      ghost_y   <= 4'd14;
      ghost_dir <= 2'd0;
      ghost_div <= 3'd0;

      game_over <= 1'b0;
      win       <= 1'b0;

      dots_row0  <= 16'h0000;
      dots_row1  <= 16'hF7DE;
      dots_row2  <= 16'h90E9;
      dots_row3  <= 16'hB1CD;
      dots_row4  <= 16'h8031;
      dots_row5  <= 16'h7FFE;
      dots_row6  <= 16'h1E78;
      dots_row7  <= 16'hBE7D;
      dots_row8  <= 16'hBE7D;
      dots_row9  <= 16'h1E78;
      dots_row10 <= 16'h7FFE;
      dots_row11 <= 16'h8031;
      dots_row12 <= 16'hB1CD;
      dots_row13 <= 16'h90E9;
      dots_row14 <= 16'hF7DE;
      dots_row15 <= 16'h0000;

    end else if (frame_tick) begin
      if (btn_restart) begin
        pac_x    <= 4'd1;
        pac_y    <= 4'd1;
        pac_dir  <= 2'd1;
        move_div <= 3'd0;
        score    <= 8'd0;

        ghost_x   <= 4'd14;
        ghost_y   <= 4'd14;
        ghost_dir <= 2'd0;
        ghost_div <= 3'd0;

        game_over <= 1'b0;
        win       <= 1'b0;

        dots_row0  <= 16'h0000;
        dots_row1  <= 16'hF7DE;
        dots_row2  <= 16'h90E9;
        dots_row3  <= 16'hB1CD;
        dots_row4  <= 16'h8031;
        dots_row5  <= 16'h7FFE;
        dots_row6  <= 16'h1E78;
        dots_row7  <= 16'hBE7D;
        dots_row8  <= 16'hBE7D;
        dots_row9  <= 16'h1E78;
        dots_row10 <= 16'h7FFE;
        dots_row11 <= 16'h8031;
        dots_row12 <= 16'hB1CD;
        dots_row13 <= 16'h90E9;
        dots_row14 <= 16'hF7DE;
        dots_row15 <= 16'h0000;
      end else begin
        move_div  <= move_div + 3'd1;
        ghost_div <= ghost_div + 3'd1;

        if (!game_over && !win) begin
          if (hit_ghost) begin
            game_over <= 1'b1;
          end else begin

            if (want_ok)
              pac_dir <= want_dir;

            if (move_div == 3'd0) begin
              if (want_ok) begin
                pac_x <= try_x;
                pac_y <= try_y;
              end else if (step_ok) begin
                pac_x <= step_x;
                pac_y <= step_y;
              end
            end

            // nowy ruch ducha
            if (ghost_div == 3'd0) begin
              ghost_dir <= ghost_next_dir;
              ghost_x   <= ghost_next_x;
              ghost_y   <= ghost_next_y;
            end

            if (move_div == 3'd0) begin
              case (pac_y)
                4'd0:  if (dots_row0[pac_x])  begin dots_row0[pac_x]  <= 1'b0; score <= score + 8'd1; end
                4'd1:  if (dots_row1[pac_x])  begin dots_row1[pac_x]  <= 1'b0; score <= score + 8'd1; end
                4'd2:  if (dots_row2[pac_x])  begin dots_row2[pac_x]  <= 1'b0; score <= score + 8'd1; end
                4'd3:  if (dots_row3[pac_x])  begin dots_row3[pac_x]  <= 1'b0; score <= score + 8'd1; end
                4'd4:  if (dots_row4[pac_x])  begin dots_row4[pac_x]  <= 1'b0; score <= score + 8'd1; end
                4'd5:  if (dots_row5[pac_x])  begin dots_row5[pac_x]  <= 1'b0; score <= score + 8'd1; end
                4'd6:  if (dots_row6[pac_x])  begin dots_row6[pac_x]  <= 1'b0; score <= score + 8'd1; end
                4'd7:  if (dots_row7[pac_x])  begin dots_row7[pac_x]  <= 1'b0; score <= score + 8'd1; end
                4'd8:  if (dots_row8[pac_x])  begin dots_row8[pac_x]  <= 1'b0; score <= score + 8'd1; end
                4'd9:  if (dots_row9[pac_x])  begin dots_row9[pac_x]  <= 1'b0; score <= score + 8'd1; end
                4'd10: if (dots_row10[pac_x]) begin dots_row10[pac_x] <= 1'b0; score <= score + 8'd1; end
                4'd11: if (dots_row11[pac_x]) begin dots_row11[pac_x] <= 1'b0; score <= score + 8'd1; end
                4'd12: if (dots_row12[pac_x]) begin dots_row12[pac_x] <= 1'b0; score <= score + 8'd1; end
                4'd13: if (dots_row13[pac_x]) begin dots_row13[pac_x] <= 1'b0; score <= score + 8'd1; end
                4'd14: if (dots_row14[pac_x]) begin dots_row14[pac_x] <= 1'b0; score <= score + 8'd1; end
                default: if (dots_row15[pac_x]) begin dots_row15[pac_x] <= 1'b0; score <= score + 8'd1; end
              endcase
            end

            if (((move_div == 3'd0) &&
                 (((want_ok ? try_x : (step_ok ? step_x : pac_x)) == ghost_x) &&
                  ((want_ok ? try_y : (step_ok ? step_y : pac_y)) == ghost_y))) ||
                ((ghost_div == 3'd0) &&
                 ((pac_x == ghost_next_x) && (pac_y == ghost_next_y)))) begin
              game_over <= 1'b1;
            end else if (!any_dots) begin
              win <= 1'b1;
            end
          end
        end
      end
    end
  end

  // ============================================================
  // Pixel -> tile decode
  // ============================================================
  wire board_area =
    (pix_x >= BOARD_X) && (pix_x < (BOARD_X + 10'd256)) &&
    (pix_y >= BOARD_Y) && (pix_y < (BOARD_Y + 10'd256));

  wire [9:0] rel_x = pix_x - BOARD_X;
  wire [9:0] rel_y = pix_y - BOARD_Y;

  wire [3:0] tile_x = rel_x[7:4];
  wire [3:0] tile_y = rel_y[7:4];

  wire [3:0] cell_x = rel_x[3:0];
  wire [3:0] cell_y = rel_y[3:0];

  wire tile_wall = wall_at(tile_x, tile_y);
  wire tile_dot  = dot_at(tile_x, tile_y);

  // ============================================================
  // Pac-Man shape
  // ============================================================
  wire pac_tile = (tile_x == pac_x) && (tile_y == pac_y);

  wire pac_body =
    pac_tile &&
    (cell_x >= 4'd2) && (cell_x <= 4'd13) &&
    (cell_y >= 4'd2) && (cell_y <= 4'd13);

  wire mouth_open = move_div[2];

  wire pac_mouth =
    pac_tile && mouth_open &&
    (
      ((pac_dir == 2'd0) && (cell_x <= 4'd5)  && (cell_y >= cell_x) && (cell_y <= (4'd15 - cell_x))) ||
      ((pac_dir == 2'd1) && (cell_x >= 4'd10) && (cell_y >= (4'd15 - cell_x)) && (cell_y <= cell_x)) ||
      ((pac_dir == 2'd2) && (cell_y <= 4'd5)  && (cell_x >= cell_y) && (cell_x <= (4'd15 - cell_y))) ||
      ((pac_dir == 2'd3) && (cell_y >= 4'd10) && (cell_x >= (4'd15 - cell_y)) && (cell_x <= cell_y))
    );

  wire pac_on = board_area && pac_body && !pac_mouth;

  // ============================================================
  // Ghost shape
  // ============================================================
  wire ghost_tile = (tile_x == ghost_x) && (tile_y == ghost_y);

  wire ghost_body =
    board_area && ghost_tile &&
    (cell_x >= 4'd2) && (cell_x <= 4'd13) &&
    (cell_y >= 4'd3) && (cell_y <= 4'd13);

  wire ghost_eye_l =
    board_area && ghost_tile &&
    (cell_x >= 4'd4) && (cell_x <= 4'd5) &&
    (cell_y >= 4'd5) && (cell_y <= 4'd6);

  wire ghost_eye_r =
    board_area && ghost_tile &&
    (cell_x >= 4'd10) && (cell_x <= 4'd11) &&
    (cell_y >= 4'd5) && (cell_y <= 4'd6);

  wire ghost_on = ghost_body;

  // ============================================================
  // Dot shape
  // ============================================================
  wire dot_on =
    board_area &&
    !tile_wall &&
    tile_dot &&
    (cell_x >= 4'd6) && (cell_x <= 4'd9) &&
    (cell_y >= 4'd6) && (cell_y <= 4'd9);

  // ============================================================
  // Wall shape
  // ============================================================
  wire wall_on = board_area && tile_wall;

  wire wall_inner =
    wall_on &&
    (cell_x >= 4'd1) && (cell_x <= 4'd14) &&
    (cell_y >= 4'd1) && (cell_y <= 4'd14);

  wire floor_on = board_area && !tile_wall;

  // ============================================================
  // Overlays
  // ============================================================
  wire game_over_bar =
    (pix_y >= 10'd220) && (pix_y < 10'd260) &&
    (pix_x >= 10'd180) && (pix_x < 10'd460);

  wire win_bar =
    (pix_y >= 10'd220) && (pix_y < 10'd260) &&
    (pix_x >= 10'd180) && (pix_x < 10'd460);

  // ============================================================
  // Coloring
  // ============================================================
  always @(*) begin
    R = 2'b00;
    G = 2'b00;
    B = 2'b00;

    if (video_active) begin
      R = 2'b00; G = 2'b00; B = 2'b00;

      if (floor_on) begin
        R = 2'b00; G = 2'b00; B = 2'b01;
      end

      if (wall_on) begin
        R = 2'b00; G = 2'b00; B = 2'b11;
      end

      if (wall_inner) begin
        R = 2'b00; G = 2'b01; B = 2'b11;
      end

      if (dot_on) begin
        R = 2'b11; G = 2'b11; B = 2'b11;
      end

      if (pac_on) begin
        R = 2'b11; G = 2'b11; B = 2'b00;
      end

      if (ghost_on) begin
        R = 2'b11; G = 2'b00; B = 2'b11;
      end

      if (ghost_eye_l || ghost_eye_r) begin
        R = 2'b11; G = 2'b11; B = 2'b11;
      end

      if (game_over && game_over_bar) begin
        R = 2'b11; G = 2'b00; B = 2'b00;
      end

      if (win && win_bar) begin
        R = 2'b00; G = 2'b11; B = 2'b00;
      end
    end
  end

endmodule