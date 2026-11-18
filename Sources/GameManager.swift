import SwiftUI
import SceneKit
import UIKit

final class GameManager: ObservableObject {
    @Published var inMenu = true
    @Published var isPaused = false
    @Published var statusText = "Выбери командира и начни космический забег"
    @Published var lastMoveNotation = "Космический рогалик"
    @Published var isAnimating = false
    @Published var isThinking = false
    @Published var isCheckNow = false
    @Published var turnIsWhite = true
    @Published var undoCount = 3
    @Published var isAdviceThinking = false
    @Published var chat: [ChatMessage] = [
        ChatMessage(sender: "Гроссмейстер AI", text: "Приветствую! В рогалике пешки — дефицит: добывай их в Рулетке, Кейсах и Паках, доводи до 8-й линии и эволюционируй армию.")
    ]

    @Published var roguelikeRun: RoguelikeRun? = nil
    @Published var roguelikeMeta: RoguelikeMeta = RoguelikeMeta()
    @Published var battleState: RoguelikeBattleState? = nil
    @Published var isPreparationPhase = false
    @Published var selectedPrepSquare: Int? = nil
    @Published var activeSkillMode: TacticalSkill? = nil
    @Published var skillFirstSquare: Int? = nil
    @Published var pendingRoguelikePromotion: RoguelikePromotionRequest? = nil
    @Published var rewardOptions: [RewardOption] = []
    @Published var shopItems: [ShopItem] = []
    @Published var activePackRewards: [PackReward]? = nil
    @Published var pendingPatcher: PatcherKind? = nil
    @Published var activeEvent: CosmicEvent? = nil
    @Published var eventOutcomeText: String? = nil
    @Published var battleBannerText: String? = nil
    @Published var lastBattleSummary: String = ""
    @Published var runEndTitle: String = ""
    @Published var runEndShardsEarned: Int = 0
    @Published var selectedUnitTooltip: String? = nil

    @Published var controlMode: ControlMode = .tap {
        didSet {
            saveSettings()
            applyControlMode()
        }
    }
    @Published var sfxEnabled = true { didSet { saveSettings() } }
    @Published var musicEnabled = true { didSet { saveSettings(); SoundEngine.shared.toggleMusic(musicEnabled) } }
    @Published var voiceEnabled = true { didSet { saveSettings() } }
    @Published var showHints = true { didSet { saveSettings(); refreshHighlights() } }
    @Published var gyroEnabled = false {
        didSet {
            saveSettings()
            space.setGyroEnabled(gyroEnabled)
        }
    }
    @Published var graphicsQuality: GraphicsQuality = .ultra {
        didSet {
            saveSettings()
            space.applyQuality(graphicsQuality)
        }
    }

    let boardCtl = BoardController()
    let space = SpaceScene()

    private(set) var board = ChessBoard.emptyRoguelike()
    private var history: [HistoryEntry] = []
    private var positionCounts: [PositionKey: Int] = [:]
    private var selectedSquare: Int? = nil
    private var legalForSelected: [Move] = []
    private var lastMove: Move? = nil
    private var gameToken = 0
    private var pendingBotMove: Move? = nil
    private var isLoadingSettings = false
    private var draggingSourceSquare: Int? = nil
    private var pendingAscensionBuff: AscensionBuff? = nil

    init() {
        isLoadingSettings = true
        loadSettings()
        isLoadingSettings = false
        loadRoguelikeFromDisk()
        board = GameManager.previewBoard()
        positionCounts = [board.key: 1]
        boardCtl.reset(board: board, flipped: false)
        space.applyQuality(graphicsQuality)
        space.setGyroEnabled(gyroEnabled)
        applyControlMode()
        SoundEngine.shared.toggleMusic(musicEnabled)
    }

    private static func previewBoard() -> ChessBoard {
        var b = ChessBoard.emptyRoguelike()
        let back: [Int8] = [4, 2, 3, 5, 6, 3, 2, 4]
        for c in 0..<8 {
            b.sq[c] = back[c]
            b.sq[8 + c] = 1
            b.sq[48 + c] = -1
            b.sq[56 + c] = -back[c]
        }
        return b
    }

    var isHumanTurn: Bool { board.whiteToMove }

    var hasActiveRoguelikeRun: Bool {
        guard let r = roguelikeRun else { return false }
        return r.phase != .gameOver && r.phase != .victory
    }

    var activeSynergies: [SynergyInfo] {
        guard let run = roguelikeRun else { return [] }
        return SynergyInfo.activeSynergies(for: run.roster)
    }

    var currentEnergy: Int {
        battleState?.energy ?? 0
    }

    func rouletteCost(vip: Bool) -> Int {
        let base = vip ? 110 : 50
        let scale = min(30, (roguelikeRun?.rouletteSpins ?? 0) * 5)
        let perkDisc = roguelikeMeta.unlockedPerks.contains(.cheapRoulette) ? 10 : 0
        let curseMult = (roguelikeRun?.curses.contains(.inflation) ?? false) ? 1.25 : 1.0
        return max(30, Int(Double(base + scale - perkDisc) * curseMult))
    }

    var alivePawnCount: Int {
        roguelikeRun?.roster.filter { $0.pieceType == 1 && !$0.isDamaged }.count ?? 0
    }

    var damagedUnitsCount: Int {
        roguelikeRun?.roster.filter { $0.isDamaged }.count ?? 0
    }

    private func saveSettings() {
        if isLoadingSettings { return }
        let d = UserDefaults.standard
        d.set(sfxEnabled, forKey: "Vibe_Sfx")
        d.set(musicEnabled, forKey: "Vibe_Music")
        d.set(voiceEnabled, forKey: "Vibe_Voice")
        d.set(showHints, forKey: "Vibe_Hints")
        d.set(gyroEnabled, forKey: "Vibe_Gyro")
        d.set(controlMode.rawValue, forKey: "Vibe_CtrlMode")
        d.set(graphicsQuality.rawValue, forKey: "Vibe_Quality")
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        if d.object(forKey: "Vibe_Sfx") != nil { sfxEnabled = d.bool(forKey: "Vibe_Sfx") }
        if d.object(forKey: "Vibe_Music") != nil { musicEnabled = d.bool(forKey: "Vibe_Music") }
        if d.object(forKey: "Vibe_Voice") != nil { voiceEnabled = d.bool(forKey: "Vibe_Voice") }
        if d.object(forKey: "Vibe_Hints") != nil { showHints = d.bool(forKey: "Vibe_Hints") }
        if d.object(forKey: "Vibe_Gyro") != nil { gyroEnabled = d.bool(forKey: "Vibe_Gyro") }
        if let m = d.string(forKey: "Vibe_CtrlMode"), let v = ControlMode(rawValue: m) { controlMode = v }
        if let m = d.string(forKey: "Vibe_Quality"), let v = GraphicsQuality(rawValue: m) { graphicsQuality = v }
    }

    func applyControlMode() {
        let usePhysics = (controlMode == .drag && !isPreparationPhase)
        space.setOrbitalMotionPaused(usePhysics)
        boardCtl.setPhysicsEnabled(usePhysics, board: board)
    }

    func toggleControlMode() {
        controlMode = (controlMode == .tap) ? .drag : .tap
        SoundEngine.shared.play("click", enabled: sfxEnabled)
    }

    func realignPhysicsPieces() {
        boardCtl.reset(board: board, flipped: false)
        refreshHighlights()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
    }

    func pauseGame() {
        if inMenu { return }
        isPaused = true
    }

    func resumeGame() {
        isPaused = false
        if let m = pendingBotMove {
            pendingBotMove = nil
            play(m)
        }
    }

    func exitToMenu() {
        gameToken += 1
        pendingBotMove = nil
        draggingSourceSquare = nil
        boardCtl.endDrag(releaseVelocity: SCNVector3Zero)
        isThinking = false
        isAnimating = false
        isPaused = false
        isPreparationPhase = false
        selectedPrepSquare = nil
        activeSkillMode = nil
        skillFirstSquare = nil
        selectedSquare = nil
        legalForSelected = []
        pendingRoguelikePromotion = nil
        selectedUnitTooltip = nil
        if var run = roguelikeRun {
            if run.phase == .inBattle {
                run.phase = .map
                run.activeNode = nil
                roguelikeRun = run
            }
            saveRoguelikeRun()
        }
        battleState = nil
        inMenu = true
        space.setGalaxyTheme(.solar)
        space.setSectorTheme(nil)
        boardCtl.setLift(nil)
        boardCtl.setHighlights(selected: nil, targets: [:], last: nil, check: nil)
        space.startMenuOrbit()
    }

    // MARK: - Run Lifecycle

    func startNewRoguelike(commander: CommanderClass, curses: [VoidCurse] = []) {
        gameToken += 1
        pendingBotMove = nil
        draggingSourceSquare = nil
        isThinking = false
        isAnimating = false
        isPaused = false
        isPreparationPhase = false
        selectedPrepSquare = nil
        activeSkillMode = nil
        skillFirstSquare = nil
        pendingRoguelikePromotion = nil
        selectedUnitTooltip = nil
        battleBannerText = nil
        activePackRewards = nil
        pendingPatcher = nil

        var units: [RoguelikeUnit] = [
            RoguelikeUnit(pieceType: 6, unitClass: .standard)
        ]
        var relics: [RoguelikeRelic] = []
        var credits = 55
        var bonusUndos = 0
        var aegis = 0

        switch commander {
        case .vanguard:
            units.append(RoguelikeUnit(pieceType: 2, unitClass: .standard))
            units.append(RoguelikeUnit(pieceType: 3, unitClass: .standard))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .recruit))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .recruit))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .berserk))
            credits = 60
        case .bastion:
            units.append(RoguelikeUnit(pieceType: 4, unitClass: .standard))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .guardian))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .guardian))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .recruit))
            relics.append(.kingAegis)
            aegis += 1
        case .chronoWalker:
            units.append(RoguelikeUnit(pieceType: 3, unitClass: .standard))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .chrono))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .chrono))
            bonusUndos = 2
            credits = 95
        case .soloTitan:
            units.append(RoguelikeUnit(pieceType: 5, unitClass: .standard))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .nova))
            credits = 65
        }

        if roguelikeMeta.unlockedPerks.contains(.extraCredits) { credits += 45 }
        if roguelikeMeta.unlockedPerks.contains(.extraPawn) {
            let bonusPool: [UnitClass] = [.recruit, .golden, .berserk, .guardian, .chrono]
            units.append(RoguelikeUnit(pieceType: 1, unitClass: bonusPool.randomElement() ?? .recruit))
        }
        if roguelikeMeta.unlockedPerks.contains(.extraUndo) { bonusUndos += 1 }
        if roguelikeMeta.unlockedPerks.contains(.startAegis) {
            if !relics.contains(.kingAegis) { relics.append(.kingAegis) }
            aegis += 1
        }
        if curses.contains(.timeLock) { bonusUndos -= 1 }

        let layers = generateCosmicMap(galaxy: .solar)
        let run = RoguelikeRun(
            commander: commander,
            galaxy: .solar,
            curses: curses,
            credits: credits,
            roster: units,
            relics: relics,
            bonusUndos: bonusUndos,
            aegisCharges: aegis,
            currentLayer: 0,
            currentNodeId: nil,
            activeNode: nil,
            completedNodeIds: [],
            mapLayers: layers,
            rouletteSpins: 0,
            phase: .map,
            battlesWon: 0,
            elitesDefeated: 0,
            enemiesCaptured: 0,
            pawnsLost: 0,
            pawnsPromoted: 0
        )

        roguelikeRun = run
        inMenu = false
        space.setGalaxyTheme(.solar)
        space.setSectorTheme(.mercury)
        space.startMenuOrbit()
        saveRoguelikeRun()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
        SoundEngine.shared.speak("Космический маршрут открыт. Вперёд!", enabled: voiceEnabled)
    }

    func continueRoguelikeRun() {
        guard var run = roguelikeRun, run.phase != .gameOver && run.phase != .victory else { return }
        gameToken += 1
        pendingBotMove = nil
        isThinking = false
        isAnimating = false
        isPaused = false
        isPreparationPhase = false
        selectedPrepSquare = nil
        activeSkillMode = nil
        skillFirstSquare = nil
        pendingRoguelikePromotion = nil
        if run.phase == .inBattle {
            run.phase = .map
            run.activeNode = nil
        }
        if run.phase == .reward && rewardOptions.isEmpty { run.phase = .map }
        if run.phase == .shop && shopItems.isEmpty { run.phase = .map }
        if run.phase == .event && activeEvent == nil { run.phase = .map }
        roguelikeRun = run
        inMenu = false
        space.setGalaxyTheme(run.galaxy)
        space.setSectorTheme(.earth)
        space.startMenuOrbit()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
    }

    func generateCosmicMap(galaxy: GalaxySystem) -> [[MapNode]] {
        let p = "G\(galaxy.rawValue)_"
        let gTitle = galaxy.shortName
        let n0 = MapNode(id: "\(p)0_0", layer: 0, lane: 1, title: galaxy == .solar ? "Орбита Меркурия" : "Врата \(gTitle)", planet: .mercury, type: .battle, nextNodeIds: ["\(p)1_0", "\(p)1_1"])

        let n1_0 = MapNode(id: "\(p)1_0", layer: 1, lane: 0, title: "Патруль Венеры", planet: .venus, type: .battle, nextNodeIds: ["\(p)2_0", "\(p)2_1"])
        let n1_1 = MapNode(id: "\(p)1_1", layer: 1, lane: 2, title: "Лунный Монолит", planet: .earth, type: .event, nextNodeIds: ["\(p)2_1", "\(p)2_2"])

        let n2_0 = MapNode(id: "\(p)2_0", layer: 2, lane: 0, title: "Рубеж Земли", planet: .earth, type: .battle, nextNodeIds: ["\(p)3_0"])
        let n2_1 = MapNode(id: "\(p)2_1", layer: 2, lane: 1, title: "Орбитальный Базар", planet: .mars, type: .shop, nextNodeIds: ["\(p)3_0", "\(p)3_1"])
        let n2_2 = MapNode(id: "\(p)2_2", layer: 2, lane: 2, title: "Страж Марса", planet: .mars, type: .elite, nextNodeIds: ["\(p)3_1"])

        let n3_0 = MapNode(id: "\(p)3_0", layer: 3, lane: 0, title: "Пояс Астероидов", planet: .asteroidBelt, type: .battle, nextNodeIds: ["\(p)4_0", "\(p)4_1"])
        let n3_1 = MapNode(id: "\(p)3_1", layer: 3, lane: 2, title: "Разлом Пояса", planet: .asteroidBelt, type: .elite, nextNodeIds: ["\(p)4_1", "\(p)4_2"])

        let n4_0 = MapNode(id: "\(p)4_0", layer: 4, lane: 0, title: "Рынок Спутника Ио", planet: .jupiter, type: .shop, nextNodeIds: ["\(p)5_0"])
        let n4_1 = MapNode(id: "\(p)4_1", layer: 4, lane: 1, title: "Шторм Юпитера", planet: .jupiter, type: .battle, nextNodeIds: ["\(p)5_0", "\(p)5_1"])
        let n4_2 = MapNode(id: "\(p)4_2", layer: 4, lane: 2, title: "Грави-Аномалия", planet: .jupiter, type: .event, nextNodeIds: ["\(p)5_1"])

        let n5_0 = MapNode(id: "\(p)5_0", layer: 5, lane: 0, title: "Кольца Сатурна", planet: .saturn, type: .battle, nextNodeIds: ["\(p)6_0", "\(p)6_1"])
        let n5_1 = MapNode(id: "\(p)5_1", layer: 5, lane: 2, title: "Титан Сатурна", planet: .saturn, type: .elite, nextNodeIds: ["\(p)6_1", "\(p)6_2"])

        let n6_0 = MapNode(id: "\(p)6_0", layer: 6, lane: 0, title: "Док Нептуна", planet: .uranusNeptune, type: .shop, nextNodeIds: ["\(p)7_0"])
        let n6_1 = MapNode(id: "\(p)6_1", layer: 6, lane: 1, title: "Пояс Койпера", planet: .uranusNeptune, type: .event, nextNodeIds: ["\(p)7_0"])
        let n6_2 = MapNode(id: "\(p)6_2", layer: 6, lane: 2, title: "Ледяной Центурион", planet: .uranusNeptune, type: .elite, nextNodeIds: ["\(p)7_0"])

        let bossTitle: String
        switch galaxy {
        case .solar: bossTitle = "Трон Пустоты (Плутон)"
        case .sirius: bossTitle = "Сердце Сириуса-X"
        case .gargantua: bossTitle = "Горизонт Гаргантюа"
        case .omega: bossTitle = "Бог Туманности Омега"
        }
        let n7 = MapNode(id: "\(p)7_0", layer: 7, lane: 1, title: bossTitle, planet: .pluto, type: .boss, nextNodeIds: [])

        return [
            [n0],
            [n1_0, n1_1],
            [n2_0, n2_1, n2_2],
            [n3_0, n3_1],
            [n4_0, n4_1, n4_2],
            [n5_0, n5_1],
            [n6_0, n6_1, n6_2],
            [n7]
        ]
    }

    func isNodeAvailable(_ node: MapNode) -> Bool {
        guard let run = roguelikeRun, run.phase == .map else { return false }
        if run.completedNodeIds.contains(node.id) { return false }
        if let curId = run.currentNodeId {
            for layerNodes in run.mapLayers {
                if let cur = layerNodes.first(where: { $0.id == curId }) {
                    return cur.nextNodeIds.contains(node.id)
                }
            }
            return false
        } else {
            return node.layer == 0
        }
    }

    func selectMapNode(_ node: MapNode) {
        guard isNodeAvailable(node), var run = roguelikeRun else { return }
        if run.relics.contains(.royalTreasury) { run.credits += 25 }
        run.activeNode = node
        space.setGalaxyTheme(run.galaxy)
        space.setSectorTheme(node.planet)
        SoundEngine.shared.play("select", enabled: sfxEnabled)

        switch node.type {
        case .battle, .elite, .boss:
            run.phase = .inBattle
            roguelikeRun = run
            startRoguelikeBattle(node: node)
        case .shop:
            run.phase = .shop
            roguelikeRun = run
            generateShopItems()
            saveRoguelikeRun()
        case .event:
            run.phase = .event
            roguelikeRun = run
            generateCosmicEvent()
            saveRoguelikeRun()
        }
    }

    private func startRoguelikeBattle(node: MapNode) {
        guard let run = roguelikeRun else { return }
        gameToken += 1
        pendingBotMove = nil
        selectedSquare = nil
        legalForSelected = []
        lastMove = nil
        pendingRoguelikePromotion = nil
        isAnimating = false
        isThinking = false
        isPaused = false
        isCheckNow = false
        selectedUnitTooltip = nil
        activeSkillMode = nil
        skillFirstSquare = nil
        isPreparationPhase = true
        selectedPrepSquare = nil
        history.removeAll()

        var b = ChessBoard.emptyRoguelike()
        b.kingLeapReady = run.relics.contains(.royalLeap)
        b.gravityNoPawnDouble = (node.planet == .jupiter)

        var unitMap: [Int: UUID] = [:]
        var battleUnits: [UUID: RoguelikeUnit] = [:]

        let kingUnit = run.roster.first(where: { $0.pieceType == 6 }) ?? RoguelikeUnit(pieceType: 6, unitClass: .standard)
        b.sq[4] = 6
        b.classes[4] = kingUnit.unitClass
        unitMap[4] = kingUnit.id
        battleUnits[kingUnit.id] = kingUnit

        let officers = run.roster
            .filter { $0.pieceType >= 2 && $0.pieceType <= 5 && !$0.isDamaged && $0.isDeployed }
            .sorted { $0.pieceType > $1.pieceType }
        let backSlots = [3, 5, 2, 6, 1, 7, 0]
        var overflowOfficers: [RoguelikeUnit] = []
        for (idx, u) in officers.enumerated() {
            if idx < backSlots.count {
                let sq = backSlots[idx]
                b.sq[sq] = Int8(u.pieceType)
                b.classes[sq] = u.unitClass
                unitMap[sq] = u.id
                battleUnits[u.id] = u
            } else {
                overflowOfficers.append(u)
            }
        }

        let pawns = run.roster.filter { $0.pieceType == 1 && !$0.isDamaged && $0.isDeployed }
        let pawnRowOffset = run.relics.contains(.vanguardPush) ? 16 : 8
        let pawnSlots = [3, 4, 2, 5, 1, 6, 0, 7].map { $0 + pawnRowOffset }
        var usedPawnSlots = 0
        for u in pawns where usedPawnSlots < pawnSlots.count {
            let sq = pawnSlots[usedPawnSlots]
            b.sq[sq] = 1
            b.classes[sq] = u.unitClass
            unitMap[sq] = u.id
            battleUnits[u.id] = u
            usedPawnSlots += 1
        }
        for u in overflowOfficers where usedPawnSlots < pawnSlots.count {
            let sq = pawnSlots[usedPawnSlots]
            b.sq[sq] = Int8(u.pieceType)
            b.classes[sq] = u.unitClass
            unitMap[sq] = u.id
            battleUnits[u.id] = u
            usedPawnSlots += 1
        }

        let enemy = buildEnemyArmy(layer: node.layer, type: node.type, galaxy: run.galaxy, extraOfficer: run.curses.contains(.ironFoes))
        b.sq[60] = -6
        let enemyBackSlots = [59, 61, 58, 62, 57, 63, 56]
        for (idx, piece) in enemy.officers.prefix(enemyBackSlots.count).enumerated() {
            b.sq[enemyBackSlots[idx]] = Int8(-piece)
        }
        let enemyPawnSlots = [51, 52, 50, 53, 49, 54, 48, 55]
        for idx in 0..<min(enemy.pawns, enemyPawnSlots.count) {
            b.sq[enemyPawnSlots[idx]] = -1
        }

        // Spawn cosmic arena tiles on middle ranks (rows 3 & 4 -> squares 24..<40)
        var centerSquares = Array(24..<40).shuffled()
        let veinCount = (node.planet == .earth) ? 2 : 1
        for _ in 0..<veinCount {
            if let sq = centerSquares.popLast() { b.tiles[sq] = .goldVein }
        }
        if node.planet == .earth || Bool.random() {
            if let sq = centerSquares.popLast() { b.tiles[sq] = .ascensionPad }
        }
        if node.planet == .venus || node.planet == .pluto || node.type == .elite {
            if let sq = centerSquares.popLast() { b.tiles[sq] = .voidRift }
        }

        board = b
        positionCounts = [board.key: 1]
        turnIsWhite = true
        let baseUndos = max(0, 2 + run.bonusUndos + (run.relics.contains(.chronoCrown) ? 2 : 0))
        undoCount = baseUndos
        lastMoveNotation = "\(node.type.icon) Расстановка"
        statusText = "Расстановка • Нажми на 2 свои фигуры, чтобы поменять"

        let bonusStartEnergy = run.roster.filter { $0.isDeployed && !$0.isDamaged }.reduce(0) { $0 + $1.energyBonus }
        let metaEnergy = roguelikeMeta.unlockedPerks.contains(.startEnergy) ? 20 : 0
        let initEnergy = min(100, 25 + bonusStartEnergy + metaEnergy)

        battleState = RoguelikeBattleState(
            node: node,
            unitMap: unitMap,
            units: battleUnits,
            destroyedIds: [],
            damagedIds: [],
            guardianSavedIds: [],
            battleCredits: 0,
            battleBonusUndos: 0,
            aegisLeft: run.aegisCharges,
            warlordUndoGains: 0,
            earnedRelics: [],
            movesPlayed: 0,
            pendingNovaStrikes: 0,
            energy: initEnergy,
            bossPhase2Triggered: false,
            synergyNovaTriggered: false
        )

        boardCtl.setPhysicsEnabled(false, board: board)
        boardCtl.reset(board: board, flipped: false)
        space.focus(flipped: false)
        refreshHighlights()
        saveRoguelikeRun()
    }

    func finishPreparationPhase() {
        guard isPreparationPhase else { return }
        isPreparationPhase = false
        selectedPrepSquare = nil
        applyControlMode()
        lastMoveNotation = battleState?.node.title ?? "В бой!"
        updateStatus()
        refreshHighlights()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
        SoundEngine.shared.speak("В бой!", enabled: voiceEnabled)

        if let run = roguelikeRun, run.relics.contains(.orbitalStrike) {
            let tok = gameToken
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, self.gameToken == tok, !self.isPreparationPhase else { return }
                self.triggerBlackHoleStrike(preferPawn: true, banner: "🕳️ Орбитальный удар сжёг пешку врага!")
            }
        }
    }

    private func buildEnemyArmy(layer: Int, type: NodeType, galaxy: GalaxySystem, extraOfficer: Bool) -> (officers: [Int], pawns: Int) {
        let tier = layer + galaxy.rawValue * 4
        var officers: [Int]
        var pawns: Int
        switch type {
        case .boss:
            if galaxy == .solar {
                officers = [5, 4, 4, 3, 3, 2, 2]
                pawns = 8
            } else {
                officers = [5, 5, 4, 4, 3, 2, 2]
                pawns = 8
            }
        case .elite:
            switch tier {
            case 0...2: officers = [4, 2, 3]; pawns = 4
            case 3...4: officers = [5, 4, 2]; pawns = 5
            case 5...6: officers = [5, 4, 4, 3, 2]; pawns = 6
            default: officers = [5, 5, 4, 3, 2, 2]; pawns = 7
            }
        default:
            switch tier {
            case 0: officers = [2]; pawns = 3
            case 1: officers = [2, 3]; pawns = 4
            case 2: officers = [2, 2, 3]; pawns = 4
            case 3: officers = [4, 2, 3]; pawns = 5
            case 4: officers = [4, 4, 2]; pawns = 5
            case 5: officers = [5, 3, 2]; pawns = 6
            case 6: officers = [5, 4, 3, 2]; pawns = 6
            default: officers = [5, 4, 4, 3, 2]; pawns = 7
            }
        }
        if extraOfficer && officers.count < 7 {
            officers.append([2, 3, 4].randomElement() ?? 2)
        }
        return (officers, pawns)
    }

    // MARK: - Tactical Skills

    func toggleSkillMode(_ skill: TacticalSkill) {
        guard !isPreparationPhase, !isAnimating, !isThinking, isHumanTurn, roguelikeRun?.phase == .inBattle else { return }
        if activeSkillMode == skill {
            activeSkillMode = nil
            skillFirstSquare = nil
            statusText = "Навык отменён • Твой ход"
            refreshHighlights()
            SoundEngine.shared.play("click", enabled: sfxEnabled)
            return
        }
        guard (battleState?.energy ?? 0) >= skill.cost else {
            showBanner("Недостаточно Энергии (\(skill.cost)⚡)")
            return
        }
        clearSelection()
        activeSkillMode = skill
        skillFirstSquare = nil
        statusText = skill.hint
        refreshHighlights()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
    }

    private func skillValidSquares(for skill: TacticalSkill) -> [Int] {
        switch skill {
        case .stasis:
            return (0..<64).filter { board.sq[$0] < 0 && board.sq[$0] != -6 && board.frozenTurns[$0] == 0 }
        case .airdrop:
            return (8..<24).filter {
                guard board.sq[$0] == 0 && board.tiles[$0] != .blocked else { return false }
                var test = board
                test.sq[$0] = 1
                return !test.inCheck(white: false)
            }
        case .swap:
            if let first = skillFirstSquare {
                return (0..<64).filter { s in
                    guard s != first && board.sq[s] > 0 else { return false }
                    var test = board
                    test.sq.swapAt(first, s)
                    return !test.inCheck(white: true) && !test.inCheck(white: false)
                }
            } else {
                return (0..<64).filter { board.sq[$0] > 0 }
            }
        case .orbitalBlast:
            return (0..<64).filter { s in
                guard board.sq[s] < 0 && board.sq[s] != -6 else { return false }
                var test = board
                test.sq[s] = 0
                return !test.inCheck(white: false)
            }
        }
    }

    private func handleSkillTap(skill: TacticalSkill, square s: Int) {
        guard var bs = battleState, var run = roguelikeRun else { return }
        let valid = skillValidSquares(for: skill)
        guard valid.contains(s) else {
            activeSkillMode = nil
            skillFirstSquare = nil
            updateStatus()
            refreshHighlights()
            return
        }

        switch skill {
        case .stasis:
            bs.energy -= skill.cost
            board.frozenTurns[s] = 2
            battleState = bs
            activeSkillMode = nil
            boardCtl.reset(board: board, flipped: false)
            boardCtl.spawnBurst(at: s, color: .cyan)
            showBanner("❄️ Стазис заморозил \(pieceTitle(abs(Int(board.sq[s])))) на \(squareName(s))!")
            SoundEngine.shared.play("select", enabled: sfxEnabled)

        case .airdrop:
            bs.energy -= skill.cost
            let reservePawn = run.roster.first {
                $0.pieceType == 1 && !$0.isDamaged && !bs.unitMap.values.contains($0.id) && !bs.destroyedIds.contains($0.id)
            }
            let unit: RoguelikeUnit
            if let rp = reservePawn {
                unit = rp
            } else {
                let fresh = RoguelikeUnit(pieceType: 1, unitClass: .recruit)
                run.roster.append(fresh)
                roguelikeRun = run
                unit = fresh
            }
            bs.units[unit.id] = unit
            bs.unitMap[s] = unit.id
            board.sq[s] = 1
            board.classes[s] = unit.unitClass
            battleState = bs
            activeSkillMode = nil
            boardCtl.reset(board: board, flipped: false)
            boardCtl.spawnBurst(at: s, color: .green)
            showBanner("♟️ Десант высадил пешку [\(unit.unitClass.title)] на \(squareName(s))!")
            SoundEngine.shared.play("move", enabled: sfxEnabled)

        case .swap:
            if skillFirstSquare == nil {
                skillFirstSquare = s
                statusText = "Теперь выбери 2-ю свою фигуру для обмена"
                refreshHighlights()
                SoundEngine.shared.play("select", enabled: sfxEnabled)
                return
            } else if let first = skillFirstSquare {
                bs.energy -= skill.cost
                board.sq.swapAt(first, s)
                board.classes.swapAt(first, s)
                board.frozenTurns.swapAt(first, s)
                let u1 = bs.unitMap[first]
                let u2 = bs.unitMap[s]
                bs.unitMap[first] = u2
                bs.unitMap[s] = u1
                battleState = bs
                activeSkillMode = nil
                skillFirstSquare = nil
                boardCtl.reset(board: board, flipped: false)
                boardCtl.spawnBurst(at: first, color: .cyan)
                boardCtl.spawnBurst(at: s, color: .cyan)
                showBanner("🔄 Квантовый телепорт!")
                SoundEngine.shared.play("select", enabled: sfxEnabled)
            }

        case .orbitalBlast:
            bs.energy -= skill.cost
            battleState = bs
            activeSkillMode = nil
            board.sq[s] = 0
            boardCtl.obliterateWithBlackHole(at: s)
            SoundEngine.shared.play("blackhole", enabled: sfxEnabled)
            showBanner("🕳️ Орбитальный залп уничтожил врага!")
            evaluateRoguelikeBattleState()
        }

        updateStatus()
        refreshHighlights()
    }

    // MARK: - Asteroids, Black Hole Strikes, Boss Phase 2

    @discardableResult
    private func triggerBlackHoleStrike(preferPawn: Bool, banner: String) -> Bool {
        var candidates: [Int] = []
        for s in 0..<64 where board.sq[s] < 0 && board.sq[s] != -6 {
            var test = board
            test.sq[s] = 0
            if !test.inCheck(white: false) && !test.inCheck(white: true) {
                candidates.append(s)
            }
        }
        guard !candidates.isEmpty else { return false }
        let targetSq: Int
        if preferPawn, let pawnSq = candidates.filter({ board.sq[$0] == -1 }).randomElement() {
            targetSq = pawnSq
        } else {
            let sorted = candidates.sorted { abs(Int(board.sq[$0])) > abs(Int(board.sq[$1])) }
            targetSq = sorted.first ?? candidates[0]
        }
        board.sq[targetSq] = 0
        boardCtl.obliterateWithBlackHole(at: targetSq)
        SoundEngine.shared.play("blackhole", enabled: sfxEnabled)
        showBanner(banner)
        refreshHighlights()
        evaluateRoguelikeBattleState()
        return true
    }

    private func maybeTriggerFallingAsteroid() {
        guard var bs = battleState, let run = roguelikeRun, roguelikeRun?.phase == .inBattle else { return }
        guard bs.movesPlayed >= 2 else { return }
        let curseAdd = run.curses.contains(.asteroidStorm) ? 0.20 : 0.0
        let galaxyAdd = Double(run.galaxy.rawValue) * 0.04
        let chance = min(0.60, bs.node.planet.asteroidChance + curseAdd + galaxyAdd)
        guard Double.random(in: 0...1) < chance else { return }

        let whiteNonKingCount = (0..<64).filter { board.sq[$0] > 0 && board.sq[$0] != 6 }.count
        let candidates = (8..<56).filter { s in
            if board.tiles[s] == .blocked { return false }
            let p = board.sq[s]
            if abs(Int(p)) == 6 { return false }
            if p > 0 && whiteNonKingCount <= 1 { return false }
            if p != 0 {
                var test = board
                test.sq[s] = 0
                return !test.inCheck(white: true) && !test.inCheck(white: false)
            }
            return true
        }
        guard !candidates.isEmpty else { return }

        // Prefer empty middle squares ~65% of the time
        let emptyCenter = candidates.filter { board.sq[$0] == 0 && $0 >= 16 && $0 < 48 }
        let targetSq: Int
        if !emptyCenter.isEmpty && Int.random(in: 0..<100) < 65 {
            targetSq = emptyCenter.randomElement()!
        } else {
            targetSq = candidates.randomElement()!
        }

        let astType: AsteroidType
        switch bs.node.planet {
        case .mercury: astType = [.fire, .fire, .stone].randomElement() ?? .fire
        case .asteroidBelt: astType = [.stone, .crystal, .fire, .void].randomElement() ?? .stone
        case .pluto: astType = [.void, .fire, .stone].randomElement() ?? .void
        default: astType = AsteroidType.allCases.randomElement() ?? .stone
        }

        var hadPiece = false
        let existing = board.sq[targetSq]
        if existing > 0, let uid = bs.unitMap[targetSq], let unit = bs.units[uid] {
            if unit.unitClass == .guardian && !bs.guardianSavedIds.contains(uid) {
                bs.guardianSavedIds.insert(uid)
                battleState = bs
                boardCtl.strikeAsteroid(at: targetSq, type: astType, destroyedPiece: false) { }
                showBanner("\(astType.icon) Метеорит отбит щитом Стража на \(squareName(targetSq))!")
                return
            }
            hadPiece = true
            bs.unitMap[targetSq] = nil
            board.sq[targetSq] = 0
            board.classes[targetSq] = .standard
            if unit.pieceType == 1 {
                bs.destroyedIds.insert(uid)
            } else {
                bs.damagedIds.insert(uid)
            }
        } else if existing < 0 {
            hadPiece = true
            board.sq[targetSq] = 0
            if astType == .crystal { bs.battleCredits += 20 }
        }

        switch astType {
        case .stone:
            board.tiles[targetSq] = .blocked
        case .fire:
            board.tiles[targetSq] = .blocked
            bs.energy = min(100, bs.energy + 15)
        case .crystal:
            board.tiles[targetSq] = .goldVein
        case .void:
            board.tiles[targetSq] = .voidRift
        }

        battleState = bs
        showBanner("\(astType.icon) \(astType.rawValue) упал на \(squareName(targetSq))!")
        SoundEngine.shared.play("capture", enabled: sfxEnabled)
        boardCtl.strikeAsteroid(at: targetSq, type: astType, destroyedPiece: hadPiece) { [weak self] in
            guard let self = self else { return }
            self.boardCtl.reset(board: self.board, flipped: false)
            self.refreshHighlights()
            self.evaluateRoguelikeBattleState()
        }
    }

    private func maybeTriggerBossPhase2() {
        guard var bs = battleState, bs.node.type == .boss, !bs.bossPhase2Triggered else { return }
        let blackNonKing = (0..<64).filter { board.sq[$0] < 0 && board.sq[$0] != -6 }.count
        guard blackNonKing <= 3 else { return }
        bs.bossPhase2Triggered = true
        var spawned: [Int] = []
        let slots = Array(40..<56).shuffled()
        for sq in slots where spawned.count < 3 {
            if board.sq[sq] == 0 && board.tiles[sq] != .blocked {
                var test = board
                test.sq[sq] = -1
                if !test.inCheck(white: true) {
                    board.sq[sq] = -1
                    spawned.append(sq)
                }
            }
        }
        battleState = bs
        if !spawned.isEmpty {
            boardCtl.reset(board: board, flipped: false)
            for s in spawned { boardCtl.spawnBurst(at: s, color: .purple) }
            showBanner("👑 ФАЗА 2 БОССА: Призвано \(spawned.count) тёмных пешек!")
            SoundEngine.shared.play("blackhole", enabled: sfxEnabled)
            SoundEngine.shared.speak("Вторая фаза босса!", enabled: voiceEnabled)
        }
    }

    private func showBanner(_ text: String) {
        battleBannerText = text
        let tok = gameToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self, self.gameToken == tok else { return }
            if self.battleBannerText == text {
                self.battleBannerText = nil
            }
        }
    }

    func toggleUnitDeployment(_ unitId: UUID) {
        guard var run = roguelikeRun else { return }
        guard let idx = run.roster.firstIndex(where: { $0.id == unitId }) else { return }
        if run.roster[idx].pieceType == 6 { return }
        run.roster[idx].isDeployed.toggle()
        roguelikeRun = run
        saveRoguelikeRun()
        SoundEngine.shared.play("click", enabled: sfxEnabled)
    }

    // MARK: - Board Input

    func tapSquare(_ s: Int) {
        guard s >= 0, s < 64 else { return }
        guard !inMenu, !isPaused, !isAnimating, !isThinking, pendingRoguelikePromotion == nil else { return }

        if isPreparationPhase {
            handlePrepTap(s)
            return
        }

        guard isHumanTurn else { return }

        if let skill = activeSkillMode {
            handleSkillTap(skill: skill, square: s)
            return
        }

        if selectedSquare != nil && legalForSelected.contains(where: { $0.to == s }) {
            attemptMove(to: s)
            return
        }
        let piece = board.sq[s]
        if piece != 0 && piece > 0 {
            if selectedSquare == s {
                clearSelection()
            } else {
                select(s)
            }
        } else {
            clearSelection()
        }
    }

    private func handlePrepTap(_ s: Int) {
        guard s < 24, board.tiles[s] != .blocked else {
            selectedPrepSquare = nil
            refreshHighlights()
            return
        }
        if let from = selectedPrepSquare {
            if from != s && (board.sq[s] >= 0) {
                board.sq.swapAt(from, s)
                board.classes.swapAt(from, s)
                if var bs = battleState {
                    let u1 = bs.unitMap[from]
                    let u2 = bs.unitMap[s]
                    bs.unitMap[from] = u2
                    bs.unitMap[s] = u1
                    battleState = bs
                }
                boardCtl.reset(board: board, flipped: false)
                SoundEngine.shared.play("move", enabled: sfxEnabled)
            }
            selectedPrepSquare = nil
            refreshHighlights()
        } else if board.sq[s] > 0 {
            selectedPrepSquare = s
            refreshHighlights()
            SoundEngine.shared.play("select", enabled: sfxEnabled)
        }
    }

    func beginPieceDrag(square s: Int, atLocal: SCNVector3) -> Bool {
        guard controlMode == .drag, !isPreparationPhase, !inMenu, !isPaused, !isAnimating else { return false }
        guard s >= 0, s < 64 else { return false }
        guard boardCtl.beginDrag(square: s, atLocal: atLocal) else { return false }
        draggingSourceSquare = s
        if !isThinking, pendingRoguelikePromotion == nil, isHumanTurn {
            let p = board.sq[s]
            if p > 0 {
                selectedSquare = s
                legalForSelected = board.legalMoves().filter { $0.from == s }
                updateSelectedTooltip(for: s)
                refreshHighlights()
            }
        }
        SoundEngine.shared.play("select", enabled: sfxEnabled)
        return true
    }

    func updatePieceDrag(toLocal: SCNVector3) {
        boardCtl.updateDrag(toLocal: toLocal)
    }

    func endPieceDrag(atLocal: SCNVector3?, releaseVelocity: SCNVector3) {
        boardCtl.endDrag(releaseVelocity: releaseVelocity)
        guard let from = draggingSourceSquare else { return }
        draggingSourceSquare = nil

        if let loc = atLocal,
           !inMenu, !isPaused, !isAnimating, !isThinking, pendingRoguelikePromotion == nil, isHumanTurn {
            let p = board.sq[from]
            if p > 0 {
                let col = Int(round(loc.x + 3.5))
                let row = Int(round(3.5 - loc.z))
                if col >= 0 && col < 8 && row >= 0 && row < 8 {
                    let targetSq = row * 8 + col
                    let tp = boardCtl.pos(targetSq)
                    let dx = loc.x - tp.x
                    let dz = loc.z - tp.z
                    if (dx * dx + dz * dz) < 0.65 * 0.65,
                       legalForSelected.contains(where: { $0.from == from && $0.to == targetSq }) {
                        selectedSquare = from
                        attemptMove(to: targetSq)
                        return
                    }
                }
            }
        }
    }

    func knockOverPiece(at square: Int, viewDir: SCNVector3) {
        guard controlMode == .drag, !isPreparationPhase, !inMenu, !isPaused, !isAnimating else { return }
        boardCtl.topplePiece(at: square, viewDir: viewDir)
        SoundEngine.shared.play("click", enabled: sfxEnabled)
        haptic(.medium)
    }

    private func select(_ s: Int) {
        selectedSquare = s
        legalForSelected = board.legalMoves().filter { $0.from == s }
        if controlMode == .tap { boardCtl.setLift(s) }
        updateSelectedTooltip(for: s)
        SoundEngine.shared.play("select", enabled: sfxEnabled)
        refreshHighlights()
    }

    private func updateSelectedTooltip(for s: Int) {
        let t = abs(Int(board.sq[s]))
        let uc = board.classes.count == 64 ? board.classes[s] : .standard
        if t == 6 && board.kingLeapReady {
            selectedUnitTooltip = "👑 Король • 🐴 Прыжок конём готов!"
        } else if uc != .standard {
            selectedUnitTooltip = "\(pieceTitle(t)) [\(uc.title)]: \(uc.description)"
        } else if board.tiles.count == 64 && board.tiles[s] != .none {
            selectedUnitTooltip = board.tiles[s].title
        } else {
            selectedUnitTooltip = nil
        }
    }

    private func clearSelection() {
        if selectedSquare == nil { return }
        selectedSquare = nil
        legalForSelected = []
        selectedUnitTooltip = nil
        boardCtl.setLift(nil)
        refreshHighlights()
    }

    private func attemptMove(to t: Int) {
        guard let from = selectedSquare else { return }
        let candidates = legalForSelected.filter { $0.to == t }
        guard let first = candidates.first else { return }
        if candidates.count > 1 {
            let pClass = board.classes.count == 64 ? board.classes[from] : .recruit
            let buffs = Array(AscensionBuff.allCases.shuffled().prefix(3))
            pendingRoguelikePromotion = RoguelikePromotionRequest(
                from: from,
                to: t,
                pawnClass: pClass == .standard ? .recruit : pClass,
                buffChoices: buffs
            )
            return
        }
        play(first)
    }

    func confirmRoguelikePromotion(pieceType: Int, buff: AscensionBuff) {
        guard let req = pendingRoguelikePromotion else { return }
        pendingRoguelikePromotion = nil
        pendingAscensionBuff = buff
        if let m = legalForSelected.first(where: { $0.from == req.from && $0.to == req.to && $0.promo == pieceType }) {
            play(m)
        }
    }

    func cancelRoguelikePromotion() {
        pendingRoguelikePromotion = nil
        pendingAscensionBuff = nil
    }

    private func play(_ m: Move) {
        guard !isAnimating, roguelikeRun?.phase == .inBattle else { return }
        let before = board
        var after = before
        after.apply(m)
        let capture = before.isCapture(m)
        let note = describeMove(m, before: before, after: after)

        history.append(HistoryEntry(
            board: before,
            prevLastMove: lastMove,
            prevNotation: lastMoveNotation,
            battleSnapshot: battleState,
            prevUndoCount: undoCount
        ))

        if var bs = battleState {
            processRoguelikeMoveHooks(move: m, before: before, after: &after, bs: &bs)
            battleState = bs
        }

        board = after
        lastMove = m
        lastMoveNotation = note
        selectedSquare = nil
        legalForSelected = []
        selectedUnitTooltip = nil
        isAnimating = true
        isCheckNow = false
        boardCtl.setHighlights(selected: nil, targets: [:], last: m, check: nil)

        SoundEngine.shared.play(capture ? "capture" : "move", enabled: sfxEnabled)
        if capture {
            let tok = gameToken
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self = self, self.gameToken == tok else { return }
                SoundEngine.shared.play("blackhole", enabled: self.sfxEnabled)
            }
        }
        haptic(capture ? .heavy : .medium)
        if m.promo != 0 { SoundEngine.shared.speak("Пешка возвышается!", enabled: voiceEnabled) }

        let token = gameToken
        boardCtl.animate(move: m, before: before, after: after) { [weak self] in
            guard let self = self, self.gameToken == token else { return }
            self.finishMove(lastWasWhite: before.whiteToMove, lastMoveTo: m.to)
        }
    }

    private func processRoguelikeMoveHooks(move m: Move, before: ChessBoard, after: inout ChessBoard, bs: inout RoguelikeBattleState) {
        bs.movesPlayed += 1
        let synergies = activeSynergies
        let hasChronoSyn = synergies.contains { $0.id == "chrono" }
        let hasBerserkSyn = synergies.contains { $0.id == "berserk" }
        let hasGuardianSyn = synergies.contains { $0.id == "guardian" }
        let hasQuantumSyn = synergies.contains { $0.id == "quantum" }

        let hasTreasury = roguelikeRun?.relics.contains(.royalTreasury) ?? false
        let isVanguard = roguelikeRun?.commander == .vanguard

        if before.whiteToMove {
            let energyGain = (bs.node.planet == .jupiter ? 13 : 8)
            bs.energy = min(100, bs.energy + energyGain)

            if hasChronoSyn && bs.movesPlayed % 10 == 0 {
                undoCount += 1
                showBanner("⏳ Хроно-Резонанс: +1 Откат!")
            }

            let movingId = bs.unitMap[m.from]
            bs.unitMap[m.to] = movingId
            bs.unitMap[m.from] = nil

            let movingUnit = movingId.flatMap { bs.units[$0] }
            let uClass = movingUnit?.unitClass ?? .standard
            let unitType = movingUnit?.pieceType ?? abs(Int(before.sq[m.from]))

            if unitType == 1 && uClass == .golden {
                bs.battleCredits += 5
            }

            if before.isCapture(m) {
                bs.energy = min(100, bs.energy + 16)
                let capType = abs(Int(before.sq[m.to]))
                let realCap = capType == 0 ? 1 : capType
                var bounty = [0, 8, 14, 14, 20, 32, 0][min(6, realCap)]
                if uClass == .golden { bounty += 20 }
                if uClass == .berserk {
                    bounty += 15
                    if unitType >= 2 { bs.energy = min(100, bs.energy + 25) }
                }
                if uClass == .chrono && unitType >= 2 && realCap >= 2 && bs.warlordUndoGains < 2 {
                    bs.warlordUndoGains += 1
                    undoCount += 1
                }
                if uClass == .quantum && unitType >= 2 {
                    after.kingLeapReady = true
                }
                if uClass == .nova && unitType >= 2 {
                    bs.pendingNovaStrikes += 1
                }
                if hasBerserkSyn {
                    bounty += 10
                    bs.energy = min(100, bs.energy + 12)
                }
                if hasQuantumSyn {
                    after.kingLeapReady = true
                }
                if hasTreasury { bounty = Int(Double(bounty) * 1.35) }
                if isVanguard { bounty = Int(Double(bounty) * 1.25) }
                bs.battleCredits += bounty
                roguelikeRun?.enemiesCaptured += 1

                if realCap >= 2 && (roguelikeRun?.relics.contains(.warlordFury) ?? false) {
                    bs.battleCredits += 15
                    if bs.warlordUndoGains < 2 {
                        bs.warlordUndoGains += 1
                        undoCount += 1
                        showBanner("⚔️ Ярость: +15 🪙 и +1 Откат!")
                    }
                }
            }

            if m.promo != 0, let uid = movingId, var u = bs.units[uid] {
                u.pieceType = m.promo
                u.ascendedCount += 1
                bs.units[uid] = u
                roguelikeRun?.pawnsPromoted += 1

                switch u.unitClass {
                case .recruit: bs.battleCredits += 25
                case .golden: bs.battleCredits += 80
                case .berserk: undoCount += 1; bs.pendingNovaStrikes += 1
                case .guardian: bs.aegisLeft += 1
                case .chrono: undoCount += 2; bs.battleBonusUndos += 1
                case .quantum: after.kingLeapReady = true
                case .nova: bs.pendingNovaStrikes += 1
                case .standard: break
                }

                if let buff = pendingAscensionBuff {
                    pendingAscensionBuff = nil
                    switch buff {
                    case .credits80:
                        bs.battleCredits += 80
                    case .chronoUndo:
                        undoCount += 2
                        bs.battleBonusUndos += 1
                    case .aegisShield:
                        bs.aegisLeft += 1
                    case .blackHoleStrike:
                        bs.pendingNovaStrikes += 1
                    case .royalLeap:
                        after.kingLeapReady = true
                        if !(roguelikeRun?.relics.contains(.royalLeap) ?? false) && !bs.earnedRelics.contains(.royalLeap) {
                            bs.earnedRelics.append(.royalLeap)
                        }
                    case .treasuryBoost:
                        bs.battleCredits += 40
                        if !(roguelikeRun?.relics.contains(.royalTreasury) ?? false) && !bs.earnedRelics.contains(.royalTreasury) {
                            bs.earnedRelics.append(.royalTreasury)
                        }
                    }
                    showBanner("\(buff.icon) Возвышение: \(buff.rawValue)!")
                }
            }
        } else {
            if before.isCapture(m) {
                let capSq = before.sq[m.to] != 0 ? m.to : (m.from >> 3) * 8 + (m.to & 7)
                if let lostId = bs.unitMap[capSq], let lostUnit = bs.units[lostId] {
                    bs.unitMap[capSq] = nil
                    if lostUnit.pieceType == 1 {
                        if lostUnit.unitClass == .guardian && !bs.guardianSavedIds.contains(lostId) {
                            bs.guardianSavedIds.insert(lostId)
                            showBanner("🛡️ Страж-пешка спаслась в резерв!")
                        } else {
                            bs.destroyedIds.insert(lostId)
                            if lostUnit.unitClass == .chrono {
                                undoCount += 1
                                showBanner("⏳ Хроно-пешка: +1 Откат!")
                            } else if lostUnit.unitClass == .nova {
                                bs.pendingNovaStrikes += 1
                            }
                        }
                    } else if lostUnit.pieceType >= 2 && lostUnit.pieceType <= 5 {
                        if (lostUnit.unitClass == .guardian || hasGuardianSyn) && !bs.guardianSavedIds.contains(lostId) {
                            bs.guardianSavedIds.insert(lostId)
                            showBanner("🛡️ \(pieceTitle(lostUnit.pieceType)) уцелела без поломки!")
                        } else {
                            bs.damagedIds.insert(lostId)
                            showBanner("⚠️ \(pieceTitle(lostUnit.pieceType)) подбита")
                        }
                        if lostUnit.unitClass == .nova {
                            bs.pendingNovaStrikes += 1
                        }
                    }
                }
            }
        }
    }

    private func resolveArenaTileAfterMove(square s: Int, wasWhite: Bool) {
        guard s >= 0, s < 64, board.tiles.count == 64 else { return }
        let mod = board.tiles[s]
        guard mod != .none && mod != .blocked else { return }
        guard var bs = battleState else { return }

        board.tiles[s] = .none
        switch mod {
        case .goldVein:
            if wasWhite {
                bs.battleCredits += 35
                battleState = bs
                boardCtl.spawnBurst(at: s, color: .yellow)
                showBanner("🪙 Золотая жила: +35 🪙!")
            }
        case .ascensionPad:
            if wasWhite && abs(Int(board.sq[s])) == 1 {
                let col = s & 7
                let curRow = s >> 3
                var destSq: Int? = nil
                if curRow < 6 {
                    for targetRow in stride(from: 6, through: curRow + 1, by: -1) {
                        let cand = targetRow * 8 + col
                        if board.sq[cand] == 0 && board.tiles[cand] != .blocked {
                            var test = board
                            test.sq[cand] = test.sq[s]
                            test.sq[s] = 0
                            if !test.inCheck(white: false) {
                                destSq = cand
                                break
                            }
                        }
                    }
                }
                if let d = destSq {
                    board.sq[d] = board.sq[s]
                    board.sq[s] = 0
                    board.classes[d] = board.classes[s]
                    board.classes[s] = .standard
                    bs.unitMap[d] = bs.unitMap[s]
                    bs.unitMap[s] = nil
                    battleState = bs
                    boardCtl.reset(board: board, flipped: false)
                    boardCtl.spawnBurst(at: d, color: .cyan)
                    showBanner("⚡ Трамплин вознёс пешку на \(squareName(d))!")
                }
            }
        case .voidRift:
            let p = board.sq[s]
            if p != 0 && abs(Int(p)) != 6 {
                var test = board
                test.sq[s] = 0
                if !test.inCheck(white: true) && !test.inCheck(white: false) {
                    board.sq[s] = 0
                    board.classes[s] = .standard
                    if p > 0, let uid = bs.unitMap[s], let u = bs.units[uid] {
                        bs.unitMap[s] = nil
                        if u.pieceType == 1 { bs.destroyedIds.insert(uid) } else { bs.damagedIds.insert(uid) }
                    } else if p < 0 {
                        bs.battleCredits += 15
                    }
                    battleState = bs
                    boardCtl.obliterateWithBlackHole(at: s)
                    SoundEngine.shared.play("blackhole", enabled: sfxEnabled)
                    showBanner("🕳️ Разлом Бездны поглотил фигуру на \(squareName(s))!")
                }
            }
        default:
            break
        }
    }

    private func finishMove(lastWasWhite: Bool, lastMoveTo: Int) {
        isAnimating = false
        resolveArenaTileAfterMove(square: lastMoveTo, wasWhite: lastWasWhite)

        if var bs = battleState, bs.pendingNovaStrikes > 0 {
            let count = bs.pendingNovaStrikes
            bs.pendingNovaStrikes = 0
            battleState = bs
            for _ in 0..<count {
                _ = triggerBlackHoleStrike(preferPawn: false, banner: "🕳️ Сверхновая поглотила врага!")
            }
        }

        if let bs = battleState, !bs.synergyNovaTriggered, bs.movesPlayed >= 5,
           activeSynergies.contains(where: { $0.id == "nova" }) {
            battleState?.synergyNovaTriggered = true
            _ = triggerBlackHoleStrike(preferPawn: true, banner: "☄️ Коллапс Звёзд снёс врага!")
        }

        if !lastWasWhite {
            maybeTriggerBossPhase2()
            maybeTriggerFallingAsteroid()
        }

        isCheckNow = board.inCheck(white: board.whiteToMove)
        positionCounts[board.key, default: 0] += 1
        evaluateRoguelikeBattleState()
        refreshHighlights()
        if roguelikeRun?.phase != .inBattle { return }
        if isCheckNow {
            SoundEngine.shared.play("check", enabled: sfxEnabled)
            SoundEngine.shared.speak("Шах!", enabled: voiceEnabled)
        } else {
            SoundEngine.shared.play("click", enabled: sfxEnabled)
        }
        updateStatus()
        if !isHumanTurn { triggerBotMove() }
    }

    private func evaluateRoguelikeBattleState() {
        guard var bs = battleState else { return }
        let blackNonKingCount = (0..<64).filter { board.sq[$0] < 0 && board.sq[$0] != -6 }.count
        if blackNonKingCount == 0 && !board.inCheck(white: true) {
            let bk = board.kingSquare(white: false)
            if bk >= 0 { boardCtl.obliterateWithBlackHole(at: bk) }
            completeRoguelikeBattleVictory(bonusNote: "Полное сокрушение врага!")
            return
        }

        let legal = board.legalMoves()
        if legal.isEmpty {
            if isCheckNow {
                if !board.whiteToMove {
                    bs.battleCredits += 30
                    battleState = bs
                    completeRoguelikeBattleVictory(bonusNote: "Блиц-Мат! (+30 🪙)")
                } else {
                    if bs.aegisLeft > 0 && history.count >= 2 {
                        triggerKingAegisDeathDefiance()
                    } else {
                        failRoguelikeRun()
                    }
                }
            } else {
                if !board.whiteToMove {
                    completeRoguelikeBattleVictory(bonusNote: "Враг загнан в пат и сдался!")
                } else {
                    if let node = roguelikeRun?.activeNode {
                        showBanner("Пат! Переигровка сектора…")
                        startRoguelikeBattle(node: node)
                    }
                }
            }
            return
        }

        if board.halfmove >= 100 || (positionCounts[board.key] ?? 0) >= 3 {
            if let node = roguelikeRun?.activeNode {
                showBanner("Тактическая ничья — переигровка!")
                startRoguelikeBattle(node: node)
            }
        }
    }

    private func triggerKingAegisDeathDefiance() {
        guard var bs = battleState else { return }
        bs.aegisLeft -= 1
        var targetEntry: HistoryEntry? = nil
        while let entry = history.popLast() {
            targetEntry = entry
            if entry.board.whiteToMove { break }
        }
        guard let snap = targetEntry else { return }
        board = snap.board
        lastMove = snap.prevLastMove
        lastMoveNotation = "🛡️ Эгида спасла от мата!"
        positionCounts[board.key] = 1
        if var restoredBs = snap.battleSnapshot {
            restoredBs.aegisLeft = bs.aegisLeft
            battleState = restoredBs
        } else {
            battleState = bs
        }
        roguelikeRun?.aegisCharges = bs.aegisLeft
        isCheckNow = board.inCheck(white: true)
        selectedSquare = nil
        legalForSelected = []
        boardCtl.reset(board: board, flipped: false)
        refreshHighlights()
        updateStatus()
        showBanner("🛡️ ЭГИДА КОРОЛЯ СПАСЛА ТЕБЯ ОТ МАТА!")
        SoundEngine.shared.play("win", enabled: sfxEnabled)
        SoundEngine.shared.speak("Эгида спасла короля!", enabled: voiceEnabled)
        haptic(.heavy)
    }

    private func completeRoguelikeBattleVictory(bonusNote: String) {
        guard var run = roguelikeRun, let bs = battleState else { return }
        gameToken += 1
        isThinking = false
        isAnimating = false
        selectedSquare = nil
        legalForSelected = []
        activeSkillMode = nil
        skillFirstSquare = nil

        var baseReward = 45 + bs.node.layer * 8 + run.galaxy.rawValue * 18
        if bs.node.type == .elite { baseReward += 35 }
        if bs.node.type == .boss { baseReward += 100 }
        if run.relics.contains(.royalTreasury) { baseReward = Int(Double(baseReward) * 1.35) }
        if run.commander == .vanguard { baseReward = Int(Double(baseReward) * 1.25) }

        var totalEarned = baseReward + bs.battleCredits
        if activeSynergies.contains(where: { $0.id == "golden" }) {
            totalEarned += Int(Double(run.credits) * 0.15)
        }

        var nextRoster: [RoguelikeUnit] = []
        for u in run.roster {
            if bs.destroyedIds.contains(u.id) {
                run.pawnsLost += 1
                continue
            }
            if var updated = bs.units[u.id] {
                if bs.damagedIds.contains(u.id) {
                    updated.isDamaged = true
                }
                nextRoster.append(updated)
            } else {
                nextRoster.append(u)
            }
        }

        var repairedMsg = ""
        if run.relics.contains(.fieldRepair) {
            if let idx = nextRoster.firstIndex(where: { $0.isDamaged }) {
                nextRoster[idx].isDamaged = false
                repairedMsg = " • 🔧 Починена: \(pieceTitle(nextRoster[idx].pieceType))"
            }
        }

        run.roster = nextRoster
        run.credits += totalEarned
        run.bonusUndos += bs.battleBonusUndos
        run.aegisCharges = bs.aegisLeft
        for r in bs.earnedRelics where !run.relics.contains(r) {
            run.relics.append(r)
        }
        run.battlesWon += 1
        if bs.node.type == .elite { run.elitesDefeated += 1 }
        if !run.completedNodeIds.contains(bs.node.id) {
            run.completedNodeIds.append(bs.node.id)
        }
        run.currentNodeId = bs.node.id
        run.currentLayer = bs.node.layer
        run.activeNode = nil

        roguelikeMeta.bestSectorReached = max(roguelikeMeta.bestSectorReached, bs.node.layer + 1 + run.galaxy.rawValue * 8)
        roguelikeMeta.bestGalaxyReached = max(roguelikeMeta.bestGalaxyReached, run.galaxy.rawValue + 1)

        lastBattleSummary = "\(bonusNote) +\(totalEarned) 🪙 • Погибло пешек: \(bs.destroyedIds.count)\(repairedMsg)"
        SoundEngine.shared.play("win", enabled: sfxEnabled)
        SoundEngine.shared.speak("Сектор зачищен!", enabled: voiceEnabled)
        boardCtl.celebrate()

        if bs.node.layer == run.mapLayers.count - 1 {
            let cursePct = run.curses.reduce(0) { $0 + $1.shardBonus }
            let baseShards = 45 + run.battlesWon * 8 + run.elitesDefeated * 12 + run.pawnsPromoted * 10
            let shards = baseShards + (baseShards * cursePct / 100)
            roguelikeMeta.starShards += shards
            roguelikeMeta.runsCompleted += 1
            roguelikeMeta.runsWon += 1
            runEndShardsEarned = shards
            runEndTitle = "\(run.galaxy.title.uppercased()) ПРОЙДЕНА!"
            run.phase = .victory
            roguelikeRun = run
            saveRoguelikeRun()
            saveRoguelikeMeta()
        } else {
            run.phase = .reward
            roguelikeRun = run
            generateRewardOptions(forElite: bs.node.type == .elite)
            saveRoguelikeRun()
            saveRoguelikeMeta()
        }
        battleState = nil
    }

    private func failRoguelikeRun() {
        guard var run = roguelikeRun else { return }
        gameToken += 1
        isThinking = false
        isAnimating = false
        selectedSquare = nil
        legalForSelected = []
        activeSkillMode = nil

        let cursePct = run.curses.reduce(0) { $0 + $1.shardBonus }
        let baseShards = 10 + run.battlesWon * 6 + run.elitesDefeated * 10 + run.pawnsPromoted * 8
        let shards = baseShards + (baseShards * cursePct / 100)
        roguelikeMeta.starShards += shards
        roguelikeMeta.runsCompleted += 1
        runEndShardsEarned = shards
        runEndTitle = "КОРОЛЬ ПАЛ — КОНЕЦ ЗАБЕГА"

        run.phase = .gameOver
        roguelikeRun = run
        battleState = nil
        SoundEngine.shared.play("check", enabled: sfxEnabled)
        SoundEngine.shared.speak("Конец забега. Звёзды помнят твой поход.", enabled: voiceEnabled)
        haptic(.heavy)
        saveRoguelikeMeta()
        deleteRoguelikeRun()
    }

    func advanceToNextGalaxy() {
        guard var run = roguelikeRun else { return }
        let nextGal = run.galaxy.next ?? .omega
        run.galaxy = nextGal
        run.currentLayer = 0
        run.currentNodeId = nil
        run.activeNode = nil
        run.completedNodeIds = []
        run.mapLayers = generateCosmicMap(galaxy: nextGal)
        run.phase = .map
        roguelikeRun = run
        space.setGalaxyTheme(nextGal)
        space.setSectorTheme(.mercury)
        space.startMenuOrbit()
        saveRoguelikeRun()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
    }

    func abandonRoguelikeRun() {
        if let run = roguelikeRun, run.phase != .victory && run.phase != .gameOver {
            let shards = max(5, run.battlesWon * 4)
            roguelikeMeta.starShards += shards
            roguelikeMeta.runsCompleted += 1
            saveRoguelikeMeta()
        }
        deleteRoguelikeRun()
        roguelikeRun = nil
        battleState = nil
        inMenu = true
        space.setGalaxyTheme(.solar)
        space.setSectorTheme(nil)
        space.startMenuOrbit()
    }

    private func updateStatus() {
        turnIsWhite = board.whiteToMove
        let planetName = battleState?.node.planet.rawValue ?? "Космос"
        if isPreparationPhase {
            statusText = "Расстановка • Меняй фигуры и жми В БОЙ"
        } else if isHumanTurn {
            statusText = isCheckNow ? "Шах! Защити Короля • \(planetName)" : "Твой ход • \(planetName)"
        } else {
            statusText = "Враг просчитывает ход…"
        }
    }

    private func refreshHighlights() {
        var targets: [Int: Bool] = [:]
        var prepSquares: [Int] = []
        var skillSquares: [Int] = []

        if isPreparationPhase {
            prepSquares = (0..<24).filter { board.sq[$0] > 0 || (selectedPrepSquare != nil && board.sq[$0] == 0 && board.tiles[$0] != .blocked) }
            boardCtl.setHighlights(selected: selectedPrepSquare, targets: [:], last: nil, check: nil, prepTargets: prepSquares, skillTargets: [])
            return
        }

        if let sk = activeSkillMode {
            skillSquares = skillValidSquares(for: sk)
            boardCtl.setHighlights(selected: skillFirstSquare, targets: [:], last: lastMove, check: nil, prepTargets: [], skillTargets: skillSquares)
            return
        }

        if showHints {
            for m in legalForSelected { targets[m.to] = board.isCapture(m) }
        }
        var checkSq: Int? = nil
        if isCheckNow {
            let k = board.kingSquare(white: board.whiteToMove)
            if k >= 0 { checkSq = k }
        }
        boardCtl.setHighlights(selected: selectedSquare, targets: targets, last: lastMove, check: checkSq)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func triggerBotMove() {
        guard !inMenu, roguelikeRun?.phase == .inBattle, !isHumanTurn, !isThinking else { return }

        isThinking = true
        updateStatus()
        let snapshot = board
        let token = gameToken

        let aiDiff: BotDifficulty
        if let node = battleState?.node {
            let tier = node.layer + (roguelikeRun?.galaxy.rawValue ?? 0) * 3
            if node.type == .boss || tier >= 6 {
                aiDiff = .hard
            } else if node.type == .elite || tier >= 3 {
                aiDiff = .medium
            } else {
                aiDiff = .easy
            }
        } else {
            aiDiff = .medium
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ai = ChessAI()
            let mv = ai.chooseMove(board: snapshot, difficulty: aiDiff)
            DispatchQueue.main.async {
                guard let self = self, self.gameToken == token, !self.inMenu else { return }
                self.isThinking = false
                guard let m = mv else { return }
                if self.isPaused || self.isAnimating {
                    self.pendingBotMove = m
                    return
                }
                self.play(m)
            }
        }
    }

    func performUndo() {
        guard !isPreparationPhase, !isAnimating, !isThinking, undoCount > 0, !history.isEmpty, pendingRoguelikePromotion == nil else { return }
        gameToken += 1
        pendingBotMove = nil
        activeSkillMode = nil
        skillFirstSquare = nil
        while let entry = history.popLast() {
            let k = board.key
            if let n = positionCounts[k] {
                if n <= 1 { positionCounts.removeValue(forKey: k) } else { positionCounts[k] = n - 1 }
            }
            board = entry.board
            lastMove = entry.prevLastMove
            lastMoveNotation = entry.prevNotation
            if let bs = entry.battleSnapshot {
                battleState = bs
            }
            if board.whiteToMove { break }
        }
        undoCount -= 1
        selectedSquare = nil
        legalForSelected = []
        selectedUnitTooltip = nil
        isCheckNow = board.inCheck(white: board.whiteToMove)
        boardCtl.reset(board: board, flipped: false)
        refreshHighlights()
        updateStatus()
        statusText = "Ход отменён. " + statusText
        SoundEngine.shared.play("select", enabled: sfxEnabled)
        haptic(.medium)
    }

    // MARK: - Rewards, Shop, Cases, Packs, Patchers

    private func generateRewardOptions(forElite: Bool) {
        guard let run = roguelikeRun else { return }
        var opts: [RewardOption] = []

        let roll = Int.random(in: 0..<100)
        if forElite && roll < 32 {
            let cls: UnitClass = [.golden, .berserk, .chrono, .quantum].randomElement() ?? .golden
            opts.append(RewardOption(
                kind: .unit(pieceType: 5, unitClass: cls),
                title: "♕ Ферзь [\(cls.title)]",
                subtitle: "Мощнейшая элита в твою армию.",
                icon: "♕",
                accent: cls.swiftUIColor
            ))
        } else if roll < 48 {
            let cls: UnitClass = [.berserk, .golden, .guardian, .chrono].randomElement() ?? .recruit
            opts.append(RewardOption(
                kind: .unit(pieceType: 4, unitClass: cls),
                title: "♖ Ладья [\(cls.title)]",
                subtitle: "Тяжёлая фигура для удержания флангов.",
                icon: "♖",
                accent: cls.swiftUIColor
            ))
        } else {
            let t = [2, 3].randomElement() ?? 2
            let cls: UnitClass = [.standard, .golden, .berserk, .guardian].randomElement() ?? .standard
            opts.append(RewardOption(
                kind: .unit(pieceType: t, unitClass: cls),
                title: "\(pieceGlyph(t)) \(pieceTitle(t)) [\(cls.title)]",
                subtitle: "Усиливает твой отряд перед следующим сектором.",
                icon: pieceGlyph(t),
                accent: cls.swiftUIColor
            ))
        }

        let missingRelics = RoguelikeRelic.allCases.filter { !run.relics.contains($0) }
        if let r = missingRelics.randomElement() {
            opts.append(RewardOption(
                kind: .relic(r),
                title: "\(r.icon) \(r.rawValue)",
                subtitle: r.description,
                icon: r.icon,
                accent: .purple
            ))
        } else {
            let cls: UnitClass = [.quantum, .nova, .chrono].randomElement() ?? .chrono
            opts.append(RewardOption(
                kind: .unit(pieceType: 1, unitClass: cls),
                title: "♙ Редкая пешка [\(cls.title)]",
                subtitle: cls.description,
                icon: "♙",
                accent: cls.swiftUIColor
            ))
        }

        if run.roster.contains(where: { $0.isDamaged }) {
            let pCls: UnitClass = [.recruit, .guardian, .golden].randomElement() ?? .recruit
            opts.append(RewardOption(
                kind: .repairAndPawn(unitClass: pCls),
                title: "🔧 Ремонт + ♙ [\(pCls.title)]",
                subtitle: "Чинит 1 подбитую фигуру и даёт дефицитную пешку.",
                icon: "🔧",
                accent: .green
            ))
        } else {
            opts.append(RewardOption(
                kind: .extraUndoAndCredits(undos: 1, credits: 40),
                title: "↩️ +1 Макс. Откат и +40 🪙",
                subtitle: "Навсегда увеличивает число откатов в каждом бою.",
                icon: "⏳",
                accent: .orange
            ))
        }

        rewardOptions = opts
    }

    func chooseReward(_ option: RewardOption) {
        guard var run = roguelikeRun else { return }
        switch option.kind {
        case .unit(let pt, let cls):
            run.roster.append(RoguelikeUnit(pieceType: pt, unitClass: cls))
        case .relic(let r):
            if !run.relics.contains(r) { run.relics.append(r) }
            if r == .kingAegis { run.aegisCharges += 1 }
        case .extraUndoAndCredits(let u, let c):
            run.bonusUndos += u
            run.credits += c
        case .repairAndPawn(let cls):
            if let idx = run.roster.firstIndex(where: { $0.isDamaged }) {
                run.roster[idx].isDamaged = false
            }
            run.roster.append(RoguelikeUnit(pieceType: 1, unitClass: cls))
        }
        run.phase = .map
        roguelikeRun = run
        rewardOptions = []
        space.startMenuOrbit()
        saveRoguelikeRun()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
    }

    func skipRewardForGold() {
        guard var run = roguelikeRun else { return }
        run.credits += 35
        run.phase = .map
        roguelikeRun = run
        rewardOptions = []
        space.startMenuOrbit()
        saveRoguelikeRun()
        SoundEngine.shared.play("click", enabled: sfxEnabled)
    }

    private func generateShopItems() {
        guard let run = roguelikeRun else { return }
        let mult = run.curses.contains(.inflation) ? 1.25 : 1.0
        func p(_ v: Int) -> Int { Int(Double(v) * mult) }

        var items: [ShopItem] = []

        // Tab 1: ALL Units (Unlimited repeatable purchase!)
        items.append(ShopItem(title: "♙ Пешка-Рекрут", subtitle: "Пополнение дефицита пешек (безлимитно).", icon: "♙", price: p(35), unlimited: true, tab: .units, kind: .unit(pieceType: 1, unitClass: .recruit)))
        items.append(ShopItem(title: "🎲 Пешка Особого Класса", subtitle: "Случайная редкая пешка (Золотая/Берсерк/Страж/Хроно/Квантовая/Сверхновая).", icon: "🌟", price: p(55), unlimited: true, tab: .units, kind: .randomRarePawn))
        items.append(ShopItem(title: "♘ Конь", subtitle: "Перепрыгивает астероиды и врагов (безлимитно).", icon: "♘", price: p(75), unlimited: true, tab: .units, kind: .unit(pieceType: 2, unitClass: .standard)))
        items.append(ShopItem(title: "♗ Слон", subtitle: "Диагональный снайпер (безлимитно).", icon: "♗", price: p(80), unlimited: true, tab: .units, kind: .unit(pieceType: 3, unitClass: .standard)))
        items.append(ShopItem(title: "♖ Ладья", subtitle: "Мощная осадная башня (безлимитно).", icon: "♖", price: p(115), unlimited: true, tab: .units, kind: .unit(pieceType: 4, unitClass: .standard)))
        items.append(ShopItem(title: "♕ Ферзь", subtitle: "Королева космоса (безлимитно).", icon: "♕", price: p(185), unlimited: true, tab: .units, kind: .unit(pieceType: 5, unitClass: .standard)))

        // Tab 2: Cases & Packs
        let caseDisc = roguelikeMeta.unlockedPerks.contains(.cheapRoulette) ? 10 : 0
        items.append(ShopItem(title: "📦 Кейс Новобранца", subtitle: "1 случайная классовая пешка (шанс на редкий класс).", icon: "📦", price: max(30, p(50) - caseDisc), unlimited: true, tab: .casesPacks, kind: .normalCase))
        items.append(ShopItem(title: "💎 Элитный Кейс Титана", subtitle: "Редкая пешка (Хроно/Квантовая/Сверхновая) или Классовый Офицер!", icon: "💎", price: max(75, p(115) - caseDisc), unlimited: true, tab: .casesPacks, kind: .eliteCase))
        items.append(ShopItem(title: "🃏 Пак «Эскадрилья» (×3)", subtitle: "Открывает 3 карты: 2 классовые пешки + 1 Офицер или Патч!", icon: "🃏", price: p(135), unlimited: true, tab: .casesPacks, kind: .squadPack))
        items.append(ShopItem(title: "🌌 Пак Артефактов (×3)", subtitle: "Открывает Реликвию + Элитную пешку + Кредиты/Эгиду!", icon: "🌌", price: p(165), unlimited: true, tab: .casesPacks, kind: .relicPack))

        // Tab 3: Patchers
        for pk in PatcherKind.allCases {
            items.append(ShopItem(title: "\(pk.icon) \(pk.rawValue)", subtitle: pk.description, icon: pk.icon, price: p(pk.price), unlimited: true, tab: .patchers, kind: .patcher(pk)))
        }

        // Tab 4: Relics & King Upgrades
        let missingRelics = RoguelikeRelic.allCases.filter { !run.relics.contains($0) }
        for r in missingRelics.prefix(2) {
            items.append(ShopItem(title: "\(r.icon) \(r.rawValue)", subtitle: r.description, icon: r.icon, price: p(105), unlimited: false, tab: .relics, kind: .relic(r)))
        }
        items.append(ShopItem(title: "↩️ +1 Макс. Откат", subtitle: "Постоянное право на дополнительный откат в каждом бою.", icon: "⏳", price: p(70), unlimited: true, tab: .relics, kind: .maxUndo))
        items.append(ShopItem(title: "🛡️ +1 Заряд Эгиды Короля", subtitle: "Дополнительное спасение от смертельного мата.", icon: "🛡️", price: p(85), unlimited: true, tab: .relics, kind: .aegisCharge))

        shopItems = items
    }

    func buyShopItem(_ item: ShopItem) {
        guard var run = roguelikeRun, !item.sold, run.credits >= item.price else { return }

        if case .patcher(let pk) = item.kind {
            guard run.roster.contains(where: { $0.pieceType != 6 }) else {
                showBanner("Нет фигур для патча!")
                return
            }
            pendingPatcher = pk
            return
        }

        run.credits -= item.price
        var openedRewards: [PackReward] = []

        switch item.kind {
        case .unit(let pt, let cls):
            run.roster.append(RoguelikeUnit(pieceType: pt, unitClass: cls))
        case .randomRarePawn:
            let cls: UnitClass = [.golden, .berserk, .guardian, .chrono, .quantum, .nova].randomElement() ?? .golden
            run.roster.append(RoguelikeUnit(pieceType: 1, unitClass: cls))
            openedRewards.append(PackReward(title: "Пешка [\(cls.title)]", subtitle: cls.description, icon: "♙", color: cls.swiftUIColor))
        case .normalCase:
            let cls: UnitClass = [.recruit, .golden, .berserk, .guardian, .chrono].randomElement() ?? .golden
            run.roster.append(RoguelikeUnit(pieceType: 1, unitClass: cls))
            openedRewards.append(PackReward(title: "Кейс: ♙ [\(cls.title)]", subtitle: cls.description, icon: "📦", color: cls.swiftUIColor))
        case .eliteCase:
            if Int.random(in: 0..<100) < 40 {
                let pt = [2, 3, 4].randomElement() ?? 2
                let cls: UnitClass = [.golden, .berserk, .chrono, .quantum, .nova].randomElement() ?? .chrono
                run.roster.append(RoguelikeUnit(pieceType: pt, unitClass: cls))
                openedRewards.append(PackReward(title: "\(pieceTitle(pt)) [\(cls.title)]", subtitle: cls.description, icon: pieceGlyph(pt), color: cls.swiftUIColor))
            } else {
                let cls: UnitClass = [.chrono, .quantum, .nova].randomElement() ?? .quantum
                run.roster.append(RoguelikeUnit(pieceType: 1, unitClass: cls))
                openedRewards.append(PackReward(title: "Редкая ♙ [\(cls.title)]", subtitle: cls.description, icon: "💎", color: cls.swiftUIColor))
            }
        case .squadPack:
            let c1: UnitClass = [.golden, .berserk, .guardian].randomElement() ?? .golden
            let c2: UnitClass = [.chrono, .quantum, .nova, .recruit].randomElement() ?? .chrono
            run.roster.append(RoguelikeUnit(pieceType: 1, unitClass: c1))
            run.roster.append(RoguelikeUnit(pieceType: 1, unitClass: c2))
            openedRewards.append(PackReward(title: "♙ [\(c1.title)]", subtitle: c1.description, icon: "♙", color: c1.swiftUIColor))
            openedRewards.append(PackReward(title: "♙ [\(c2.title)]", subtitle: c2.description, icon: "♙", color: c2.swiftUIColor))
            let pt = [2, 3, 4].randomElement() ?? 2
            let c3: UnitClass = [.berserk, .golden, .guardian, .standard].randomElement() ?? .standard
            run.roster.append(RoguelikeUnit(pieceType: pt, unitClass: c3))
            openedRewards.append(PackReward(title: "\(pieceTitle(pt)) [\(c3.title)]", subtitle: "Боевой офицер!", icon: pieceGlyph(pt), color: .cyan))
        case .relicPack:
            let missing = RoguelikeRelic.allCases.filter { !run.relics.contains($0) }
            if let r = missing.randomElement() {
                run.relics.append(r)
                if r == .kingAegis { run.aegisCharges += 1 }
                openedRewards.append(PackReward(title: r.rawValue, subtitle: r.description, icon: r.icon, color: .purple))
            } else {
                run.aegisCharges += 1
                openedRewards.append(PackReward(title: "+1 Эгида Короля", subtitle: "Защита от мата", icon: "🛡️", color: .green))
            }
            let pCls: UnitClass = [.quantum, .nova, .chrono].randomElement() ?? .nova
            run.roster.append(RoguelikeUnit(pieceType: 1, unitClass: pCls))
            openedRewards.append(PackReward(title: "♙ [\(pCls.title)]", subtitle: pCls.description, icon: "♙", color: pCls.swiftUIColor))
            run.credits += 45
            openedRewards.append(PackReward(title: "+45 Кредитов", subtitle: "Кэшбэк из пака", icon: "🪙", color: .yellow))
        case .patcher:
            break
        case .relic(let r):
            if !run.relics.contains(r) { run.relics.append(r) }
            if r == .kingAegis { run.aegisCharges += 1 }
        case .maxUndo:
            run.bonusUndos += 1
        case .aegisCharge:
            run.aegisCharges += 1
        }

        if let idx = shopItems.firstIndex(where: { $0.id == item.id }) {
            if shopItems[idx].unlimited {
                shopItems[idx].buyCount += 1
                shopItems[idx].price = Int(Double(shopItems[idx].price) * 1.15)
            } else {
                shopItems[idx].sold = true
            }
        }

        roguelikeRun = run
        if !openedRewards.isEmpty {
            activePackRewards = openedRewards
            SoundEngine.shared.play("win", enabled: sfxEnabled)
        } else {
            SoundEngine.shared.play("select", enabled: sfxEnabled)
        }
        saveRoguelikeRun()
    }

    func applyPatcherToUnit(_ unitId: UUID) {
        guard var run = roguelikeRun, let pk = pendingPatcher else { return }
        let mult = run.curses.contains(.inflation) ? 1.25 : 1.0
        let price = Int(Double(pk.price) * mult)
        guard run.credits >= price, let idx = run.roster.firstIndex(where: { $0.id == unitId && $0.pieceType != 6 }) else {
            pendingPatcher = nil
            return
        }

        run.credits -= price
        switch pk {
        case .mutateClass:
            let pool: [UnitClass] = [.golden, .berserk, .guardian, .chrono, .quantum, .nova].filter { $0 != run.roster[idx].unitClass }
            run.roster[idx].unitClass = pool.randomElement() ?? .golden
        case .promoteTier:
            let cur = run.roster[idx].pieceType
            if cur == 1 {
                run.roster[idx].pieceType = [2, 3].randomElement() ?? 2
            } else if cur == 2 || cur == 3 {
                run.roster[idx].pieceType = 4
            } else if cur == 4 {
                run.roster[idx].pieceType = 5
            } else {
                run.roster[idx].energyBonus += 25
            }
            run.roster[idx].isDamaged = false
        case .armorGuardian:
            run.roster[idx].unitClass = .guardian
            run.roster[idx].isDamaged = false
        case .overclockNova:
            run.roster[idx].unitClass = .nova
            run.roster[idx].energyBonus += 15
        }

        if let sIdx = shopItems.firstIndex(where: { if case .patcher(let k) = $0.kind { return k == pk }; return false }) {
            shopItems[sIdx].buyCount += 1
        }
        pendingPatcher = nil
        roguelikeRun = run
        saveRoguelikeRun()
        SoundEngine.shared.play("win", enabled: sfxEnabled)
    }

    func cancelPatcher() {
        pendingPatcher = nil
    }

    func dismissPackRewards() {
        activePackRewards = nil
    }

    func repairDamagedUnit(_ unitId: UUID) {
        guard var run = roguelikeRun, run.credits >= 40 else { return }
        guard let idx = run.roster.firstIndex(where: { $0.id == unitId && $0.isDamaged }) else { return }
        run.credits -= 40
        run.roster[idx].isDamaged = false
        roguelikeRun = run
        saveRoguelikeRun()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
    }

    func leaveShop() {
        guard var run = roguelikeRun else { return }
        if let node = run.activeNode {
            if !run.completedNodeIds.contains(node.id) {
                run.completedNodeIds.append(node.id)
            }
            run.currentNodeId = node.id
            run.currentLayer = node.layer
        }
        run.activeNode = nil
        run.phase = .map
        roguelikeRun = run
        shopItems = []
        pendingPatcher = nil
        activePackRewards = nil
        space.startMenuOrbit()
        saveRoguelikeRun()
    }

    func spinRoulette(vip: Bool = false) -> RoulettePrize? {
        guard var run = roguelikeRun else { return nil }
        let cost = rouletteCost(vip: vip)
        guard run.credits >= cost else { return nil }
        run.credits -= cost
        run.rouletteSpins += 1

        let prize = generateRandomRoulettePrize(vip: vip)
        switch prize.kind {
        case .pawn(let cls):
            run.roster.append(RoguelikeUnit(pieceType: 1, unitClass: cls))
        case .doublePawn(let c1, let c2):
            run.roster.append(RoguelikeUnit(pieceType: 1, unitClass: c1))
            run.roster.append(RoguelikeUnit(pieceType: 1, unitClass: c2))
        case .officer(let pt, let cls):
            run.roster.append(RoguelikeUnit(pieceType: pt, unitClass: cls))
        case .aegisAndCredits:
            run.aegisCharges += 1
            run.credits += 45
        case .patcher:
            if let idx = run.roster.indices.filter({ run.roster[$0].pieceType != 6 }).randomElement() {
                let cls: UnitClass = [.quantum, .nova, .chrono, .golden].randomElement() ?? .quantum
                run.roster[idx].unitClass = cls
                run.roster[idx].energyBonus += 10
            } else {
                run.credits += 60
            }
        }

        roguelikeRun = run
        saveRoguelikeRun()
        return prize
    }

    func generateRandomRoulettePrize(vip: Bool = false) -> RoulettePrize {
        let r = Int.random(in: 0..<100)
        if vip {
            if r < 22 { return makePrize(for: .pawn(.chrono)) }
            if r < 42 { return makePrize(for: .pawn(.quantum)) }
            if r < 60 { return makePrize(for: .pawn(.nova)) }
            if r < 76 { return makePrize(for: .doublePawn(.golden, .berserk)) }
            if r < 89 { return makePrize(for: .officer([2, 3, 4].randomElement() ?? 2, [.golden, .berserk, .chrono].randomElement() ?? .chrono)) }
            if r < 96 { return makePrize(for: .patcher(.mutateClass)) }
            return makePrize(for: .officer(5, .quantum))
        } else {
            if r < 26 { return makePrize(for: .pawn(.recruit)) }
            if r < 45 { return makePrize(for: .pawn(.golden)) }
            if r < 61 { return makePrize(for: .pawn(.berserk)) }
            if r < 75 { return makePrize(for: .pawn(.guardian)) }
            if r < 85 { return makePrize(for: .pawn(.chrono)) }
            if r < 91 { return makePrize(for: .pawn(.quantum)) }
            if r < 95 { return makePrize(for: .pawn(.nova)) }
            if r < 98 { return makePrize(for: .doublePawn(.golden, .berserk)) }
            if r < 99 { return makePrize(for: .officer([2, 3].randomElement() ?? 2, .chrono)) }
            return makePrize(for: .aegisAndCredits)
        }
    }

    func makePrize(for kind: RoulettePrizeKind) -> RoulettePrize {
        switch kind {
        case .pawn(let cls):
            return RoulettePrize(title: "Пешка [\(cls.title)]", subtitle: cls.description, icon: "♙", color: cls.swiftUIColor, kind: kind)
        case .doublePawn(let c1, let c2):
            return RoulettePrize(title: "ДЖЕКПОТ: 2 Пешки!", subtitle: "\(c1.title) + \(c2.title)", icon: "🎰", color: .yellow, kind: kind)
        case .officer(let pt, let cls):
            return RoulettePrize(title: "\(pieceTitle(pt)) [\(cls.title)]!", subtitle: "Редкий офицер из капсулы!", icon: pieceGlyph(pt), color: .cyan, kind: kind)
        case .aegisAndCredits:
            return RoulettePrize(title: "Эгида + 45 🪙", subtitle: "Редкий артефакт Короля!", icon: "🛡️", color: .green, kind: kind)
        case .patcher(let pk):
            return RoulettePrize(title: "Авто-Патч!", subtitle: "Случайный боец улучшен (\(pk.rawValue))", icon: "🧬", color: .purple, kind: kind)
        }
    }

    private func generateCosmicEvent() {
        eventOutcomeText = nil
        let events: [CosmicEvent] = [
            CosmicEvent(
                title: "Древний Монолит",
                story: "Среди обломков астероида парит обелиск с гравировкой древних шахматных богов. Он требует жертву или плату.",
                choices: [
                    EventChoice(label: "Пожертвовать 1 пешкой", effectNote: "Случайная Реликвия + 80 🪙 (если есть пешка)", kind: .sacrificePawnForRelicAndGold),
                    EventChoice(label: "Отремонтировать броню", effectNote: "Чинит ВСЕ подбитые фигуры или даёт +40 🪙", kind: .repairAllOrGainGold),
                    EventChoice(label: "Собрать звёздную пыль", effectNote: "+50 🪙 без риска", kind: .gainCreditsSafe)
                ]
            ),
            CosmicEvent(
                title: "Брошенный Челнок",
                story: "Внутри дрейфующей капсулы слышен сигнал стазис-камеры с замороженным отрядом.",
                choices: [
                    EventChoice(label: "Вскрыть криокапсулу", effectNote: "Редкая пешка (Квантовая / Сверхновая / Хроно)", kind: .gambleRarePawn),
                    EventChoice(label: "Синхронизировать реактор", effectNote: "+1 Макс. Откат навсегда", kind: .gainUndoAndEnergy),
                    EventChoice(label: "Разобрать обшивку на лом", effectNote: "+55 🪙", kind: .gainCreditsSafe)
                ]
            )
        ]
        activeEvent = events.randomElement()
    }

    func resolveCosmicEvent(_ choice: EventChoice) {
        guard var run = roguelikeRun, eventOutcomeText == nil else { return }
        switch choice.kind {
        case .sacrificePawnForRelicAndGold:
            if let idx = run.roster.firstIndex(where: { $0.pieceType == 1 }) {
                let lost = run.roster.remove(at: idx)
                run.pawnsLost += 1
                run.credits += 80
                let missing = RoguelikeRelic.allCases.filter { !run.relics.contains($0) }
                if let r = missing.randomElement() {
                    run.relics.append(r)
                    if r == .kingAegis { run.aegisCharges += 1 }
                    eventOutcomeText = "Пешка [\(lost.unitClass.title)] принесена в дар. Получено: \(r.icon) \(r.rawValue) и +80 🪙!"
                } else {
                    run.credits += 60
                    eventOutcomeText = "Пешка принесена в дар. Получено +140 🪙!"
                }
            } else {
                run.credits += 25
                eventOutcomeText = "Нет пешек для жертвы — монолит выдал +25 🪙."
            }
        case .repairAllOrGainGold:
            let dmgCount = run.roster.filter { $0.isDamaged }.count
            if dmgCount > 0 {
                for i in run.roster.indices { run.roster[i].isDamaged = false }
                eventOutcomeText = "Отремонтировано фигур: \(dmgCount)!"
            } else {
                run.credits += 40
                eventOutcomeText = "Вся армия цела. Найдено +40 🪙."
            }
        case .gambleRarePawn:
            let rareCls: UnitClass = [.quantum, .nova, .chrono, .golden].randomElement() ?? .quantum
            run.roster.append(RoguelikeUnit(pieceType: 1, unitClass: rareCls))
            eventOutcomeText = "Из криокапсулы вышла пешка [\(rareCls.title)]!"
        case .gainCreditsSafe:
            run.credits += 55
            eventOutcomeText = "Корабельный трюм пополнен: +55 🪙."
        case .gainUndoAndEnergy:
            run.bonusUndos += 1
            eventOutcomeText = "Временной реактор синхронизирован: +1 Макс. Откат!"
        }
        roguelikeRun = run
        saveRoguelikeRun()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
    }

    func leaveCosmicEvent() {
        guard var run = roguelikeRun else { return }
        if let node = run.activeNode {
            if !run.completedNodeIds.contains(node.id) {
                run.completedNodeIds.append(node.id)
            }
            run.currentNodeId = node.id
            run.currentLayer = node.layer
        }
        run.activeNode = nil
        run.phase = .map
        roguelikeRun = run
        activeEvent = nil
        eventOutcomeText = nil
        space.startMenuOrbit()
        saveRoguelikeRun()
    }

    func buyMetaPerk(_ perk: MetaPerk) {
        guard !roguelikeMeta.unlockedPerks.contains(perk), roguelikeMeta.starShards >= perk.cost else { return }
        roguelikeMeta.starShards -= perk.cost
        roguelikeMeta.unlockedPerks.append(perk)
        saveRoguelikeMeta()
        SoundEngine.shared.play("win", enabled: sfxEnabled)
    }

    private func saveRoguelikeRun() {
        guard let run = roguelikeRun else { return }
        if let data = try? JSONEncoder().encode(run) {
            UserDefaults.standard.set(data, forKey: "Vibe_RoguelikeRun2")
        }
    }

    private func deleteRoguelikeRun() {
        UserDefaults.standard.removeObject(forKey: "Vibe_RoguelikeRun2")
    }

    private func saveRoguelikeMeta() {
        if let data = try? JSONEncoder().encode(roguelikeMeta) {
            UserDefaults.standard.set(data, forKey: "Vibe_RoguelikeMeta2")
        }
    }

    private func loadRoguelikeFromDisk() {
        if let data = UserDefaults.standard.data(forKey: "Vibe_RoguelikeMeta2"),
           let m = try? JSONDecoder().decode(RoguelikeMeta.self, from: data) {
            roguelikeMeta = m
        }
        if let data = UserDefaults.standard.data(forKey: "Vibe_RoguelikeRun2"),
           let r = try? JSONDecoder().decode(RoguelikeRun.self, from: data) {
            roguelikeRun = r
        }
    }

    // MARK: - AI Advisor & Scene Attach

    func sendUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        chat.append(ChatMessage(sender: "Ты", text: trimmed))
        let lower = trimmed.lowercased()
        if lower.contains("лучш") || lower.contains("ход") || lower.contains("совет") {
            requestAdvice()
        } else if lower.contains("оцен") || lower.contains("шанс") || lower.contains("позици") {
            requestEvaluation()
        } else {
            reply("Используй Патчеры, собирай синергии 2+ классов и выбивай редкие пешки в Рулетке.")
        }
    }

    private func reply(_ text: String) {
        chat.append(ChatMessage(sender: "Гроссмейстер AI", text: text))
        SoundEngine.shared.speak(text, enabled: voiceEnabled)
    }

    private func requestAdvice() {
        if inMenu || roguelikeRun?.phase != .inBattle {
            reply("Сначала начни бой на доске.")
            return
        }
        if isAdviceThinking { return }
        isAdviceThinking = true
        let snap = board
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ai = ChessAI()
            let mv = ai.bestMove(board: snap, maxDepth: 4, time: 1.4)
            var text = "Ходов нет."
            if let m = mv {
                var after = snap
                after.apply(m)
                text = "Советую сыграть " + describeMove(m, before: snap, after: after) + "."
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAdviceThinking = false
                self.reply(text)
            }
        }
    }

    private func requestEvaluation() {
        let cp = ChessAI.evaluateWhite(board)
        let pawns = Double(cp) / 100.0
        let num = String(format: "%+.2f", pawns)
        if abs(cp) < 40 {
            reply("Позиция примерно равная (\(num)).")
        } else if cp > 0 {
            reply("Перевес у белых: \(num).")
        } else {
            reply("Перевес у чёрных: \(num).")
        }
    }

    func attachBoardToSpace() {
        boardCtl.root.removeFromParentNode()
        boardCtl.root.position = SCNVector3Zero
        boardCtl.root.eulerAngles = SCNVector3Zero
        space.boardMount.addChildNode(boardCtl.root)
        applyControlMode()
    }
}
