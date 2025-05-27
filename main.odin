package main

import "core:fmt"
import sdl "vendor:sdl3"
import sdlImage "vendor:sdl3/image"

// ------------------------------------------------------------------------------------------------
// Datastructures
// ------------------------------------------------------------------------------------------------

Entity :: struct {
	texture:     ^sdl.Texture,
	destination: sdl.FRect,
	health:      i32,
}

Game :: struct {
	// Context
	perfFrequency:   f64,
	window:          ^sdl.Window,
	renderer:        ^sdl.Renderer,

	// Laser
	laser:           [MAX_LASERS]Entity,
	fire:            bool,
	ticksSinceFired: i32,

	// Player 
	player:          Entity,
	left:            bool,
	right:           bool,
	up:              bool,
	down:            bool,
}

// ------------------------------------------------------------------------------------------------
// Constants
// ------------------------------------------------------------------------------------------------

TICKS_BETWEEN_SHOTS :: 20
MAX_LASERS :: (60 / TICKS_BETWEEN_SHOTS) * 2

MOVEMENT_AMOUNT :: 5
PLAYER_SPEED :: 400
LASER_SPEED :: 700

TARGET_DELTA_TIME :: 1000 / 60

WINDOW_WIDTH :: 1600
WINDOW_HEIGHT :: 960

// ------------------------------------------------------------------------------------------------
// Globals
// ------------------------------------------------------------------------------------------------

game: Game

// ------------------------------------------------------------------------------------------------
// Sdl setup and mainloop
// ------------------------------------------------------------------------------------------------

main :: proc() {
	initWindow()
	defer cleanup()
	createEntities()
	mainLoop()
}

mainLoop :: proc() {
	getTime := proc() -> f64 {
		return f64(sdl.GetPerformanceCounter()) * 1000 / game.perfFrequency
	}

	// Enforce a framerate on our game 
	game.perfFrequency = f64(sdl.GetPerformanceFrequency())
	start: f64
	end: f64

	event: sdl.Event
	state: [^]u8

	for {
		start = getTime()

		if exitGame := userInput(&event); exitGame {
			return
		}
		updateAssets()
		draw()

		end = getTime()

		// Loop lock to hit our framerate, around 17ms must have passed before moving onto the
		// next frame
		for end - start < TARGET_DELTA_TIME {
			end = getTime()
		}

		game.ticksSinceFired += 1
	}
}

// ------------------------------------------------------------------------------------------------
// Free memory 
// ------------------------------------------------------------------------------------------------

cleanup :: proc() {
	sdl.DestroyWindow(game.window)
	sdl.DestroyRenderer(game.renderer)
	sdl.Quit()
}

// ------------------------------------------------------------------------------------------------
// Load Textures - note increase of scale factor reduces image size. 0 = original size
// ------------------------------------------------------------------------------------------------

createEntities :: proc() {
	destination := sdl.FRect {
		x = 20,
		y = WINDOW_WIDTH / 2,
	}

	// Load player texture
	playerTexture := sdlImage.LoadTexture(game.renderer, "./assets/player.png")
	assert(
		playerTexture != nil,
		fmt.tprintf(
			"error: sdlImage.LoadTexture() failed while loading playerTexture: %v",
			sdl.GetError(),
		),
	)

	playerScaleFactor: f32 = 10
	game.player = Entity {
		texture     = playerTexture,
		destination = destination,
		health      = 10,
	}
	game.player.destination.w = f32(playerTexture.w) / playerScaleFactor
	game.player.destination.h = f32(playerTexture.h) / playerScaleFactor

	// Load laser texture
	laserScaleFactor: f32 = 3
	laserTexture := sdlImage.LoadTexture(game.renderer, "./assets/bulletOrange.png")
	assert(
		playerTexture != nil,
		fmt.tprintf(
			"error: sdlImage.LoadTexture() failed while loading laserTexture: %v",
			sdl.GetError(),
		),
	)

	for i in 0 ..< MAX_LASERS {
		newLaser := Entity {
			texture     = laserTexture,
			destination = destination,
		}
		newLaser.destination.w = f32(laserTexture.w) / laserScaleFactor
		newLaser.destination.h = f32(laserTexture.h) / laserScaleFactor

		game.laser[i] = newLaser
	}
}

// ------------------------------------------------------------------------------------------------
// Draw assets onto the screen
// ------------------------------------------------------------------------------------------------

draw :: proc() {
	// Render assets
	sdl.RenderTexture(game.renderer, game.player.texture, nil, &game.player.destination)

	for i in 0 ..< MAX_LASERS {
		if game.laser[i].health > 0 {
			sdl.RenderTexture(
				game.renderer,
				game.laser[i].texture,
				nil,
				&game.laser[i].destination,
			)
		}
	}

	// Clears the render so it starts with a blank slate for next frame
	sdl.RenderPresent(game.renderer)
	sdl.SetRenderDrawColor(game.renderer, 0, 0, 0, 100) // Background colour 
	sdl.RenderClear(game.renderer)
}

// ------------------------------------------------------------------------------------------------
// Initalize SDL 
// ------------------------------------------------------------------------------------------------

initWindow :: proc() {
	assert(sdl.Init({.VIDEO}), fmt.tprintf("error: sdl.Init() failed: %v", string(sdl.GetError())))

	game.window = sdl.CreateWindow("Odin space shooter", WINDOW_WIDTH, WINDOW_HEIGHT, nil)
	assert(
		game.window != nil,
		fmt.tprintf("error: sdl.CreateWindow() failed: %v", string(sdl.GetError())),
	)

	game.renderer = sdl.CreateRenderer(game.window, nil)
	assert(
		game.renderer != nil,
		fmt.tprintf("error: sld.CreateRenderer() failed: %v", string(sdl.GetError())),
	)
}

// ------------------------------------------------------------------------------------------------
// Update assets
// ------------------------------------------------------------------------------------------------

updateAssets :: proc() {
	movePlayer := proc(x: f32, y: f32) {
		// Clamp keeps a number within a range
		game.player.destination.x = clamp(
			game.player.destination.x + x,
			0,
			WINDOW_WIDTH - game.player.destination.w,
		)
		game.player.destination.y = clamp(
			game.player.destination.y + y,
			0,
			WINDOW_HEIGHT - game.player.destination.h,
		)
	}

	// Unlink Movement and framerate
	getDeltaMotion := proc(speed: f32) -> f32 {
		return speed * (f32(TARGET_DELTA_TIME) / 1000)
	}

	if game.left {
		movePlayer(-getDeltaMotion(PLAYER_SPEED), 0)
	}
	if game.right {
		movePlayer(getDeltaMotion(PLAYER_SPEED), 0)
	}
	if game.up {
		movePlayer(0, -getDeltaMotion(PLAYER_SPEED))
	}
	if game.down {
		movePlayer(0, getDeltaMotion(PLAYER_SPEED))
	}

	if game.fire && game.ticksSinceFired >= TICKS_BETWEEN_SHOTS {
		for i in 0 ..< MAX_LASERS {
			if game.laser[i].health == 0 {
				game.laser[i].destination.x = game.player.destination.x + 30
				game.laser[i].destination.y = game.player.destination.y
				game.laser[i].health = 1
				game.ticksSinceFired = 0
				break
			}
		}
	}


	for i in 0 ..< MAX_LASERS {
		if game.laser[i].health > 0 {
			game.laser[i].destination.x += getDeltaMotion(LASER_SPEED)

			if game.laser[i].destination.x > WINDOW_WIDTH {
				game.laser[i].health = 0
			}
		}
	}
}

// ------------------------------------------------------------------------------------------------
// User input
// ------------------------------------------------------------------------------------------------

userInput :: proc(event: ^sdl.Event) -> bool {
	keyboardState := sdl.GetKeyboardState(nil)

	for sdl.PollEvent(event) {
		#partial switch event.type {
		case sdl.EventType.QUIT:
			return true

		case sdl.EventType.KEY_DOWN:
			#partial switch event.key.scancode {
			case .ESCAPE:
				return true
			}
		}
	}

	game.left = keyboardState[sdl.Scancode.A]
	game.right = keyboardState[sdl.Scancode.D]
	game.up = keyboardState[sdl.Scancode.W]
	game.down = keyboardState[sdl.Scancode.S]
	game.fire = keyboardState[sdl.Scancode.SPACE]

	return false
}

// ------------------------------------------------------------------------------------------------
