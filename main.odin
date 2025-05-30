package main

import "core:fmt"
import sdl "vendor:sdl3"
import sdlImage "vendor:sdl3/image"

main :: proc() {
	// ----------------------------------------------------------------------------------------------
	// Start Window
	// ----------------------------------------------------------------------------------------------

	assert(sdl.Init({.VIDEO}), fmt.tprintf("Error: sdl.Init() failed: %v", string(sdl.GetError())))

	windowWidth: f32 = 1600
	windowHeight: f32 = 900
	window := sdl.CreateWindow("Odin Space Shooter", i32(windowWidth), i32(windowHeight), nil)
	assert(
		window != nil,
		fmt.tprintf("Error: sdl.CreateWindow() failed: %v", string(sdl.GetError())),
	)

	renderer := sdl.CreateRenderer(window, nil)
	assert(
		renderer != nil,
		fmt.tprintf("Error: sdl.CreateRenderer() failed: %v", string(sdl.GetError())),
	)

	// ----------------------------------------------------------------------------------------------
	// Load Textures
	// ----------------------------------------------------------------------------------------------

	playerTexture := sdlImage.LoadTexture(renderer, "./assets/player.png")
	assert(
		playerTexture != nil,
		fmt.tprintf(
			"Error: sdlImage.LoadTexture() failed to load player texture: %v",
			string(sdl.GetError()),
		),
	)

	laserTexture := sdlImage.LoadTexture(renderer, "./assets/bulletOrange.png")
	assert(
		laserTexture != nil,
		fmt.tprintf(
			"Error: sdlImage.LoadTexture() failed to load laser texture: %v",
			string(sdl.GetError()),
		),
	)

	// ----------------------------------------------------------------------------------------------
	// Create Entities and related data 
	// ----------------------------------------------------------------------------------------------

	playerScaleFactor: f32 = 10
	playerData := sdl.FRect {
		x = 20,
		y = windowHeight / 2,
		w = f32(playerTexture.w) / playerScaleFactor,
		h = f32(playerTexture.h) / playerScaleFactor,
	}

	maxLasers :: 10
	laserScaleFactor: f32 = 3
	laserDataWidth := f32(laserTexture.w) / laserScaleFactor
	laserDataHeight := f32(laserTexture.h) / laserScaleFactor

	laserPositions := [maxLasers]sdl.FRect{}

	for i in 0 ..< maxLasers {
		newLaserData := sdl.FRect {
			x = windowWidth + 1,
			y = windowHeight + 1,
			w = laserDataWidth,
			h = laserDataHeight,
		}
		laserPositions[i] = newLaserData
	}

	// ----------------------------------------------------------------------------------------------
	// Main loop
	// ----------------------------------------------------------------------------------------------

	playerXMax := windowWidth - playerData.w
	playerYMax := windowHeight - playerData.h

	timeDelta: f32 = 1000 / 60
	playerDeltaMovement := 400 * timeDelta / 1000
	laserDeltaMovement := 700 * timeDelta / 1000

	activePtr := byte(0)

	ticksBetweenFire: f32 = 20
	ticksSinceFire: f32 = 0

	event: sdl.Event
	keysPressed: [^]bool

	start: f32
	end: f32
	perfFrequency := f32(sdl.GetPerformanceFrequency())

	for {
		start = f32(sdl.GetPerformanceCounter()) * 1000 / perfFrequency

		// Input
		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case sdl.EventType.QUIT:
				return
			case sdl.EventType.KEY_DOWN:
				if event.key.scancode == .ESCAPE {
					return
				}
			}
		}

		keysPressed = sdl.GetKeyboardState(nil)
		if keysPressed[sdl.Scancode.A] {
			playerData.x = clamp(playerData.x - playerDeltaMovement, 0, playerXMax)
		}
		if keysPressed[sdl.Scancode.D] {
			playerData.x = clamp(playerData.x + playerDeltaMovement, 0, playerXMax)
		}
		if keysPressed[sdl.Scancode.W] {
			playerData.y = clamp(playerData.y - playerDeltaMovement, 0, playerYMax)
		}
		if keysPressed[sdl.Scancode.S] {
			playerData.y = clamp(playerData.y + playerDeltaMovement, 0, playerYMax)
		}

		ticksSinceFire -= 1

		if keysPressed[sdl.Scancode.SPACE] && ticksSinceFire <= 0 && activePtr < maxLasers {
			laserPositions[activePtr].x = playerData.x + 30
			laserPositions[activePtr].y = playerData.y
			activePtr += 1
			ticksSinceFire = ticksBetweenFire
		}


		for i in 0 ..< activePtr {
			if laserPositions[i].x > windowWidth {
				activePtr -= 1
				laserPositions[i] = laserPositions[activePtr]
			}

			laserPositions[i].x += laserDeltaMovement
		}

		// Draw
		for i in 0 ..< activePtr {
			sdl.RenderTexture(renderer, laserTexture, nil, &laserPositions[i])
		}

		sdl.RenderTexture(renderer, playerTexture, nil, &playerData)
		sdl.RenderPresent(renderer)
		sdl.SetRenderDrawColor(renderer, 0, 0, 0, 100)
		sdl.RenderClear(renderer)

		for end - start < timeDelta {
			end = f32(sdl.GetPerformanceCounter()) * 1000 / perfFrequency
		}
	}

	// ----------------------------------------------------------------------------------------------
}
