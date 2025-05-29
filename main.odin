package main

import "core:fmt"
import sdl "vendor:sdl3"
import sdlImage "vendor:sdl3/image"

// ------------------------------------------------------------------------------------------------
// Datastructures
// ------------------------------------------------------------------------------------------------

Entity :: struct {
	destination: sdl.FRect,
	health:      u8,
}

Lasers :: struct {
	active, inactive:       [MAX_LASERS]Entity,
	activeIdx, inactiveIdx: byte,
}

Game :: struct {
	// Context
	renderer:       ^sdl.Renderer,
	textures:       [TOTAL_TEXTURES]^sdl.Texture,
	keysPressed:    [^]bool,

	// Laser
	lasers:         Lasers,
	ticksUntilFire: i32,

	// Player 
	player:         Entity,
}


// ------------------------------------------------------------------------------------------------
// Globals
// ------------------------------------------------------------------------------------------------

// 60 / TICKS_PER_SHOT = lasers fired per second 
TICKS_BETWEEN_SHOTS :: 20
// Should probaby be linked to width and limited to X amount. Play around with for desired effect
MAX_LASERS :: 10

TARGET_DELTA_TIME :: 1000.0 / 60.0

PLAYER_SPEED :: 400
LASER_SPEED :: 700
LASER_DELTA_SPEED :: LASER_SPEED * TARGET_DELTA_TIME / 1000
PLAYER_DELTA_SPEED :: PLAYER_SPEED * TARGET_DELTA_TIME / 1000

WINDOW_WIDTH :: 1600
WINDOW_HEIGHT :: 960

// We use this as essentially constant ptrs into our texture ptr array
TOTAL_TEXTURES :: byte(2)
PLAYER_TEXTURE_IDX :: 0
LASER_TEXTURE_IDX :: 1

game: Game

// ------------------------------------------------------------------------------------------------
// Sdl setup and mainloop
// ------------------------------------------------------------------------------------------------

main :: proc() {
	window := initWindow()
	defer cleanup(window)
	createEntities()
	mainLoop()
}

mainLoop :: proc() {
	getTime := #force_inline proc(perfFrequency: f64) -> f64 {
		return f64(sdl.GetPerformanceCounter()) * 1000 / perfFrequency
	}

	// Enforce a framerate on our game 
	start: f64
	end: f64
	perfFrequency := f64(sdl.GetPerformanceFrequency())

	event: sdl.Event

	for {
		start = getTime(perfFrequency)

		if exitGame := userInput(&event); exitGame {
			return
		}
		updateAssets()
		draw()

		end = getTime(perfFrequency)

		// Loop lock to hit our framerate, around 17ms must have passed before moving onto the
		// next frame
		for end - start < TARGET_DELTA_TIME {
			end = getTime(perfFrequency)
		}
	}
}

// ------------------------------------------------------------------------------------------------
// Free memory 
// ------------------------------------------------------------------------------------------------

cleanup :: proc(window: ^sdl.Window) {
	sdl.DestroyWindow(window)
	sdl.DestroyRenderer(game.renderer)
	sdl.Quit()
}

// ------------------------------------------------------------------------------------------------
// Load Textures - note increase of scale factor reduces image size. 0 = original size
// ------------------------------------------------------------------------------------------------

createEntities :: proc() {
	// Player
	game.textures[PLAYER_TEXTURE_IDX] = sdlImage.LoadTexture(game.renderer, "./assets/player.png")
	assert(
		game.textures[PLAYER_TEXTURE_IDX] != nil,
		fmt.tprintf(
			"error: sdlImage.LoadTexture() failed while loading playerTexture: %v",
			sdl.GetError(),
		),
	)

	playerScaleFactor :: 10
	game.player = Entity {
		destination = sdl.FRect {
			x = 20,
			y = WINDOW_WIDTH / 2,
			w = f32(game.textures[PLAYER_TEXTURE_IDX].w) / playerScaleFactor,
			h = f32(game.textures[PLAYER_TEXTURE_IDX].h) / playerScaleFactor,
		},
		health = 10,
	}

	// Lasers
	game.textures[LASER_TEXTURE_IDX] = sdlImage.LoadTexture(
		game.renderer,
		"./assets/bulletOrange.png",
	)
	assert(
		game.textures[LASER_TEXTURE_IDX] != nil,
		fmt.tprintf(
			"error: sdlImage.LoadTexture() failed while loading laserTexture: %v",
			sdl.GetError(),
		),
	)

	laserScaleFactor :: 3
	laserDestWidth := f32(game.textures[LASER_TEXTURE_IDX].w) / laserScaleFactor
	laserDestHeight := f32(game.textures[LASER_TEXTURE_IDX].h) / laserScaleFactor
	laserStartingX := f32(WINDOW_WIDTH + 1)

	for i in 0 ..< MAX_LASERS {
		newLaser := Entity {
			destination = {
				x = laserStartingX,
				y = WINDOW_HEIGHT,
				w = laserDestWidth,
				h = laserDestHeight,
			},
		}
		game.lasers.inactive[i] = newLaser
		game.lasers.active[i] = newLaser
		game.lasers.inactiveIdx += 1
	}
}

// ------------------------------------------------------------------------------------------------
// Draw assets onto the screen
// ------------------------------------------------------------------------------------------------

draw :: #force_inline proc() {
	sdl.RenderTexture(
		game.renderer,
		game.textures[PLAYER_TEXTURE_IDX],
		nil,
		&game.player.destination,
	)

	for i in 0 ..< game.lasers.activeIdx {
		sdl.RenderTexture(
			game.renderer,
			game.textures[LASER_TEXTURE_IDX],
			nil,
			&game.lasers.active[i].destination,
		)
	}

	// Clears the render so it starts with a blank slate for next frame
	sdl.RenderPresent(game.renderer)
	sdl.SetRenderDrawColor(game.renderer, 0, 0, 0, 100) // Background colour 
	sdl.RenderClear(game.renderer)
}

// ------------------------------------------------------------------------------------------------
// Initalize SDL 
// ------------------------------------------------------------------------------------------------

initWindow :: proc() -> ^sdl.Window {
	assert(sdl.Init({.VIDEO}), fmt.tprintf("error: sdl.Init() failed: %v", string(sdl.GetError())))

	window := sdl.CreateWindow("Odin space shooter", WINDOW_WIDTH, WINDOW_HEIGHT, nil)
	assert(
		window != nil,
		fmt.tprintf("error: sdl.CreateWindow() failed: %v", string(sdl.GetError())),
	)

	game.renderer = sdl.CreateRenderer(window, nil)
	assert(
		game.renderer != nil,
		fmt.tprintf("error: sld.CreateRenderer() failed: %v", string(sdl.GetError())),
	)

	return window
}

// ------------------------------------------------------------------------------------------------
// Update
// ------------------------------------------------------------------------------------------------

updateAssets :: #force_inline proc() {
	// Player
	movePlayer := #force_inline proc(x: f32, y: f32) {
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

	if game.keysPressed[sdl.Scancode.A] {
		movePlayer(-PLAYER_DELTA_SPEED, 0)
	}
	if game.keysPressed[sdl.Scancode.D] {
		movePlayer(PLAYER_DELTA_SPEED, 0)
	}
	if game.keysPressed[sdl.Scancode.W] {
		movePlayer(0, -PLAYER_DELTA_SPEED)
	}
	if game.keysPressed[sdl.Scancode.S] {
		movePlayer(0, PLAYER_DELTA_SPEED)
	}

	// Laser
	if game.keysPressed[sdl.Scancode.SPACE] &&
	   game.ticksUntilFire <= 0 &&
	   game.lasers.activeIdx < MAX_LASERS {

		game.lasers.active[game.lasers.activeIdx].destination.x = game.player.destination.x + 30
		game.lasers.active[game.lasers.activeIdx].destination.y = game.player.destination.y

		game.lasers.inactiveIdx -= 1
		game.lasers.activeIdx += 1

		game.ticksUntilFire = TICKS_BETWEEN_SHOTS
	}

	// Using 2 loops prevents a very subtle bug where swapping the last element
	// prevents a single tick of update for that element. Note this approach can give lasers
  // off the screen an extra tick of movement. 
	for i in 0 ..< game.lasers.activeIdx {
		game.lasers.active[i].destination.x += LASER_DELTA_SPEED
	}

	for i in 0 ..< game.lasers.activeIdx {
		if game.lasers.active[i].destination.x > WINDOW_WIDTH {
			game.lasers.inactiveIdx += 1
			game.lasers.activeIdx -= 1
			game.lasers.active[i] = game.lasers.active[game.lasers.activeIdx]
		}
	}

	game.ticksUntilFire -= 1
}

// ------------------------------------------------------------------------------------------------
// User input
// ------------------------------------------------------------------------------------------------

userInput :: #force_inline proc(event: ^sdl.Event) -> bool {
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

	game.keysPressed = sdl.GetKeyboardState(nil)

	return false
}

// ------------------------------------------------------------------------------------------------
