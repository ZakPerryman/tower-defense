package main

import "core:math"
import "core:math/linalg"

import "core:os"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:sort"

import "core:strings"

import "vendor:raylib"

TowerType :: enum {
    SPADES,
    DIAMONDS,
    CLUBS,
    HEARTS,
    SWORDS,
    WANDS,
    COINS,
    CUPS,
    ARCANAS
}

TowerTypeString := [TowerType]string{
    .SPADES = "SPADES",
    .DIAMONDS = "DIAMONDS",
    .CLUBS = "CLUBS",
    .HEARTS = "HEARTS",
    .SWORDS = "SWORDS",
    .WANDS = "WANDS",
    .COINS = "COINS",
    .CUPS = "CUPS",
    .ARCANAS = "ARCANAS"
}

ArcanaType :: enum {
    NONE,
    FOOL,
    MAGICIAN,
    HIGHPRIESTESS,
    EMPRESS,
    EMPEROR,
    HIEROPHANT,
    LOVERS,
    CHARIOT,
    STRENGTH,
    HERMIT,
    FORTUNE,
    JUSTICE,
    HANGEDMAN,
    DEATH,
    TEMPERANCE,
    DEVIL,
    TOWER,
    STAR,
    MOON,
    SUN,
    JUDGEMENT,
    WORLD
}

ArcanaTypeStrings := [ArcanaType]string {
    .NONE = "NONE",
    .FOOL = "FOOL",
    .MAGICIAN = "MAGICIAN",
    .HIGHPRIESTESS = "HIGHPRIESTESS",
    .EMPRESS = "EMPRESS",
    .EMPEROR = "EMPEROR",
    .HIEROPHANT = "HIEROPHANT",
    .LOVERS = "LOVERS",
    .CHARIOT = "CHARIOT",
    .STRENGTH = "STRENGTH",
    .HERMIT = "HERMIT",
    .FORTUNE = "FORTUNE",
    .JUSTICE = "JUSTICE",
    .HANGEDMAN = "HANGEDMAN",
    .DEATH = "DEATH",
    .TEMPERANCE = "TEMPERANCE",
    .DEVIL = "DEVIL",
    .TOWER = "TOWER",
    .STAR = "STAR",
    .MOON = "MOON",
    .SUN = "SUN",
    .JUDGEMENT = "JUDGEMENT",
    .WORLD = "WORLD"
}

TowerBuyInfo :: struct {
    index: int,
    cost: int,
}

TowerTargeting :: enum {
    FIRST,
    LAST,
    MOST_HEALTH,
    LEAST_HEALTH,
    FASTEST,
    SLOWEST,
}

TowerEffect :: enum {
    NONE,
    SLOW,
    PIERCE,
    CHARM,
}

Tower :: struct {
    type: TowerType,
    arcana: ArcanaType,

    x: f32,
    y: f32,

    range: f32,
    damage: f32,
    fireRate: f32,
    fireAccumulator: f32,

    targeting: TowerTargeting,
    effect: TowerEffect,
}

Mob :: struct {
    distanceAlongPath: f32,
    speed: f32,
    health: f32,
    maxHealth: f32,
    armor: f32,
    killAward: int,
    leakPenalty: int,
    baseColor: raylib.Color,
    towerPierce: f32,
    towerSlow: f32,
    towerCharm: f32,
}

EmptyBuy := TowerBuyInfo{}

GameState :: struct {
    money: int,
    leaks: int,
    kills: int,
    maxLeaks: int,
    deltaTime : f32,
    towers: [dynamic]Tower,
    mobs: [dynamic]Mob,
    path: [dynamic][2]f32,
    currentWave: int,

    wonMap: bool,
    gameOver: bool,

    currentBuyTower: TowerBuyInfo,
    lastHoverBuyTower: TowerBuyInfo,

    currentSelectedTower: int,
    lastHoverSelectedTower: int,

    wavesActive: bool,
    waveUnitAccumulator: f32,
    waveUnitCount: int,
    wavePatternCountdown: f32,
    wavePatternCount: int,

    consumedClick: bool,
}

TowerShop : []TowerBuyInfo = {
    TowerBuyInfo{
        0,
        75
    },

    TowerBuyInfo{
        1,
        25
    },

    TowerBuyInfo{
        2,
        25
    },

    TowerBuyInfo{
        3,
        25
    }
}

TowerTemplates : []Tower = {
    Tower{
        .SPADES,
        .NONE,

        0,
        0,

        64,
        15,
        0.75,
        0,
        .FIRST,
        .NONE,
    },
    Tower{
        .DIAMONDS,
        .NONE,

        0,
        0,

        64,
        1,
        0.2,
        0,
        .FIRST,
        .SLOW,
    },
    Tower{
        .CLUBS,
        .NONE,

        0,
        0,

        64,
        1,
        0.2,
        0,
        .FIRST,
        .PIERCE,
    },
    Tower{
        .HEARTS,
        .NONE,

        0,
        0,

        64,
        1,
        0.2,
        0,
        .FIRST,
        .CHARM,
    },
}

MobTemplates : []Mob = {
    Mob{
        0, 128, 10, 10, 0, 3, 1, raylib.GREEN, 0, 0, 0
    },
    Mob{
        0, 192, 5, 5, 0, 1, 1, raylib.BLUE, 0, 0, 0
    },
    Mob{
        0, 64, 45, 45, 0, 5, 1, raylib.YELLOW, 0, 0, 0
    },
    Mob{
        0, 32, 75, 75, 0, 10, 5, raylib.PINK, 0, 0, 0
    },
}

Wave :: struct {
    unitSpawnPattern: []int,
    unitDelay: f32,
    patternRepeatCount: int,
    patternRepeatDelay: f32,
    shouldStopOnFinish: bool,
}

Waves : []Wave = {
    Wave{
        {0, 0, 0, 0, 0, 0, 0, 0},
        0.2,
        8,
        0.7,
        true
    },
    Wave{
        {0, 1, 0, 1, 0, 1, 0, 1},
        0.2,
        8,
        0.7,
        false
    },
    Wave{
        {1, 2, 1, 2, 1, 2, 2, 2},
        0.2,
        8,
        0.7,
        true
    },
    Wave{
        {3, 3, 1, 1, 1, 1, 3, 3},
        0.2,
        8,
        0.7,
        true
    }
}

SpriteAtlas : raylib.Texture2D
SpriteWin : raylib.Texture2D
SpriteLose: raylib.Texture2D

reset_gamestate :: proc() -> GameState {
    gameState := GameState{}

    gameState.path = load_path()
    gameState.money = 100
    gameState.maxLeaks = 10
    gameState.deltaTime = SIM_RATE

    gameState.currentSelectedTower = -1
    gameState.lastHoverSelectedTower = -1

    return gameState
}

SIM_RATE :: 1.0 / 60.0

main :: proc() {
    raylib.InitWindow(0, 0, "Slots Tower Defense")
    raylib.ToggleFullscreen()
    gameState := reset_gamestate()

    SpriteAtlas = raylib.LoadTexture("assets/atlas.png")
    SpriteWin = raylib.LoadTexture("assets/game-win.png")
    SpriteLose = raylib.LoadTexture("assets/game-lose.png")

    simAccumulator : f32 = 0.0

    for(!raylib.WindowShouldClose()) {
        raylib.BeginDrawing()
        raylib.ClearBackground(raylib.BLANK)
        simAccumulator += raylib.GetFrameTime()
        
        if(raylib.IsMouseButtonPressed(.LEFT)) {
            gameState.consumedClick = false
            // gameState.currentSelectedTower = -1
        }

        if(!gameState.gameOver) {
            if(simAccumulator >= SIM_RATE) {
                update_towers(&gameState)
                update_mobs(&gameState)
                update_misc(&gameState)

                simAccumulator = 0.0
            }        

            render_mobs(gameState)
            render_towers(&gameState)
            render_misc(gameState)
            update_shop(&gameState)
            render_debug(gameState)
        } else {
            render_gameover(gameState)
        }

        // if(raylib.IsMouseButtonPressed(.LEFT)) {
        //     append(&gameState.path, raylib.GetMousePosition())
        //     fmt.printf("gameState.path size: %d\n", len(gameState.path))
        // }

        // if(raylib.IsKeyPressed(.F1)) {
        //     save_path(gameState.path)
        // }
        // if(raylib.IsKeyPressed(.F2)) {
        //     fmt.printf("[Gamepath]%d\n", len(gameState.path))
        //     gameState.path = load_path()
        //     fmt.printf("[Gamepath]%d\n", len(gameState.path))
        // }

        // if(raylib.IsMouseButtonPressed(.LEFT)) {
        //     append(&gameState.mobs, Mob{
        //         0, 128, 10, 10, 0, 5
        //     })
        // }

        if(raylib.IsKeyPressed(.SPACE)) {
            gameState.wavesActive = true

            if(gameState.gameOver) {
                gameState = reset_gamestate()
            }
        }

        if(raylib.IsMouseButtonPressed(.RIGHT)) {
            if(gameState.currentBuyTower != EmptyBuy && gameState.money >= gameState.currentBuyTower.cost) {
                gameState.money -= gameState.currentBuyTower.cost
                using towerCopy := TowerTemplates[gameState.currentBuyTower.index]
                towerCopy.x = cast(f32)raylib.GetMouseX()
                towerCopy.y = cast(f32)raylib.GetMouseY()
                append(&gameState.towers, towerCopy)
            }
        }

        if(!gameState.consumedClick) {
            gameState.currentSelectedTower = -1
        }

        raylib.EndDrawing()
    }

    raylib.CloseWindow()
}

save_path :: proc(path: [dynamic][2]f32) {
    handle, open_err := os.open("path.dev.bin", os.O_CREATE)

    os.write(handle, mem.any_to_bytes(len(path)))
    
    for &point in path {
        os.write(handle, slice.bytes_from_ptr(&point, size_of([2]f32)))
    }

    os.close(handle)
}

load_path :: proc() -> [dynamic][2]f32 {
    path := make([dynamic][2]f32)

    handle, open_err := os.open("path.dev.bin")
    
    fileData := make([]byte, 4096)
    dataRead, read_err := os.read(handle, fileData)
    os.close(handle)

    points := (transmute(^int)raw_data(fileData[:size_of(int)]))^
    for i in 0..<points {
        pointOffset := size_of(int) + size_of([2]f32) * i
        point := (transmute(^[2]f32)raw_data(fileData[pointOffset : pointOffset + size_of([2]f32)]))^
        append(&path, point)
    }

    return path
}

calculate_path_length :: proc(path: [dynamic][2]f32) -> (length:f32){
    for node, idx in path {
        if(idx + 1 < len(path)) {
            nextNode := path[idx + 1]

            length += linalg.distance(node, nextNode)
        }
    }

    return
}

generate_path :: proc(gameState: ^GameState) {

}

// Z is rotation
place_on_path :: proc(gameState: GameState, distanceAlongPath: f32) -> (result: [3]f32) {
    distanceCovered: f32 = 0

    for node, idx in gameState.path {
        if(idx < len(gameState.path) - 1) {
            nextNode := gameState.path[idx + 1]

            if(distanceCovered + linalg.distance(node, nextNode) < distanceAlongPath) {
                distanceCovered += linalg.distance(node, nextNode)
                continue
            }
            else
            {
                currentLinePath := distanceAlongPath - distanceCovered
                pathAngle := math.atan2(nextNode.y - node.y, nextNode.x - node.x)
                result.xy = node + {math.cos(pathAngle) * currentLinePath, math.sin(pathAngle) * currentLinePath}
                result.z = pathAngle
                return
            }
        }
        else {
            break
        }
    }

    return
}

update_towers :: proc(gameState: ^GameState) {
    for &tower, idx in gameState.towers {
        if(raylib.CheckCollisionPointCircle(raylib.GetMousePosition(), {tower.x, tower.y}, 16)) {
            gameState.lastHoverSelectedTower = idx

            if(raylib.IsMouseButtonDown(.LEFT)) {
                gameState.currentSelectedTower = idx
                gameState.consumedClick = true
            }
        }

        towerMobs := [dynamic]^Mob{}
        for &mob, idx in gameState.mobs {
            if(linalg.distance(place_on_path(gameState^, mob.distanceAlongPath).xy, [2]f32{tower.x, tower.y}) <= tower.range) {
                append(&towerMobs, &mob)
            }
        }

        towerMobList := towerMobs[:]
        towerMobListInterface := sort.slice_interface(&towerMobList)
        towerMobListInterface.swap = proc(it: sort.Interface, i, j: int) {
            tempSlice := transmute(^[]^Mob)it.collection
            tempMob : ^Mob
            tempMob = tempSlice[i]
            tempSlice[i] = tempSlice[j]
            tempSlice[j] = tempMob
        }
        
        switch(tower.targeting) {
            case .FIRST:
                towerMobListInterface.less = proc(it: sort.Interface, i, j: int) -> bool {
                    tempSlice := cast(^[]^Mob)it.collection
                    return tempSlice[i].distanceAlongPath > tempSlice[j].distanceAlongPath
                }
            case .LAST:
                towerMobListInterface.less = proc(it: sort.Interface, i, j: int) -> bool {
                    tempSlice := cast(^[]^Mob)it.collection
                    return tempSlice[i].distanceAlongPath < tempSlice[j].distanceAlongPath
                }
            case .FASTEST:
                towerMobListInterface.less = proc(it: sort.Interface, i, j: int) -> bool {
                    tempSlice := cast(^[]^Mob)it.collection
                    return tempSlice[i].speed - tempSlice[i].towerSlow > tempSlice[j].speed - tempSlice[j].towerSlow
                }
            case .SLOWEST:
                towerMobListInterface.less = proc(it: sort.Interface, i, j: int) -> bool {
                    tempSlice := cast(^[]^Mob)it.collection
                    return tempSlice[i].speed - tempSlice[i].towerSlow < tempSlice[j].speed - tempSlice[j].towerSlow
                }
            case .LEAST_HEALTH:
                towerMobListInterface.less = proc(it: sort.Interface, i, j: int) -> bool {
                    tempSlice := cast(^[]^Mob)it.collection
                    return tempSlice[i].health > tempSlice[j].health
                }
            case .MOST_HEALTH:
                towerMobListInterface.less = proc(it: sort.Interface, i, j: int) -> bool {
                    tempSlice := cast(^[]^Mob)it.collection
                    return tempSlice[i].health < tempSlice[j].health
                }
        }

        sort.sort(towerMobListInterface)

        if(len(towerMobs) > 0) {
            currentTarget := towerMobList[0]
            if(tower.fireRate <= tower.fireAccumulator) {
                towerDamage := tower.damage
                switch(tower.effect) {
                    case .NONE:
                    case .CHARM:
                        towerDamage = 0
                        currentTarget.towerCharm += tower.damage
                    case .PIERCE:
                        currentTarget.towerPierce += tower.damage * 0.2
                    case .SLOW:
                        currentTarget.towerSlow += tower.damage * 0.1
                }

                currentTarget.health -= towerDamage - (currentTarget.armor - currentTarget.towerPierce)
                tower.fireAccumulator = 0
            }
        }

        if(tower.fireAccumulator < tower.fireRate) {
            tower.fireAccumulator += gameState.deltaTime
        }
    }
}

update_mobs :: proc(gameState: ^GameState) {
    if(gameState.currentWave == len(Waves)) {
        if(len(gameState.mobs) == 0) {
            gameState.gameOver = true
            gameState.wonMap = true
        }
    }

    if(gameState.wavesActive) {
        if(gameState.currentWave < len(Waves)) {
            waveInfo := Waves[gameState.currentWave]
            if(gameState.wavePatternCountdown > 0.0 && gameState.wavePatternCount < waveInfo.patternRepeatCount) {
                gameState.wavePatternCountdown -= gameState.deltaTime
            } else {
                gameState.waveUnitAccumulator += gameState.deltaTime
        
                if(gameState.waveUnitAccumulator >= waveInfo.unitDelay) {
                    gameState.waveUnitAccumulator = 0
                    if(gameState.waveUnitCount < len(waveInfo.unitSpawnPattern)) {
                        append(&gameState.mobs, MobTemplates[waveInfo.unitSpawnPattern[gameState.waveUnitCount]])
                        gameState.waveUnitCount += 1
                    } else {
                        if(gameState.wavePatternCount >= waveInfo.patternRepeatCount) {
                            if(waveInfo.shouldStopOnFinish) {
                                gameState.currentWave += 1
                                gameState.waveUnitCount = 0
                                gameState.wavePatternCount = 0
                                gameState.wavesActive = false
                            } else {
                                gameState.currentWave += 1
                                gameState.waveUnitCount = 0
                                gameState.wavePatternCount = 0
                                gameState.wavePatternCountdown = waveInfo.patternRepeatDelay
                            }
                        }
                        else {
                            gameState.waveUnitCount = 0
                            gameState.wavePatternCount += 1
                            gameState.wavePatternCountdown = waveInfo.patternRepeatDelay
                        }
                    }
                }
            }
        }
    }

    charmedMobs: [dynamic]Mob = {}
    pathLength := calculate_path_length(gameState.path)

    for &mob, idx in gameState.mobs {
        if(mob.towerCharm >= mob.health) {
            append(&charmedMobs, mob)
        }
    }

    for &mob, idx in gameState.mobs {
        if(mob.health <= 0) {
            gameState.kills += 1
            gameState.money += mob.killAward
            unordered_remove(&gameState.mobs, idx)
        }

        if(mob.towerCharm >= mob.health) {
            continue
        }

        mobBlockageDistance := pathLength
        blockingMob : ^Mob = nil

        for &charmedMob in charmedMobs {
            if(charmedMob.distanceAlongPath >= mob.distanceAlongPath) {
                mobBlockageDistance = charmedMob.distanceAlongPath
                blockingMob = &charmedMob
            }
        }

        if(blockingMob != nil && mobBlockageDistance - mob.distanceAlongPath > 0 && mobBlockageDistance - mob.distanceAlongPath < 5 && mobBlockageDistance > mob.distanceAlongPath) {
            blockingMob.health -= cast(f32)mob.killAward * gameState.deltaTime
        } else {
            mob.distanceAlongPath += max(mob.speed - mob.towerSlow, 1) * gameState.deltaTime
        }

        if(mob.distanceAlongPath > pathLength) {
            gameState.leaks += 1

            if(gameState.leaks > gameState.maxLeaks) {
                gameState.gameOver = true
            }

            unordered_remove(&gameState.mobs, idx)
        }
    }
}

update_misc :: proc(gameState: ^GameState) {

}

render_towers :: proc(gameState: ^GameState) {
    for tower, idx in gameState.towers {
        raylib.DrawTextureRec(SpriteAtlas, source_area_from_index(sprite_index_from_type(tower.type)), {tower.x - 16, tower.y - 16}, raylib.WHITE)
        raylib.DrawCircle(cast(i32)tower.x, cast(i32)tower.y, 4, raylib.ColorAlpha(raylib.GREEN, tower.fireAccumulator / tower.fireRate))
        
        if(idx == gameState.lastHoverSelectedTower) {
            raylib.DrawCircleLines(cast(i32)tower.x, cast(i32)tower.y, tower.range, raylib.GREEN)
        }

        if(idx == gameState.currentSelectedTower) {
            raylib.DrawCircleLines(cast(i32)tower.x, cast(i32)tower.y, tower.range, raylib.WHITE)
        } 
    }

    if(gameState.currentSelectedTower != -1) {
        currentTower := &gameState.towers[gameState.currentSelectedTower]
        raylib.DrawRectangle(raylib.GetRenderWidth() - 256, raylib.GetRenderHeight() - 128, 256, 128, raylib.GRAY)
        raylib.DrawRectangle(raylib.GetRenderWidth() - 256 + 8, raylib.GetRenderHeight() - 128 + 16, 32, 32, raylib.WHITE)
        raylib.DrawTextureRec(SpriteAtlas, source_area_from_index(sprite_index_from_type(currentTower.type)), {cast(f32)(raylib.GetRenderWidth() - 256 + 8), cast(f32)(raylib.GetRenderHeight() - 128 + 16)}, raylib.WHITE)
        raylib.DrawText(strings.clone_to_cstring(TowerTypeString[currentTower.type]), raylib.GetRenderWidth() - 256 + 8 + 32 + 8, raylib.GetRenderHeight() - 128 + 16, 16, raylib.BLACK)

        if(currentTower.arcana != .NONE) {
            raylib.DrawText(strings.clone_to_cstring(ArcanaTypeStrings[currentTower.arcana]), raylib.GetRenderWidth() - 256 + 8 + 32 + 8, raylib.GetRenderHeight() - 128 + 16 + 4 + 16, 16, raylib.BLACK)
        }

        damageStringBuilder : strings.Builder
        strings.builder_init(&damageStringBuilder)

        fmt.sbprintf(&damageStringBuilder, "%f", currentTower.damage)
        damageString, _ := strings.to_cstring(&damageStringBuilder)
        raylib.DrawText(damageString, raylib.GetRenderWidth() - 256 + 8 + 32 + 8, raylib.GetRenderHeight() - 128 + 16 + 4 + 16 + 4 + 16, 16, raylib.BLACK)
    
        targetingX := raylib.GetRenderWidth() - 256 + 8
        targetingY := raylib.GetRenderHeight() - 128 + 16 + 60
        for mode, idx in TowerTargeting {
            modeColor := raylib.BLACK
            if(currentTower.targeting == mode) {
                modeColor = raylib.WHITE
            }

            raylib.DrawRectangle(targetingX + cast(i32)(34*idx), targetingY, 32, 32, modeColor)
            raylib.DrawTextureRec(SpriteAtlas, source_area_from_index(sprite_index_from_targeting_mode(mode)), {
                cast(f32)(targetingX + cast(i32)(34*idx)),
                cast(f32)targetingY}, raylib.WHITE)

            if(raylib.CheckCollisionPointRec(raylib.GetMousePosition(), {
                cast(f32)(targetingX + cast(i32)(34*idx)),
                cast(f32)targetingY,
                32,
                32
            })) {
                if(raylib.IsMouseButtonPressed(.LEFT)) {
                    currentTower.targeting = mode
                    gameState.consumedClick = true
                }
            }
        }
    }
}

render_mobs :: proc(gameState: GameState) {
    for mob in gameState.mobs {
        mobPosition := place_on_path(gameState, mob.distanceAlongPath)

        raylib.DrawCircle(cast(i32) mobPosition.x, cast(i32) mobPosition.y, 8, raylib.ColorLerp(raylib.RED, mob.baseColor, mob.health / mob.maxHealth))
    }
}

update_shop :: proc(gameState: ^GameState) {
    ButtonSpacing : i32 = 4
    ButtonSize : i32 = 32
    drawStartX, drawStartY : i32
    drawStartX = raylib.GetRenderWidth() - (ButtonSize + ButtonSpacing)
    towersHeight := (ButtonSize * cast(i32)len(TowerShop) + ButtonSpacing * cast(i32)(len(TowerShop) - 1))
    drawStartY = raylib.GetRenderHeight() / 2 - towersHeight
    
    hoverIndex := -1

    for tower, idx in TowerShop {
        buttonColor := raylib.WHITE
        
        

        spacing : i32 = ButtonSpacing * cast(i32)(idx)

        buttonY := drawStartY + (ButtonSize * cast(i32)idx) + spacing

        if(tower.cost > gameState.money) {
            buttonColor = raylib.GRAY
        } else {
            if(tower == gameState.currentBuyTower) {
                buttonColor = raylib.GREEN
            } else {
                if(raylib.CheckCollisionPointRec(raylib.GetMousePosition(), raylib.Rectangle{
                    cast(f32)drawStartX, cast(f32)buttonY, cast(f32)ButtonSize, cast(f32)ButtonSize
                })) {
                    hoverIndex = idx
                    buttonColor = raylib.YELLOW
                    gameState.lastHoverBuyTower = tower
                    if(raylib.IsMouseButtonPressed(.LEFT)) {
                        gameState.currentBuyTower = tower
                    }
                }
            }
        }

        raylib.DrawRectangle(drawStartX, buttonY, ButtonSize, ButtonSize, buttonColor)
        raylib.DrawTextureRec(SpriteAtlas, source_area_from_index(sprite_index_from_type(TowerTemplates[tower.index].type)), {cast(f32)drawStartX, cast(f32)buttonY}, raylib.WHITE)
    }

    towerInfo := gameState.currentBuyTower
    if(hoverIndex != -1) {
        towerInfo = gameState.lastHoverBuyTower
    }

    if(towerInfo != EmptyBuy) {
        towerCostSB: strings.Builder
        strings.builder_init(&towerCostSB)
        fmt.sbprintf(&towerCostSB, "%d", towerInfo.cost)
        res, err := strings.to_cstring(&towerCostSB)

        raylib.DrawText(res, raylib.GetRenderWidth() - raylib.MeasureText(res, 32), drawStartY + towersHeight, 32, raylib.YELLOW)
    }
    
}

render_misc :: proc(gameState: GameState) {
    moneySB: strings.Builder
    strings.builder_init(&moneySB)
    fmt.sbprintf(&moneySB, "%d", gameState.money)
    res, err := strings.to_cstring(&moneySB)

    raylib.DrawText(res, 0, 0, 32, raylib.YELLOW)
    raylib.DrawTexturePro(SpriteAtlas, source_area_from_index(49), {cast(f32)raylib.MeasureText(res, 32), 0, 32, 32}, {0, 0}, 0, raylib.WHITE)

    leaksSB: strings.Builder
    strings.builder_init(&leaksSB)
    fmt.sbprintf(&leaksSB, "%d", gameState.leaks)
    res, err = strings.to_cstring(&leaksSB)

    raylib.DrawText(res, 0, 32, 32, raylib.RED)
    raylib.DrawTexturePro(SpriteAtlas, source_area_from_index(48), {cast(f32)raylib.MeasureText(res, 32), 32, 32, 32}, {0, 0}, 0, raylib.WHITE)

    mobsSB: strings.Builder
    strings.builder_init(&mobsSB)
    fmt.sbprintf(&mobsSB, "%d", len(gameState.mobs))
    res, err = strings.to_cstring(&mobsSB)

    raylib.DrawText(res, 0, 64, 32, raylib.WHITE)

    if(gameState.wavesActive) {
        raylib.DrawTexturePro(SpriteAtlas, source_area_from_index(65), {0, 96, 32, 32}, {0, 0}, 0, raylib.WHITE)
    } else {
        raylib.DrawTexturePro(SpriteAtlas, source_area_from_index(64), {0, 96, 32, 32}, {0, 0}, 0, raylib.WHITE)
    }
}

blend_color :: proc(a: raylib.Color, b: raylib.Color, mix: f32) -> raylib.Color {
    return raylib.Color{
        cast(u8)math.min(255, cast(f32)a.r * mix + cast(f32)b.r * (1.0 - mix)),
        cast(u8)math.min(255, cast(f32)a.g * mix + cast(f32)b.g * (1.0 - mix)),
        cast(u8)math.min(255, cast(f32)a.b * mix + cast(f32)b.b * (1.0 - mix)),
        cast(u8)math.min(255, cast(f32)a.a * mix + cast(f32)b.a * (1.0 - mix)),
    }
}

render_debug :: proc(gameState: GameState) {
    for point, idx in gameState.path {
        if(idx + 1 < len(gameState.path)) {
            colorMix := cast(f32)idx / cast(f32)(len(gameState.path) - 1)
            nextPoint := gameState.path[idx + 1]
            raylib.DrawLine(cast(i32)math.floor(point.x), cast(i32)math.floor(point.y), cast(i32)math.floor(nextPoint.x), cast(i32)math.floor(nextPoint.y), blend_color(raylib.RED, raylib.GREEN, colorMix))
        }
    }
}

render_gameover :: proc(gameState: GameState) {
    width, height : i32
    width = raylib.GetRenderWidth()
    height = raylib.GetRenderHeight()
    if(gameState.wonMap) {
        raylib.DrawTexture(SpriteWin, width / 2 - (SpriteWin.width / 2), height / 2 - (SpriteWin.height / 2), raylib.WHITE)
    } else {
        raylib.DrawTexture(SpriteLose, width / 2 - (SpriteWin.width / 2), height / 2 - (SpriteWin.height / 2), raylib.WHITE)
    }
}

source_area_from_index :: proc(index: int) -> raylib.Rectangle {
    WIDTH :: 512
    SPRITE_WIDTH :: 32

    x := SPRITE_WIDTH * (index % (WIDTH / SPRITE_WIDTH))
    y := SPRITE_WIDTH * (index / (WIDTH / SPRITE_WIDTH))

    return raylib.Rectangle{cast(f32)x, cast(f32)y, cast(f32)SPRITE_WIDTH, cast(f32)SPRITE_WIDTH}
}

sprite_index_from_type :: proc(type: TowerType) -> int {
    return cast(int)type
}

sprite_index_from_targeting_mode :: proc(type: TowerTargeting) -> int {
    return cast(int)type + 80
}