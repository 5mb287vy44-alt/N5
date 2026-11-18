import SwiftUI
import SceneKit
import AVFoundation
import AudioToolbox
import CoreMotion
import UIKit

enum ControlMode: String, CaseIterable, Identifiable, Codable {
    case tap = "Нажатие"
    case drag = "Руками (Физика)"
    var id: String { rawValue }
}

enum BotDifficulty: String, CaseIterable, Identifiable, Codable {
    case easy = "Новичок"
    case medium = "Тактик"
    case hard = "Гроссмейстер"
    var id: String { rawValue }
}

enum GraphicsQuality: String, CaseIterable, Identifiable, Codable {
    case standard = "Стандарт"
    case high = "Высокое"
    case ultra = "Ультра"
    var id: String { rawValue }
}

enum UnitClass: UInt8, Codable, CaseIterable, Identifiable {
    case standard = 0
    case recruit = 1
    case golden = 2
    case berserk = 3
    case guardian = 4
    case chrono = 5
    case quantum = 6
    case nova = 7

    var id: UInt8 { rawValue }

    var title: String {
        switch self {
        case .standard: return "Стандарт"
        case .recruit: return "Рекрут"
        case .golden: return "Золотой"
        case .berserk: return "Берсерк"
        case .guardian: return "Страж"
        case .chrono: return "Хроно"
        case .quantum: return "Квантовый"
        case .nova: return "Сверхновая"
        }
    }

    var description: String {
        switch self {
        case .standard: return "Обычная фигура без модификаторов."
        case .recruit: return "Базовый боец. +25 🪙 при возвышении."
        case .golden: return "Пешка: +5 🪙/шаг, +80 🪙 возвыш. Офицер: +20 🪙 за взятие."
        case .berserk: return "Пешка прыгает на 2 клетки всегда. Офицер: +15 🪙 и +25⚡ за взятие."
        case .guardian: return "1 раз за бой переживает гибель/астероид (возврат в строй)."
        case .chrono: return "При гибели/взятии офицером даёт +1 Откат. Возвышение: +2 Отката."
        case .quantum: return "Пешка ходит и по диагонали вперёд. Офицер обновляет Прыжок Короля."
        case .nova: return "При возвышении или гибели сносит врага Чёрной Дырой."
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .standard: return .white
        case .recruit: return Color(red: 0.72, green: 0.82, blue: 0.94)
        case .golden: return Color(red: 1.0, green: 0.82, blue: 0.25)
        case .berserk: return Color(red: 1.0, green: 0.28, blue: 0.28)
        case .guardian: return Color(red: 0.25, green: 0.90, blue: 0.45)
        case .chrono: return Color.cyan
        case .quantum: return Color(red: 0.78, green: 0.40, blue: 1.0)
        case .nova: return Color.orange
        }
    }

    var uiColor: UIColor? {
        switch self {
        case .standard, .recruit: return nil
        case .golden: return UIColor(red: 1.0, green: 0.82, blue: 0.20, alpha: 1)
        case .berserk: return UIColor(red: 1.0, green: 0.22, blue: 0.22, alpha: 1)
        case .guardian: return UIColor(red: 0.22, green: 0.92, blue: 0.44, alpha: 1)
        case .chrono: return UIColor(red: 0.10, green: 0.88, blue: 1.0, alpha: 1)
        case .quantum: return UIColor(red: 0.76, green: 0.35, blue: 1.0, alpha: 1)
        case .nova: return UIColor(red: 1.0, green: 0.56, blue: 0.12, alpha: 1)
        }
    }
}

enum TileModifier: UInt8, Codable, Equatable {
    case none = 0
    case blocked = 1
    case goldVein = 2
    case ascensionPad = 3
    case voidRift = 4

    var title: String {
        switch self {
        case .none: return ""
        case .blocked: return "Разрушена астероидом"
        case .goldVein: return "Золотая жила (+35 🪙)"
        case .ascensionPad: return "Трамплин вознесения"
        case .voidRift: return "Разлом Бездны"
        }
    }
}

enum AsteroidType: String, Codable, CaseIterable {
    case stone = "Каменный астероид"
    case fire = "Огненный болид"
    case crystal = "Кристальный метеорит"
    case void = "Осколок Пустоты"

    var icon: String {
        switch self {
        case .stone: return "🪨"
        case .fire: return "🔥"
        case .crystal: return "💎"
        case .void: return "🕳️"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .stone: return UIColor(red: 0.65, green: 0.60, blue: 0.56, alpha: 1)
        case .fire: return UIColor(red: 1.0, green: 0.42, blue: 0.12, alpha: 1)
        case .crystal: return UIColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1)
        case .void: return UIColor(red: 0.72, green: 0.25, blue: 1.0, alpha: 1)
        }
    }
}

enum GalaxySystem: Int, Codable, CaseIterable, Identifiable {
    case solar = 0
    case sirius = 1
    case gargantua = 2
    case omega = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .solar: return "Галактика 1: Солнечная система"
        case .sirius: return "Галактика 2: Бинарный Сириус-X"
        case .gargantua: return "Галактика 3: Горизонт Гаргантюа"
        case .omega: return "Галактика 4: Туманность Омега"
        }
    }

    var shortName: String {
        switch self {
        case .solar: return "Солнечная"
        case .sirius: return "Сириус-X"
        case .gargantua: return "Гаргантюа"
        case .omega: return "Омега"
        }
    }

    var subtitle: String {
        switch self {
        case .solar: return "Классическая колыбель от Меркурия до Плутона"
        case .sirius: return "Голубой гипергигант • Враги быстрее и опаснее"
        case .gargantua: return "Сверхмассивная Чёрная Дыра с искажением пространства"
        case .omega: return "Финальный разлом материи • Максимальная награда"
        }
    }

    var next: GalaxySystem? {
        GalaxySystem(rawValue: rawValue + 1)
    }
}

struct Move: Equatable, Codable {
    var from: Int
    var to: Int
    var promo: Int = 0
}

struct PositionKey: Hashable {
    var sq: [Int8]
    var whiteToMove: Bool
    var castle: UInt8
    var ep: Int
}

struct ChessBoard: Equatable {
    var sq: [Int8]
    var whiteToMove: Bool
    var castle: UInt8
    var ep: Int
    var halfmove: Int
    var fullmove: Int
    var classes: [UnitClass]
    var tiles: [TileModifier]
    var frozenTurns: [Int]
    var kingLeapReady: Bool
    var gravityNoPawnDouble: Bool
    var isRoguelike: Bool

    init(
        sq: [Int8],
        whiteToMove: Bool,
        castle: UInt8,
        ep: Int,
        halfmove: Int,
        fullmove: Int,
        classes: [UnitClass] = [UnitClass](repeating: .standard, count: 64),
        tiles: [TileModifier] = [TileModifier](repeating: .none, count: 64),
        frozenTurns: [Int] = [Int](repeating: 0, count: 64),
        kingLeapReady: Bool = false,
        gravityNoPawnDouble: Bool = false,
        isRoguelike: Bool = true
    ) {
        self.sq = sq
        self.whiteToMove = whiteToMove
        self.castle = castle
        self.ep = ep
        self.halfmove = halfmove
        self.fullmove = fullmove
        self.classes = classes
        self.tiles = tiles
        self.frozenTurns = frozenTurns
        self.kingLeapReady = kingLeapReady
        self.gravityNoPawnDouble = gravityNoPawnDouble
        self.isRoguelike = isRoguelike
    }

    static func emptyRoguelike() -> ChessBoard {
        ChessBoard(
            sq: [Int8](repeating: 0, count: 64),
            whiteToMove: true,
            castle: 0b1111,
            ep: -1,
            halfmove: 0,
            fullmove: 1
        )
    }

    var key: PositionKey {
        PositionKey(sq: sq, whiteToMove: whiteToMove, castle: castle, ep: ep)
    }

    private static let knightOffsets: [(Int, Int)] = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    private static let kingOffsets: [(Int, Int)] = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    private static let diagDirs: [(Int, Int)] = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    private static let lineDirs: [(Int, Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    private static let allDirs: [(Int, Int)] = [(1, 1), (1, -1), (-1, 1), (-1, -1), (1, 0), (-1, 0), (0, 1), (0, -1)]

    private static func castleMask(_ s: Int) -> UInt8 {
        switch s {
        case 0: return 0b1101
        case 7: return 0b1110
        case 4: return 0b1100
        case 56: return 0b0111
        case 63: return 0b1011
        case 60: return 0b0011
        default: return 0b1111
        }
    }

    private func isBlocked(_ s: Int) -> Bool {
        tiles.count == 64 && tiles[s] == .blocked
    }

    private func isFrozen(_ s: Int) -> Bool {
        frozenTurns.count == 64 && frozenTurns[s] > 0
    }

    func kingSquare(white: Bool) -> Int {
        let k: Int8 = white ? 6 : -6
        for s in 0..<64 where sq[s] == k { return s }
        return -1
    }

    func inCheck(white: Bool) -> Bool {
        let k = kingSquare(white: white)
        if k < 0 { return false }
        return isAttacked(k, byWhite: !white)
    }

    func isAttacked(_ s: Int, byWhite: Bool) -> Bool {
        let c = s & 7
        let r = s >> 3
        let pawn: Int8 = byWhite ? 1 : -1
        let pr = byWhite ? r - 1 : r + 1
        if pr >= 0 && pr < 8 {
            if c > 0 && sq[pr * 8 + c - 1] == pawn { return true }
            if c < 7 && sq[pr * 8 + c + 1] == pawn { return true }
        }
        let knight: Int8 = byWhite ? 2 : -2
        for (dc, dr) in ChessBoard.knightOffsets {
            let nc = c + dc
            let nr = r + dr
            if nc >= 0 && nc < 8 && nr >= 0 && nr < 8 && sq[nr * 8 + nc] == knight { return true }
        }
        let king: Int8 = byWhite ? 6 : -6
        for (dc, dr) in ChessBoard.kingOffsets {
            let nc = c + dc
            let nr = r + dr
            if nc >= 0 && nc < 8 && nr >= 0 && nr < 8 && sq[nr * 8 + nc] == king { return true }
        }
        let bishop: Int8 = byWhite ? 3 : -3
        let rook: Int8 = byWhite ? 4 : -4
        let queen: Int8 = byWhite ? 5 : -5
        for (dc, dr) in ChessBoard.diagDirs {
            var nc = c + dc
            var nr = r + dr
            while nc >= 0 && nc < 8 && nr >= 0 && nr < 8 {
                let idx = nr * 8 + nc
                if isBlocked(idx) { break }
                let p = sq[idx]
                if p != 0 {
                    if p == bishop || p == queen { return true }
                    break
                }
                nc += dc
                nr += dr
            }
        }
        for (dc, dr) in ChessBoard.lineDirs {
            var nc = c + dc
            var nr = r + dr
            while nc >= 0 && nc < 8 && nr >= 0 && nr < 8 {
                let idx = nr * 8 + nc
                if isBlocked(idx) { break }
                let p = sq[idx]
                if p != 0 {
                    if p == rook || p == queen { return true }
                    break
                }
                nc += dc
                nr += dr
            }
        }
        return false
    }

    func isCapture(_ m: Move) -> Bool {
        if sq[m.to] != 0 { return true }
        return abs(Int(sq[m.from])) == 1 && (m.from & 7) != (m.to & 7) && m.to == ep
    }

    func pseudoLegalMoves() -> [Move] {
        var moves: [Move] = []
        moves.reserveCapacity(48)
        let white = whiteToMove
        let hasClasses = isRoguelike && classes.count == 64
        for s in 0..<64 {
            let p = Int(sq[s])
            if p == 0 || (p > 0) != white { continue }
            if isFrozen(s) { continue }
            let type = abs(p)
            let c = s & 7
            let r = s >> 3
            let uClass: UnitClass = (hasClasses && white) ? classes[s] : .standard
            switch type {
            case 1:
                let dir = white ? 1 : -1
                let startRow = white ? 1 : 6
                let promoRow = white ? 7 : 0
                let nr = r + dir
                if nr >= 0 && nr < 8 {
                    let t = nr * 8 + c
                    if sq[t] == 0 && !isBlocked(t) {
                        if nr == promoRow {
                            for pr in [5, 4, 3, 2] { moves.append(Move(from: s, to: t, promo: pr)) }
                        } else {
                            moves.append(Move(from: s, to: t))
                            let allowStdDouble = (r == startRow) && (!gravityNoPawnDouble || !white)
                            let canDouble = allowStdDouble || (white && uClass == .berserk && r + 2 * dir < 8)
                            if canDouble {
                                let nr2 = r + 2 * dir
                                if nr2 >= 0 && nr2 < 8 {
                                    let t2 = nr2 * 8 + c
                                    if sq[t2] == 0 && !isBlocked(t2) {
                                        if nr2 == promoRow {
                                            for pr in [5, 4, 3, 2] { moves.append(Move(from: s, to: t2, promo: pr)) }
                                        } else {
                                            moves.append(Move(from: s, to: t2))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    for dc in [-1, 1] {
                        let nc = c + dc
                        if nc < 0 || nc > 7 { continue }
                        let t = nr * 8 + nc
                        if isBlocked(t) { continue }
                        let target = Int(sq[t])
                        if target != 0 && (target > 0) != white {
                            if nr == promoRow {
                                for pr in [5, 4, 3, 2] { moves.append(Move(from: s, to: t, promo: pr)) }
                            } else {
                                moves.append(Move(from: s, to: t))
                            }
                        } else if target == 0 && t == ep {
                            moves.append(Move(from: s, to: t))
                        } else if target == 0 && white && uClass == .quantum {
                            if nr == promoRow {
                                for pr in [5, 4, 3, 2] { moves.append(Move(from: s, to: t, promo: pr)) }
                            } else {
                                moves.append(Move(from: s, to: t))
                            }
                        }
                    }
                }
            case 2, 6:
                let offsets = (type == 2) ? ChessBoard.knightOffsets : ChessBoard.kingOffsets
                for (dc, dr) in offsets {
                    let nc = c + dc
                    let nr = r + dr
                    if nc < 0 || nc > 7 || nr < 0 || nr > 7 { continue }
                    let t = nr * 8 + nc
                    if isBlocked(t) { continue }
                    let target = Int(sq[t])
                    if target == 0 || (target > 0) != white { moves.append(Move(from: s, to: t)) }
                }
                if type == 6 {
                    addCastling(&moves, from: s, white: white)
                    if isRoguelike && white && kingLeapReady {
                        for (dc, dr) in ChessBoard.knightOffsets {
                            let nc = c + dc
                            let nr = r + dr
                            if nc < 0 || nc > 7 || nr < 0 || nr > 7 { continue }
                            let t = nr * 8 + nc
                            if isBlocked(t) { continue }
                            let target = Int(sq[t])
                            if target == 0 || (target < 0 && target != -6) {
                                moves.append(Move(from: s, to: t))
                            }
                        }
                    }
                }
            default:
                let dirs = (type == 3) ? ChessBoard.diagDirs : ((type == 4) ? ChessBoard.lineDirs : ChessBoard.allDirs)
                for (dc, dr) in dirs {
                    var nc = c + dc
                    var nr = r + dr
                    while nc >= 0 && nc < 8 && nr >= 0 && nr < 8 {
                        let t = nr * 8 + nc
                        if isBlocked(t) { break }
                        let target = Int(sq[t])
                        if target == 0 {
                            moves.append(Move(from: s, to: t))
                        } else {
                            if (target > 0) != white { moves.append(Move(from: s, to: t)) }
                            break
                        }
                        nc += dc
                        nr += dr
                    }
                }
            }
        }
        return moves
    }

    private func addCastling(_ moves: inout [Move], from s: Int, white: Bool) {
        if white && s == 4 {
            if (castle & 1) != 0 && sq[5] == 0 && sq[6] == 0 && sq[7] == 4 && !isBlocked(5) && !isBlocked(6) && !isFrozen(7) {
                let safe = !isAttacked(4, byWhite: false) && !isAttacked(5, byWhite: false) && !isAttacked(6, byWhite: false)
                if safe { moves.append(Move(from: 4, to: 6)) }
            }
            if (castle & 2) != 0 && sq[3] == 0 && sq[2] == 0 && sq[1] == 0 && sq[0] == 4 && !isBlocked(3) && !isBlocked(2) && !isBlocked(1) && !isFrozen(0) {
                let safe = !isAttacked(4, byWhite: false) && !isAttacked(3, byWhite: false) && !isAttacked(2, byWhite: false)
                if safe { moves.append(Move(from: 4, to: 2)) }
            }
        } else if !white && s == 60 {
            if (castle & 4) != 0 && sq[61] == 0 && sq[62] == 0 && sq[63] == -4 && !isBlocked(61) && !isBlocked(62) && !isFrozen(63) {
                let safe = !isAttacked(60, byWhite: true) && !isAttacked(61, byWhite: true) && !isAttacked(62, byWhite: true)
                if safe { moves.append(Move(from: 60, to: 62)) }
            }
            if (castle & 8) != 0 && sq[59] == 0 && sq[58] == 0 && sq[57] == 0 && sq[56] == -4 && !isBlocked(59) && !isBlocked(58) && !isBlocked(57) && !isFrozen(56) {
                let safe = !isAttacked(60, byWhite: true) && !isAttacked(59, byWhite: true) && !isAttacked(58, byWhite: true)
                if safe { moves.append(Move(from: 60, to: 58)) }
            }
        }
    }

    func legalMoves() -> [Move] {
        let pseudo = pseudoLegalMoves()
        var result: [Move] = []
        result.reserveCapacity(pseudo.count)
        let white = whiteToMove
        for m in pseudo {
            var nb = self
            nb.apply(m)
            if !nb.inCheck(white: white) { result.append(m) }
        }
        return result
    }

    mutating func apply(_ m: Move) {
        let piece = sq[m.from]
        let type = abs(Int(piece))
        let white = piece > 0
        let captured = sq[m.to]
        let fromCol = m.from & 7
        let toCol = m.to & 7
        if type == 1 || captured != 0 { halfmove = 0 } else { halfmove += 1 }
        let didEnPassant = type == 1 && captured == 0 && fromCol != toCol && m.to == ep
        if didEnPassant {
            sq[(m.from >> 3) * 8 + toCol] = 0
        }
        sq[m.to] = piece
        sq[m.from] = 0
        if type == 1 && m.promo != 0 {
            sq[m.to] = Int8(white ? m.promo : -m.promo)
        }
        if isRoguelike && classes.count == 64 {
            if type == 6 && white && kingLeapReady {
                let dc = abs(toCol - fromCol)
                let dr = abs((m.to >> 3) - (m.from >> 3))
                if (dc == 1 && dr == 2) || (dc == 2 && dr == 1) {
                    kingLeapReady = false
                }
            }
            classes[m.to] = classes[m.from]
            classes[m.from] = .standard
            if didEnPassant {
                classes[(m.from >> 3) * 8 + toCol] = .standard
            }
        }
        if frozenTurns.count == 64 {
            frozenTurns[m.to] = frozenTurns[m.from]
            frozenTurns[m.from] = 0
            for i in 0..<64 where frozenTurns[i] > 0 {
                if (white && sq[i] > 0) || (!white && sq[i] < 0) {
                    frozenTurns[i] -= 1
                }
            }
        }
        var newEp = -1
        if type == 1 && abs(m.to - m.from) == 16 { newEp = (m.from + m.to) / 2 }
        if type == 6 && abs(toCol - fromCol) == 2 {
            let base = (m.from >> 3) * 8
            if toCol == 6 {
                sq[base + 5] = sq[base + 7]
                sq[base + 7] = 0
                if isRoguelike && classes.count == 64 {
                    classes[base + 5] = classes[base + 7]
                    classes[base + 7] = .standard
                }
            } else {
                sq[base + 3] = sq[base]
                sq[base] = 0
                if isRoguelike && classes.count == 64 {
                    classes[base + 3] = classes[base]
                    classes[base] = .standard
                }
            }
        }
        castle &= ChessBoard.castleMask(m.from) & ChessBoard.castleMask(m.to)
        ep = newEp
        if !white { fullmove += 1 }
        whiteToMove.toggle()
    }
}

extension ChessBoard: Codable {
    enum CodingKeys: String, CodingKey {
        case sq, whiteToMove, castle, ep, halfmove, fullmove, classes, tiles, frozenTurns, kingLeapReady, gravityNoPawnDouble, isRoguelike
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sq = try c.decode([Int8].self, forKey: .sq)
        whiteToMove = try c.decode(Bool.self, forKey: .whiteToMove)
        castle = try c.decode(UInt8.self, forKey: .castle)
        ep = try c.decode(Int.self, forKey: .ep)
        halfmove = try c.decode(Int.self, forKey: .halfmove)
        fullmove = try c.decode(Int.self, forKey: .fullmove)
        classes = try c.decodeIfPresent([UnitClass].self, forKey: .classes) ?? [UnitClass](repeating: .standard, count: 64)
        tiles = try c.decodeIfPresent([TileModifier].self, forKey: .tiles) ?? [TileModifier](repeating: .none, count: 64)
        frozenTurns = try c.decodeIfPresent([Int].self, forKey: .frozenTurns) ?? [Int](repeating: 0, count: 64)
        kingLeapReady = try c.decodeIfPresent(Bool.self, forKey: .kingLeapReady) ?? false
        gravityNoPawnDouble = try c.decodeIfPresent(Bool.self, forKey: .gravityNoPawnDouble) ?? false
        isRoguelike = try c.decodeIfPresent(Bool.self, forKey: .isRoguelike) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sq, forKey: .sq)
        try c.encode(whiteToMove, forKey: .whiteToMove)
        try c.encode(castle, forKey: .castle)
        try c.encode(ep, forKey: .ep)
        try c.encode(halfmove, forKey: .halfmove)
        try c.encode(fullmove, forKey: .fullmove)
        try c.encode(classes, forKey: .classes)
        try c.encode(tiles, forKey: .tiles)
        try c.encode(frozenTurns, forKey: .frozenTurns)
        try c.encode(kingLeapReady, forKey: .kingLeapReady)
        try c.encode(gravityNoPawnDouble, forKey: .gravityNoPawnDouble)
        try c.encode(isRoguelike, forKey: .isRoguelike)
    }
}

func squareName(_ s: Int) -> String {
    let files = ["a", "b", "c", "d", "e", "f", "g", "h"]
    return files[s & 7] + String((s >> 3) + 1)
}

func describeMove(_ m: Move, before: ChessBoard, after: ChessBoard) -> String {
    let letters = ["", "", "К", "С", "Л", "Ф", "Кр"]
    let p = abs(Int(before.sq[m.from]))
    var s: String
    if p == 6 && abs((m.to & 7) - (m.from & 7)) == 2 {
        s = ((m.to & 7) == 6) ? "O-O" : "O-O-O"
    } else {
        s = (p >= 1 && p <= 6) ? letters[p] : ""
        s += squareName(m.from)
        s += before.isCapture(m) ? "×" : "–"
        s += squareName(m.to)
        if m.promo >= 2 && m.promo <= 5 { s += "=" + letters[m.promo] }
    }
    if after.inCheck(white: after.whiteToMove) {
        s += after.legalMoves().isEmpty ? "#" : "+"
    }
    return s
}

func pieceTitle(_ type: Int) -> String {
    switch type {
    case 1: return "Пешка"
    case 2: return "Конь"
    case 3: return "Слон"
    case 4: return "Ладья"
    case 5: return "Ферзь"
    case 6: return "Король"
    default: return "Фигура"
    }
}

func pieceGlyph(_ type: Int) -> String {
    switch type {
    case 1: return "♙"
    case 2: return "♘"
    case 3: return "♗"
    case 4: return "♖"
    case 5: return "♕"
    case 6: return "♔"
    default: return "♟️"
    }
}

final class ChessAI {
    private var deadline = Date()
    private var aborted = false
    private var nodes = 0
    private static let mate = 100000
    private static let inf = 1000000
    private static let values: [Int] = [0, 100, 320, 330, 500, 900, 0]

    private static let pawnPST: [Int] = [
         0,  0,  0,  0,  0,  0,  0,  0,
        50, 50, 50, 50, 50, 50, 50, 50,
        10, 10, 20, 30, 30, 20, 10, 10,
         5,  5, 10, 25, 25, 10,  5,  5,
         0,  0,  0, 20, 20,  0,  0,  0,
         5, -5,-10,  0,  0,-10, -5,  5,
         5, 10, 10,-20,-20, 10, 10,  5,
         0,  0,  0,  0,  0,  0,  0,  0]
    private static let knightPST: [Int] = [
        -50,-40,-30,-30,-30,-30,-40,-50,
        -40,-20,  0,  0,  0,  0,-20,-40,
        -30,  0, 10, 15, 15, 10,  0,-30,
        -30,  5, 15, 20, 20, 15,  5,-30,
        -30,  0, 15, 20, 20, 15,  0,-30,
        -30,  5, 10, 15, 15, 10,  5,-30,
        -40,-20,  0,  5,  5,  0,-20,-40,
        -50,-40,-30,-30,-30,-30,-40,-50]
    private static let bishopPST: [Int] = [
        -20,-10,-10,-10,-10,-10,-10,-20,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -10,  0,  5, 10, 10,  5,  0,-10,
        -10,  5,  5, 10, 10,  5,  5,-10,
        -10,  0, 10, 10, 10, 10,  0,-10,
        -10, 10, 10, 10, 10, 10, 10,-10,
        -10,  5,  0,  0,  0,  0,  5,-10,
        -20,-10,-10,-10,-10,-10,-10,-20]
    private static let rookPST: [Int] = [
          0,  0,  0,  0,  0,  0,  0,  0,
          5, 10, 10, 10, 10, 10, 10,  5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
          0,  0,  0,  5,  5,  0,  0,  0]
    private static let queenPST: [Int] = [
        -20,-10,-10, -5, -5,-10,-10,-20,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -10,  0,  5,  5,  5,  5,  0,-10,
         -5,  0,  5,  5,  5,  5,  0, -5,
          0,  0,  5,  5,  5,  5,  0, -5,
        -10,  5,  5,  5,  5,  5,  0,-10,
        -10,  0,  5,  0,  0,  0,  0,-10,
        -20,-10,-10, -5, -5,-10,-10,-20]
    private static let kingMidPST: [Int] = [
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -20,-30,-30,-40,-40,-30,-30,-20,
        -10,-20,-20,-20,-20,-20,-20,-10,
         20, 20,  0,  0,  0,  0, 20, 20,
         20, 30, 10,  0,  0, 10, 30, 20]
    private static let kingEndPST: [Int] = [
        -50,-40,-30,-20,-20,-30,-40,-50,
        -30,-20,-10,  0,  0,-10,-20,-30,
        -30,-10, 20, 30, 30, 20,-10,-30,
        -30,-10, 30, 40, 40, 30,-10,-30,
        -30,-10, 30, 40, 40, 30,-10,-30,
        -30,-10, 20, 30, 30, 20,-10,-30,
        -30,-30,  0,  0,  0,  0,-30,-30,
        -50,-30,-30,-30,-30,-30,-30,-50]

    static func evaluateWhite(_ b: ChessBoard) -> Int {
        var npm = 0
        for s in 0..<64 {
            let t = abs(Int(b.sq[s]))
            if t >= 2 && t <= 5 { npm += values[t] }
        }
        let endgame = npm <= 2600
        var score = 0
        for s in 0..<64 {
            let p = Int(b.sq[s])
            if p == 0 { continue }
            let t = abs(p)
            let white = p > 0
            let r = s >> 3
            let c = s & 7
            let idx = white ? (7 - r) * 8 + c : r * 8 + c
            var v = values[t]
            switch t {
            case 1: v += pawnPST[idx]
            case 2: v += knightPST[idx]
            case 3: v += bishopPST[idx]
            case 4: v += rookPST[idx]
            case 5: v += queenPST[idx]
            default: v += endgame ? kingEndPST[idx] : kingMidPST[idx]
            }
            score += white ? v : -v
        }
        return score
    }

    private func evaluate(_ b: ChessBoard) -> Int {
        let w = ChessAI.evaluateWhite(b)
        return b.whiteToMove ? w : -w
    }

    private func orderScore(_ m: Move, _ b: ChessBoard) -> Int {
        var s = 0
        let victim = abs(Int(b.sq[m.to]))
        let attacker = abs(Int(b.sq[m.from]))
        if victim != 0 {
            s += 10 * ChessAI.values[victim] - ChessAI.values[attacker] + 1000
        } else if attacker == 1 && (m.from & 7) != (m.to & 7) && m.to == b.ep {
            s += 1000 + 900
        }
        if m.promo != 0 { s += ChessAI.values[m.promo] }
        return s
    }

    private func ordered(_ moves: [Move], _ b: ChessBoard) -> [Move] {
        var scored: [(Int, Move)] = []
        scored.reserveCapacity(moves.count)
        for m in moves { scored.append((orderScore(m, b), m)) }
        scored.sort { $0.0 > $1.0 }
        return scored.map { $0.1 }
    }

    private func checkTime() {
        nodes += 1
        if nodes & 1023 == 0 && Date() > deadline { aborted = true }
    }

    private func negamax(_ b: ChessBoard, depth: Int, alpha: Int, beta: Int, ply: Int) -> Int {
        checkTime()
        if aborted { return 0 }
        if b.halfmove >= 100 { return 0 }
        if depth <= 0 { return quiesce(b, alpha: alpha, beta: beta, qdepth: 0) }
        let moves = b.legalMoves()
        if moves.isEmpty {
            return b.inCheck(white: b.whiteToMove) ? -(ChessAI.mate - ply) : 0
        }
        var a = alpha
        for m in ordered(moves, b) {
            var nb = b
            nb.apply(m)
            let score = -negamax(nb, depth: depth - 1, alpha: -beta, beta: -a, ply: ply + 1)
            if aborted { return 0 }
            if score >= beta { return beta }
            if score > a { a = score }
        }
        return a
    }

    private func quiesce(_ b: ChessBoard, alpha: Int, beta: Int, qdepth: Int) -> Int {
        checkTime()
        if aborted { return 0 }
        let stand = evaluate(b)
        if qdepth >= 6 { return stand }
        if stand >= beta { return beta }
        var a = max(alpha, stand)
        var tactical: [Move] = []
        for m in b.pseudoLegalMoves() where b.isCapture(m) || m.promo != 0 { tactical.append(m) }
        for m in ordered(tactical, b) {
            var nb = b
            nb.apply(m)
            if nb.inCheck(white: !nb.whiteToMove) { continue }
            let score = -quiesce(nb, alpha: -beta, beta: -a, qdepth: qdepth + 1)
            if aborted { return 0 }
            if score >= beta { return beta }
            if score > a { a = score }
        }
        return a
    }

    func bestMove(board: ChessBoard, maxDepth: Int, time: Double) -> Move? {
        let legal = board.legalMoves()
        if legal.isEmpty { return nil }
        if legal.count == 1 { return legal[0] }
        deadline = Date().addingTimeInterval(time)
        aborted = false
        nodes = 0
        var best = legal[0]
        var list = ordered(legal, board)
        var depth = 1
        while depth <= maxDepth {
            var bestThis: Move? = nil
            var bestScore = -ChessAI.inf
            var alpha = -ChessAI.inf
            for m in list {
                var nb = board
                nb.apply(m)
                let score = -negamax(nb, depth: depth - 1, alpha: -ChessAI.inf, beta: -alpha, ply: 1)
                if aborted { break }
                if score > bestScore {
                    bestScore = score
                    bestThis = m
                }
                if score > alpha { alpha = score }
            }
            if aborted { break }
            if let b = bestThis {
                best = b
                if let i = list.firstIndex(of: b) {
                    list.remove(at: i)
                    list.insert(b, at: 0)
                }
            }
            if bestScore > ChessAI.mate - 200 { break }
            depth += 1
        }
        return best
    }

    func chooseMove(board: ChessBoard, difficulty: BotDifficulty) -> Move? {
        let legal = board.legalMoves()
        if legal.isEmpty { return nil }
        switch difficulty {
        case .easy:
            if Int.random(in: 0..<100) < 30 { return legal.randomElement() }
            return bestMove(board: board, maxDepth: 2, time: 0.6)
        case .medium:
            return bestMove(board: board, maxDepth: 3, time: 1.2)
        case .hard:
            return bestMove(board: board, maxDepth: 6, time: 2.2)
        }
    }
}

final class SoundEngine: NSObject {
    static let shared = SoundEngine()
    private var players: [String: AVAudioPlayer] = [:]
    private var bgPlayer: AVAudioPlayer?
    private let speechSynth = AVSpeechSynthesizer()

    override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for n in ["move", "capture", "blackhole", "select", "click", "check", "win"] { loadSound(n) }
        players["blackhole"]?.volume = 0.9
        players["select"]?.volume = 0.75
        players["click"]?.volume = 0.75
        if let url = Bundle.main.url(forResource: "ambient", withExtension: "wav") {
            bgPlayer = try? AVAudioPlayer(contentsOf: url)
            bgPlayer?.numberOfLoops = -1
            bgPlayer?.volume = 0.30
            bgPlayer?.prepareToPlay()
        }
    }

    private func loadSound(_ name: String) {
        if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
            players[name] = try? AVAudioPlayer(contentsOf: url)
            players[name]?.prepareToPlay()
        }
    }

    func play(_ name: String, enabled: Bool = true) {
        guard enabled else { return }
        DispatchQueue.main.async {
            if let p = self.players[name] {
                p.currentTime = 0
                p.play()
            } else {
                AudioServicesPlaySystemSound(1104)
            }
        }
    }

    func toggleMusic(_ on: Bool) {
        DispatchQueue.main.async {
            if on { self.bgPlayer?.play() } else { self.bgPlayer?.pause() }
        }
    }

    func speak(_ text: String, enabled: Bool = true) {
        guard enabled else { return }
        DispatchQueue.main.async {
            let u = AVSpeechUtterance(string: text)
            u.voice = AVSpeechSynthesisVoice(language: "ru-RU")
            u.rate = 0.48
            u.pitchMultiplier = 0.9
            self.speechSynth.speak(u)
        }
    }
}

enum CommanderClass: String, Codable, CaseIterable, Identifiable {
    case vanguard = "Авангард"
    case bastion = "Бастион"
    case chronoWalker = "Хроно-Маг"
    case soloTitan = "Соло-Титан"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .vanguard: return "Мобильность и трофеи"
        case .bastion: return "Броня, ладьи и Эгида"
        case .chronoWalker: return "Контроль времени и рулетка"
        case .soloTitan: return "Ферзь + 1 пешка (Хардкор)"
        }
    }

    var details: String {
        switch self {
        case .vanguard: return "Король, Конь, Слон, 3 пешки (2 Рекрута, 1 Берсерк). +25% 🪙."
        case .bastion: return "Король, Ладья, 3 пешки (2 Стража, 1 Рекрут). Реликвия: Эгида Короля."
        case .chronoWalker: return "Король, Слон, 2 Хроно-пешки, +2 Отката и 85 🪙 на Рулетку."
        case .soloTitan: return "Король, Ферзь и всего 1 пешка (Сверхновая). Жёсткий дефицит!"
        }
    }

    var icon: String {
        switch self {
        case .vanguard: return "bolt.shield.fill"
        case .bastion: return "shield.lefthalf.filled"
        case .chronoWalker: return "hourglass.circle.fill"
        case .soloTitan: return "crown.fill"
        }
    }
}

enum RoguelikeRelic: String, Codable, CaseIterable, Identifiable {
    case kingAegis = "Эгида Короля"
    case chronoCrown = "Хроно-Корона"
    case royalLeap = "Прыжок Короля"
    case orbitalStrike = "Орбитальный Удар"
    case royalTreasury = "Казна Империи"
    case fieldRepair = "Полевой Ремонт"
    case vanguardPush = "Передовой Рубеж"
    case warlordFury = "Ярость Полководца"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .kingAegis: return "🛡️"
        case .chronoCrown: return "⏳"
        case .royalLeap: return "🐴"
        case .orbitalStrike: return "🕳️"
        case .royalTreasury: return "💰"
        case .fieldRepair: return "🔧"
        case .vanguardPush: return "🚀"
        case .warlordFury: return "⚔️"
        }
    }

    var description: String {
        switch self {
        case .kingAegis: return "1 раз за бой спасает от мата: отматывает время назад до твоего хода."
        case .chronoCrown: return "+2 Отката хода в каждом бою."
        case .royalLeap: return "1 раз за бой Король может прыгнуть как Конь."
        case .orbitalStrike: return "В начале каждого боя Чёрная Дыра сжигает 1 пешку врага."
        case .royalTreasury: return "+35% кредитов за все бои и +25 🪙 при входе в сектор."
        case .fieldRepair: return "После каждого боя бесплатно чинит 1 подбитую элитную фигуру."
        case .vanguardPush: return "Все твои пешки стартуют на 3-й линии ближе к врагу."
        case .warlordFury: return "За взятие вражеского офицера +15 🪙 и +1 Откат (до 2/бой)."
        }
    }
}

enum AscensionBuff: String, Codable, CaseIterable, Identifiable {
    case credits80 = "Золотой Триумф"
    case chronoUndo = "Ткань Времени"
    case aegisShield = "Щит Вознесения"
    case blackHoleStrike = "Удар Сингулярности"
    case royalLeap = "Прыжок Монарха"
    case treasuryBoost = "Имперский Налог"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .credits80: return "🪙"
        case .chronoUndo: return "↩️"
        case .aegisShield: return "🛡️"
        case .blackHoleStrike: return "🕳️"
        case .royalLeap: return "🐴"
        case .treasuryBoost: return "💎"
        }
    }

    var description: String {
        switch self {
        case .credits80: return "+80 Кредитов прямо сейчас для Рулетки и Магазина."
        case .chronoUndo: return "+2 Отката в этом бою и +1 Макс. Откат навсегда."
        case .aegisShield: return "+1 Эгида Короля (защита от мата) на этот и будущие бои."
        case .blackHoleStrike: return "Чёрная Дыра немедленно поглощает вражескую фигуру на доске!"
        case .royalLeap: return "Обновляет Прыжок Короля конём и добавляет реликвию."
        case .treasuryBoost: return "+40 🪙 сейчас и реликвия «Казна Империи» (+35% наград)."
        }
    }
}

enum TacticalSkill: String, CaseIterable, Identifiable {
    case stasis = "Стазис"
    case airdrop = "Десант"
    case swap = "Телепорт"
    case orbitalBlast = "Залп"

    var id: String { rawValue }

    var cost: Int {
        switch self {
        case .stasis: return 35
        case .airdrop: return 45
        case .swap: return 55
        case .orbitalBlast: return 75
        }
    }

    var icon: String {
        switch self {
        case .stasis: return "❄️"
        case .airdrop: return "♟️"
        case .swap: return "🔄"
        case .orbitalBlast: return "🕳️"
        }
    }

    var hint: String {
        switch self {
        case .stasis: return "Нажми на вражескую фигуру (не Короля), чтобы заморозить на 2 хода."
        case .airdrop: return "Нажми на пустую клетку 2–3 линии, чтобы высадить пешку."
        case .swap: return "Выбери по очереди 2 свои фигуры на доске, чтобы поменять их местами."
        case .orbitalBlast: return "Нажми на врага (не Короля) — его поглотит Чёрная Дыра!"
        }
    }
}

struct SynergyInfo: Identifiable {
    var id: String
    var title: String
    var icon: String
    var bonus: String
    var color: Color

    static func activeSynergies(for roster: [RoguelikeUnit]) -> [SynergyInfo] {
        let active = roster.filter { $0.isDeployed && !$0.isDamaged }
        var counts: [UnitClass: Int] = [:]
        for u in active where u.unitClass != .standard {
            counts[u.unitClass, default: 0] += 1
        }
        var res: [SynergyInfo] = []
        if (counts[.chrono] ?? 0) >= 2 {
            res.append(SynergyInfo(id: "chrono", title: "Хроно-Резонанс (2+)", icon: "⏳", bonus: "Каждые 5 ходов +1 Откат", color: .cyan))
        }
        if (counts[.golden] ?? 0) >= 2 {
            res.append(SynergyInfo(id: "golden", title: "Золотой Синдикат (2+)", icon: "🪙", bonus: "+15% к капиталу после боя", color: .yellow))
        }
        if (counts[.guardian] ?? 0) >= 2 {
            res.append(SynergyInfo(id: "guardian", title: "Железный Бастион (2+)", icon: "🛡️", bonus: "Офицеры 1 раз не ломаются", color: .green))
        }
        if (counts[.berserk] ?? 0) >= 2 {
            res.append(SynergyInfo(id: "berserk", title: "Кровавый Натиск (2+)", icon: "🔥", bonus: "+10 🪙 и +12⚡ за взятие", color: .red))
        }
        if (counts[.quantum] ?? 0) >= 2 {
            res.append(SynergyInfo(id: "quantum", title: "Квантовый Сдвиг (2+)", icon: "🟣", bonus: "Взятия заряжают Прыжок Короля", color: .purple))
        }
        if (counts[.nova] ?? 0) >= 2 {
            res.append(SynergyInfo(id: "nova", title: "Коллапс Звёзд (2+)", icon: "☄️", bonus: "Удар Чёрной Дыры на 3-м ходу", color: .orange))
        }
        return res
    }
}

enum PatcherKind: String, Codable, CaseIterable, Identifiable {
    case mutateClass = "Патч «Смена Класса»"
    case promoteTier = "Патч «Эволюция Ранга»"
    case armorGuardian = "Патч «Несокрушимость»"
    case overclockNova = "Патч «Оверклок Энергии»"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .mutateClass: return "🧬"
        case .promoteTier: return "⬆️"
        case .armorGuardian: return "🛡️"
        case .overclockNova: return "⚡"
        }
    }

    var price: Int {
        switch self {
        case .mutateClass: return 55
        case .promoteTier: return 95
        case .armorGuardian: return 70
        case .overclockNova: return 80
        }
    }

    var description: String {
        switch self {
        case .mutateClass: return "Назначает выбранной фигуре редкий случайный класс."
        case .promoteTier: return "Повышает ранг: Пешка→Конь/Слон→Ладья→Ферзь!"
        case .armorGuardian: return "Чинит фигуру и навсегда ставит ей класс «Страж»."
        case .overclockNova: return "Делает фигуру «Сверхновой» и даёт +15⚡ в начале боёв."
        }
    }
}

enum VoidCurse: String, Codable, CaseIterable, Identifiable {
    case asteroidStorm = "Астероидный шквал"
    case inflation = "Космическая инфляция"
    case ironFoes = "Тяжёлая гвардия врага"
    case timeLock = "Дефицит откатов"

    var id: String { rawValue }

    var shardBonus: Int {
        switch self {
        case .asteroidStorm: return 30
        case .inflation: return 25
        case .ironFoes: return 40
        case .timeLock: return 35
        }
    }

    var description: String {
        switch self {
        case .asteroidStorm: return "+20% шанс падения астероидов на каждом ходу (+\(shardBonus)% ✨)."
        case .inflation: return "Рулетка и магазин на 25% дороже (+\(shardBonus)% ✨)."
        case .ironFoes: return "У врага на 1 дополнительного офицера больше (+\(shardBonus)% ✨)."
        case .timeLock: return "-1 к стартовым откатам в каждом бою (+\(shardBonus)% ✨)."
        }
    }
}

struct RoguelikeUnit: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var pieceType: Int
    var unitClass: UnitClass
    var isDamaged: Bool = false
    var isDeployed: Bool = true
    var ascendedCount: Int = 0
    var energyBonus: Int = 0
}

enum PlanetBiome: String, Codable, CaseIterable {
    case mercury = "Меркурий"
    case venus = "Венера"
    case earth = "Земля и Луна"
    case mars = "Марс"
    case asteroidBelt = "Пояс Астероидов"
    case jupiter = "Юпитер"
    case saturn = "Сатурн"
    case uranusNeptune = "Уран и Нептун"
    case pluto = "Плутон / Сингулярность"

    var badgeColor: Color {
        switch self {
        case .mercury: return Color(red: 1.0, green: 0.68, blue: 0.28)
        case .venus: return Color(red: 1.0, green: 0.84, blue: 0.44)
        case .earth: return Color(red: 0.30, green: 0.78, blue: 1.0)
        case .mars: return Color(red: 1.0, green: 0.42, blue: 0.25)
        case .asteroidBelt: return Color(red: 0.78, green: 0.72, blue: 0.64)
        case .jupiter: return Color(red: 0.96, green: 0.62, blue: 0.36)
        case .saturn: return Color(red: 0.95, green: 0.85, blue: 0.56)
        case .uranusNeptune: return Color(red: 0.32, green: 0.92, blue: 0.95)
        case .pluto: return Color(red: 0.76, green: 0.42, blue: 1.0)
        }
    }

    var modifierTitle: String {
        switch self {
        case .mercury: return "🔥 Жар: 22% метеориты"
        case .venus: return "🕳️ Кислотные разломы"
        case .earth: return "🪙 Золотые жилы и трамплины"
        case .mars: return "🪨 Марсианская буря (26%)"
        case .asteroidBelt: return "☄️ Бомбардировка (35%)"
        case .jupiter: return "⚡ Высокая гравитация (+5⚡/ход)"
        case .saturn: return "💀 Усиленные элитные враги"
        case .uranusNeptune: return "❄️ Крио-обломки"
        case .pluto: return "👑 Босс: 2 Фазы + Разломы"
        }
    }

    var asteroidChance: Double {
        switch self {
        case .mercury: return 0.22
        case .venus: return 0.16
        case .earth: return 0.12
        case .mars: return 0.26
        case .asteroidBelt: return 0.35
        case .jupiter: return 0.18
        case .saturn: return 0.20
        case .uranusNeptune: return 0.24
        case .pluto: return 0.28
        }
    }
}

enum NodeType: String, Codable {
    case battle = "Бой"
    case elite = "Элита"
    case shop = "Магазин"
    case event = "Событие"
    case boss = "Босс"

    var icon: String {
        switch self {
        case .battle: return "⚔️"
        case .elite: return "💀"
        case .shop: return "🛒"
        case .event: return "✨"
        case .boss: return "👑"
        }
    }

    var color: Color {
        switch self {
        case .battle: return .cyan
        case .elite: return .red
        case .shop: return .yellow
        case .event: return .purple
        case .boss: return .orange
        }
    }
}

struct MapNode: Identifiable, Codable, Equatable {
    var id: String
    var layer: Int
    var lane: Int
    var title: String
    var planet: PlanetBiome
    var type: NodeType
    var nextNodeIds: [String]
}

enum RoguelikePhase: String, Codable {
    case map
    case inBattle
    case reward
    case shop
    case event
    case victory
    case gameOver
}

struct RewardOption: Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: RewardKind
    var title: String
    var subtitle: String
    var icon: String
    var accent: Color
}

enum RewardKind: Equatable {
    case unit(pieceType: Int, unitClass: UnitClass)
    case relic(RoguelikeRelic)
    case extraUndoAndCredits(undos: Int, credits: Int)
    case repairAndPawn(unitClass: UnitClass)
}

enum ShopTab: String, CaseIterable, Identifiable {
    case units = "Фигуры"
    case casesPacks = "Кейсы и Паки"
    case patchers = "Патчеры"
    case relics = "Реликвии"
    var id: String { rawValue }
}

struct ShopItem: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String
    var icon: String
    var price: Int
    var sold: Bool = false
    var unlimited: Bool = false
    var buyCount: Int = 0
    var tab: ShopTab
    var kind: ShopKind
}

enum ShopKind: Equatable {
    case unit(pieceType: Int, unitClass: UnitClass)
    case randomRarePawn
    case normalCase
    case eliteCase
    case squadPack
    case relicPack
    case patcher(PatcherKind)
    case relic(RoguelikeRelic)
    case maxUndo
    case aegisCharge
}

struct PackReward: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String
    var icon: String
    var color: Color
}

struct CosmicEvent: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var story: String
    var choices: [EventChoice]
}

struct EventChoice: Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String
    var effectNote: String
    var kind: EventEffectKind
}

enum EventEffectKind: Equatable {
    case sacrificePawnForRelicAndGold
    case repairAllOrGainGold
    case gambleRarePawn
    case gainCreditsSafe
    case gainUndoAndEnergy
}

struct RoulettePrize: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String
    var icon: String
    var color: Color
    var kind: RoulettePrizeKind
}

enum RoulettePrizeKind: Equatable {
    case pawn(UnitClass)
    case doublePawn(UnitClass, UnitClass)
    case officer(Int, UnitClass)
    case aegisAndCredits
    case patcher(PatcherKind)
}

enum MetaPerk: String, Codable, CaseIterable, Identifiable {
    case extraCredits = "Стартовый капитал"
    case extraPawn = "Рекрутский набор"
    case cheapRoulette = "VIP-Рулетка"
    case extraUndo = "Хроно-резерв"
    case startAegis = "Благословение Эгиды"
    case startEnergy = "Плазменный реактор"

    var id: String { rawValue }

    var cost: Int {
        switch self {
        case .extraCredits: return 35
        case .extraPawn: return 55
        case .cheapRoulette: return 50
        case .extraUndo: return 70
        case .startAegis: return 95
        case .startEnergy: return 65
        }
    }

    var description: String {
        switch self {
        case .extraCredits: return "+45 🪙 в начале каждого нового забега."
        case .extraPawn: return "+1 случайная особая пешка на старте забега."
        case .cheapRoulette: return "Рулетка и кейсы дешевле на 10 🪙."
        case .extraUndo: return "+1 Макс. Откат в каждом бою навсегда."
        case .startAegis: return "+1 заряд Эгиды Короля на старте забега."
        case .startEnergy: return "+20⚡ стартовой Энергии в каждом бою."
        }
    }
}

struct RoguelikeMeta: Codable {
    var starShards: Int = 30
    var bestSectorReached: Int = 0
    var bestGalaxyReached: Int = 1
    var runsCompleted: Int = 0
    var runsWon: Int = 0
    var unlockedPerks: [MetaPerk] = []
}

struct RoguelikeRun: Codable {
    var id: UUID = UUID()
    var commander: CommanderClass
    var galaxy: GalaxySystem
    var curses: [VoidCurse]
    var credits: Int
    var roster: [RoguelikeUnit]
    var relics: [RoguelikeRelic]
    var bonusUndos: Int
    var aegisCharges: Int
    var currentLayer: Int
    var currentNodeId: String?
    var activeNode: MapNode?
    var completedNodeIds: [String]
    var mapLayers: [[MapNode]]
    var rouletteSpins: Int
    var phase: RoguelikePhase
    var battlesWon: Int
    var elitesDefeated: Int
    var enemiesCaptured: Int
    var pawnsLost: Int
    var pawnsPromoted: Int
}

struct RoguelikeBattleState {
    var node: MapNode
    var unitMap: [Int: UUID]
    var units: [UUID: RoguelikeUnit]
    var destroyedIds: Set<UUID>
    var damagedIds: Set<UUID>
    var guardianSavedIds: Set<UUID>
    var battleCredits: Int
    var battleBonusUndos: Int
    var aegisLeft: Int
    var warlordUndoGains: Int
    var earnedRelics: [RoguelikeRelic]
    var movesPlayed: Int
    var pendingNovaStrikes: Int
    var energy: Int
    var bossPhase2Triggered: Bool
    var synergyNovaTriggered: Bool
}

struct RoguelikePromotionRequest: Equatable {
    var from: Int
    var to: Int
    var pawnClass: UnitClass
    var buffChoices: [AscensionBuff]
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: String
    let text: String
}

struct HistoryEntry {
    var board: ChessBoard
    var prevLastMove: Move?
    var prevNotation: String
    var battleSnapshot: RoguelikeBattleState?
    var prevUndoCount: Int?
}

@main
struct VibeChessApp: App {
    var body: some Scene {
        WindowGroup {
            MainGameView()
        }
    }
}
