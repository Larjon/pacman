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
  // 8x8 tiles, each tile 32x32 pixels => 256x256 total
  // ============================================================
  localparam [9:0] BOARD_X = 10'd192;
  localparam [9:0] BOARD_Y = 10'd112;

  // ============================================================
  // Game state
  // ============================================================
  reg [2:0] pac_x;
  reg [2:0] pac_y;
  reg [1:0] pac_dir;
  reg [1:0] want_dir;
  reg [2:0] move_div;

  reg [2:0] ghost_x;
  reg [2:0] ghost_y;
  reg [1:0] ghost_dir;
  reg [2:0] ghost_div;

  reg game_over;
  reg win;

  reg [7:0] dots [0:7];

  // ============================================================
  // Wall map
  // 1 = wall
  // ============================================================
  function wall_at;
    input [2:0] tx;
    input [2:0] ty;
    reg [7:0] row;
    begin
      case (ty)
        3'd0: row = 8'b11111111;
        3'd1: row = 8'b10011001;
        3'd2: row = 8'b10100101;
        3'd3: row = 8'b10000001;
        3'd4: row = 8'b10111101;
        3'd5: row = 8'b10000001;
        3'd6: row = 8'b10011001;
        default: row = 8'b11111111;
      endcase
      wall_at = row[tx];
    end
  endfunction

  // ============================================================
  // Dot read helper
  // ============================================================
  function dot_at;
    input [2:0] tx;
    input [2:0] ty;
    begin
      dot_at = dots[ty][tx];
    end
  endfunction

  // ============================================================
  // Pac-Man movement helpers
  // ============================================================
  reg [2:0] try_x;
  reg [2:0] try_y;
  reg [2:0] step_x;
  reg [2:0] step_y;

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
      2'd0: if (pac_x != 3'd0) try_x = pac_x - 3'd1;
      2'd1: if (pac_x != 3'd7) try_x = pac_x + 3'd1;
      2'd2: if (pac_y != 3'd0) try_y = pac_y - 3'd1;
      default: if (pac_y != 3'd7) try_y = pac_y + 3'd1;
    endcase
  end

  always @(*) begin
    step_x = pac_x;
    step_y = pac_y;

    case (pac_dir)
      2'd0: if (pac_x != 3'd0) step_x = pac_x - 3'd1;
      2'd1: if (pac_x != 3'd7) step_x = pac_x + 3'd1;
      2'd2: if (pac_y != 3'd0) step_y = pac_y - 3'd1;
      default: if (pac_y != 3'd7) step_y = pac_y + 3'd1;
    endcase
  end

  wire want_ok = !wall_at(try_x, try_y);
  wire step_ok = !wall_at(step_x, step_y);

  wire [2:0] pac_next_x = want_ok ? try_x : (step_ok ? step_x : pac_x);
  wire [2:0] pac_next_y = want_ok ? try_y : (step_ok ? step_y : pac_y);

  // ============================================================
  // Ghost movement helpers - cheap version
  // ============================================================
  reg [2:0] ghost_nx;
  reg [2:0] ghost_ny;

  reg [2:0] g_left_x,  g_left_y;
  reg [2:0] g_right_x, g_right_y;
  reg [2:0] g_up_x,    g_up_y;
  reg [2:0] g_down_x,  g_down_y;

  wire g_left_ok;
  wire g_right_ok;
  wire g_up_ok;
  wire g_down_ok;
  wire ghost_step_ok;

  reg [2:0] ghost_next_x;
  reg [2:0] ghost_next_y;
  reg [1:0] ghost_next_dir;

  always @(*) begin
    ghost_nx = ghost_x;
    ghost_ny = ghost_y;

    case (ghost_dir)
      2'd0: if (ghost_x != 3'd0) ghost_nx = ghost_x - 3'd1;
      2'd1: if (ghost_x != 3'd7) ghost_nx = ghost_x + 3'd1;
      2'd2: if (ghost_y != 3'd0) ghost_ny = ghost_y - 3'd1;
      default: if (ghost_y != 3'd7) ghost_ny = ghost_y + 3'd1;
    endcase
  end

  always @(*) begin
    g_left_x  = ghost_x; g_left_y  = ghost_y;
    g_right_x = ghost_x; g_right_y = ghost_y;
    g_up_x    = ghost_x; g_up_y    = ghost_y;
    g_down_x  = ghost_x; g_down_y  = ghost_y;

    if (ghost_x != 3'd0) g_left_x  = ghost_x - 3'd1;
    if (ghost_x != 3'd7) g_right_x = ghost_x + 3'd1;
    if (ghost_y != 3'd0) g_up_y    = ghost_y - 3'd1;
    if (ghost_y != 3'd7) g_down_y  = ghost_y + 3'd1;
  end

  assign g_left_ok     = !wall_at(g_left_x,  g_left_y);
  assign g_right_ok    = !wall_at(g_right_x, g_right_y);
  assign g_up_ok       = !wall_at(g_up_x,    g_up_y);
  assign g_down_ok     = !wall_at(g_down_x,  g_down_y);
  assign ghost_step_ok = !wall_at(ghost_nx,  ghost_ny);

  always @(*) begin
    ghost_next_x   = ghost_x;
    ghost_next_y   = ghost_y;
    ghost_next_dir = ghost_dir;

    if (ghost_step_ok) begin
      ghost_next_x = ghost_nx;
      ghost_next_y = ghost_ny;
    end else begin
      case (ghost_dir)
        2'd0: begin
          if (g_up_ok) begin
            ghost_next_dir = 2'd2;
            ghost_next_x   = g_up_x;
            ghost_next_y   = g_up_y;
          end else if (g_down_ok) begin
            ghost_next_dir = 2'd3;
            ghost_next_x   = g_down_x;
            ghost_next_y   = g_down_y;
          end else if (g_right_ok) begin
            ghost_next_dir = 2'd1;
            ghost_next_x   = g_right_x;
            ghost_next_y   = g_right_y;
          end
        end

        2'd1: begin
          if (g_down_ok) begin
            ghost_next_dir = 2'd3;
            ghost_next_x   = g_down_x;
            ghost_next_y   = g_down_y;
          end else if (g_up_ok) begin
            ghost_next_dir = 2'd2;
            ghost_next_x   = g_up_x;
            ghost_next_y   = g_up_y;
          end else if (g_left_ok) begin
            ghost_next_dir = 2'd0;
            ghost_next_x   = g_left_x;
            ghost_next_y   = g_left_y;
          end
        end

        2'd2: begin
          if (g_right_ok) begin
            ghost_next_dir = 2'd1;
            ghost_next_x   = g_right_x;
            ghost_next_y   = g_right_y;
          end else if (g_left_ok) begin
            ghost_next_dir = 2'd0;
            ghost_next_x   = g_left_x;
            ghost_next_y   = g_left_y;
          end else if (g_down_ok) begin
            ghost_next_dir = 2'd3;
            ghost_next_x   = g_down_x;
            ghost_next_y   = g_down_y;
          end
        end

        default: begin
          if (g_left_ok) begin
            ghost_next_dir = 2'd0;
            ghost_next_x   = g_left_x;
            ghost_next_y   = g_left_y;
          end else if (g_right_ok) begin
            ghost_next_dir = 2'd1;
            ghost_next_x   = g_right_x;
            ghost_next_y   = g_right_y;
          end else if (g_up_ok) begin
            ghost_next_dir = 2'd2;
            ghost_next_x   = g_up_x;
            ghost_next_y   = g_up_y;
          end
        end
      endcase
    end
  end

  // ============================================================
  // Any dots left?
  // ============================================================
  wire any_dots =
    (|dots[0]) || (|dots[1]) || (|dots[2]) || (|dots[3]) ||
    (|dots[4]) || (|dots[5]) || (|dots[6]) || (|dots[7]);

  // ============================================================
  // Collision
  // ============================================================
  wire hit_ghost = (pac_x == ghost_x) && (pac_y == ghost_y);

  // ============================================================
  // Main game logic
  // ============================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pac_x    <= 3'd1;
      pac_y    <= 3'd1;
      pac_dir  <= 2'd1;
      move_div <= 3'd0;

      ghost_x   <= 3'd6;
      ghost_y   <= 3'd6;
      ghost_dir <= 2'd0;
      ghost_div <= 3'd0;

      game_over <= 1'b0;
      win       <= 1'b0;

      dots[0] <= 8'b00000000;
      dots[1] <= 8'b01100110;
      dots[2] <= 8'b01011010;
      dots[3] <= 8'b01111110;
      dots[4] <= 8'b01000010;
      dots[5] <= 8'b01111110;
      dots[6] <= 8'b01100110;
      dots[7] <= 8'b00000000;

    end else if (frame_tick) begin
      if (btn_restart) begin
        pac_x    <= 3'd1;
        pac_y    <= 3'd1;
        pac_dir  <= 2'd1;
        move_div <= 3'd0;

        ghost_x   <= 3'd6;
        ghost_y   <= 3'd6;
        ghost_dir <= 2'd0;
        ghost_div <= 3'd0;

        game_over <= 1'b0;
        win       <= 1'b0;

        dots[0] <= 8'b00000000;
        dots[1] <= 8'b01100110;
        dots[2] <= 8'b01011010;
        dots[3] <= 8'b01111110;
        dots[4] <= 8'b01000010;
        dots[5] <= 8'b01111110;
        dots[6] <= 8'b01100110;
        dots[7] <= 8'b00000000;
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
              pac_x <= pac_next_x;
              pac_y <= pac_next_y;

              if (dots[pac_next_y][pac_next_x])
                dots[pac_next_y][pac_next_x] <= 1'b0;
            end

            if (ghost_div == 3'd1) begin
              ghost_dir <= ghost_next_dir;
              ghost_x   <= ghost_next_x;
              ghost_y   <= ghost_next_y;
            end

            if (((move_div == 3'd0) &&
                 (pac_next_x == ghost_x) &&
                 (pac_next_y == ghost_y)) ||
                ((ghost_div == 3'd1) &&
                 (pac_x == ghost_next_x) &&
                 (pac_y == ghost_next_y))) begin
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
  // 8x8 tiles, 32x32 each
  // ============================================================
  wire board_area =
    (pix_x >= BOARD_X) && (pix_x < (BOARD_X + 10'd256)) &&
    (pix_y >= BOARD_Y) && (pix_y < (BOARD_Y + 10'd256));

  wire [9:0] rel_x = pix_x - BOARD_X;
  wire [9:0] rel_y = pix_y - BOARD_Y;

  wire [2:0] tile_x = rel_x[7:5];
  wire [2:0] tile_y = rel_y[7:5];

  wire [4:0] cell_x = rel_x[4:0];
  wire [4:0] cell_y = rel_y[4:0];

  wire tile_wall = wall_at(tile_x, tile_y);
  wire tile_dot  = dot_at(tile_x, tile_y);

  // ============================================================
  // Shapes
  // ============================================================
  wire pac_on =
    board_area &&
    (tile_x == pac_x) &&
    (tile_y == pac_y) &&
    (cell_x >= 5'd6)  && (cell_x <= 5'd25) &&
    (cell_y >= 5'd6)  && (cell_y <= 5'd25);

  wire ghost_on =
    board_area &&
    (tile_x == ghost_x) &&
    (tile_y == ghost_y) &&
    (cell_x >= 5'd6)  && (cell_x <= 5'd25) &&
    (cell_y >= 5'd6)  && (cell_y <= 5'd25);

  wire dot_on =
    board_area &&
    !tile_wall &&
    tile_dot &&
    (cell_x >= 5'd15) && (cell_x <= 5'd16) &&
    (cell_y >= 5'd15) && (cell_y <= 5'd16);

  wire wall_on  = board_area && tile_wall;
  wire floor_on = board_area && !tile_wall;

  // ============================================================
  // Coloring
  // ============================================================
  always @(*) begin
    R = 2'b00;
    G = 2'b00;
    B = 2'b00;

    if (video_active) begin
      if (game_over) begin
        // ciemnoczerwone tło przy przegranej
        R = 2'b01; G = 2'b00; B = 2'b00;
      end else if (win) begin
        // ciemnozielone tło przy wygranej
        R = 2'b00; G = 2'b01; B = 2'b00;
      end else if (ghost_on) begin
        R = 2'b11; G = 2'b00; B = 2'b11;
      end else if (pac_on) begin
        R = 2'b11; G = 2'b11; B = 2'b00;
      end else if (dot_on) begin
        R = 2'b11; G = 2'b11; B = 2'b11;
      end else if (wall_on) begin
        R = 2'b00; G = 2'b00; B = 2'b11;
      end else if (floor_on) begin
        R = 2'b00; G = 2'b00; B = 2'b01;
      end
    end
  end

endmodule