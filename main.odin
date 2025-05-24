package main

import fmt "core:fmt"
import m "core:math/linalg/hlsl"
// Odin ships with built in vendor libraries instead of a package manager.
// This ensure that developers know what's being used in their projects
// and helps ward off time in "dependancy hell."
import rl "vendor:raylib"
import rand "core:math/rand"
import la "core:math/linalg"
import "core:strings"


// Create game structs: paddles and ball.
Paddle :: struct{
	p : m.float2,
	score : int,
	dim : m.int2,
}
Ball :: struct{
	p : m.float2,
	v : m.float2,
}

player1 : Paddle
player2 : Paddle
ball : Ball

// Sound
boop_sound: rl.Sound;
bang_sound: rl.Sound;

main :: proc(){
	// Setup window
	window_dim := m.int2{800, 600}
	rl.InitWindow(window_dim.x, window_dim.y, "Pong")
	rl.InitAudioDevice()
	rl.SetTargetFPS(60)
	is_running := true


	// Set sound
	boop_sound = rl.LoadSound("Assets/boop.wav")
	bang_sound = rl.LoadSound("Assets/bang.wav")

	init_match(&ball, &player1, &player2, window_dim)

	// Sets the speed of the game. The bigger the number, the faster.
	current_speed :f32= 8.0

	for is_running && !rl.WindowShouldClose(){
		// Main game loop
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)


		// Integration of velocity.
		ball.p += (ball.v * current_speed) // notice how velocity implimentation scales off of game speed.

		// Wall collision logic. Sees it x or y coordinate is in violation
		// then mirrors if it is.
		if ball.p.x < 0{
			ball.p.x = 0
			ball.v.x = -ball.v.x
			rl.PlaySound(bang_sound)
		}else if ball.p.x > f32(window_dim.x){
			ball.p.x = f32(window_dim.x)
			ball.v.x = -ball.v.x
			rl.PlaySound(bang_sound)
		}else if ball.p.y < 0{
			ball.p.y = 0
			ball.v.y = -ball.v.y
			rl.PlaySound(bang_sound)
		}else if ball.p.y > f32(window_dim.y){
			ball.p.y = f32(window_dim.y)
			ball.v.y = -ball.v.y
			rl.PlaySound(bang_sound)
		}

		// Paddle movement
		if rl.IsKeyDown(rl.KeyboardKey.W){
			player1.p.y -= current_speed
		}else if rl.IsKeyDown(rl.KeyboardKey.S){
			player1.p.y += current_speed
		}

		if rl.IsKeyDown(rl.KeyboardKey.UP){
			player2.p.y -= current_speed
		}else if rl.IsKeyDown(rl.KeyboardKey.DOWN){
			player2.p.y += current_speed
		}

		// Collision with border
		enforce_paddle_bounds_move(&player1, window_dim)
		enforce_paddle_bounds_move(&player2, window_dim)

		// Collision with paddles
		paddle_ball_collision_detection(&ball, player1)
		paddle_ball_collision_detection(&ball, player2)

		
		// Score checking
		if ball.p.x < 1{
			player2.score += 1
			init_match(&ball, &player1, &player2, window_dim)

		}
		if ball.p.x > f32(window_dim.x) - 1{
			player1.score += 1
			init_match(&ball, &player1, &player2, window_dim)
		}

		// Draw paddle and ball
		draw_paddle(player1)
		draw_paddle(player2)
		rl.DrawRectangle(i32(ball.p.x), i32(ball.p.y), 10, 10, rl.WHITE)

		// Scoreboard
		p1_score := strings.clone_to_cstring(fmt.tprintf("P1: %v", player1.score), context.temp_allocator)
		rl.DrawText(p1_score, 100, 100, 20, rl.DARKGRAY)

		p2_score := strings.clone_to_cstring(fmt.tprintf("P2: %v", player2.score), context.temp_allocator)
		rl.DrawText(p2_score, window_dim.x - 100, 100, 20, rl.DARKGRAY)

		if rl.IsKeyDown(rl.KeyboardKey.SEVEN){
			is_running = false
		}

		rl.EndDrawing()
	}
}

init_match :: proc(ball :^Ball, player1, player2 :^Paddle, window_dim :m.int2){
	/*
		This method initializes a pong match.
		When a point is scored, this moves everything back in place.
	*/
	// Resets positions and dimensions
	player1.p = m.float2{100.0, f32(window_dim.y/2)}
	player2.p = m.float2{f32(window_dim.x - 100.0), f32(window_dim.y/2)}
	player1.dim = m.int2{10, 60}
	player2.dim = m.int2{10, 60}

	ball.p = {f32(window_dim.x/2), f32(window_dim.y/2)}


	xdir :f32= 1.0
	randx := rand.float32_range(0.0,1.0)
	if randx > 0.5{
		xdir = -1.0
	}

	// This makes the ball start in a random direction each time.
	ball.v = la.normalize(m.float2{xdir, rand.float32_range(-0.7, 0.7)})
	fmt.println(ball.v)
}

paddle_ball_collision_detection :: proc(ball :^Ball, paddle :Paddle){
	/*
		This method checks for collison. If the ball does collide with a paddle	
		it will bounce away mirroring it's initial movement at contact.
	*/
	if ball.p.x < paddle.p.x + f32(paddle.dim.x) &&
	ball.p.x > paddle.p.x - f32(paddle.dim.x) &&
	ball.p.y < paddle.p.y + f32(paddle.dim.y) &&
	ball.p.y > paddle.p.y - f32(paddle.dim.y){
		ball.v.x = -ball.v.x
		fmt.println("Collision with paddle.")
		rl.PlaySound(boop_sound)
	}
}

draw_paddle :: proc(paddle :Paddle){
	/*
		This procedure draws the paddle. It simply takes the necessary dimensions and draws
		the paddle rectangle.
	*/
	paddle_rec := rl.Rectangle{paddle.p.x, paddle.p.y, f32(paddle.dim.x), f32(paddle.dim.y)}
	paddle_origin := la.Vector2f32{paddle_rec.width/2.0, paddle_rec.height/2.0}
	rl.DrawRectanglePro(paddle_rec, paddle_origin, 0, rl.WHITE)
}

enforce_paddle_bounds_move :: proc(paddle :^Paddle, window_dim :m.int2){
	/*
		This ensures that the paddle can't move off of the screen.
	*/
	if paddle.p.y - (f32(paddle.dim.y) / 2.0) < 0{
		paddle.p.y = (f32(paddle.dim.y)/2.0)
	}else if paddle.p.y + (f32(paddle.dim.y)/2.0) > f32(window_dim.y){
		paddle.p.y = f32(window_dim.y) - f32(paddle.dim.y/2)
	}
}