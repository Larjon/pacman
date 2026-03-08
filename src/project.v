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
  // 10x10 tiles, each tile 25x25 pixels => 250x250 total
  // Centered similarly to the 8x8 version
  // ============================================================
  localparam [9:0] BOARD_X = 10'd195;
  localparam [9:0] BOARD_Y = 10'd115;
  localparam [9:0] BOARD_W = 10'd250;
  localparam [9:0] BOARD_H = 10'd250;

  // ============================================================
  // Game state
  // ============================================================
  reg [3:0] pac_x;
  reg [3:0] pac_y;
  reg [1:0] pac_dir;
  reg [1:0] want_dir;
  reg [2:0] move_div;

  reg [3:0] ghost_x;
  reg [3:0] ghost_y;
  reg [1:0] ghost_dir;
  reg [2:0] ghost_div;

  reg game_over;
  reg win;

  reg [9:0] dots [0:9];

  // ============================================================
  // Wall map
  // 1 = wall
  // ============================================================
  function wall_at;
    input [3:0] tx;
    input [3:0] ty;
    reg [9:0] row;
    begin
      case (ty)
        4'd0: row = 10'b1111111111;
        4'd1: row = 10'b1001001001;
        4'd2: row = 10'b1010110101;
        4'd3: row = 10'b1000000001;
        4'd4: row = 10'b1011111101;
        4'd5: row = 10'b1000000001;
        4'd6: row = 10'b1010110101;
        4'd7: row = 10'b1001001001;
        4'd8: row = 10'b1000000001;
        default: row = 10'b1111111111;
      endcase
      wall_at = row[tx];
    end
  endfunction

  // ============================================================
  // Dot read helper
  // ============================================================
  function dot_at;
    input [3:0] tx;
    input [3:0] ty;
    begin
      dot_at = dots[ty][tx];
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
      2'd0: if (pac_x != 4'd0) try_x = pac_x - 4'd1;
      2'd1: if (pac_x != 4'd9) try_x = pac_x + 4'd1;
      2'd2: if (pac_y != 4'd0) try_y = pac_y - 4'd1;
      default: if (pac_y != 4'd9) try_y = pac_y + 4'd1;
    endcase
  end

  always @(*) begin
    step_x = pac_x;
    step_y = pac_y;

    case (pac_dir)
      2'd0: if (pac_x != 4'd0) step_x = pac_x - 4'd1;
      2'd1: if (pac_x != 4'd9) step_x = pac_x + 4'd1;
      2'd2: if (pac_y != 4'd0) step_y = pac_y - 4'd1;
      default: if (pac_y != 4'd9) step_y = pac_y + 4'd1;
    endcase
  end

  wire want_ok = !wall_at(try_x, try_y);
  wire step_ok = !wall_at(step_x, step_y);

  wire [3:0] pac_next_x = want_ok ? try_x : (step_ok ? step_x : pac_x);
  wire [3:0] pac_next_y = want_ok ? try_y : (step_ok ? step_y : pac_y);

  // ============================================================
  // Ghost movement helpers - cheap version
  // ============================================================
  reg [3:0] ghost_nx;
  reg [3:0] ghost_ny;

  reg [3:0] g_left_x,  g_left_y;
  reg [3:0] g_right_x, g_right_y;
  reg [3:0] g_up_x,    g_up_y;
  reg [3:0] g_down_x,  g_down_y;

  wire g_left_ok;
  wire g_right_ok;
  wire g_up_ok;
  wire g_down_ok;
  wire ghost_step_ok;

  reg [3:0] ghost_next_x;
  reg [3:0] ghost_next_y;
  reg [1:0] ghost_next_dir;

  always @(*) begin
    ghost_nx = ghost_x;
    ghost_ny = ghost_y;

    case (ghost_dir)
      2'd0: if (ghost_x != 4'd0) ghost_nx = ghost_x - 4'd1;
      2'd1: if (ghost_x != 4'd9) ghost_nx = ghost_x + 4'd1;
      2'd2: if (ghost_y != 4'd0) ghost_ny = ghost_y - 4'd1;
      default: if (ghost_y != 4'd9) ghost_ny = ghost_y + 4'd1;
    endcase
  end

  always @(*) begin
    g_left_x  = ghost_x; g_left_y  = ghost_y;
    g_right_x = ghost_x; g_right_y = ghost_y;
    g_up_x    = ghost_x; g_up_y    = ghost_y;
    g_down_x  = ghost_x; g_down_y  = ghost_y;

    if (ghost_x != 4'd0) g_left_x  = ghost_x - 4'd1;
    if (ghost_x != 4'd9) g_right_x = ghost_x + 4'd1;
    if (ghost_y != 4'd0) g_up_y    = ghost_y - 4'd1;
    if (ghost_y != 4'd9) g_down_y  = ghost_y + 4'd1;
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
    (|dots[0]) || (|dots[1]) || (|dots[2]) || (|dots[3]) || (|dots[4]) ||
    (|dots[5]) || (|dots[6]) || (|dots[7]) || (|dots[8]) || (|dots[9]);

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

      ghost_x   <= 4'd8;
      ghost_y   <= 4'd8;
      ghost_dir <= 2'd0;
      ghost_div <= 3'd0;

      game_over <= 1'b0;
      win       <= 1'b0;

      dots[0] <= 10'b0000000000;
      dots[1] <= 10'b0110110110;
      dots[2] <= 10'b0101001010;
      dots[3] <= 10'b0111111110;
      dots[4] <= 10'b0100000010;
      dots[5] <= 10'b0101111010;
      dots[6] <= 10'b0101001010;
      dots[7] <= 10'b0110110110;
      dots[8] <= 10'b0111111110;
      dots[9] <= 10'b0000000000;

    end else if (frame_tick) begin
      if (btn_restart) begin
        pac_x    <= 4'd1;
        pac_y    <= 4'd1;
        pac_dir  <= 2'd1;
        move_div <= 3'd0;

        ghost_x   <= 4'd8;
        ghost_y   <= 4'd8;
        ghost_dir <= 2'd0;
        ghost_div <= 3'd0;

        game_over <= 1'b0;
        win       <= 1'b0;

        dots[0] <= 10'b0000000000;
        dots[1] <= 10'b0110110110;
        dots[2] <= 10'b0101001010;
        dots[3] <= 10'b0111111110;
        dots[4] <= 10'b0100000010;
        dots[5] <= 10'b0101111010;
        dots[6] <= 10'b0101001010;
        dots[7] <= 10'b0110110110;
        dots[8] <= 10'b0111111110;
        dots[9] <= 10'b0000000000;
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
  // 10x10 tiles, 25x25 each
  // ============================================================
  wire board_area =
    (pix_x >= BOARD_X) && (pix_x < (BOARD_X + BOARD_W)) &&
    (pix_y >= BOARD_Y) && (pix_y < (BOARD_Y + BOARD_H));

  wire [9:0] rel_x = pix_x - BOARD_X;
  wire [9:0] rel_y = pix_y - BOARD_Y;

  reg [3:0] tile_x;
  reg [3:0] tile_y;
  reg [9:0] cell_x;
  reg [9:0] cell_y;

  always @(*) begin
    if (rel_x < 10'd25) begin
      tile_x = 4'd0; cell_x = rel_x[4:0];
    end else if (rel_x < 10'd50) begin
      tile_x = 4'd1; cell_x = rel_x - 10'd25;
    end else if (rel_x < 10'd75) begin
      tile_x = 4'd2; cell_x = rel_x - 10'd50;
    end else if (rel_x < 10'd100) begin
      tile_x = 4'd3; cell_x = rel_x - 10'd75;
    end else if (rel_x < 10'd125) begin
      tile_x = 4'd4; cell_x = rel_x - 10'd100;
    end else if (rel_x < 10'd150) begin
      tile_x = 4'd5; cell_x = rel_x - 10'd125;
    end else if (rel_x < 10'd175) begin
      tile_x = 4'd6; cell_x = rel_x - 10'd150;
    end else if (rel_x < 10'd200) begin
      tile_x = 4'd7; cell_x = rel_x - 10'd175;
    end else if (rel_x < 10'd225) begin
      tile_x = 4'd8; cell_x = rel_x - 10'd200;
    end else begin
      tile_x = 4'd9; cell_x = rel_x - 10'd225;
    end
  end

  always @(*) begin
    if (rel_y < 10'd25) begin
      tile_y = 4'd0; cell_y = rel_y[4:0];
    end else if (rel_y < 10'd50) begin
      tile_y = 4'd1; cell_y = rel_y - 10'd25;
    end else if (rel_y < 10'd75) begin
      tile_y = 4'd2; cell_y = rel_y - 10'd50;
    end else if (rel_y < 10'd100) begin
      tile_y = 4'd3; cell_y = rel_y - 10'd75;
    end else if (rel_y < 10'd125) begin
      tile_y = 4'd4; cell_y = rel_y - 10'd100;
    end else if (rel_y < 10'd150) begin
      tile_y = 4'd5; cell_y = rel_y - 10'd125;
    end else if (rel_y < 10'd175) begin
      tile_y = 4'd6; cell_y = rel_y - 10'd150;
    end else if (rel_y < 10'd200) begin
      tile_y = 4'd7; cell_y = rel_y - 10'd175;
    end else if (rel_y < 10'd225) begin
      tile_y = 4'd8; cell_y = rel_y - 10'd200;
    end else begin
      tile_y = 4'd9; cell_y = rel_y - 10'd225;
    end
  end

  wire tile_wall = wall_at(tile_x, tile_y);
  wire tile_dot  = dot_at(tile_x, tile_y);

  // ============================================================
  // Shapes
  // Simple square sprites kept lightweight
  // ============================================================
  wire pac_on =
    board_area &&
    (tile_x == pac_x) &&
    (tile_y == pac_y) &&
    (cell_x >= 5'd5)  && (cell_x <= 5'd19) &&
    (cell_y >= 5'd5)  && (cell_y <= 5'd19);

  wire ghost_on =
    board_area &&
    (tile_x == ghost_x) &&
    (tile_y == ghost_y) &&
    (cell_x >= 5'd5)  && (cell_x <= 5'd19) &&
    (cell_y >= 5'd5)  && (cell_y <= 5'd19);

  wire dot_on =
    board_area &&
    !tile_wall &&
    tile_dot &&
    (cell_x >= 5'd11) && (cell_x <= 5'd13) &&
    (cell_y >= 5'd11) && (cell_y <= 5'd13);

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
        R = 2'b01; G = 2'b00; B = 2'b00;
      end else if (win) begin
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
