#import "Basic";
#import "Math";

rl :: #import "raylib";

WINDOW_SIZE :: 1000;
GRID_WIDTH :: 20;
CELL_SIZE :: 16;
CANVAS_SIZE :: GRID_WIDTH * CELL_SIZE;
MAX_SNAKE_LENGTH :: GRID_WIDTH * GRID_WIDTH;
TICK_RATE :: 0.13;

snake: [MAX_SNAKE_LENGTH]Vector2i;
snake_length: int;
tick_timer: float32 = TICK_RATE;
move_direction := Vector2i.{ 1, 0 };
game_over := false;
food_pos: Vector2i;

Vector2i :: struct {
	x, y: int;
}

operator + :: (a: Vector2i, b: Vector2i) -> Vector2i {
	return .{ a.x + b.x, a.y + b.y };
}

operator - :: (a: Vector2i, b: Vector2i) -> Vector2i {
	return .{ a.x - b.x, a.y - b.y };
}

operator == :: (a: Vector2i, b: Vector2i) -> bool {
	return a.x == b.x && a.y == b.y;
}

restart :: () {
	snake_length = 3;
	start_head_pos := Vector2i.{ GRID_WIDTH / 2, GRID_WIDTH / 2 };
	snake[0] = start_head_pos;
	snake[1] = .{ snake[0].x - 1, snake[0].y };
	snake[2] = .{ snake[1].x - 1, snake[1].y };
	
	game_over = false;

	move_direction = .{ 1, 0 };

	spawn_food();
}


spawn_food :: () {
	occupied: [GRID_WIDTH][GRID_WIDTH]bool;

	for 0..snake_length-1 {
		occupied[snake[it].x][snake[it].y] = true;
	}

	free_cells: [..]Vector2i;

	for i: 0..GRID_WIDTH-1 {
		for j: 0..GRID_WIDTH-1 {
			if !occupied[i][j] {
				array_add(*free_cells, .{ i, j });
			}
		}
	}

	if free_cells.count > 0 {
		index := rl.GetRandomValue(0, cast(s32) free_cells.count-1);
		food_pos = free_cells[index];
	}

	free(free_cells.data);
}

main :: () {
	rl.SetConfigFlags(.FLAG_VSYNC_HINT);

	rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "Snake!");
	rl.InitAudioDevice();

	restart();

	food_texture := rl.LoadTexture("assets/food.png");
	head_texture := rl.LoadTexture("assets/head.png");
	body_texture := rl.LoadTexture("assets/body.png");
	tail_texture := rl.LoadTexture("assets/tail.png");

	eat_sound   := rl.LoadSound("assets/eat.wav");
	crash_sound := rl.LoadSound("assets/crash.wav");

	while !rl.WindowShouldClose() {
		
		if rl.IsKeyDown(.KEY_UP) {
			move_direction = { 0, -1 };
		}

		if rl.IsKeyDown(.KEY_DOWN) {
			move_direction = { 0, 1 };
		}

		if rl.IsKeyDown(.KEY_RIGHT) {
			move_direction = { 1, 0 };
		}

		if rl.IsKeyDown(.KEY_LEFT) {
			move_direction = { -1, 0 };
		}

		if game_over {
			if rl.IsKeyDown(.KEY_ENTER) {
				restart();
			}
		} else {
			tick_timer -= rl.GetFrameTime();
		}

		if tick_timer <= 0 {
			next_part_pos := snake[0];
			snake[0] += move_direction;

			head := snake[0];
			if head.x < 0 || head.x >= GRID_WIDTH || head.y < 0 || head.y >= GRID_WIDTH {
				rl.PlaySound(crash_sound);
				game_over = true;
			}

			for 1..snake_length-1 {
				curr_pos := snake[it];

				// Check if the snake is eating itself.
				if curr_pos == head {
					rl.PlaySound(crash_sound);
					game_over = true;
				}

				snake[it] = next_part_pos;
				next_part_pos = curr_pos;
			}

			// Eating...
			if head.x == food_pos.x && head.y == food_pos.y {
				snake_length += 1;
				snake[snake_length-1] = next_part_pos;
				spawn_food();

				rl.PlaySound(eat_sound);
			}
			
			tick_timer = TICK_RATE + tick_timer;
		}

		rl.BeginDrawing();
		rl.ClearBackground(.{76, 53, 83, 255});

		camera := rl.Camera2D.{
			zoom = cast(float)WINDOW_SIZE / CANVAS_SIZE
		};

		rl.BeginMode2D(camera);

		// Draw the snake.
		for 0..snake_length-1 {
			snake_x := cast(float) (snake[it].x * CELL_SIZE + 0.5 * CELL_SIZE);
			snake_y := cast(float) (snake[it].y * CELL_SIZE + 0.5 * CELL_SIZE);

			part_texture := body_texture;
			dir: Vector2i;

			if it == 0 {
				part_texture = head_texture;
				dir = snake[it] - snake[it + 1];
			} else if it == snake_length-1 {
				part_texture = tail_texture;
				dir = snake[it - 1] - snake[it];
			} else {
				dir = snake[it - 1] - snake[it];
			}

			rot := atan2(cast(float64) dir.y, cast(float64) dir.x) * (180 / PI);

			rl.DrawTexturePro(part_texture, 
				.{ 0, 0, cast(float) part_texture.width, cast(float) part_texture.height },
				.{ snake_x, snake_y, CELL_SIZE, CELL_SIZE },
				.{ CELL_SIZE, CELL_SIZE } * 0.5,
				xx rot,
				rl.WHITE
			);
		}

		if game_over {
			rl.DrawText("Game Over!", 4, 4, 25, rl.RED);
			rl.DrawText("Press Enter to play again", 4, 30, 15, rl.BLACK);
		}

		// Draw the score counter.
		score_text := sprint("Score: %", snake_length - 3);
		rl.DrawText(to_c_string(score_text), 4, CANVAS_SIZE - 14, 10, rl.RAYWHITE);
		free(score_text);

		// Draw the food.
		food_x := cast(float) (food_pos.x * CELL_SIZE);
		food_y := cast(float) (food_pos.y * CELL_SIZE);
		rl.DrawTexturePro(food_texture, .{ 0, 0, CELL_SIZE, CELL_SIZE }, .{ food_x, food_y, CELL_SIZE, CELL_SIZE }, .{ 0, 0 }, 0.0, rl.WHITE);

		rl.EndMode2D();
		rl.EndDrawing();
	}

	rl.UnloadTexture(food_texture);
	rl.UnloadTexture(head_texture);
	rl.UnloadTexture(body_texture);
	rl.UnloadTexture(tail_texture);

	rl.UnloadSound(eat_sound);
	rl.UnloadSound(crash_sound);

	rl.CloseAudioDevice();
	rl.CloseWindow();
}
