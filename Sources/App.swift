import SwiftUI
import SceneKit
import ARKit
import AVFoundation
import AudioToolbox
import CoreMotion
import UIKit

enum Side: String, Codable {
    case white, black
    var opposite: Side { self == .white ? .black : .white }
    var title: String { self == .white ? "Белые" : "Чёрные" }
}

enum TimeControl: String, CaseIterable, Identifiable, Codable {
    case infinite = "Без времени"
    case blitz3 = "Блиц 3 мин"
    case rapid5 = "Рапид 5 мин"
    case classic10 = "Классика 10 мин"
    var id: String { rawValue }
    var initialSeconds: Int {
        switch self {
        case .infinite: return 0
        case .blitz3: return 180
        case .rapid5: return 300
        case .classic10: return 600
        }
    }
}

enum GameMode: String, CaseIterable, Identifiable, Codable {
    case vsBot = "1 Игрок (vs Бот)"
    case passAndPlay = "2 Игрока (Вдвоем)"
    var id: String { rawValue }
}

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

enum GameResult: Equatable {
    case checkmate(winner: Side)
    case stalemate
    case insufficient
    case fiftyMove
    case repetition
    case timeout(loser: Side)

    var title: String {
        switch self {
        case .checkmate(let w): return "Мат! Победили \(w == .white ? "белые" : "чёрные")"
        case .stalemate: return "Пат — ничья"
        case .insufficient: return "Ничья: мало материала"
        case .fiftyMove: return "Ничья: правило 50 ходов"
        case .repetition: return "Ничья: троекратное повторение"
        case .timeout(let l): return "Время вышло! Победили \(l == .white ? "чёрные" : "белые")"
        }
    }
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

    var shortBadge: String {
        switch self {
        case .standard: return ""
        case .recruit: return "РЕК"
        case .golden: return "ЗОЛ"
        case .berserk: return "БЕР"
        case .guardian: return "СТР"
        case .chrono: return "ХРН"
        case .quantum: return "КВН"
        case .nova: return "НОВА"
        }
    }

    var description: String {
        switch self {
        case .standard: return "Обычная фигура без модификаторов."
        case .recruit: return "Базовый боец. При превращении на 8-й линии даёт +25 🪙."
        case .golden: return "+5 🪙 за ход пешкой, +20 🪙 за взятие и +80 🪙 при превращении."
        case .berserk: return "Пешка может прыгать на 2 клетки вперёд с любой линии. +15 🪙 за взятие."
        case .guardian: return "1 раз за бой при гибели возвращается в резерв. Возвышение даёт +1 Эгиду."
        case .chrono: return "При гибели даёт +1 Откат. При возвышении +2 Отката и +1 Макс. Откат."
        case .quantum: return "Пешка может шагать на 1 клетку по диагонали вперёд. Даёт Королю прыжок конём."
        case .nova: return "При гибели или возвышении сжигает врага Чёрной Дырой."
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
    var kingLeapReady: Bool
    var isRoguelike: Bool

    init(
        sq: [Int8],
        whiteToMove: Bool,
        castle: UInt8,
        ep: Int,
        halfmove: Int,
        fullmove: Int,
        classes: [UnitClass] = [],
        kingLeapReady: Bool = false,
        isRoguelike: Bool = false
    ) {
        self.sq = sq
        self.whiteToMove = whiteToMove
        self.castle = castle
        self.ep = ep
        self.halfmove = halfmove
        self.fullmove = fullmove
        self.classes = classes
        self.kingLeapReady = kingLeapReady
        self.isRoguelike = isRoguelike
    }

    static func initial() -> ChessBoard {
        var b = ChessBoard(
            sq: [Int8](repeating: 0, count: 64),
            whiteToMove: true,
            castle: 0b1111,
            ep: -1,
            halfmove: 0,
            fullmove: 1
        )
        let back: [Int8] = [4, 2, 3, 5, 6, 3, 2, 4]
        for c in 0..<8 {
            b.sq[c] = back[c]
            b.sq[8 + c] = 1
            b.sq[48 + c] = -1
            b.sq[56 + c] = -back[c]
        }
        return b
    }

    var key: PositionKey {
        return PositionKey(sq: sq, whiteToMove: whiteToMove, castle: castle, ep: ep)
    }

    fileprivate static let knightOffsets: [(Int, Int)] = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    fileprivate static let kingOffsets: [(Int, Int)] = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    fileprivate static let diagDirs: [(Int, Int)] = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    fileprivate static let lineDirs: [(Int, Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    fileprivate static let allDirs: [(Int, Int)] = [(1, 1), (1, -1), (-1, 1), (-1, -1), (1, 0), (-1, 0), (0, 1), (0, -1)]

    fileprivate static func castleMask(_ s: Int) -> UInt8 {
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
                let p = sq[nr * 8 + nc]
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
                let p = sq[nr * 8 + nc]
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
                    if sq[t] == 0 {
                        if nr == promoRow {
                            for pr in [5, 4, 3, 2] { moves.append(Move(from: s, to: t, promo: pr)) }
                        } else {
                            moves.append(Move(from: s, to: t))
                            let canDouble = (r == startRow) || (white && uClass == .berserk && r + 2 * dir < 8)
                            if canDouble {
                                let nr2 = r + 2 * dir
                                if nr2 >= 0 && nr2 < 8 {
                                    let t2 = nr2 * 8 + c
                                    if sq[t2] == 0 {
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
            if (castle & 1) != 0 && sq[5] == 0 && sq[6] == 0 && sq[7] == 4 {
                let safe = !isAttacked(4, byWhite: false) && !isAttacked(5, byWhite: false) && !isAttacked(6, byWhite: false)
                if safe { moves.append(Move(from: 4, to: 6)) }
            }
            if (castle & 2) != 0 && sq[3] == 0 && sq[2] == 0 && sq[1] == 0 && sq[0] == 4 {
                let safe = !isAttacked(4, byWhite: false) && !isAttacked(3, byWhite: false) && !isAttacked(2, byWhite: false)
                if safe { moves.append(Move(from: 4, to: 2)) }
            }
        } else if !white && s == 60 {
            if (castle & 4) != 0 && sq[61] == 0 && sq[62] == 0 && sq[63] == -4 {
                let safe = !isAttacked(60, byWhite: true) && !isAttacked(61, byWhite: true) && !isAttacked(62, byWhite: true)
                if safe { moves.append(Move(from: 60, to: 62)) }
            }
            if (castle & 8) != 0 && sq[59] == 0 && sq[58] == 0 && sq[57] == 0 && sq[56] == -4 {
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

    func insufficientMaterial() -> Bool {
        var minors = 0
        for s in 0..<64 {
            let t = abs(Int(sq[s]))
            if t == 0 || t == 6 { continue }
            if t == 2 || t == 3 { minors += 1 } else { return false }
        }
        return minors <= 1
    }
}

extension ChessBoard: Codable {
    enum CodingKeys: String, CodingKey {
        case sq, whiteToMove, castle, ep, halfmove, fullmove, classes, kingLeapReady, isRoguelike
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sq = try c.decode([Int8].self, forKey: .sq)
        whiteToMove = try c.decode(Bool.self, forKey: .whiteToMove)
        castle = try c.decode(UInt8.self, forKey: .castle)
        ep = try c.decode(Int.self, forKey: .ep)
        halfmove = try c.decode(Int.self, forKey: .halfmove)
        fullmove = try c.decode(Int.self, forKey: .fullmove)
        classes = try c.decodeIfPresent([UnitClass].self, forKey: .classes) ?? []
        kingLeapReady = try c.decodeIfPresent(Bool.self, forKey: .kingLeapReady) ?? false
        isRoguelike = try c.decodeIfPresent(Bool.self, forKey: .isRoguelike) ?? false
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
        try c.encode(kingLeapReady, forKey: .kingLeapReady)
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
            return bestMove(board: board, maxDepth: 6, time: 2.5)
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
        case .vanguard: return "Старт: Король, Конь, Слон, 3 пешки (2 Рекрута, 1 Берсерк). Бонус: +25% 🪙."
        case .bastion: return "Старт: Король, Ладья, 3 пешки (2 Стража, 1 Рекрут). Реликвия: Эгида Короля."
        case .chronoWalker: return "Старт: Король, Слон, 2 Хроно-пешки, +2 Отката и 85 🪙 на Рулетку."
        case .soloTitan: return "Старт: Король, Ферзь и всего 1 пешка (Сверхновая). Острый дефицит пешек!"
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
        case .warlordFury: return "За каждое взятие вражеского офицера +15 🪙 и +1 Откат (до 2 раз за бой)."
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

struct RoguelikeUnit: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var pieceType: Int
    var unitClass: UnitClass
    var isDamaged: Bool = false
    var isDeployed: Bool = true
    var ascendedCount: Int = 0
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
    case pluto = "Плутон"

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

    var subtitle: String {
        switch self {
        case .mercury: return "Раскалённый аванпост"
        case .venus: return "Кислотные штормы"
        case .earth: return "Орбитальный рубеж"
        case .mars: return "Красный бастион"
        case .asteroidBelt: return "Зона обломков"
        case .jupiter: return "Гравитационный гигант"
        case .saturn: return "Кольцевой лабиринт"
        case .uranusNeptune: return "Ледяная граница"
        case .pluto: return "Трон Пустоты"
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

struct ShopItem: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String
    var icon: String
    var price: Int
    var sold: Bool = false
    var kind: ShopKind
}

enum ShopKind: Equatable {
    case unit(pieceType: Int, unitClass: UnitClass)
    case relic(RoguelikeRelic)
    case maxUndo
    case aegisCharge
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
    case gainUndoAndRoyalLeap
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
}

enum MetaPerk: String, Codable, CaseIterable, Identifiable {
    case extraCredits = "Стартовый капитал"
    case extraPawn = "Рекрутский набор"
    case cheapRoulette = "VIP-Рулетка"
    case extraUndo = "Хроно-резерв"
    case startAegis = "Благословение Эгиды"

    var id: String { rawValue }

    var cost: Int {
        switch self {
        case .extraCredits: return 35
        case .extraPawn: return 55
        case .cheapRoulette: return 50
        case .extraUndo: return 70
        case .startAegis: return 95
        }
    }

    var description: String {
        switch self {
        case .extraCredits: return "+40 🪙 в начале каждого нового забега."
        case .extraPawn: return "+1 случайная особая пешка на старте забега."
        case .cheapRoulette: return "Вращение Космической Рулетки дешевле на 10 🪙."
        case .extraUndo: return "+1 Макс. Откат в каждом бою навсегда."
        case .startAegis: return "+1 заряд Эгиды Короля на старте забега."
        }
    }
}

struct RoguelikeMeta: Codable {
    var starShards: Int = 25
    var bestSectorReached: Int = 0
    var runsCompleted: Int = 0
    var runsWon: Int = 0
    var unlockedPerks: [MetaPerk] = []
}

struct RoguelikeRun: Codable {
    var id: UUID = UUID()
    var commander: CommanderClass
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
    var endlessLoop: Int
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

struct PromotionRequest: Equatable {
    var from: Int
    var to: Int
    var white: Bool
}

struct HistoryEntry {
    var board: ChessBoard
    var prevLastMove: Move?
    var prevNotation: String
    var battleSnapshot: RoguelikeBattleState?
    var prevUndoCount: Int?
}

struct SaveSlot: Identifiable, Codable {
    var id: String
    var title: String
    var dateString: String
    var board: ChessBoard
    var playerSide: Side
    var mode: GameMode
    var difficulty: BotDifficulty
    var timeControl: TimeControl
    var whiteSeconds: Int
    var blackSeconds: Int
    var lastMove: Move?
}

final class GameManager: ObservableObject {
    @Published var inMenu = true
    @Published var isPaused = false
    @Published var statusText = "Выбери режим и начни партию"
    @Published var lastMoveNotation = "Начало партии"
    @Published var isARMode = false {
        didSet {
            if isARMode && controlMode == .drag { controlMode = .tap }
        }
    }
    @Published var isAnimating = false
    @Published var isThinking = false
    @Published var isCheckNow = false
    @Published var turnIsWhite = true
    @Published var gameResult: GameResult? = nil
    @Published var pendingPromotion: PromotionRequest? = nil
    @Published var undoCount = 3
    @Published var whiteSeconds = 300
    @Published var blackSeconds = 300
    @Published var isClockActive = false
    @Published var saveSlots: [SaveSlot] = []
    @Published var isAdviceThinking = false
    @Published var chat: [ChatMessage] = [
        ChatMessage(sender: "Гроссмейстер AI", text: "Приветствую! Доступны Классические шахматы и Космический рогалик «Ход за ходом».")
    ]

    @Published var isRoguelikeActive = false
    @Published var roguelikeRun: RoguelikeRun? = nil
    @Published var roguelikeMeta: RoguelikeMeta = RoguelikeMeta()
    @Published var battleState: RoguelikeBattleState? = nil
    @Published var pendingRoguelikePromotion: RoguelikePromotionRequest? = nil
    @Published var rewardOptions: [RewardOption] = []
    @Published var shopItems: [ShopItem] = []
    @Published var activeEvent: CosmicEvent? = nil
    @Published var eventOutcomeText: String? = nil
    @Published var battleBannerText: String? = nil
    @Published var lastBattleSummary: String = ""
    @Published var runEndTitle: String = ""
    @Published var runEndShardsEarned: Int = 0
    @Published var selectedUnitTooltip: String? = nil

    @Published var playerSide: Side = .white { didSet { saveSettings() } }
    @Published var mode: GameMode = .vsBot { didSet { saveSettings() } }
    @Published var controlMode: ControlMode = .tap {
        didSet {
            saveSettings()
            applyControlMode()
        }
    }
    @Published var difficulty: BotDifficulty = .hard { didSet { saveSettings() } }
    @Published var timeControl: TimeControl = .rapid5 { didSet { saveSettings() } }
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
    weak var arSceneView: ARSCNView?
    var arBoardAnchorNode: SCNNode?

    private var board = ChessBoard.initial()
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
        loadSavesFromDisk()
        loadRoguelikeFromDisk()
        positionCounts = [board.key: 1]
        boardCtl.reset(board: board, flipped: false)
        space.applyQuality(graphicsQuality)
        space.setGyroEnabled(gyroEnabled)
        applyControlMode()
        SoundEngine.shared.toggleMusic(musicEnabled)
    }

    var isHumanTurn: Bool {
        if isRoguelikeActive { return board.whiteToMove }
        if mode == .passAndPlay { return true }
        return board.whiteToMove == (playerSide == .white)
    }

    var shouldFlipCamera: Bool {
        if isRoguelikeActive { return false }
        return mode == .vsBot && playerSide == .black
    }

    var hasAutoSave: Bool { saveSlots.contains { $0.id == "auto" } }
    var hasActiveRoguelikeRun: Bool {
        guard let r = roguelikeRun else { return false }
        return r.phase != .gameOver && r.phase != .victory
    }

    var rouletteCost: Int {
        let base = 50 + min(30, (roguelikeRun?.rouletteSpins ?? 0) * 5)
        let discount = roguelikeMeta.unlockedPerks.contains(.cheapRoulette) ? 10 : 0
        return max(30, base - discount)
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
        d.set(mode.rawValue, forKey: "Vibe_Mode")
        d.set(difficulty.rawValue, forKey: "Vibe_Diff")
        d.set(timeControl.rawValue, forKey: "Vibe_Time")
        d.set(playerSide.rawValue, forKey: "Vibe_Side2")
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
        if let m = d.string(forKey: "Vibe_Mode"), let v = GameMode(rawValue: m) { mode = v }
        if let m = d.string(forKey: "Vibe_Diff"), let v = BotDifficulty(rawValue: m) { difficulty = v }
        if let m = d.string(forKey: "Vibe_Time"), let v = TimeControl(rawValue: m) { timeControl = v }
        if let m = d.string(forKey: "Vibe_Side2"), let v = Side(rawValue: m) { playerSide = v }
    }

    func applyControlMode() {
        let usePhysics = (controlMode == .drag && !isARMode)
        space.setOrbitalMotionPaused(usePhysics)
        boardCtl.setPhysicsEnabled(usePhysics, board: board)
    }

    func toggleControlMode() {
        controlMode = (controlMode == .tap) ? .drag : .tap
        SoundEngine.shared.play("click", enabled: sfxEnabled)
    }

    func realignPhysicsPieces() {
        boardCtl.reset(board: board, flipped: shouldFlipCamera)
        refreshHighlights()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
    }

    func startNewGame() {
        gameToken += 1
        isRoguelikeActive = false
        battleState = nil
        pendingBotMove = nil
        draggingSourceSquare = nil
        pendingRoguelikePromotion = nil
        selectedUnitTooltip = nil
        board = ChessBoard.initial()
        history.removeAll()
        positionCounts = [board.key: 1]
        selectedSquare = nil
        legalForSelected = []
        lastMove = nil
        gameResult = nil
        pendingPromotion = nil
        isAnimating = false
        isThinking = false
        isPaused = false
        isCheckNow = false
        undoCount = 3
        lastMoveNotation = "Партия началась"
        let t = timeControl.initialSeconds
        whiteSeconds = t
        blackSeconds = t
        isClockActive = (timeControl != .infinite)
        inMenu = false
        space.setSectorTheme(nil)
        boardCtl.reset(board: board, flipped: shouldFlipCamera)
        applyControlMode()
        space.focus(flipped: shouldFlipCamera)
        refreshHighlights()
        updateStatus()
        autoSave()
        if mode == .vsBot && playerSide == .black {
            SoundEngine.shared.speak("Белые ходят первыми.", enabled: voiceEnabled)
            triggerBotMove()
        } else {
            SoundEngine.shared.speak("Твой ход.", enabled: voiceEnabled)
        }
    }

    func continueGame() {
        if let slot = saveSlots.first(where: { $0.id == "auto" }) { loadFromSlot(slot) }
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
        selectedSquare = nil
        legalForSelected = []
        pendingPromotion = nil
        pendingRoguelikePromotion = nil
        selectedUnitTooltip = nil
        if isRoguelikeActive, var run = roguelikeRun {
            if run.phase == .inBattle {
                run.phase = .map
                run.activeNode = nil
                roguelikeRun = run
            }
            saveRoguelikeRun()
        }
        isRoguelikeActive = false
        battleState = nil
        inMenu = true
        space.setSectorTheme(nil)
        boardCtl.setLift(nil)
        boardCtl.setHighlights(selected: nil, targets: [:], last: nil, check: nil)
        space.startMenuOrbit()
    }

    func restartGame() {
        if isRoguelikeActive, let c = roguelikeRun?.commander {
            startNewRoguelike(commander: c)
        } else {
            startNewGame()
        }
    }

    func startNewRoguelike(commander: CommanderClass) {
        gameToken += 1
        pendingBotMove = nil
        draggingSourceSquare = nil
        isARMode = false
        isThinking = false
        isAnimating = false
        isPaused = false
        gameResult = nil
        pendingPromotion = nil
        pendingRoguelikePromotion = nil
        selectedUnitTooltip = nil
        battleBannerText = nil
        isClockActive = false

        var units: [RoguelikeUnit] = [
            RoguelikeUnit(pieceType: 6, unitClass: .standard)
        ]
        var relics: [RoguelikeRelic] = []
        var credits = 45
        var bonusUndos = 0
        var aegis = 0

        switch commander {
        case .vanguard:
            units.append(RoguelikeUnit(pieceType: 2, unitClass: .standard))
            units.append(RoguelikeUnit(pieceType: 3, unitClass: .standard))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .recruit))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .recruit))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .berserk))
            credits = 50
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
            credits = 85
        case .soloTitan:
            units.append(RoguelikeUnit(pieceType: 5, unitClass: .standard))
            units.append(RoguelikeUnit(pieceType: 1, unitClass: .nova))
            credits = 55
        }

        if roguelikeMeta.unlockedPerks.contains(.extraCredits) { credits += 40 }
        if roguelikeMeta.unlockedPerks.contains(.extraPawn) {
            let bonusPool: [UnitClass] = [.recruit, .golden, .berserk, .guardian, .chrono]
            units.append(RoguelikeUnit(pieceType: 1, unitClass: bonusPool.randomElement() ?? .recruit))
        }
        if roguelikeMeta.unlockedPerks.contains(.extraUndo) { bonusUndos += 1 }
        if roguelikeMeta.unlockedPerks.contains(.startAegis) {
            if !relics.contains(.kingAegis) { relics.append(.kingAegis) }
            aegis += 1
        }

        let layers = generateCosmicMap(loop: 0)
        let run = RoguelikeRun(
            commander: commander,
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
            endlessLoop: 0,
            phase: .map,
            battlesWon: 0,
            elitesDefeated: 0,
            enemiesCaptured: 0,
            pawnsLost: 0,
            pawnsPromoted: 0
        )

        roguelikeRun = run
        isRoguelikeActive = true
        inMenu = false
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
        isARMode = false
        isClockActive = false
        isThinking = false
        isAnimating = false
        isPaused = false
        gameResult = nil
        pendingPromotion = nil
        pendingRoguelikePromotion = nil
        if run.phase == .inBattle {
            run.phase = .map
            run.activeNode = nil
        }
        if run.phase == .reward && rewardOptions.isEmpty { run.phase = .map }
        if run.phase == .shop && shopItems.isEmpty { run.phase = .map }
        if run.phase == .event && activeEvent == nil { run.phase = .map }
        roguelikeRun = run
        isRoguelikeActive = true
        inMenu = false
        space.setSectorTheme(.earth)
        space.startMenuOrbit()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
    }

    func generateCosmicMap(loop: Int) -> [[MapNode]] {
        let prefix = "L\(loop)_"
        let n0 = MapNode(id: "\(prefix)0_0", layer: 0, lane: 1, title: "Орбита Меркурия", planet: .mercury, type: .battle, nextNodeIds: ["\(prefix)1_0", "\(prefix)1_1"])

        let n1_0 = MapNode(id: "\(prefix)1_0", layer: 1, lane: 0, title: "Патруль Венеры", planet: .venus, type: .battle, nextNodeIds: ["\(prefix)2_0", "\(prefix)2_1"])
        let n1_1 = MapNode(id: "\(prefix)1_1", layer: 1, lane: 2, title: "Лунный Монолит", planet: .earth, type: .event, nextNodeIds: ["\(prefix)2_1", "\(prefix)2_2"])

        let n2_0 = MapNode(id: "\(prefix)2_0", layer: 2, lane: 0, title: "Рубеж Земли", planet: .earth, type: .battle, nextNodeIds: ["\(prefix)3_0"])
        let n2_1 = MapNode(id: "\(prefix)2_1", layer: 2, lane: 1, title: "Орбитальный Базар", planet: .mars, type: .shop, nextNodeIds: ["\(prefix)3_0", "\(prefix)3_1"])
        let n2_2 = MapNode(id: "\(prefix)2_2", layer: 2, lane: 2, title: "Страж Марса", planet: .mars, type: .elite, nextNodeIds: ["\(prefix)3_1"])

        let n3_0 = MapNode(id: "\(prefix)3_0", layer: 3, lane: 0, title: "Пояс Астероидов", planet: .asteroidBelt, type: .battle, nextNodeIds: ["\(prefix)4_0", "\(prefix)4_1"])
        let n3_1 = MapNode(id: "\(prefix)3_1", layer: 3, lane: 2, title: "Разлом Пояса", planet: .asteroidBelt, type: .elite, nextNodeIds: ["\(prefix)4_1", "\(prefix)4_2"])

        let n4_0 = MapNode(id: "\(prefix)4_0", layer: 4, lane: 0, title: "Рынок Спутника Ио", planet: .jupiter, type: .shop, nextNodeIds: ["\(prefix)5_0"])
        let n4_1 = MapNode(id: "\(prefix)4_1", layer: 4, lane: 1, title: "Шторм Юпитера", planet: .jupiter, type: .battle, nextNodeIds: ["\(prefix)5_0", "\(prefix)5_1"])
        let n4_2 = MapNode(id: "\(prefix)4_2", layer: 4, lane: 2, title: "Грави-Аномалия", planet: .jupiter, type: .event, nextNodeIds: ["\(prefix)5_1"])

        let n5_0 = MapNode(id: "\(prefix)5_0", layer: 5, lane: 0, title: "Кольца Сатурна", planet: .saturn, type: .battle, nextNodeIds: ["\(prefix)6_0", "\(prefix)6_1"])
        let n5_1 = MapNode(id: "\(prefix)5_1", layer: 5, lane: 2, title: "Титан Сатурна", planet: .saturn, type: .elite, nextNodeIds: ["\(prefix)6_1", "\(prefix)6_2"])

        let n6_0 = MapNode(id: "\(prefix)6_0", layer: 6, lane: 0, title: "Док Нептуна", planet: .uranusNeptune, type: .shop, nextNodeIds: ["\(prefix)7_0"])
        let n6_1 = MapNode(id: "\(prefix)6_1", layer: 6, lane: 1, title: "Пояс Койпера", planet: .uranusNeptune, type: .event, nextNodeIds: ["\(prefix)7_0"])
        let n6_2 = MapNode(id: "\(prefix)6_2", layer: 6, lane: 2, title: "Ледяной Центурион", planet: .uranusNeptune, type: .elite, nextNodeIds: ["\(prefix)7_0"])

        let bossTitle = loop == 0 ? "Трон Пустоты (Плутон)" : "Сингулярность Цикла #\(loop + 1)"
        let n7 = MapNode(id: "\(prefix)7_0", layer: 7, lane: 1, title: bossTitle, planet: .pluto, type: .boss, nextNodeIds: [])

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
        if run.relics.contains(.royalTreasury) {
            run.credits += 25
        }
        run.activeNode = node
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
        gameResult = nil
        pendingPromotion = nil
        pendingRoguelikePromotion = nil
        isAnimating = false
        isThinking = false
        isPaused = false
        isCheckNow = false
        selectedUnitTooltip = nil
        history.removeAll()

        var b = ChessBoard(
            sq: [Int8](repeating: 0, count: 64),
            whiteToMove: true,
            castle: 0b1111,
            ep: -1,
            halfmove: 0,
            fullmove: 1,
            classes: [UnitClass](repeating: .standard, count: 64),
            kingLeapReady: run.relics.contains(.royalLeap),
            isRoguelike: true
        )

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

        let enemy = buildEnemyArmy(layer: node.layer, type: node.type, loop: run.endlessLoop)
        b.sq[60] = -6
        let enemyBackSlots = [59, 61, 58, 62, 57, 63, 56]
        for (idx, piece) in enemy.officers.prefix(enemyBackSlots.count).enumerated() {
            b.sq[enemyBackSlots[idx]] = Int8(-piece)
        }
        let enemyPawnSlots = [51, 52, 50, 53, 49, 54, 48, 55]
        for idx in 0..<min(enemy.pawns, enemyPawnSlots.count) {
            b.sq[enemyPawnSlots[idx]] = -1
        }

        board = b
        positionCounts = [board.key: 1]
        turnIsWhite = true
        let baseUndos = 2 + run.bonusUndos + (run.relics.contains(.chronoCrown) ? 2 : 0)
        undoCount = baseUndos
        lastMoveNotation = "\(node.type.icon) \(node.title)"
        statusText = "Твой ход • \(node.planet.rawValue)"

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
            pendingNovaStrikes: 0
        )

        boardCtl.reset(board: board, flipped: false)
        applyControlMode()
        space.focus(flipped: false)
        refreshHighlights()
        saveRoguelikeRun()

        if run.relics.contains(.orbitalStrike) {
            let tok = gameToken
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
                guard let self = self, self.gameToken == tok, self.isRoguelikeActive else { return }
                self.triggerBlackHoleStrike(preferPawn: true, banner: "🕳️ Орбитальный удар сжёг пешку врага!")
            }
        }
    }

    private func buildEnemyArmy(layer: Int, type: NodeType, loop: Int) -> (officers: [Int], pawns: Int) {
        let tier = layer + loop * 5
        switch type {
        case .boss:
            if loop == 0 {
                return ([5, 4, 4, 3, 3, 2, 2], 8)
            } else {
                return ([5, 5, 4, 4, 3, 2, 2], 8)
            }
        case .elite:
            switch tier {
            case 0...2: return ([4, 2, 3], 4)
            case 3...4: return ([5, 4, 2], 5)
            case 5...6: return ([5, 4, 4, 3, 2], 6)
            default: return ([5, 5, 4, 3, 2, 2], 7)
            }
        default:
            switch tier {
            case 0: return ([2], 3)
            case 1: return ([2, 3], 4)
            case 2: return ([2, 2, 3], 4)
            case 3: return ([4, 2, 3], 5)
            case 4: return ([4, 4, 2], 5)
            case 5: return ([5, 3, 2], 6)
            case 6: return ([5, 4, 3, 2], 6)
            default: return ([5, 4, 4, 3, 2], 7)
            }
        }
    }

    @discardableResult
    private func triggerBlackHoleStrike(preferPawn: Bool, banner: String) -> Bool {
        var candidates: [Int] = []
        for s in 0..<64 where board.sq[s] < 0 && board.sq[s] != -6 {
            var test = board
            test.sq[s] = 0
            if !test.inCheck(white: false) {
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
        evaluateGameState()
        return true
    }

    private func showBanner(_ text: String) {
        battleBannerText = text
        let tok = gameToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
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

    func tapSquare(_ s: Int) {
        guard s >= 0, s < 64 else { return }
        guard !inMenu, !isPaused, !isAnimating, !isThinking, gameResult == nil, pendingPromotion == nil, pendingRoguelikePromotion == nil else { return }
        guard isHumanTurn else { return }
        if selectedSquare != nil && legalForSelected.contains(where: { $0.to == s }) {
            attemptMove(to: s)
            return
        }
        let piece = board.sq[s]
        if piece != 0 && (piece > 0) == board.whiteToMove {
            if selectedSquare == s {
                clearSelection()
            } else {
                select(s)
            }
        } else {
            clearSelection()
        }
    }

    func beginPieceDrag(square s: Int, atLocal: SCNVector3) -> Bool {
        guard controlMode == .drag, !isARMode, !inMenu, !isPaused, !isAnimating else { return false }
        guard s >= 0, s < 64 else { return false }
        guard boardCtl.beginDrag(square: s, atLocal: atLocal) else { return false }
        draggingSourceSquare = s
        if !isThinking, gameResult == nil, pendingPromotion == nil, pendingRoguelikePromotion == nil, isHumanTurn {
            let p = board.sq[s]
            if p != 0 && (p > 0) == board.whiteToMove {
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
           !inMenu, !isPaused, !isAnimating, !isThinking, gameResult == nil, pendingPromotion == nil, pendingRoguelikePromotion == nil, isHumanTurn {
            let p = board.sq[from]
            if p != 0 && (p > 0) == board.whiteToMove {
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
        guard controlMode == .drag, !isARMode, !inMenu, !isPaused, !isAnimating else { return }
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
        guard isRoguelikeActive, board.classes.count == 64 else {
            selectedUnitTooltip = nil
            return
        }
        let t = abs(Int(board.sq[s]))
        let uc = board.classes[s]
        if t == 6 && board.kingLeapReady {
            selectedUnitTooltip = "👑 Король • 🐴 Прыжок конём готов!"
        } else if uc != .standard {
            selectedUnitTooltip = "\(pieceTitle(t)) [\(uc.title)]: \(uc.description)"
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
            if isRoguelikeActive {
                let pClass = board.classes.count == 64 ? board.classes[from] : .recruit
                let buffs = Array(AscensionBuff.allCases.shuffled().prefix(3))
                pendingRoguelikePromotion = RoguelikePromotionRequest(
                    from: from,
                    to: t,
                    pawnClass: pClass == .standard ? .recruit : pClass,
                    buffChoices: buffs
                )
            } else {
                pendingPromotion = PromotionRequest(from: from, to: t, white: board.sq[from] > 0)
            }
            return
        }
        play(first)
    }

    func choosePromotion(_ type: Int) {
        guard let req = pendingPromotion else { return }
        pendingPromotion = nil
        if let m = legalForSelected.first(where: { $0.from == req.from && $0.to == req.to && $0.promo == type }) {
            play(m)
        }
    }

    func cancelPromotion() {
        pendingPromotion = nil
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
        guard !isAnimating, gameResult == nil else { return }
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

        if isRoguelikeActive, var bs = battleState {
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
            self.finishMove()
        }
    }

    private func processRoguelikeMoveHooks(move m: Move, before: ChessBoard, after: inout ChessBoard, bs: inout RoguelikeBattleState) {
        bs.movesPlayed += 1
        let hasTreasury = roguelikeRun?.relics.contains(.royalTreasury) ?? false
        let isVanguard = roguelikeRun?.commander == .vanguard

        if before.whiteToMove {
            let movingId = bs.unitMap[m.from]
            bs.unitMap[m.to] = movingId
            bs.unitMap[m.from] = nil

            let movingUnit = movingId.flatMap { bs.units[$0] }
            let uClass = movingUnit?.unitClass ?? .standard

            if movingUnit?.pieceType == 1 && uClass == .golden {
                bs.battleCredits += 5
            }

            if before.isCapture(m) {
                let capType = abs(Int(before.sq[m.to]))
                let realCap = capType == 0 ? 1 : capType
                var bounty = [0, 6, 12, 12, 18, 28, 0][min(6, realCap)]
                if uClass == .golden { bounty += 20 }
                if uClass == .berserk { bounty += 15 }
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
                case .recruit:
                    bs.battleCredits += 25
                case .golden:
                    bs.battleCredits += 80
                case .berserk:
                    undoCount += 1
                    bs.pendingNovaStrikes += 1
                case .guardian:
                    bs.aegisLeft += 1
                case .chrono:
                    undoCount += 2
                    bs.battleBonusUndos += 1
                case .quantum:
                    after.kingLeapReady = true
                case .nova:
                    bs.pendingNovaStrikes += 1
                case .standard:
                    break
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
                        bs.damagedIds.insert(lostId)
                        showBanner("⚠️ \(pieceTitle(lostUnit.pieceType)) подбита (нужен ремонт)")
                    }
                }
            }
        }
    }

    private func finishMove() {
        isAnimating = false
        if isRoguelikeActive, var bs = battleState, bs.pendingNovaStrikes > 0 {
            let count = bs.pendingNovaStrikes
            bs.pendingNovaStrikes = 0
            battleState = bs
            for _ in 0..<count {
                _ = triggerBlackHoleStrike(preferPawn: false, banner: "🕳️ Сверхновая поглотила врага!")
            }
        }

        isCheckNow = board.inCheck(white: board.whiteToMove)
        positionCounts[board.key, default: 0] += 1
        evaluateGameState()
        refreshHighlights()
        if gameResult != nil || (isRoguelikeActive && roguelikeRun?.phase != .inBattle) { return }
        if isCheckNow {
            SoundEngine.shared.play("check", enabled: sfxEnabled)
            SoundEngine.shared.speak("Шах!", enabled: voiceEnabled)
        } else {
            SoundEngine.shared.play("click", enabled: sfxEnabled)
        }
        updateStatus()
        if !isRoguelikeActive {
            autoSave()
            if mode == .vsBot && !isHumanTurn { triggerBotMove() }
        } else {
            if !isHumanTurn { triggerBotMove() }
        }
    }

    private func evaluateGameState() {
        if isRoguelikeActive {
            evaluateRoguelikeBattleState()
            return
        }
        let legal = board.legalMoves()
        if legal.isEmpty {
            if isCheckNow {
                endGame(.checkmate(winner: board.whiteToMove ? .black : .white))
            } else {
                endGame(.stalemate)
            }
        } else if board.insufficientMaterial() {
            endGame(.insufficient)
        } else if board.halfmove >= 100 {
            endGame(.fiftyMove)
        } else if (positionCounts[board.key] ?? 0) >= 3 {
            endGame(.repetition)
        }
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
        if let r = roguelikeRun, r.aegisCharges > bs.aegisLeft {
            roguelikeRun?.aegisCharges = bs.aegisLeft
        }
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

        var baseReward = 40 + bs.node.layer * 8
        if bs.node.type == .elite { baseReward += 35 }
        if bs.node.type == .boss { baseReward += 90 }
        if run.relics.contains(.royalTreasury) { baseReward = Int(Double(baseReward) * 1.35) }
        if run.commander == .vanguard { baseReward = Int(Double(baseReward) * 1.25) }

        let totalEarned = baseReward + bs.battleCredits

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

        roguelikeMeta.bestSectorReached = max(roguelikeMeta.bestSectorReached, bs.node.layer + 1 + run.endlessLoop * 8)

        lastBattleSummary = "\(bonusNote) +\(totalEarned) 🪙 • Погибло пешек: \(bs.destroyedIds.count)\(repairedMsg)"
        SoundEngine.shared.play("win", enabled: sfxEnabled)
        SoundEngine.shared.speak("Сектор зачищен!", enabled: voiceEnabled)
        boardCtl.celebrate()

        if bs.node.layer == run.mapLayers.count - 1 {
            let shards = 40 + run.battlesWon * 8 + run.elitesDefeated * 12 + run.pawnsPromoted * 10
            roguelikeMeta.starShards += shards
            roguelikeMeta.runsCompleted += 1
            roguelikeMeta.runsWon += 1
            runEndShardsEarned = shards
            runEndTitle = run.endlessLoop == 0 ? "ПОБЕДА! ПЛУТОН ПОКОРЁН!" : "ЦИКЛ #\(run.endlessLoop + 1) ПРОЙДЕН!"
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

        let shards = 10 + run.battlesWon * 6 + run.elitesDefeated * 10 + run.pawnsPromoted * 8
        roguelikeMeta.starShards += shards
        roguelikeMeta.runsCompleted += 1
        runEndShardsEarned = shards
        runEndTitle = "КОРОЛЬ ПАЛ — КОНЕЦ ЗАБЕГА"

        run.phase = .gameOver
        roguelikeRun = run
        battleState = nil
        SoundEngine.shared.play("check", enabled: sfxEnabled)
        SoundEngine.shared.speak("Конец забега. Твой путь увековечен среди звёзд.", enabled: voiceEnabled)
        haptic(.heavy)
        saveRoguelikeMeta()
        deleteRoguelikeRun()
    }

    func continueIntoEndlessLoop() {
        guard var run = roguelikeRun else { return }
        run.endlessLoop += 1
        run.currentLayer = 0
        run.currentNodeId = nil
        run.activeNode = nil
        run.completedNodeIds = []
        run.mapLayers = generateCosmicMap(loop: run.endlessLoop)
        run.phase = .map
        roguelikeRun = run
        space.setSectorTheme(.pluto)
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
        isRoguelikeActive = false
        battleState = nil
        inMenu = true
        space.setSectorTheme(nil)
        space.startMenuOrbit()
    }

    private func endGame(_ result: GameResult) {
        gameToken += 1
        gameResult = result
        isThinking = false
        isAnimating = false
        pendingBotMove = nil
        selectedSquare = nil
        legalForSelected = []
        statusText = result.title
        SoundEngine.shared.play("win", enabled: sfxEnabled)
        SoundEngine.shared.speak(result.title, enabled: voiceEnabled)
        haptic(.heavy)
        if case .checkmate = result { boardCtl.celebrate() }
        saveSlots.removeAll { $0.id == "auto" }
        persistSlots()
    }

    private func updateStatus() {
        turnIsWhite = board.whiteToMove
        if let r = gameResult {
            statusText = r.title
            return
        }
        if isRoguelikeActive {
            let planetName = battleState?.node.planet.rawValue ?? "Космос"
            if isHumanTurn {
                statusText = isCheckNow ? "Шах! Защити Короля • \(planetName)" : "Твой ход • \(planetName)"
            } else {
                statusText = "Враг просчитывает ход…"
            }
            return
        }
        let side = board.whiteToMove ? "Белые" : "Чёрные"
        if mode == .vsBot {
            if isHumanTurn {
                statusText = isCheckNow ? "Шах! Твой ход" : "Твой ход"
            } else {
                statusText = "Гроссмейстер думает…"
            }
        } else {
            statusText = isCheckNow ? "Шах! Ходят \(side.lowercased())" : "Ходят \(side.lowercased())"
        }
    }

    private func refreshHighlights() {
        var targets: [Int: Bool] = [:]
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
        guard !inMenu, gameResult == nil, !isThinking else { return }
        if !isRoguelikeActive && (mode != .vsBot || isHumanTurn) { return }
        if isRoguelikeActive && (roguelikeRun?.phase != .inBattle || isHumanTurn) { return }

        isThinking = true
        updateStatus()
        let snapshot = board
        let token = gameToken

        let aiDiff: BotDifficulty
        if isRoguelikeActive, let node = battleState?.node {
            let layer = node.layer + (roguelikeRun?.endlessLoop ?? 0) * 3
            if node.type == .boss || layer >= 6 {
                aiDiff = .hard
            } else if node.type == .elite || layer >= 3 {
                aiDiff = .medium
            } else {
                aiDiff = .easy
            }
        } else {
            aiDiff = difficulty
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ai = ChessAI()
            let mv = ai.chooseMove(board: snapshot, difficulty: aiDiff)
            DispatchQueue.main.async {
                guard let self = self, self.gameToken == token, !self.inMenu, self.gameResult == nil else { return }
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
        guard !isAnimating, !isThinking, undoCount > 0, !history.isEmpty, pendingPromotion == nil, pendingRoguelikePromotion == nil else { return }
        gameToken += 1
        pendingBotMove = nil
        while let entry = history.popLast() {
            let k = board.key
            if let n = positionCounts[k] {
                if n <= 1 { positionCounts.removeValue(forKey: k) } else { positionCounts[k] = n - 1 }
            }
            board = entry.board
            lastMove = entry.prevLastMove
            lastMoveNotation = entry.prevNotation
            if isRoguelikeActive, let bs = entry.battleSnapshot {
                battleState = bs
            }
            if isRoguelikeActive {
                if board.whiteToMove { break }
            } else {
                if mode == .passAndPlay || isHumanTurn { break }
            }
        }
        undoCount -= 1
        gameResult = nil
        selectedSquare = nil
        legalForSelected = []
        selectedUnitTooltip = nil
        isCheckNow = board.inCheck(white: board.whiteToMove)
        if !isRoguelikeActive && timeControl != .infinite {
            whiteSeconds = max(whiteSeconds, 15)
            blackSeconds = max(blackSeconds, 15)
        }
        boardCtl.reset(board: board, flipped: shouldFlipCamera)
        refreshHighlights()
        updateStatus()
        statusText = "Ход отменён. " + statusText
        SoundEngine.shared.play("select", enabled: sfxEnabled)
        haptic(.medium)
        if !isRoguelikeActive && mode == .vsBot && !isHumanTurn { triggerBotMove() }
    }

    private func generateRewardOptions(forElite: Bool) {
        guard let run = roguelikeRun else { return }
        var opts: [RewardOption] = []

        let roll = Int.random(in: 0..<100)
        if forElite && roll < 28 {
            opts.append(RewardOption(
                kind: .unit(pieceType: 5, unitClass: .standard),
                title: "♕ Элитный Ферзь",
                subtitle: "Добавляет Ферзя в твою постоянную армию.",
                icon: "♕",
                accent: .yellow
            ))
        } else if roll < 45 {
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
            let cls: UnitClass = [.standard, .golden, .berserk].randomElement() ?? .standard
            opts.append(RewardOption(
                kind: .unit(pieceType: t, unitClass: cls),
                title: "\(pieceGlyph(t)) \(pieceTitle(t)) [\(cls.title)]",
                subtitle: "Усиливает твой отряд перед следующим сектором.",
                icon: pieceGlyph(t),
                accent: .cyan
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
                kind: .extraUndoAndCredits(undos: 1, credits: 35),
                title: "↩️ +1 Макс. Откат и +35 🪙",
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
        run.credits += 30
        run.phase = .map
        roguelikeRun = run
        rewardOptions = []
        space.startMenuOrbit()
        saveRoguelikeRun()
        SoundEngine.shared.play("click", enabled: sfxEnabled)
    }

    private func generateShopItems() {
        guard let run = roguelikeRun else { return }
        var items: [ShopItem] = []

        let pawnCls: UnitClass = [.golden, .berserk, .guardian, .chrono, .quantum].randomElement() ?? .golden
        items.append(ShopItem(
            title: "♙ Пешка [\(pawnCls.title)]",
            subtitle: pawnCls.description,
            icon: "♙",
            price: 45,
            kind: .unit(pieceType: 1, unitClass: pawnCls)
        ))

        let officerChoices: [(Int, Int)] = [(2, 75), (3, 80), (4, 115), (5, 175)]
        let pick = officerChoices.randomElement() ?? (2, 75)
        items.append(ShopItem(
            title: "\(pieceGlyph(pick.0)) \(pieceTitle(pick.0))",
            subtitle: "Постоянный боец в твою армию.",
            icon: pieceGlyph(pick.0),
            price: pick.1,
            kind: .unit(pieceType: pick.0, unitClass: .standard)
        ))

        let missingRelics = RoguelikeRelic.allCases.filter { !run.relics.contains($0) }
        if let r = missingRelics.randomElement() {
            items.append(ShopItem(
                title: "\(r.icon) \(r.rawValue)",
                subtitle: r.description,
                icon: r.icon,
                price: 105,
                kind: .relic(r)
            ))
        } else {
            items.append(ShopItem(
                title: "🛡️ +1 Заряд Эгиды",
                subtitle: "Доп. спасение от мата в бою.",
                icon: "🛡️",
                price: 85,
                kind: .aegisCharge
            ))
        }

        items.append(ShopItem(
            title: "↩️ +1 Макс. Откат",
            subtitle: "Постоянное право на дополнительный откат.",
            icon: "⏳",
            price: 70,
            kind: .maxUndo
        ))

        shopItems = items
    }

    func buyShopItem(_ item: ShopItem) {
        guard var run = roguelikeRun, !item.sold, run.credits >= item.price else { return }
        run.credits -= item.price
        switch item.kind {
        case .unit(let pt, let cls):
            run.roster.append(RoguelikeUnit(pieceType: pt, unitClass: cls))
        case .relic(let r):
            if !run.relics.contains(r) { run.relics.append(r) }
            if r == .kingAegis { run.aegisCharges += 1 }
        case .maxUndo:
            run.bonusUndos += 1
        case .aegisCharge:
            run.aegisCharges += 1
        }
        if let idx = shopItems.firstIndex(where: { $0.id == item.id }) {
            shopItems[idx].sold = true
        }
        roguelikeRun = run
        saveRoguelikeRun()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
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
        space.startMenuOrbit()
        saveRoguelikeRun()
    }

    func spinRoulette() -> RoulettePrize? {
        guard var run = roguelikeRun, run.credits >= rouletteCost else { return nil }
        run.credits -= rouletteCost
        run.rouletteSpins += 1

        let prize = generateRandomRoulettePrize()
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
            run.credits += 40
        }

        roguelikeRun = run
        saveRoguelikeRun()
        return prize
    }

    func generateRandomRoulettePrize() -> RoulettePrize {
        let r = Int.random(in: 0..<100)
        if r < 28 {
            return makePrize(for: .pawn(.recruit))
        } else if r < 46 {
            return makePrize(for: .pawn(.golden))
        } else if r < 62 {
            return makePrize(for: .pawn(.berserk))
        } else if r < 76 {
            return makePrize(for: .pawn(.guardian))
        } else if r < 86 {
            return makePrize(for: .pawn(.chrono))
        } else if r < 92 {
            return makePrize(for: .pawn(.quantum))
        } else if r < 96 {
            return makePrize(for: .pawn(.nova))
        } else if r < 98 {
            return makePrize(for: .doublePawn(.golden, .berserk))
        } else if r < 99 {
            return makePrize(for: .officer([2, 3].randomElement() ?? 2, .chrono))
        } else {
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
            return RoulettePrize(title: "Эгида + 40 🪙", subtitle: "Редкий артефакт Короля!", icon: "🛡️", color: .green, kind: kind)
        }
    }

    private func generateCosmicEvent() {
        eventOutcomeText = nil
        let events: [CosmicEvent] = [
            CosmicEvent(
                title: "Древний Монолит",
                story: "Среди обломков астероида парит обелиск с гравировкой древних шахматных богов. Он требует жертву или плату.",
                choices: [
                    EventChoice(label: "Пожертвовать 1 пешкой", effectNote: "Случайная Реликвия + 75 🪙 (если есть пешка)", kind: .sacrificePawnForRelicAndGold),
                    EventChoice(label: "Отремонтировать броню", effectNote: "Чинит ВСЕ подбитые фигуры или даёт +35 🪙", kind: .repairAllOrGainGold),
                    EventChoice(label: "Собрать звёздную пыль", effectNote: "+45 🪙 без риска", kind: .gainCreditsSafe)
                ]
            ),
            CosmicEvent(
                title: "Брошенный Челнок",
                story: "Внутри дрейфующей капсулы слышен сигнал стазис-камеры с замороженным отрядом.",
                choices: [
                    EventChoice(label: "Вскрыть криокапсулу", effectNote: "Редкая пешка (Квантовая / Сверхновая / Хроно)", kind: .gambleRarePawn),
                    EventChoice(label: "Перенастроить временной реактор", effectNote: "+1 Макс. Откат навсегда", kind: .gainUndoAndRoyalLeap),
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
                run.credits += 75
                let missing = RoguelikeRelic.allCases.filter { !run.relics.contains($0) }
                if let r = missing.randomElement() {
                    run.relics.append(r)
                    if r == .kingAegis { run.aegisCharges += 1 }
                    eventOutcomeText = "Пешка [\(lost.unitClass.title)] принесена в дар. Получено: \(r.icon) \(r.rawValue) и +75 🪙!"
                } else {
                    run.credits += 60
                    eventOutcomeText = "Пешка принесена в дар. Получено +135 🪙!"
                }
            } else {
                run.credits += 25
                eventOutcomeText = "У тебя нет пешек для жертвы — монолит выдал +25 🪙 жалости."
            }
        case .repairAllOrGainGold:
            let dmgCount = run.roster.filter { $0.isDamaged }.count
            if dmgCount > 0 {
                for i in run.roster.indices { run.roster[i].isDamaged = false }
                eventOutcomeText = "Отремонтировано фигур: \(dmgCount)!"
            } else {
                run.credits += 35
                eventOutcomeText = "Вся армия цела. Найдено +35 🪙."
            }
        case .gambleRarePawn:
            let rareCls: UnitClass = [.quantum, .nova, .chrono, .golden].randomElement() ?? .quantum
            run.roster.append(RoguelikeUnit(pieceType: 1, unitClass: rareCls))
            eventOutcomeText = "Из криокапсулы вышла пешка [\(rareCls.title)]!"
        case .gainCreditsSafe:
            run.credits += 50
            eventOutcomeText = "Корабельный трюм пополнен: +50 🪙."
        case .gainUndoAndRoyalLeap:
            run.bonusUndos += 1
            eventOutcomeText = "Временной реактор синхронизирован: +1 Макс. Откат во всех боях!"
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
            UserDefaults.standard.set(data, forKey: "Vibe_RoguelikeRun")
        }
    }

    private func deleteRoguelikeRun() {
        UserDefaults.standard.removeObject(forKey: "Vibe_RoguelikeRun")
    }

    private func saveRoguelikeMeta() {
        if let data = try? JSONEncoder().encode(roguelikeMeta) {
            UserDefaults.standard.set(data, forKey: "Vibe_RoguelikeMeta")
        }
    }

    private func loadRoguelikeFromDisk() {
        if let data = UserDefaults.standard.data(forKey: "Vibe_RoguelikeMeta"),
           let m = try? JSONDecoder().decode(RoguelikeMeta.self, from: data) {
            roguelikeMeta = m
        }
        if let data = UserDefaults.standard.data(forKey: "Vibe_RoguelikeRun"),
           let r = try? JSONDecoder().decode(RoguelikeRun.self, from: data) {
            roguelikeRun = r
        }
    }

    func onClockTick() {
        guard isClockActive, !isRoguelikeActive, !inMenu, !isPaused, gameResult == nil, pendingPromotion == nil else { return }
        if board.whiteToMove {
            if whiteSeconds > 0 { whiteSeconds -= 1 }
            if whiteSeconds == 0 { endGame(.timeout(loser: .white)) }
        } else {
            if blackSeconds > 0 { blackSeconds -= 1 }
            if blackSeconds == 0 { endGame(.timeout(loser: .black)) }
        }
    }

    func saveToSlot(slotId: String, title: String, silent: Bool = false) {
        let f = DateFormatter()
        f.dateFormat = "dd.MM HH:mm"
        let slot = SaveSlot(id: slotId, title: title, dateString: f.string(from: Date()), board: board,
                            playerSide: playerSide, mode: mode, difficulty: difficulty, timeControl: timeControl,
                            whiteSeconds: whiteSeconds, blackSeconds: blackSeconds, lastMove: lastMove)
        saveSlots.removeAll { $0.id == slotId }
        saveSlots.append(slot)
        persistSlots()
        if !silent { SoundEngine.shared.play("select", enabled: sfxEnabled) }
    }

    func deleteSlot(_ id: String) {
        saveSlots.removeAll { $0.id == id }
        persistSlots()
    }

    private func autoSave() {
        if gameResult != nil || isRoguelikeActive { return }
        saveToSlot(slotId: "auto", title: "Автосейв", silent: true)
    }

    private func persistSlots() {
        if let data = try? JSONEncoder().encode(saveSlots) {
            UserDefaults.standard.set(data, forKey: "Vibe_Slots2")
        }
    }

    private func loadSavesFromDisk() {
        if let data = UserDefaults.standard.data(forKey: "Vibe_Slots2"),
           let s = try? JSONDecoder().decode([SaveSlot].self, from: data) {
            saveSlots = s.filter { $0.board.sq.count == 64 }
        }
    }

    func loadFromSlot(_ slot: SaveSlot) {
        guard slot.board.sq.count == 64 else { return }
        gameToken += 1
        isRoguelikeActive = false
        battleState = nil
        pendingBotMove = nil
        mode = slot.mode
        difficulty = slot.difficulty
        playerSide = slot.playerSide
        timeControl = slot.timeControl
        board = slot.board
        history.removeAll()
        positionCounts = [board.key: 1]
        lastMove = slot.lastMove
        selectedSquare = nil
        legalForSelected = []
        whiteSeconds = slot.whiteSeconds
        blackSeconds = slot.blackSeconds
        isClockActive = (slot.timeControl != .infinite)
        gameResult = nil
        pendingPromotion = nil
        pendingRoguelikePromotion = nil
        isAnimating = false
        isThinking = false
        isPaused = false
        isCheckNow = board.inCheck(white: board.whiteToMove)
        undoCount = 3
        lastMoveNotation = "Партия загружена"
        inMenu = false
        space.setSectorTheme(nil)
        boardCtl.reset(board: board, flipped: shouldFlipCamera)
        applyControlMode()
        space.focus(flipped: shouldFlipCamera)
        refreshHighlights()
        updateStatus()
        SoundEngine.shared.play("select", enabled: sfxEnabled)
        evaluateGameState()
        if gameResult == nil && mode == .vsBot && !isHumanTurn { triggerBotMove() }
    }

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
            reply("Следи за безопасностью короля, развивай фигуры и береги пешки для возвышения.")
        }
    }

    private func reply(_ text: String) {
        chat.append(ChatMessage(sender: "Гроссмейстер AI", text: text))
        SoundEngine.shared.speak(text, enabled: voiceEnabled)
    }

    private func requestAdvice() {
        if inMenu || gameResult != nil || (isRoguelikeActive && roguelikeRun?.phase != .inBattle) {
            reply("Сначала начни бой на доске.")
            return
        }
        if isAdviceThinking { return }
        isAdviceThinking = true
        let snap = board
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ai = ChessAI()
            let mv = ai.bestMove(board: snap, maxDepth: 4, time: 1.5)
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
        arBoardAnchorNode = nil
        boardCtl.root.removeFromParentNode()
        boardCtl.root.position = SCNVector3Zero
        boardCtl.root.eulerAngles = SCNVector3Zero
        space.boardMount.addChildNode(boardCtl.root)
        applyControlMode()
    }

    func attachBoard(to node: SCNNode) {
        boardCtl.root.removeFromParentNode()
        boardCtl.root.position = SCNVector3Zero
        boardCtl.root.eulerAngles = SCNVector3Zero
        node.addChildNode(boardCtl.root)
        boardCtl.setPhysicsEnabled(false, board: board)
    }
}

struct TextureCache {
    static let wood = load("wood_texture")
    static let woodNormal = load("wood_normal")
    static let woodRough = load("wood_rough")
    static let marble = load("marble_texture")
    static let marbleNormal = load("marble_normal")
    static let marbleRough = load("marble_rough")
    static let pieceWhite = load("piece_white")
    static let pieceBlack = load("piece_black")
    static let pieceNormal = load("piece_normal")
    static let pieceRough = load("piece_rough")
    static let mercury = load("mercury_texture")
    static let mercuryNormal = load("mercury_normal")
    static let venus = load("venus_texture")
    static let earth = load("earth_texture")
    static let earthClouds = load("earth_clouds")
    static let mars = load("mars_texture")
    static let marsNormal = load("mars_normal")
    static let moon = load("moon_texture")
    static let moonNormal = load("moon_normal")
    static let jupiter = load("jupiter_texture")
    static let saturn = load("saturn_texture")
    static let saturnRing = load("saturn_ring")
    static let uranus = load("uranus_texture")
    static let uranusRing = load("uranus_ring")
    static let neptune = load("neptune_texture")
    static let pluto = load("pluto_texture")
    static let asteroid = load("asteroid_texture")
    static let asteroidNormal = load("asteroid_normal")
    static let sun = load("sun_texture")
    static let sky = load("sky_nebula")
    static let env = load("env_studio")
    static let glow = load("fx_glow")
    static let glowWarm = load("fx_glow_warm")
    static let dust = load("fx_dust")
    static let spark = load("fx_spark")
    static let streak = load("fx_streak")
    static let burst = load("fx_burst")
    static let beam = load("fx_beam")
    static let halo = load("fx_halo")
    static let haloWarm = load("fx_halo_warm")
    static let blackholeDisk = load("fx_blackhole_disk")
    static let blackholeRing = load("fx_blackhole_ring")
    static let nebulaCyan = load("fx_nebula_cyan")
    static let nebulaPurple = load("fx_nebula_purple")
    static let nebulaGold = load("fx_nebula_gold")
    static let nebulaEmerald = load("fx_nebula_emerald")
    static let nebulaCrimson = load("fx_nebula_crimson")
    static let cometTail = load("fx_comet_tail")
    static let shockwave = load("fx_shockwave")
    static let flareRing = load("fx_flare_ring")
    static let hlCyan = load("hl_tile_cyan")
    static let hlYellow = load("hl_tile_yellow")
    static let hlRed = load("hl_tile_red")
    static let hlHint = load("hl_tile_hint")
    static let hlDot = load("hl_dot_green")
    static let hlRing = load("hl_ring_red")

    private static func load(_ name: String) -> UIImage? {
        if let path = Bundle.main.path(forResource: name, ofType: "png") { return UIImage(contentsOfFile: path) }
        return UIImage(named: name)
    }
}

enum Lathe {
    static func geometry(_ profile: [(Float, Float)], segments: Int = 64) -> SCNGeometry {
        let n = profile.count
        var segN: [(Float, Float)] = []
        var cum = [Float](repeating: 0, count: n)
        for i in 0..<(n - 1) {
            let dr = profile[i + 1].0 - profile[i].0
            let dy = profile[i + 1].1 - profile[i].1
            let len = max(0.0001, (dr * dr + dy * dy).squareRoot())
            segN.append((dy / len, -dr / len))
            cum[i + 1] = cum[i] + len
        }
        let total = max(0.0001, cum[n - 1])
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        for i in 0..<n {
            var nn = segN[min(i, n - 2)]
            if i > 0 && i < n - 1 {
                let a = segN[i - 1]
                let b = segN[i]
                let sx = a.0 + b.0
                let sy = a.1 + b.1
                let l = (sx * sx + sy * sy).squareRoot()
                if l > 0.0001 { nn = (sx / l, sy / l) }
            }
            let r = profile[i].0
            let y = profile[i].1
            let v = CGFloat(cum[i] / total)
            for j in 0...segments {
                let a = Float(j) / Float(segments) * 2 * Float.pi
                let c = cos(a)
                let s = sin(a)
                vertices.append(SCNVector3(r * c, y, r * s))
                normals.append(SCNVector3(nn.0 * c, nn.1, nn.0 * s))
                uvs.append(CGPoint(x: CGFloat(j) / CGFloat(segments), y: v))
            }
        }
        var indices: [Int32] = []
        let cols = segments + 1
        for i in 0..<(n - 1) {
            for j in 0..<segments {
                let a = Int32(i * cols + j)
                let b = Int32((i + 1) * cols + j)
                let c = Int32(i * cols + j + 1)
                let d = Int32((i + 1) * cols + j + 1)
                indices.append(contentsOf: [a, b, c, c, b, d])
            }
        }
        let vs = SCNGeometrySource(vertices: vertices)
        let ns = SCNGeometrySource(normals: normals)
        let ts = SCNGeometrySource(textureCoordinates: uvs)
        let el = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: [vs, ns, ts], elements: [el])
    }
}

enum PieceBuilder {
    private static var templates: [Int: SCNNode] = [:]

    static func height(for code: Int8) -> Float {
        switch abs(Int(code)) {
        case 1: return 0.89
        case 2: return 1.15
        case 3: return 1.35
        case 4: return 1.08
        case 5: return 1.42
        default: return 1.54
        }
    }

    static func node(for code: Int8) -> SCNNode {
        let key = Int(code)
        if let t = templates[key] { return t.clone() }
        let t = build(code)
        templates[key] = t
        return t.clone()
    }

    static let gold: SCNMaterial = {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(red: 1.0, green: 0.78, blue: 0.32, alpha: 1)
        m.metalness.contents = 1.0
        m.roughness.contents = 0.16
        m.clearCoat.contents = 0.85
        m.clearCoatRoughness.contents = 0.04
        m.shaderModifiers = [
            SCNShaderModifierEntryPoint.fragment:
                "#pragma body\nfloat3 n = normalize(_surface.normal);\nfloat3 v = normalize(_surface.view);\nfloat rim = pow(1.0 - saturate(abs(dot(n, v))), 3.2);\nfloat glint = pow(saturate(dot(reflect(-v, n), normalize(float3(-0.2, 0.7, -0.7)))), 18.0);\n_output.color.rgb += float3(1.0, 0.82, 0.38) * (rim * 0.25 + glint * 0.35);\n"
        ]
        return m
    }()

    private static func bodyMaterial(white: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        let tf = SCNMatrix4MakeScale(2, 1.5, 1)
        let tex = white ? TextureCache.pieceWhite : TextureCache.pieceBlack
        if let img = tex {
            m.diffuse.contents = img
            m.diffuse.wrapS = .repeat
            m.diffuse.wrapT = .repeat
            m.diffuse.contentsTransform = tf
        } else {
            m.diffuse.contents = white ? UIColor(red: 0.90, green: 0.86, blue: 0.78, alpha: 1) : UIColor(red: 0.12, green: 0.10, blue: 0.09, alpha: 1)
        }
        if let nm = TextureCache.pieceNormal {
            m.normal.contents = nm
            m.normal.wrapS = .repeat
            m.normal.wrapT = .repeat
            m.normal.contentsTransform = tf
            m.normal.intensity = 0.65
        }
        if let rm = TextureCache.pieceRough {
            m.roughness.contents = rm
            m.roughness.wrapS = .repeat
            m.roughness.wrapT = .repeat
            m.roughness.contentsTransform = tf
        } else {
            m.roughness.contents = white ? 0.18 : 0.11
        }
        m.metalness.contents = white ? 0.02 : 0.24
        m.clearCoat.contents = 1.0
        m.clearCoatRoughness.contents = 0.045
        m.shaderModifiers = [
            SCNShaderModifierEntryPoint.fragment: white
                ? "#pragma body\nfloat3 n = normalize(_surface.normal);\nfloat3 v = normalize(_surface.view);\nfloat fres = pow(1.0 - saturate(abs(dot(n, v))), 3.6);\n_output.color.rgb += float3(1.0, 0.88, 0.68) * fres * 0.10 + float3(0.32, 0.56, 0.96) * fres * 0.08;\n"
                : "#pragma body\nfloat3 n = normalize(_surface.normal);\nfloat3 v = normalize(_surface.view);\nfloat fres = pow(1.0 - saturate(abs(dot(n, v))), 3.2);\n_output.color.rgb += float3(0.95, 0.75, 0.42) * fres * 0.18 + float3(0.35, 0.65, 1.0) * fres * 0.16;\n"
        ]
        return m
    }

    private static func lathe(_ p: [(Float, Float)], _ mat: SCNMaterial) -> SCNNode {
        let g = Lathe.geometry(p)
        g.materials = [mat]
        return SCNNode(geometry: g)
    }

    private static func ring(_ radius: CGFloat, _ pipe: CGFloat, _ y: Float) -> SCNNode {
        let t = SCNTorus(ringRadius: radius, pipeRadius: pipe)
        t.ringSegmentCount = 48
        t.pipeSegmentCount = 10
        t.materials = [gold]
        let n = SCNNode(geometry: t)
        n.position = SCNVector3(0, y, 0)
        return n
    }

    private static func ball(_ r: CGFloat, _ x: Float, _ y: Float, _ z: Float, _ mat: SCNMaterial) -> SCNNode {
        let s = SCNSphere(radius: r)
        s.segmentCount = 24
        s.materials = [mat]
        let n = SCNNode(geometry: s)
        n.position = SCNVector3(x, y, z)
        return n
    }

    private static let pawnProfile: [(Float, Float)] = [
        (0, 0), (0.38, 0), (0.38, 0.04), (0.36, 0.06),
        (0.36, 0.075), (0.32, 0.095), (0.31, 0.12), (0.26, 0.14),
        (0.22, 0.17), (0.155, 0.26), (0.125, 0.38), (0.12, 0.46),
        (0.2, 0.485), (0.215, 0.505), (0.2, 0.525), (0.125, 0.55),
        (0.11, 0.58), (0.15, 0.62), (0.18, 0.68), (0.19, 0.74),
        (0.17, 0.8), (0.12, 0.85), (0.06, 0.875), (0, 0.885)
    ]
    private static let rookProfile: [(Float, Float)] = [
        (0, 0), (0.38, 0), (0.38, 0.04), (0.36, 0.06),
        (0.36, 0.075), (0.32, 0.095), (0.31, 0.12), (0.26, 0.14),
        (0.235, 0.16), (0.21, 0.24), (0.195, 0.4), (0.19, 0.58),
        (0.205, 0.6), (0.27, 0.64), (0.29, 0.665), (0.29, 0.69),
        (0.265, 0.71), (0.265, 0.92), (0.3, 0.93), (0.3, 1),
        (0.235, 1), (0.235, 0.94), (0, 0.94)
    ]
    private static let bishopProfile: [(Float, Float)] = [
        (0, 0), (0.38, 0), (0.38, 0.04), (0.36, 0.06),
        (0.36, 0.075), (0.32, 0.095), (0.31, 0.12), (0.26, 0.14),
        (0.22, 0.17), (0.165, 0.3), (0.125, 0.45), (0.12, 0.58),
        (0.2, 0.605), (0.215, 0.625), (0.2, 0.645), (0.125, 0.67),
        (0.13, 0.7), (0.19, 0.76), (0.22, 0.86), (0.21, 0.96),
        (0.17, 1.06), (0.11, 1.15), (0.07, 1.2), (0.09, 1.225),
        (0.09, 1.255), (0.065, 1.285), (0.03, 1.31), (0, 1.315)
    ]
    private static let queenProfile: [(Float, Float)] = [
        (0, 0), (0.38, 0), (0.38, 0.04), (0.36, 0.06),
        (0.36, 0.075), (0.32, 0.095), (0.31, 0.12), (0.26, 0.14),
        (0.23, 0.18), (0.17, 0.32), (0.135, 0.5), (0.125, 0.68),
        (0.21, 0.7), (0.225, 0.73), (0.205, 0.76), (0.135, 0.79),
        (0.17, 0.86), (0.22, 0.96), (0.265, 1.06), (0.29, 1.15),
        (0.3, 1.2), (0.26, 1.22), (0.2, 1.2), (0.12, 1.17),
        (0, 1.17)
    ]
    private static let kingProfile: [(Float, Float)] = [
        (0, 0), (0.38, 0), (0.38, 0.04), (0.36, 0.06),
        (0.36, 0.075), (0.32, 0.095), (0.31, 0.12), (0.26, 0.14),
        (0.23, 0.18), (0.175, 0.32), (0.14, 0.52), (0.13, 0.72),
        (0.22, 0.745), (0.235, 0.775), (0.215, 0.805), (0.14, 0.835),
        (0.185, 0.92), (0.235, 1.03), (0.265, 1.13), (0.275, 1.21),
        (0.235, 1.235), (0.15, 1.22), (0.07, 1.2), (0, 1.2)
    ]
    private static let knightProfile: [(Float, Float)] = [
        (0, 0), (0.38, 0), (0.38, 0.04), (0.36, 0.06),
        (0.36, 0.075), (0.32, 0.095), (0.31, 0.12), (0.26, 0.14),
        (0.235, 0.17), (0.205, 0.24), (0.19, 0.32), (0, 0.34)
    ]

    private static let knightHeadPts: [(CGFloat, CGFloat)] = [
        (-0.0438, 0), (0.0237, 0), (0.0827, 0.0028), (0.133, 0.0084),
        (0.1747, 0.0169), (0.2078, 0.0281), (0.2323, 0.0422), (0.2483, 0.0591),
        (0.2556, 0.0788), (0.2544, 0.1013), (0.252, 0.1244), (0.2486, 0.1481),
        (0.2441, 0.1725), (0.2384, 0.1975), (0.2317, 0.2231), (0.2239, 0.2494),
        (0.215, 0.2763), (0.205, 0.3038), (0.1983, 0.3294), (0.1948, 0.3531),
        (0.1947, 0.375), (0.1978, 0.395), (0.2042, 0.4131), (0.2139, 0.4294),
        (0.2269, 0.4437), (0.2431, 0.4562), (0.2605, 0.467), (0.2789, 0.4761),
        (0.2984, 0.4834), (0.3191, 0.4891), (0.3408, 0.493), (0.3636, 0.4952),
        (0.3875, 0.4956), (0.4125, 0.4944), (0.4355, 0.495), (0.4564, 0.4975),
        (0.4753, 0.5019), (0.4922, 0.5081), (0.507, 0.5162), (0.5198, 0.5262),
        (0.5306, 0.5381), (0.5394, 0.5519), (0.5458, 0.5656), (0.5498, 0.5794),
        (0.5516, 0.5931), (0.5509, 0.6069), (0.548, 0.6206), (0.5427, 0.6344),
        (0.535, 0.6481), (0.525, 0.6619), (0.5134, 0.6762), (0.5003, 0.6912),
        (0.4856, 0.7069), (0.4694, 0.7231), (0.4516, 0.74), (0.4322, 0.7575),
        (0.4113, 0.7756), (0.3888, 0.7944), (0.3675, 0.8125), (0.3475, 0.83),
        (0.3287, 0.8469), (0.3112, 0.8631), (0.295, 0.8787), (0.28, 0.8937),
        (0.2662, 0.9081), (0.2537, 0.9219), (0.2423, 0.9367), (0.232, 0.9527),
        (0.2228, 0.9697), (0.2147, 0.9878), (0.2077, 1.007), (0.2017, 1.0273),
        (0.1969, 1.0488), (0.1931, 1.0713), (0.1884, 1.0888), (0.1828, 1.1012),
        (0.1763, 1.1087), (0.1688, 1.1112), (0.1603, 1.1087), (0.1509, 1.1012),
        (0.1406, 1.0887), (0.1294, 1.0713), (0.1178, 1.0578), (0.1059, 1.0484),
        (0.0938, 1.0431), (0.0812, 1.0419), (0.0684, 1.0447), (0.0553, 1.0516),
        (0.0419, 1.0625), (0.0281, 1.0775), (0.0142, 1.0881), (0.0002, 1.0944),
        (-0.0141, 1.0962), (-0.0284, 1.0937), (-0.043, 1.0869), (-0.0577, 1.0756),
        (-0.0725, 1.06), (-0.0875, 1.04), (-0.1023, 1.0183), (-0.117, 0.9948),
        (-0.1316, 0.9697), (-0.1459, 0.9428), (-0.1602, 0.9142), (-0.1742, 0.8839),
        (-0.1881, 0.8519), (-0.2019, 0.8181), (-0.2152, 0.7833), (-0.228, 0.7473),
        (-0.2403, 0.7103), (-0.2522, 0.6722), (-0.2636, 0.633), (-0.2745, 0.5927),
        (-0.285, 0.5512), (-0.295, 0.5087), (-0.303, 0.4659), (-0.3089, 0.4228),
        (-0.3128, 0.3794), (-0.3147, 0.3356), (-0.3145, 0.2916), (-0.3123, 0.2472),
        (-0.3081, 0.2025), (-0.3019, 0.1575), (-0.288, 0.1181), (-0.2664, 0.0844),
        (-0.2372, 0.0563), (-0.2003, 0.0338), (-0.1558, 0.0169), (-0.1036, 0.0056)
    ]

    private static func knightHead(_ mat: SCNMaterial, white: Bool) -> SCNNode {
        let s: CGFloat = 0.72
        let p = UIBezierPath()
        for (i, pt) in knightHeadPts.enumerated() {
            let q = CGPoint(x: pt.0 * s, y: 0.34 + pt.1 * s)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.close()
        p.flatness = 0.05
        let shape = SCNShape(path: p, extrusionDepth: 0.30)
        shape.chamferRadius = 0.04
        shape.materials = [mat]
        let node = SCNNode(geometry: shape)
        let bb = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation(0, 0, (bb.min.z + bb.max.z) / 2)

        let holder = SCNNode()
        holder.addChildNode(node)
        let eyeMat = white ? bodyMaterial(white: false) : gold
        let ex = Float(0.33 * s)
        let ey = Float(0.34 + 0.68 * s)
        for z in [Float(-0.15), Float(0.15)] {
            holder.addChildNode(ball(0.032, ex, ey, z, eyeMat))
        }
        return holder
    }

    private static func build(_ code: Int8) -> SCNNode {
        let type = abs(Int(code))
        let white = code > 0
        let mat = bodyMaterial(white: white)
        let root = SCNNode()

        switch type {
        case 1:
            root.addChildNode(lathe(pawnProfile, mat))
            root.addChildNode(ring(0.214, 0.011, 0.505))
        case 2:
            root.addChildNode(lathe(knightProfile, mat))
            let head = knightHead(mat, white: white)
            head.eulerAngles.y = white ? Float.pi / 2 : -Float.pi / 2
            root.addChildNode(head)
            root.addChildNode(ring(0.192, 0.011, 0.32))
        case 3:
            root.addChildNode(lathe(bishopProfile, mat))
            root.addChildNode(ring(0.215, 0.011, 0.625))
            root.addChildNode(ring(0.128, 0.009, 0.69))
            root.addChildNode(ball(0.04, 0, 1.335, 0, gold))
        case 4:
            root.addChildNode(lathe(rookProfile, mat))
            root.addChildNode(ring(0.29, 0.012, 0.677))
            for k in 0..<8 {
                let a = Float(k) * Float.pi / 4
                let b = SCNBox(width: 0.06, height: 0.09, length: 0.10, chamferRadius: 0.008)
                b.materials = [mat]
                let bn = SCNNode(geometry: b)
                bn.position = SCNVector3(0.2675 * cos(a), 1.045, 0.2675 * sin(a))
                bn.eulerAngles.y = -a
                root.addChildNode(bn)
            }
        case 5:
            root.addChildNode(lathe(queenProfile, mat))
            root.addChildNode(ring(0.225, 0.012, 0.73))
            root.addChildNode(ring(0.292, 0.011, 1.19))
            root.addChildNode(ball(0.06, 0, 1.225, 0, gold))
            for k in 0..<9 {
                let a = Float(k) * 2 * Float.pi / 9
                let c = SCNCone(topRadius: 0, bottomRadius: 0.034, height: 0.16)
                c.materials = [mat]
                let cn = SCNNode(geometry: c)
                cn.position = SCNVector3(0.27 * cos(a), 1.29, 0.27 * sin(a))
                root.addChildNode(cn)
                root.addChildNode(ball(0.026, 0.27 * cos(a), 1.38, 0.27 * sin(a), gold))
            }
        default:
            root.addChildNode(lathe(kingProfile, mat))
            root.addChildNode(ring(0.235, 0.012, 0.775))
            root.addChildNode(ring(0.27, 0.011, 1.205))
            root.addChildNode(ball(0.055, 0, 1.235, 0, gold))
            let v = SCNBox(width: 0.075, height: 0.26, length: 0.075, chamferRadius: 0.015)
            v.materials = [gold]
            let vn = SCNNode(geometry: v)
            vn.position = SCNVector3(0, 1.40, 0)
            root.addChildNode(vn)
            let h = SCNBox(width: 0.21, height: 0.06, length: 0.075, chamferRadius: 0.015)
            h.materials = [gold]
            let hn = SCNNode(geometry: h)
            hn.position = SCNVector3(0, 1.46, 0)
            root.addChildNode(hn)
        }
        root.addChildNode(ring(0.362, 0.013, 0.068))
        return root.flattenedClone()
    }
}

final class BoardController {
    let root = SCNNode()
    private let squaresNode = SCNNode()
    private let piecesNode = SCNNode()
    private let labelsNode = SCNNode()
    private let fxNode = SCNNode()
    private let colliderNode = SCNNode()
    private var overlays: [SCNNode] = []
    private var overlayMats: [SCNMaterial] = []
    private var pieceNodes: [Int: SCNNode] = [:]
    private var labelContainers: [SCNNode] = []
    private var liftedSquare: Int? = nil
    private var animationToken = 0
    private var physicsActive = false
    private let restY: Float = 0.075

    private let dragLock = NSLock()
    private var draggedNode: SCNNode? = nil
    private var dragTargetLocal = SCNVector3Zero

    init() {
        root.addChildNode(squaresNode)
        root.addChildNode(piecesNode)
        root.addChildNode(labelsNode)
        root.addChildNode(fxNode)
        root.addChildNode(colliderNode)
        buildSquares()
        buildFrame()
        buildLabels()
    }

    func pos(_ s: Int) -> SCNVector3 {
        return SCNVector3(Float(s & 7) - 3.5, restY, 3.5 - Float(s >> 3))
    }

    static func squareIndex(from node: SCNNode) -> Int? {
        var cur: SCNNode? = node
        while let n = cur {
            if let name = n.name, name.hasPrefix("pc_") || name.hasPrefix("sq_") {
                return Int(name.dropFirst(3))
            }
            cur = n.parent
        }
        return nil
    }

    private func applyMap(_ prop: SCNMaterialProperty, _ image: UIImage?, _ transform: SCNMatrix4) {
        guard let img = image else { return }
        prop.contents = img
        prop.wrapS = .repeat
        prop.wrapT = .repeat
        prop.contentsTransform = transform
    }

    private func buildSquares() {
        let fresnelShader = "#pragma body\nfloat3 n = normalize(_surface.normal);\nfloat3 v = normalize(_surface.view);\nfloat fres = pow(1.0 - saturate(abs(dot(n, v))), 4.4);\n_output.color.rgb += float3(0.45, 0.65, 1.0) * fres * 0.07;\n"
        for s in 0..<64 {
            let c = s & 7
            let r = s >> 3
            let dark = (r + c) % 2 == 0
            let box = SCNBox(width: 1.0, height: 0.15, length: 1.0, chamferRadius: 0.012)
            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased
            let ox = Float((s * 53) % 16) / 16.0
            let oy = Float((s * 29 + 7) % 16) / 16.0
            let tf = SCNMatrix4Mult(SCNMatrix4MakeScale(0.5, 0.5, 1), SCNMatrix4MakeTranslation(ox, oy, 0))
            if dark {
                if TextureCache.wood != nil {
                    applyMap(mat.diffuse, TextureCache.wood, tf)
                    applyMap(mat.normal, TextureCache.woodNormal, tf)
                    applyMap(mat.roughness, TextureCache.woodRough, tf)
                } else {
                    mat.diffuse.contents = UIColor(red: 0.35, green: 0.20, blue: 0.10, alpha: 1)
                    mat.roughness.contents = 0.40
                }
                mat.clearCoat.contents = 0.58
                mat.clearCoatRoughness.contents = 0.10
            } else {
                if TextureCache.marble != nil {
                    applyMap(mat.diffuse, TextureCache.marble, tf)
                    applyMap(mat.normal, TextureCache.marbleNormal, tf)
                    applyMap(mat.roughness, TextureCache.marbleRough, tf)
                } else {
                    mat.diffuse.contents = UIColor(red: 0.88, green: 0.85, blue: 0.78, alpha: 1)
                    mat.roughness.contents = 0.22
                }
                mat.clearCoat.contents = 0.94
                mat.clearCoatRoughness.contents = 0.035
            }
            mat.metalness.contents = 0.0
            mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: fresnelShader]
            box.materials = [mat]
            let node = SCNNode(geometry: box)
            node.name = "sq_\(s)"
            node.position = SCNVector3(Float(c) - 3.5, 0, 3.5 - Float(r))
            squaresNode.addChildNode(node)

            let plane = SCNPlane(width: 0.96, height: 0.96)
            let om = SCNMaterial()
            om.lightingModel = .constant
            om.diffuse.contents = UIColor.green
            om.isDoubleSided = true
            om.writesToDepthBuffer = false
            plane.materials = [om]
            let on = SCNNode(geometry: plane)
            on.name = "sq_\(s)"
            on.eulerAngles.x = -Float.pi / 2
            on.position = SCNVector3(Float(c) - 3.5, 0.083, 3.5 - Float(r))
            on.renderingOrder = 10
            on.castsShadow = false
            on.isHidden = true
            squaresNode.addChildNode(on)
            overlays.append(on)
            overlayMats.append(om)
        }
    }

    private func buildFrame() {
        let fm = SCNMaterial()
        fm.lightingModel = .physicallyBased
        let tf = SCNMatrix4MakeScale(2.5, 0.5, 1)
        if TextureCache.wood != nil {
            applyMap(fm.diffuse, TextureCache.wood, tf)
            applyMap(fm.normal, TextureCache.woodNormal, tf)
            applyMap(fm.roughness, TextureCache.woodRough, tf)
            fm.multiply.contents = UIColor(red: 0.62, green: 0.46, blue: 0.36, alpha: 1)
        } else {
            fm.diffuse.contents = UIColor(red: 0.22, green: 0.13, blue: 0.08, alpha: 1)
            fm.roughness.contents = 0.4
        }
        fm.metalness.contents = 0.0
        fm.clearCoat.contents = 0.62
        fm.clearCoatRoughness.contents = 0.09
        let strips: [(CGFloat, CGFloat, Float, Float)] = [
            (9.9, 0.95, 0, 4.475), (9.9, 0.95, 0, -4.475), (0.95, 8.0, 4.475, 0), (0.95, 8.0, -4.475, 0)
        ]
        for (w, l, x, z) in strips {
            let b = SCNBox(width: w, height: 0.3, length: l, chamferRadius: 0.04)
            b.materials = [fm]
            let n = SCNNode(geometry: b)
            n.position = SCNVector3(x, restY - 0.15, z)
            root.addChildNode(n)
        }
        let slab = SCNBox(width: 10.5, height: 0.25, length: 10.5, chamferRadius: 0.06)
        slab.materials = [fm]
        let sn = SCNNode(geometry: slab)
        sn.position = SCNVector3(0, -0.35, 0)
        root.addChildNode(sn)

        let inlay: [(CGFloat, CGFloat, Float, Float)] = [
            (8.14, 0.05, 0, 4.045), (8.14, 0.05, 0, -4.045), (0.05, 8.14, 4.045, 0), (0.05, 8.14, -4.045, 0),
            (9.78, 0.04, 0, 4.88), (9.78, 0.04, 0, -4.88), (0.04, 9.78, 4.88, 0), (0.04, 9.78, -4.88, 0)
        ]
        for (w, l, x, z) in inlay {
            let b = SCNBox(width: w, height: 0.03, length: l, chamferRadius: 0.008)
            b.materials = [PieceBuilder.gold]
            let n = SCNNode(geometry: b)
            n.position = SCNVector3(x, restY + 0.002, z)
            n.castsShadow = false
            root.addChildNode(n)
        }
    }

    private func buildLabels() {
        let files = ["A", "B", "C", "D", "E", "F", "G", "H"]
        for c in 0..<8 {
            addLabel(files[c], x: Float(c) - 3.5, z: 4.45)
            addLabel(files[c], x: Float(c) - 3.5, z: -4.45)
        }
        for r in 0..<8 {
            addLabel(String(r + 1), x: 4.45, z: 3.5 - Float(r))
            addLabel(String(r + 1), x: -4.45, z: 3.5 - Float(r))
        }
    }

    private func addLabel(_ text: String, x: Float, z: Float) {
        let container = SCNNode()
        container.position = SCNVector3(x, 0.092, z)
        let plane = SCNPlane(width: 0.5, height: 0.5)
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = BoardController.labelImage(text)
        m.isDoubleSided = true
        plane.materials = [m]
        let pn = SCNNode(geometry: plane)
        pn.eulerAngles.x = -Float.pi / 2
        pn.castsShadow = false
        container.addChildNode(pn)
        labelsNode.addChildNode(container)
        labelContainers.append(container)
    }

    static func labelImage(_ text: String) -> UIImage {
        let size = CGSize(width: 128, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 88, weight: .bold),
                .foregroundColor: UIColor(red: 1.0, green: 0.86, blue: 0.52, alpha: 1.0),
                .paragraphStyle: style
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let h = str.size().height
            str.draw(in: CGRect(x: 0, y: (size.height - h) / 2, width: size.width, height: h))
        }
    }

    func setPhysicsEnabled(_ enabled: Bool, board: ChessBoard) {
        physicsActive = enabled
        endDrag(releaseVelocity: SCNVector3Zero)
        if enabled {
            colliderNode.position = SCNVector3(0, -0.125, 0)
            let box = SCNBox(width: 10.3, height: 0.4, length: 10.3, chamferRadius: 0)
            let body = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
            body.friction = 0.72
            body.restitution = 0.2
            body.categoryBitMask = 1
            body.collisionBitMask = 2
            body.contactTestBitMask = 0
            colliderNode.physicsBody = body
        } else {
            colliderNode.physicsBody = nil
        }
        rebuild(from: board)
    }

    private func attachPhysics(to node: SCNNode, code: Int8) {
        let h = PieceBuilder.height(for: code)
        let cyl = SCNCylinder(radius: 0.33, height: CGFloat(h))
        let cylShape = SCNPhysicsShape(geometry: cyl, options: nil)
        let offset = SCNMatrix4MakeTranslation(0, h * 0.5, 0)
        let shape = SCNPhysicsShape(shapes: [cylShape], transforms: [NSValue(scnMatrix4: offset)])
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)
        body.mass = 1.25
        body.centerOfMassOffset = SCNVector3(0, h * 0.28, 0)
        body.friction = 0.72
        body.rollingFriction = 0.22
        body.restitution = 0.22
        body.damping = 0.16
        body.angularDamping = 0.26
        body.categoryBitMask = 2
        body.collisionBitMask = 1 | 2
        body.contactTestBitMask = 2
        node.physicsBody = body
    }

    func beginDrag(square s: Int, atLocal: SCNVector3) -> Bool {
        guard physicsActive, let node = pieceNodes[s], let body = node.physicsBody else { return false }
        dragLock.lock()
        draggedNode = node
        dragTargetLocal = SCNVector3(atLocal.x, restY + 0.50, atLocal.z)
        dragLock.unlock()
        body.isAffectedByGravity = false
        body.angularVelocityFactor = SCNVector3(0.25, 0.25, 0.25)
        body.clearAllForces()
        return true
    }

    func updateDrag(toLocal: SCNVector3) {
        dragLock.lock()
        dragTargetLocal = SCNVector3(toLocal.x, restY + 0.50, toLocal.z)
        dragLock.unlock()
    }

    func endDrag(releaseVelocity: SCNVector3) {
        dragLock.lock()
        let node = draggedNode
        draggedNode = nil
        dragLock.unlock()
        guard let n = node, let body = n.physicsBody else { return }
        body.isAffectedByGravity = true
        body.angularVelocityFactor = SCNVector3(1, 1, 1)
        let vx = min(14, max(-14, releaseVelocity.x))
        let vy = min(6, max(-6, releaseVelocity.y))
        let vz = min(14, max(-14, releaseVelocity.z))
        body.velocity = SCNVector3(vx, vy, vz)
    }

    func updateDraggedPiecePhysics() {
        dragLock.lock()
        let node = draggedNode
        let targetLocal = dragTargetLocal
        dragLock.unlock()
        guard let n = node, let body = n.physicsBody else { return }
        let targetWorld = root.convertPosition(targetLocal, to: nil)
        let curWorld = n.presentation.worldPosition
        let dx = targetWorld.x - curWorld.x
        let dy = targetWorld.y - curWorld.y
        let dz = targetWorld.z - curWorld.z
        let vx = min(22, max(-22, dx * 18.0))
        let vy = min(22, max(-22, dy * 18.0))
        let vz = min(22, max(-22, dz * 18.0))
        body.velocity = SCNVector3(vx, vy, vz)
        let e = n.presentation.eulerAngles
        let len = (e.x * e.x + e.z * e.z).squareRoot()
        if len > 0.02 {
            body.angularVelocity = SCNVector4(-e.x / len, 0, -e.z / len, len * 8.0)
        } else {
            body.angularVelocity = SCNVector4(0, 1, 0, 0)
        }
    }

    func topplePiece(at square: Int, viewDir: SCNVector3) {
        guard physicsActive, let n = pieceNodes[square], let body = n.physicsBody else { return }
        let len = max(0.001, (viewDir.x * viewDir.x + viewDir.z * viewDir.z).squareRoot())
        let dx = viewDir.x / len
        let dz = viewDir.z / len
        body.applyForce(SCNVector3(dx * 7.5, 2.2, dz * 7.5), at: SCNVector3(0, 0.85, 0), asImpulse: true)
        body.applyTorque(SCNVector4(dz, 0.35, -dx, 3.2), asImpulse: true)
    }

    func setFlipped(_ flipped: Bool) {
        let a: Float = flipped ? Float.pi : 0
        for c in labelContainers { c.eulerAngles.y = a }
    }

    func reset(board: ChessBoard, flipped: Bool) {
        animationToken += 1
        endDrag(releaseVelocity: SCNVector3Zero)
        for child in fxNode.childNodes { child.removeFromParentNode() }
        setFlipped(flipped)
        rebuild(from: board)
    }

    private func addClassAura(to node: SCNNode, unitClass: UnitClass) {
        guard let color = unitClass.uiColor else { return }
        let torus = SCNTorus(ringRadius: 0.42, pipeRadius: 0.022)
        torus.ringSegmentCount = 36
        torus.pipeSegmentCount = 8
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = color
        mat.blendMode = .add
        mat.writesToDepthBuffer = false
        torus.materials = [mat]
        let ringNode = SCNNode(geometry: torus)
        ringNode.position = SCNVector3(0, 0.025, 0)
        ringNode.castsShadow = false
        ringNode.renderingOrder = 12
        node.addChildNode(ringNode)
    }

    private func rebuild(from board: ChessBoard) {
        endDrag(releaseVelocity: SCNVector3Zero)
        for n in piecesNode.childNodes where n.name != "fly" { n.removeFromParentNode() }
        pieceNodes.removeAll()
        liftedSquare = nil
        let hasClasses = board.isRoguelike && board.classes.count == 64
        for s in 0..<64 {
            let code = board.sq[s]
            if code == 0 { continue }
            let n = PieceBuilder.node(for: code)
            n.name = "pc_\(s)"
            n.position = pos(s)
            if hasClasses && code > 0 {
                addClassAura(to: n, unitClass: board.classes[s])
            }
            if physicsActive { attachPhysics(to: n, code: code) }
            piecesNode.addChildNode(n)
            pieceNodes[s] = n
        }
    }

    func setHighlights(selected: Int?, targets: [Int: Bool], last: Move?, check: Int?) {
        for o in overlays { o.isHidden = true }
        func show(_ s: Int, _ img: UIImage?, _ fallback: UIColor) {
            if s < 0 || s >= 64 { return }
            overlays[s].isHidden = false
            if let i = img {
                overlayMats[s].diffuse.contents = i
                overlayMats[s].transparency = 1.0
            } else {
                overlayMats[s].diffuse.contents = fallback
                overlayMats[s].transparency = 0.5
            }
        }
        if let l = last {
            show(l.from, TextureCache.hlYellow, UIColor.yellow)
            show(l.to, TextureCache.hlYellow, UIColor.yellow)
        }
        if let s = selected { show(s, TextureCache.hlCyan, UIColor.cyan) }
        for (s, isCapture) in targets {
            if isCapture {
                show(s, TextureCache.hlRing, UIColor.systemRed)
            } else {
                show(s, TextureCache.hlDot, UIColor.systemGreen)
            }
        }
        if let c = check { show(c, TextureCache.hlRed, UIColor.red) }
    }

    func setLift(_ s: Int?) {
        if physicsActive { liftedSquare = nil; return }
        if let old = liftedSquare, old != s, let n = pieceNodes[old] {
            n.removeAllActions()
            n.runAction(SCNAction.move(to: pos(old), duration: 0.12))
        }
        if let s = s, liftedSquare != s, let n = pieceNodes[s] {
            n.removeAllActions()
            let p = pos(s)
            n.runAction(SCNAction.move(to: SCNVector3(p.x, restY + 0.3, p.z), duration: 0.12))
        }
        liftedSquare = s
    }

    func obliterateWithBlackHole(at square: Int) {
        spawnBlackHole(at: square)
        guard let cap = pieceNodes[square] else { return }
        pieceNodes[square] = nil
        cap.name = "fly"
        cap.physicsBody = nil
        cap.removeAllActions()
        let startPos = pos(square)
        let baseRestY = self.restY
        let spaghettify = SCNAction.customAction(duration: 0.52) { node, elapsed in
            let u = Float(elapsed / 0.52)
            let accel = u * u
            let spin = accel * 16.0
            let radius = 0.09 * (1.0 - u) * sin(u * Float.pi)
            let sx = max(0.02, 1.0 - 0.94 * pow(u, 1.15))
            let sy = 1.0 + 2.35 * sin(u * Float.pi * 0.78) - 1.15 * accel
            node.scale = SCNVector3(sx, max(0.03, sy), sx)
            node.eulerAngles = SCNVector3(0.32 * u, spin, 0.22 * u)
            node.position = SCNVector3(
                startPos.x + radius * cos(spin),
                baseRestY + 0.12 - 1.08 * accel,
                startPos.z + radius * sin(spin)
            )
            node.opacity = CGFloat(max(0.0, 1.0 - pow(u, 2.2)))
        }
        cap.runAction(SCNAction.sequence([spaghettify, SCNAction.removeFromParentNode()]))
    }

    func spawnBlackHole(at square: Int) {
        let p = pos(square)
        let bh = SCNNode()
        bh.position = SCNVector3(p.x, restY + 0.025, p.z)
        bh.scale = SCNVector3(0.01, 0.01, 0.01)
        fxNode.addChildNode(bh)

        let voidSphere = SCNSphere(radius: 0.44)
        voidSphere.segmentCount = 36
        let voidMat = SCNMaterial()
        voidMat.lightingModel = .constant
        voidMat.diffuse.contents = UIColor.black
        voidMat.writesToDepthBuffer = true
        voidMat.shaderModifiers = [
            SCNShaderModifierEntryPoint.fragment:
                "#pragma body\nfloat3 n = normalize(_surface.normal);\nfloat3 v = normalize(_surface.view);\nfloat ndv = saturate(abs(dot(n, v)));\nfloat pulse = 0.88 + 0.18 * sin(scn_frame.time * 9.0);\nfloat photon = pow(1.0 - ndv, 4.2) * pulse;\nfloat innerRim = smoothstep(0.16, 0.0, ndv);\n_output.color.rgb = float3(1.0, 0.72, 0.30) * photon * 2.8 + float3(0.85, 0.55, 1.0) * innerRim * 1.6;\n"
        ]
        voidSphere.materials = [voidMat]
        let voidNode = SCNNode(geometry: voidSphere)
        voidNode.scale = SCNVector3(1.0, 0.56, 1.0)
        voidNode.position = SCNVector3(0, -0.01, 0)
        voidNode.renderingOrder = 15
        voidNode.castsShadow = false
        bh.addChildNode(voidNode)

        let lensPlane = SCNPlane(width: 1.55, height: 1.55)
        let lensMat = SCNMaterial()
        lensMat.lightingModel = .constant
        lensMat.diffuse.contents = TextureCache.blackholeRing ?? UIColor(red: 1.0, green: 0.75, blue: 0.4, alpha: 1)
        lensMat.blendMode = .add
        lensMat.writesToDepthBuffer = false
        lensMat.isDoubleSided = true
        lensPlane.materials = [lensMat]
        let lensNode = SCNNode(geometry: lensPlane)
        let bb = SCNBillboardConstraint()
        bb.freeAxes = SCNBillboardAxis.Y
        lensNode.constraints = [bb]
        lensNode.position = SCNVector3(0, 0.06, 0)
        lensNode.renderingOrder = 19
        lensNode.castsShadow = false
        bh.addChildNode(lensNode)

        let funnel = SCNCone(topRadius: 0.56, bottomRadius: 0.02, height: 1.05)
        funnel.radialSegmentCount = 36
        let funnelMat = SCNMaterial()
        funnelMat.lightingModel = .constant
        funnelMat.diffuse.contents = UIColor(red: 0.42, green: 0.16, blue: 0.85, alpha: 0.90)
        funnelMat.blendMode = .add
        funnelMat.writesToDepthBuffer = false
        funnelMat.isDoubleSided = true
        funnel.materials = [funnelMat]
        let funnelNode = SCNNode(geometry: funnel)
        funnelNode.position = SCNVector3(0, -0.53, 0)
        funnelNode.renderingOrder = 14
        funnelNode.castsShadow = false
        funnelNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 9.0, z: 0, duration: 1.0)))
        bh.addChildNode(funnelNode)

        let diskPlane = SCNPlane(width: 2.05, height: 2.05)
        let diskMat = SCNMaterial()
        diskMat.lightingModel = .constant
        diskMat.diffuse.contents = TextureCache.blackholeDisk ?? UIColor.orange
        diskMat.blendMode = .add
        diskMat.writesToDepthBuffer = false
        diskMat.isDoubleSided = true
        diskMat.shaderModifiers = [
            SCNShaderModifierEntryPoint.fragment:
                "#pragma body\nfloat2 uv = _surface.diffuseTexcoord;\nfloat ripple = 0.88 + 0.22 * sin(length(uv - float2(0.5)) * 28.0 - scn_frame.time * 10.0);\n_output.color.rgb *= ripple;\n"
        ]
        diskPlane.materials = [diskMat]
        let diskNode = SCNNode(geometry: diskPlane)
        diskNode.eulerAngles.x = -Float.pi / 2
        diskNode.position = SCNVector3(0, 0.015, 0)
        diskNode.renderingOrder = 18
        diskNode.castsShadow = false
        diskNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0, z: 10.5, duration: 1.0)))
        bh.addChildNode(diskNode)

        let innerRing = SCNNode(geometry: lensPlane)
        innerRing.eulerAngles = SCNVector3(-Float.pi / 2 + 0.25, 0, 0)
        innerRing.scale = SCNVector3(0.95, 0.95, 0.95)
        innerRing.position = SCNVector3(0, 0.045, 0)
        innerRing.renderingOrder = 20
        innerRing.castsShadow = false
        innerRing.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0, z: -8.0, duration: 1.0)))
        bh.addChildNode(innerRing)

        let underDisk = SCNNode(geometry: diskPlane)
        underDisk.eulerAngles.x = -Float.pi / 2
        underDisk.position = SCNVector3(0, -0.62, 0)
        underDisk.scale = SCNVector3(0.75, 0.75, 0.75)
        underDisk.renderingOrder = 16
        underDisk.castsShadow = false
        underDisk.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0, z: -8.5, duration: 1.0)))
        bh.addChildNode(underDisk)

        if let jetImg = TextureCache.beam {
            let jetPlane = SCNPlane(width: 0.24, height: 1.8)
            let jm = SCNMaterial()
            jm.lightingModel = .constant
            jm.diffuse.contents = jetImg
            jm.blendMode = .add
            jm.writesToDepthBuffer = false
            jm.isDoubleSided = true
            jetPlane.materials = [jm]
            let jetUp = SCNNode(geometry: jetPlane)
            jetUp.position = SCNVector3(0, 0.95, 0)
            jetUp.opacity = 0.45
            jetUp.renderingOrder = 17
            jetUp.castsShadow = false
            bh.addChildNode(jetUp)
        }
        if let swImg = TextureCache.shockwave {
            let swPlane = SCNPlane(width: 1.2, height: 1.2)
            let swm = SCNMaterial()
            swm.lightingModel = .constant
            swm.diffuse.contents = swImg
            swm.blendMode = .add
            swm.writesToDepthBuffer = false
            swm.isDoubleSided = true
            swPlane.materials = [swm]
            let sw = SCNNode(geometry: swPlane)
            sw.eulerAngles.x = -Float.pi / 2
            sw.position = SCNVector3(0, 0.02, 0)
            sw.scale = SCNVector3(0.3, 0.3, 0.3)
            sw.renderingOrder = 17
            sw.castsShadow = false
            bh.addChildNode(sw)
            sw.runAction(SCNAction.group([SCNAction.scale(to: 1.9, duration: 0.45), SCNAction.fadeOut(duration: 0.45)]))
        }
        if let glowImg = TextureCache.glowWarm {
            let gPlane = SCNPlane(width: 2.1, height: 2.1)
            let gMat = SCNMaterial()
            gMat.lightingModel = .constant
            gMat.diffuse.contents = glowImg
            gMat.blendMode = .add
            gMat.writesToDepthBuffer = false
            gMat.isDoubleSided = true
            gPlane.materials = [gMat]
            let gNode = SCNNode(geometry: gPlane)
            gNode.eulerAngles.x = -Float.pi / 2
            gNode.position = SCNVector3(0, 0.008, 0)
            gNode.opacity = 0.85
            gNode.renderingOrder = 17
            gNode.castsShadow = false
            bh.addChildNode(gNode)
        }

        let ps = SCNParticleSystem()
        ps.loops = false
        ps.emissionDuration = 0.62
        ps.birthRate = 340
        ps.particleLifeSpan = 0.44
        ps.particleLifeSpanVariation = 0.14
        ps.emitterShape = SCNTorus(ringRadius: 0.82, pipeRadius: 0.10)
        ps.birthLocation = .surface
        ps.birthDirection = .surfaceNormal
        ps.particleVelocity = -1.95
        ps.particleVelocityVariation = 0.65
        ps.acceleration = SCNVector3(0, -2.2, 0)
        ps.particleSize = 0.055
        ps.particleSizeVariation = 0.03
        ps.particleColor = UIColor(red: 1.0, green: 0.72, blue: 0.32, alpha: 1)
        ps.particleColorVariation = SCNVector4(0.18, 0.25, 0.30, 0)
        ps.blendMode = .additive
        ps.isLightingEnabled = false
        if let img = TextureCache.spark { ps.particleImage = img }
        let psHolder = SCNNode()
        psHolder.position = SCNVector3(0, 0.20, 0)
        psHolder.addParticleSystem(ps)
        psHolder.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 12.0, z: 0, duration: 1.0)))
        bh.addChildNode(psHolder)

        let open = SCNAction.scale(to: 1.0, duration: 0.16)
        open.timingMode = .easeOut
        let hold = SCNAction.wait(duration: 0.56)
        let collapse = SCNAction.group([
            SCNAction.scale(to: 0.01, duration: 0.24),
            SCNAction.fadeOut(duration: 0.24)
        ])
        collapse.timingMode = .easeIn
        bh.runAction(SCNAction.sequence([open, hold, collapse, SCNAction.removeFromParentNode()]))
    }

    func burst(at square: Int, color: UIColor, intensity: CGFloat = 1.0, height: Float = 0.45) {
        let ps = SCNParticleSystem()
        ps.loops = false
        ps.emissionDuration = 0.06
        ps.birthRate = 4200 * intensity
        ps.particleLifeSpan = 0.9
        ps.particleLifeSpanVariation = 0.4
        ps.particleVelocity = 3.0
        ps.particleVelocityVariation = 1.8
        ps.birthLocation = .volume
        ps.birthDirection = .random
        ps.emitterShape = SCNSphere(radius: 0.12)
        ps.acceleration = SCNVector3(0, -4.5, 0)
        ps.particleSize = 0.06
        ps.particleSizeVariation = 0.03
        ps.particleColor = color
        ps.blendMode = .additive
        ps.isLightingEnabled = false
        if let img = TextureCache.spark { ps.particleImage = img }
        let n = SCNNode()
        let p = pos(square)
        n.position = SCNVector3(p.x, p.y + height, p.z)
        n.addParticleSystem(ps)
        fxNode.addChildNode(n)
        n.runAction(SCNAction.sequence([SCNAction.wait(duration: 2.2), SCNAction.removeFromParentNode()]))
    }

    func celebrate() {
        let colors: [UIColor] = [
            UIColor(red: 1.0, green: 0.82, blue: 0.35, alpha: 1),
            UIColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 1),
            UIColor(red: 1.0, green: 0.45, blue: 0.75, alpha: 1),
            UIColor(red: 0.5, green: 1.0, blue: 0.6, alpha: 1)
        ]
        for i in 0..<8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.32) { [weak self] in
                guard let self = self else { return }
                self.burst(at: Int.random(in: 0..<64), color: colors[i % colors.count], intensity: 1.4, height: 2.6)
            }
        }
    }

    func animate(move m: Move, before: ChessBoard, after: ChessBoard, completion: @escaping () -> Void) {
        liftedSquare = nil
        endDrag(releaseVelocity: SCNVector3Zero)
        let token = animationToken
        var finished = false
        let finish: () -> Void = { [weak self] in
            if finished { return }
            finished = true
            guard let self = self, self.animationToken == token else { return }
            self.rebuild(from: after)
            completion()
        }

        guard let mover = pieceNodes[m.from] else {
            finish()
            return
        }
        pieceNodes[m.from] = nil
        mover.physicsBody = nil
        mover.removeAllActions()

        var capSq = -1
        if before.sq[m.to] != 0 {
            capSq = m.to
        } else if abs(Int(before.sq[m.from])) == 1 && (m.from & 7) != (m.to & 7) && m.to == before.ep {
            capSq = (m.from >> 3) * 8 + (m.to & 7)
        }
        let hasCapture = capSq >= 0 && pieceNodes[capSq] != nil
        if capSq >= 0, let cap = pieceNodes[capSq] {
            pieceNodes[capSq] = nil
            cap.name = "fly"
            cap.physicsBody = nil
            cap.removeAllActions()
            spawnBlackHole(at: capSq)

            let shroud = SCNNode(geometry: SCNSphere(radius: 0.35))
            let sm = SCNMaterial()
            sm.lightingModel = .constant
            sm.diffuse.contents = UIColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 0.55)
            sm.blendMode = .add
            sm.writesToDepthBuffer = false
            shroud.geometry?.materials = [sm]
            shroud.position = SCNVector3(0, 0.55, 0)
            shroud.opacity = 0
            shroud.castsShadow = false
            cap.addChildNode(shroud)
            shroud.runAction(SCNAction.sequence([SCNAction.wait(duration: 0.10), SCNAction.fadeOpacity(to: 0.85, duration: 0.25)]))

            let startPos = pos(capSq)
            let shockLift = SCNAction.move(to: SCNVector3(startPos.x, restY + 0.16, startPos.z), duration: 0.08)
            shockLift.timingMode = .easeOut
            let baseRestY = self.restY
            let spaghettify = SCNAction.customAction(duration: 0.52) { node, elapsed in
                let u = Float(elapsed / 0.52)
                let accel = u * u
                let spin = accel * 16.0
                let radius = 0.09 * (1.0 - u) * sin(u * Float.pi)
                let sx = max(0.02, 1.0 - 0.94 * pow(u, 1.15))
                let sy = 1.0 + 2.35 * sin(u * Float.pi * 0.78) - 1.15 * accel
                node.scale = SCNVector3(sx, max(0.03, sy), sx)
                node.eulerAngles = SCNVector3(0.32 * u, spin, 0.22 * u)
                node.position = SCNVector3(
                    startPos.x + radius * cos(spin),
                    baseRestY + 0.16 - 1.08 * accel,
                    startPos.z + radius * sin(spin)
                )
                node.opacity = CGFloat(max(0.0, 1.0 - pow(u, 2.2)))
            }
            cap.runAction(SCNAction.sequence([shockLift, spaghettify, SCNAction.removeFromParentNode()]))
        }

        let fromCol = m.from & 7
        let toCol = m.to & 7
        if abs(Int(before.sq[m.from])) == 6 && abs(toCol - fromCol) == 2 {
            let base = (m.from >> 3) * 8
            let rookFrom = base + (toCol == 6 ? 7 : 0)
            let rookTo = base + (toCol == 6 ? 5 : 3)
            if let rook = pieceNodes[rookFrom] {
                pieceNodes[rookFrom] = nil
                rook.physicsBody = nil
                rook.removeAllActions()
                let rp = pos(rookTo)
                let up = SCNAction.move(to: SCNVector3(rook.position.x, restY + 0.5, rook.position.z), duration: 0.12)
                let glide = SCNAction.move(to: SCNVector3(rp.x, restY + 0.5, rp.z), duration: 0.28)
                let down = SCNAction.move(to: rp, duration: 0.12)
                rook.runAction(SCNAction.sequence([up, glide, down]))
            }
        }

        let target = pos(m.to)
        let lift = SCNAction.move(to: SCNVector3(mover.position.x, restY + 0.72, mover.position.z), duration: 0.14)
        let glide = SCNAction.move(to: SCNVector3(target.x, restY + 0.72, target.z), duration: hasCapture ? 0.38 : 0.28)
        let drop = SCNAction.move(to: target, duration: 0.14)
        lift.timingMode = .easeOut
        glide.timingMode = .easeInEaseOut
        drop.timingMode = .easeIn
        let done = SCNAction.run { _ in
            DispatchQueue.main.async { finish() }
        }
        mover.runAction(SCNAction.sequence([lift, glide, drop, done]))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { finish() }
    }
    final class SpaceScene {
    let scene = SCNScene()
    let boardMount = SCNNode()
    let orbit = SCNNode()
    private let pitch = SCNNode()
    private let gyroNode = SCNNode()
    private let camNode = SCNNode()
    private let solarSystem = SCNNode()
    private let boardOrbitPivot = SCNNode()
    private let boardAnchor = SCNNode()
    private let beamsNode = SCNNode()
    private let dustNode = SCNNode()
    private let beltsNode = SCNNode()
    private let nebulaeNode = SCNNode()
    private let skySphereNode = SCNNode()
    private let eventsNode = SCNNode()
    private var backLight: SCNLight? = nil
    private var keyLight: SCNLight? = nil
    private var fillLight: SCNLight? = nil
    private var underLight: SCNLight? = nil
    private var ambientLight: SCNLight? = nil
    private let baseCam = SCNVector3(0, 10.2, 10.4)
    private var zoom: Float = 1.0

    private let motionMgr = CMMotionManager()
    private var gyroEnabled = false
    private var gyroRef: CMAttitude? = nil
    private var lastEventTime: TimeInterval = 0
    private var lastMeteorTime: TimeInterval = 0
    private var currentQuality: GraphicsQuality = .ultra

    init() {
        scene.rootNode.addChildNode(solarSystem)
        scene.physicsWorld.gravity = SCNVector3(0, -14.0, 0)
        solarSystem.addChildNode(eventsNode)
        buildBackground()
        buildNebulae()
        buildStars()
        buildSun()
        buildPlanets()
        buildAsteroidBelt()
        buildKuiperBelt()
        buildComet()
        buildBoardRig()
        buildBeams(from: SCNVector3(0, -8.4, -44))
        buildDust()
        buildCameraAndLights()
        applyQuality(.ultra)
        startBoardFloat()
        startMenuOrbit()
    }

    var cameraNode: SCNNode { camNode }

    func setSectorTheme(_ biome: PlanetBiome?) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.9
        guard let b = biome else {
            fillLight?.color = UIColor(red: 0.55, green: 0.70, blue: 1.0, alpha: 1)
            underLight?.color = UIColor(red: 0.42, green: 0.60, blue: 0.98, alpha: 1)
            ambientLight?.color = UIColor(red: 0.72, green: 0.78, blue: 1.0, alpha: 1)
            backLight?.color = UIColor(red: 1.0, green: 0.85, blue: 0.66, alpha: 1)
            SCNTransaction.commit()
            return
        }
        switch b {
        case .mercury:
            backLight?.color = UIColor(red: 1.0, green: 0.72, blue: 0.36, alpha: 1)
            fillLight?.color = UIColor(red: 1.0, green: 0.58, blue: 0.25, alpha: 1)
            underLight?.color = UIColor(red: 0.85, green: 0.35, blue: 0.15, alpha: 1)
        case .venus:
            backLight?.color = UIColor(red: 1.0, green: 0.90, blue: 0.55, alpha: 1)
            fillLight?.color = UIColor(red: 0.92, green: 0.72, blue: 0.35, alpha: 1)
            underLight?.color = UIColor(red: 0.68, green: 0.45, blue: 0.25, alpha: 1)
        case .earth:
            backLight?.color = UIColor(red: 1.0, green: 0.90, blue: 0.76, alpha: 1)
            fillLight?.color = UIColor(red: 0.40, green: 0.78, blue: 1.0, alpha: 1)
            underLight?.color = UIColor(red: 0.25, green: 0.58, blue: 1.0, alpha: 1)
        case .mars:
            backLight?.color = UIColor(red: 1.0, green: 0.68, blue: 0.45, alpha: 1)
            fillLight?.color = UIColor(red: 1.0, green: 0.42, blue: 0.28, alpha: 1)
            underLight?.color = UIColor(red: 0.75, green: 0.22, blue: 0.15, alpha: 1)
        case .asteroidBelt:
            backLight?.color = UIColor(red: 0.95, green: 0.80, blue: 0.62, alpha: 1)
            fillLight?.color = UIColor(red: 0.72, green: 0.68, blue: 0.64, alpha: 1)
            underLight?.color = UIColor(red: 0.52, green: 0.42, blue: 0.32, alpha: 1)
        case .jupiter:
            backLight?.color = UIColor(red: 1.0, green: 0.78, blue: 0.54, alpha: 1)
            fillLight?.color = UIColor(red: 0.90, green: 0.58, blue: 0.42, alpha: 1)
            underLight?.color = UIColor(red: 0.65, green: 0.35, blue: 0.72, alpha: 1)
        case .saturn:
            backLight?.color = UIColor(red: 1.0, green: 0.88, blue: 0.64, alpha: 1)
            fillLight?.color = UIColor(red: 0.88, green: 0.80, blue: 0.55, alpha: 1)
            underLight?.color = UIColor(red: 0.42, green: 0.75, blue: 0.92, alpha: 1)
        case .uranusNeptune:
            backLight?.color = UIColor(red: 0.78, green: 0.94, blue: 1.0, alpha: 1)
            fillLight?.color = UIColor(red: 0.30, green: 0.88, blue: 1.0, alpha: 1)
            underLight?.color = UIColor(red: 0.18, green: 0.48, blue: 0.96, alpha: 1)
        case .pluto:
            backLight?.color = UIColor(red: 0.86, green: 0.64, blue: 1.0, alpha: 1)
            fillLight?.color = UIColor(red: 0.68, green: 0.34, blue: 0.96, alpha: 1)
            underLight?.color = UIColor(red: 0.45, green: 0.15, blue: 0.78, alpha: 1)
        }
        SCNTransaction.commit()
    }

    private func markSolarBody(_ node: SCNNode) {
        node.categoryBitMask = 2
        for c in node.childNodes { markSolarBody(c) }
    }

    func setGyroEnabled(_ enabled: Bool) {
        gyroEnabled = enabled
        gyroRef = nil
        if enabled {
            if motionMgr.isDeviceMotionAvailable {
                motionMgr.deviceMotionUpdateInterval = 1.0 / 60.0
                motionMgr.startDeviceMotionUpdates()
            }
        } else {
            motionMgr.stopDeviceMotionUpdates()
        }
    }

    func recalibrateGyro() {
        gyroRef = motionMgr.deviceMotion?.attitude.copy() as? CMAttitude
    }

    func updateFrame(atTime time: TimeInterval) {
        if gyroEnabled, let att = motionMgr.deviceMotion?.attitude {
            if gyroRef == nil { gyroRef = att.copy() as? CMAttitude }
            if let ref = gyroRef, let rel = att.copy() as? CMAttitude {
                rel.multiply(byInverseOf: ref)
                let targetPitch = Float(max(-0.26, min(0.26, rel.pitch * 0.45)))
                let targetYaw = Float(max(-0.30, min(0.30, -rel.roll * 0.45)))
                let cur = gyroNode.eulerAngles
                gyroNode.eulerAngles = SCNVector3(
                    cur.x + (targetPitch - cur.x) * 0.12,
                    cur.y + (targetYaw - cur.y) * 0.12,
                    0
                )
            }
        } else {
            let cur = gyroNode.eulerAngles
            if abs(cur.x) > 0.001 || abs(cur.y) > 0.001 {
                gyroNode.eulerAngles = SCNVector3(cur.x * 0.88, cur.y * 0.88, 0)
            }
        }

        if lastEventTime == 0 {
            lastEventTime = time - 3.2
            lastMeteorTime = time - 1.5
        }
        if time - lastEventTime > 4.6 {
            lastEventTime = time
            DispatchQueue.main.async { [weak self] in self?.spawnMeteorCollision() }
        }
        if time - lastMeteorTime > 2.9 {
            lastMeteorTime = time
            DispatchQueue.main.async { [weak self] in self?.spawnShootingStar() }
        }
    }

    func setOrbitalMotionPaused(_ paused: Bool) {
        if paused {
            boardOrbitPivot.removeAction(forKey: "boardOrbit")
            boardMount.removeAction(forKey: "float")
            boardMount.runAction(SCNAction.group([
                SCNAction.move(to: SCNVector3Zero, duration: 0.2),
                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2)
            ]))
        } else {
            if boardOrbitPivot.action(forKey: "boardOrbit") == nil {
                boardOrbitPivot.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat(2 * Float.pi), z: 0, duration: 180)), forKey: "boardOrbit")
            }
            if boardMount.action(forKey: "float") == nil {
                startBoardFloat()
            }
        }
    }

    private func spawnMeteorCollision() {
        let ang = Float.random(in: 0...(2 * Float.pi))
        let r = Float.random(in: 50...88)
        let y = Float.random(in: -4...9)
        let impact = SCNVector3(r * sin(ang), y, r * cos(ang))

        let d1 = SCNVector3(Float.random(in: -16...16), Float.random(in: -6...6), Float.random(in: -16...16))
        let d2 = SCNVector3(-d1.x * 0.92, -d1.y * 0.85, -d1.z * 0.92)

        let rockGeo = asteroidGeometry(seed: Int.random(in: 1...20))
        let m1 = SCNNode(geometry: rockGeo)
        let m2 = SCNNode(geometry: rockGeo)
        m1.scale = SCNVector3(0.55, 0.55, 0.55)
        m2.scale = SCNVector3(0.46, 0.46, 0.46)
        m1.position = SCNVector3(impact.x + d1.x, impact.y + d1.y, impact.z + d1.z)
        m2.position = SCNVector3(impact.x + d2.x, impact.y + d2.y, impact.z + d2.z)
        m1.castsShadow = false
        m2.castsShadow = false
        markSolarBody(m1)
        markSolarBody(m2)
        for m in [m1, m2] {
            if let g = TextureCache.glowWarm {
                let sp = sprite(g, 3.6, 3.6)
                sp.opacity = 0.85
                m.addChildNode(sp)
            }
            let trail = SCNParticleSystem()
            trail.loops = true
            trail.birthRate = 220
            trail.particleLifeSpan = 0.45
            trail.particleSize = 0.28
            trail.particleColor = UIColor(red: 1.0, green: 0.62, blue: 0.22, alpha: 0.95)
            trail.blendMode = .additive
            trail.isLightingEnabled = false
            if let sp = TextureCache.spark { trail.particleImage = sp }
            m.addParticleSystem(trail)
            eventsNode.addChildNode(m)
        }
        m1.runAction(SCNAction.sequence([SCNAction.move(to: impact, duration: 0.85), SCNAction.removeFromParentNode()]))
        m2.runAction(SCNAction.sequence([SCNAction.move(to: impact, duration: 0.85), SCNAction.removeFromParentNode()]))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            guard let self = self else { return }
            let expNode = SCNNode()
            expNode.position = impact
            self.eventsNode.addChildNode(expNode)

            let flash = self.sprite(TextureCache.burst, 13.5, 13.5)
            flash.scale = SCNVector3(0.2, 0.2, 0.2)
            flash.runAction(SCNAction.sequence([
                SCNAction.group([SCNAction.scale(to: 1.65, duration: 0.12), SCNAction.fadeIn(duration: 0.04)]),
                SCNAction.group([SCNAction.scale(to: 0.2, duration: 0.55), SCNAction.fadeOut(duration: 0.55)])
            ]))
            expNode.addChildNode(flash)

            let glow = self.sprite(TextureCache.glowWarm, 18.0, 18.0)
            glow.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.5, duration: 0.16),
                SCNAction.fadeOut(duration: 0.85)
            ]))
            expNode.addChildNode(glow)

            let flare = self.sprite(TextureCache.flareRing, 14.0, 14.0)
            flare.scale = SCNVector3(0.2, 0.2, 0.2)
            flare.runAction(SCNAction.group([SCNAction.scale(to: 1.8, duration: 0.55), SCNAction.fadeOut(duration: 0.55)]))
            expNode.addChildNode(flare)

            if self.currentQuality != .standard {
                if let swImg = TextureCache.shockwave {
                    let swp = SCNPlane(width: 13.0, height: 13.0)
                    let swm = SCNMaterial()
                    swm.lightingModel = .constant
                    swm.diffuse.contents = swImg
                    swm.blendMode = .add
                    swm.writesToDepthBuffer = false
                    swm.isDoubleSided = true
                    swp.materials = [swm]
                    for k in 0..<2 {
                        let sw = SCNNode(geometry: swp)
                        sw.eulerAngles = SCNVector3(Float.random(in: -0.9...0.9) + Float(k) * Float.pi / 2, Float.random(in: 0...3), 0)
                        sw.scale = SCNVector3(0.08, 0.08, 0.08)
                        sw.castsShadow = false
                        sw.runAction(SCNAction.group([SCNAction.scale(to: 1.85, duration: 0.95), SCNAction.fadeOut(duration: 0.95)]))
                        expNode.addChildNode(sw)
                    }
                }

                let ps = SCNParticleSystem()
                ps.loops = false
                ps.emissionDuration = 0.09
                ps.birthRate = 3600
                ps.particleLifeSpan = 1.8
                ps.particleLifeSpanVariation = 0.7
                ps.particleVelocity = 7.8
                ps.particleVelocityVariation = 4.2
                ps.birthLocation = .volume
                ps.birthDirection = .random
                ps.emitterShape = SCNSphere(radius: 0.45)
                ps.particleSize = 0.28
                ps.particleSizeVariation = 0.16
                ps.particleColor = UIColor(red: 1.0, green: 0.74, blue: 0.26, alpha: 1)
                ps.particleColorVariation = SCNVector4(0.16, 0.24, 0.30, 0)
                ps.blendMode = .additive
                ps.isLightingEnabled = false
                if let spImg = TextureCache.spark { ps.particleImage = spImg }
                let psNode = SCNNode()
                psNode.addParticleSystem(ps)
                expNode.addChildNode(psNode)

                let shardGeo = self.asteroidGeometry(seed: 9)
                for _ in 0..<12 {
                    let sh = SCNNode(geometry: shardGeo)
                    let sc = Float.random(in: 0.15...0.36)
                    sh.scale = SCNVector3(sc, sc, sc)
                    sh.castsShadow = false
                    self.markSolarBody(sh)
                    if let gw = TextureCache.glowWarm {
                        let gsh = self.sprite(gw, 1.9, 1.9)
                        gsh.opacity = 0.75
                        sh.addChildNode(gsh)
                    }
                    let v = SCNVector3(Float.random(in: -9...9), Float.random(in: -6...6), Float.random(in: -9...9))
                    sh.runAction(SCNAction.group([
                        SCNAction.move(by: v, duration: 2.4),
                        SCNAction.rotateBy(x: 7, y: 9, z: 6, duration: 2.4),
                        SCNAction.fadeOut(duration: 2.4)
                    ]))
                    expNode.addChildNode(sh)
                }
            }

            expNode.runAction(SCNAction.sequence([SCNAction.wait(duration: 2.8), SCNAction.removeFromParentNode()]))
        }
    }

    private func spawnShootingStar() {
        let a = Float.random(in: 0...(2 * Float.pi))
        let r: Float = Float.random(in: 115...175)
        let y = Float.random(in: 5...55)
        let start = SCNVector3(r * sin(a), y, r * cos(a))
        let dir = SCNVector3(Float.random(in: -34...34), Float.random(in: -20 ... -6), Float.random(in: -34...34))
        let meteor = sprite(TextureCache.streak, 7.5, 1.0)
        meteor.position = start
        meteor.look(at: SCNVector3(start.x + dir.x, start.y + dir.y, start.z + dir.z))
        eventsNode.addChildNode(meteor)
        meteor.runAction(SCNAction.sequence([
            SCNAction.group([SCNAction.move(by: dir, duration: 1.05), SCNAction.fadeOut(duration: 1.05)]),
            SCNAction.removeFromParentNode()
        ]))
    }

    static func fallbackEnvironment() -> UIImage {
        let size = CGSize(width: 256, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors: [CGColor] = [
                UIColor(red: 0.55, green: 0.62, blue: 0.85, alpha: 1).cgColor,
                UIColor(red: 1.00, green: 0.95, blue: 0.85, alpha: 1).cgColor,
                UIColor(red: 0.22, green: 0.15, blue: 0.10, alpha: 1).cgColor
            ]
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 0.5, 1.0]) {
                ctx.cgContext.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
    }

    private func buildBackground() {
        scene.background.contents = UIColor(red: 0.004, green: 0.006, blue: 0.02, alpha: 1)
        if let sky = TextureCache.sky {
            let sk = SCNSphere(radius: 290)
            sk.segmentCount = 48
            let sm = SCNMaterial()
            sm.lightingModel = .constant
            sm.diffuse.contents = sky
            sm.cullMode = .front
            sm.writesToDepthBuffer = false
            sk.materials = [sm]
            skySphereNode.geometry = sk
            skySphereNode.castsShadow = false
            skySphereNode.renderingOrder = -100
            skySphereNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0.05, z: 0, duration: 30)))
            scene.rootNode.addChildNode(skySphereNode)
        }
        if let env = TextureCache.env {
            scene.lightingEnvironment.contents = env
        } else {
            scene.lightingEnvironment.contents = SpaceScene.fallbackEnvironment()
        }
        scene.lightingEnvironment.intensity = 1.25
    }

    private func buildNebulae() {
        let imgs = [
            TextureCache.nebulaCyan, TextureCache.nebulaPurple,
            TextureCache.nebulaGold, TextureCache.nebulaEmerald, TextureCache.nebulaCrimson
        ].compactMap { $0 }
        guard !imgs.isEmpty else { return }
        let nebShader = "#pragma body\nfloat pulse = 0.90 + 0.14 * sin(scn_frame.time * 0.65 + _surface.diffuseTexcoord.x * 6.28);\n_output.color.rgb *= pulse;\n"
        for i in 0..<36 {
            let az = Float(i) * (2 * Float.pi / 36.0) + Float.random(in: -0.18...0.18)
            let el = Float.random(in: -0.55...0.72)
            let dist = Float.random(in: 194...268)
            let size = CGFloat(Float.random(in: 82...172))
            let plane = SCNPlane(width: size, height: size)
            let m = SCNMaterial()
            m.lightingModel = .constant
            m.diffuse.contents = imgs[i % imgs.count]
            m.blendMode = .add
            m.writesToDepthBuffer = false
            m.isDoubleSided = true
            m.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: nebShader]
            plane.materials = [m]
            let n = SCNNode(geometry: plane)
            n.position = SCNVector3(dist * cos(el) * sin(az), dist * sin(el), -dist * cos(el) * cos(az))
            n.look(at: SCNVector3Zero)
            n.eulerAngles.z = Float.random(in: 0...(2 * Float.pi))
            let baseOp = CGFloat(Float.random(in: 0.28...0.52))
            n.opacity = baseOp
            n.renderingOrder = -90
            n.castsShadow = false
            let rot = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0, z: CGFloat(i % 2 == 0 ? 0.08 : -0.07), duration: 20))
            n.runAction(rot)
            nebulaeNode.addChildNode(n)
        }
        nebulaeNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0.09, z: 0, duration: 30)))
        scene.rootNode.addChildNode(nebulaeNode)
    }

    private func buildStars() {
        var geos: [SCNGeometry] = []
        let tints: [UIColor] = [
            UIColor.white,
            UIColor(red: 0.72, green: 0.86, blue: 1.0, alpha: 1),
            UIColor(red: 1.0, green: 0.90, blue: 0.68, alpha: 1),
            UIColor(red: 1.0, green: 0.72, blue: 0.60, alpha: 1)
        ]
        for c in tints {
            let g = SCNSphere(radius: 0.14)
            g.segmentCount = 6
            let m = SCNMaterial()
            m.lightingModel = .constant
            m.diffuse.contents = c
            g.materials = [m]
            geos.append(g)
        }
        let stars = SCNNode()
        for i in 0..<1500 {
            var x: Float = 0
            var y: Float = 0
            var z: Float = 0
            var len: Float = 0
            var tries = 0
            repeat {
                x = Float.random(in: -1...1)
                y = Float.random(in: -1...1)
                z = Float.random(in: -1...1)
                len = (x * x + y * y + z * z).squareRoot()
                tries += 1
            } while (len > 1 || len < 0.2) && tries < 20
            if len > 1 || len < 0.2 { continue }
            let d = Float.random(in: 195...265) / len
            let n = SCNNode(geometry: geos[i % geos.count])
            n.position = SCNVector3(x * d, y * d, z * d)
            let k = Float.random(in: 0.45...1.9)
            n.scale = SCNVector3(k, k, k)
            n.castsShadow = false
            stars.addChildNode(n)
        }
        for _ in 0..<36 {
            let a = Float.random(in: 0...(2 * Float.pi))
            let e = Float.random(in: -0.9...1.0)
            let d: Float = Float.random(in: 205...255)
            let g = sprite(TextureCache.burst, 5.8, 5.8)
            g.position = SCNVector3(d * cos(e) * sin(a), d * sin(e), -d * cos(e) * cos(a))
            g.opacity = CGFloat(Float.random(in: 0.45...0.95))
            stars.addChildNode(g)
        }
        stars.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0.12, z: 0, duration: 30)))
        scene.rootNode.addChildNode(stars)
    }

    private func sprite(_ image: UIImage?, _ w: CGFloat, _ h: CGFloat) -> SCNNode {
        guard let img = image else { return SCNNode() }
        let plane = SCNPlane(width: w, height: h)
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = img
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        plane.materials = [m]
        let n = SCNNode(geometry: plane)
        let bb = SCNBillboardConstraint()
        bb.freeAxes = SCNBillboardAxis.all
        n.constraints = [bb]
        n.castsShadow = false
        return n
    }

    private func buildSun() {
        let sun = SCNSphere(radius: 4.0)
        sun.segmentCount = 64
        let sm = SCNMaterial()
        sm.lightingModel = .constant
        if let img = TextureCache.sun {
            sm.diffuse.contents = img
            sm.emission.contents = img
        } else {
            sm.diffuse.contents = UIColor(red: 1.0, green: 0.75, blue: 0.25, alpha: 1)
            sm.emission.contents = UIColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1)
        }
        sm.emission.intensity = 2.4
        sm.shaderModifiers = [
            SCNShaderModifierEntryPoint.fragment:
                "#pragma body\nfloat2 uv = _surface.diffuseTexcoord;\nfloat t = scn_frame.time * 0.45;\nfloat n1 = sin(uv.x * 28.0 + t * 2.2) * cos(uv.y * 20.0 - t * 1.7);\nfloat n2 = sin((uv.x + uv.y) * 46.0 - t * 3.1) * cos((uv.x - uv.y) * 38.0 + t * 2.5);\nfloat flare = saturate(0.5 + 0.30 * n1 + 0.22 * n2);\nfloat3 n = normalize(_surface.normal);\nfloat3 v = normalize(_surface.view);\nfloat rim = pow(1.0 - saturate(abs(dot(n, v))), 2.1);\n_output.color.rgb *= (0.86 + 0.42 * flare);\n_output.color.rgb += float3(1.0, 0.52, 0.14) * rim * 1.55;\n"
        ]
        sun.materials = [sm]
        let sunNode = SCNNode(geometry: sun)
        sunNode.position = SCNVector3Zero
        sunNode.castsShadow = false
        sunNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0.35, z: 0, duration: 15)))
        solarSystem.addChildNode(sunNode)

        let corona = sprite(TextureCache.glowWarm, 42, 42)
        corona.opacity = 0.95
        corona.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.scale(to: 1.07, duration: 3.0),
            SCNAction.scale(to: 0.94, duration: 3.4)
        ])))
        let core = sprite(TextureCache.glow, 18, 18)
        let flare = sprite(TextureCache.streak, 82, 9.5)
        flare.opacity = 0.85
        let star = sprite(TextureCache.burst, 40, 40)
        star.opacity = 0.72
        let optRing = sprite(TextureCache.flareRing, 24, 24)
        optRing.opacity = 0.35
        for n in [corona, core, flare, star, optRing] { sunNode.addChildNode(n) }

        let solarLight = SCNLight()
        solarLight.type = .omni
        solarLight.intensity = 2400
        solarLight.color = UIColor(red: 1.0, green: 0.94, blue: 0.84, alpha: 1)
        solarLight.attenuationStartDistance = 260
        solarLight.attenuationEndDistance = 320
        solarLight.attenuationFalloffExponent = 0
        solarLight.categoryBitMask = 2
        let slNode = SCNNode()
        slNode.light = solarLight
        slNode.position = SCNVector3Zero
        solarSystem.addChildNode(slNode)
    }

    private func planetNode(radius: CGFloat, image: UIImage?, normal: UIImage?, fallback: UIColor, roughness: CGFloat = 0.85, limbTint: (Float, Float, Float)? = nil, animatedFlow: Bool = false) -> SCNNode {
        let sphere = SCNSphere(radius: radius)
        sphere.segmentCount = 48
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        if let img = image { m.diffuse.contents = img } else { m.diffuse.contents = fallback }
        if let nm = normal {
            m.normal.contents = nm
            m.normal.intensity = 1.0
        }
        m.roughness.contents = roughness
        m.metalness.contents = 0.0
        if let lt = limbTint {
            if animatedFlow {
                m.shaderModifiers = [
                    SCNShaderModifierEntryPoint.fragment:
                        "#pragma body\nfloat3 n = normalize(_surface.normal);\nfloat3 v = normalize(_surface.view);\nfloat rim = pow(1.0 - saturate(abs(dot(n, v))), 3.1);\nfloat band = 0.94 + 0.08 * sin(_surface.diffuseTexcoord.y * 40.0 + scn_frame.time * 0.8);\n_output.color.rgb = _output.color.rgb * band + float3(\(lt.0), \(lt.1), \(lt.2)) * rim * 0.45;\n"
                ]
            } else {
                m.shaderModifiers = [
                    SCNShaderModifierEntryPoint.fragment:
                        "#pragma body\nfloat3 n = normalize(_surface.normal);\nfloat3 v = normalize(_surface.view);\nfloat rim = pow(1.0 - saturate(abs(dot(n, v))), 3.2);\n_output.color.rgb += float3(\(lt.0), \(lt.1), \(lt.2)) * rim * 0.45;\n"
                ]
            }
        }
        sphere.materials = [m]
        let n = SCNNode(geometry: sphere)
        n.castsShadow = false
        markSolarBody(n)
        return n
    }

    @discardableResult
    private func addOrbitBody(
        distance: Float,
        orbitPeriod: TimeInterval,
        startAngleDeg: Float,
        inclinationDeg: Float = 0,
        axialTiltDeg: Float = 0,
        spinPeriod: TimeInterval,
        retrograde: Bool = false,
        bodyBuilder: (SCNNode) -> Void
    ) -> (holder: SCNNode, axial: SCNNode) {
        let plane = SCNNode()
        plane.eulerAngles.z = inclinationDeg * Float.pi / 180.0
        solarSystem.addChildNode(plane)

        let orbitPivot = SCNNode()
        orbitPivot.eulerAngles.y = startAngleDeg * Float.pi / 180.0
        orbitPivot.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat(2 * Float.pi), z: 0, duration: orbitPeriod)))
        plane.addChildNode(orbitPivot)

        let holder = SCNNode()
        holder.position = SCNVector3(0, 0, distance)
        orbitPivot.addChildNode(holder)

        let axialHolder = SCNNode()
        axialHolder.eulerAngles.z = axialTiltDeg * Float.pi / 180.0
        holder.addChildNode(axialHolder)

        let spinNode = SCNNode()
        let dir: CGFloat = retrograde ? -1.0 : 1.0
        spinNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: dir * CGFloat(2 * Float.pi), z: 0, duration: spinPeriod)))
        axialHolder.addChildNode(spinNode)

        bodyBuilder(spinNode)
        return (holder, axialHolder)
    }

    private func addMoon(to parent: SCNNode, radius: CGFloat, distance: Float, orbitPeriod: TimeInterval, startAngleDeg: Float, inclinationDeg: Float = 0, retrograde: Bool = false, image: UIImage?, normal: UIImage?, fallback: UIColor) {
        let tilt = SCNNode()
        tilt.eulerAngles.z = inclinationDeg * Float.pi / 180.0
        parent.addChildNode(tilt)

        let piv = SCNNode()
        piv.eulerAngles.y = startAngleDeg * Float.pi / 180.0
        let dir: CGFloat = retrograde ? -1.0 : 1.0
        piv.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: dir * CGFloat(2 * Float.pi), z: 0, duration: orbitPeriod)))
        tilt.addChildNode(piv)

        let moon = planetNode(radius: radius, image: image, normal: normal, fallback: fallback, roughness: 0.9)
        moon.position = SCNVector3(distance, 0, 0)
        moon.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: dir * CGFloat(2 * Float.pi), z: 0, duration: orbitPeriod)))
        piv.addChildNode(moon)
    }

    private func buildPlanets() {
        addOrbitBody(distance: 10.5, orbitPeriod: 24, startAngleDeg: 148, inclinationDeg: 7.0, axialTiltDeg: 0.03, spinPeriod: 36) { spin in
            spin.addChildNode(planetNode(radius: 0.55, image: TextureCache.mercury, normal: TextureCache.mercuryNormal, fallback: .gray, roughness: 0.92))
        }

        let venus = addOrbitBody(distance: 16.5, orbitPeriod: 38, startAngleDeg: 212, inclinationDeg: 3.4, axialTiltDeg: 177.4, spinPeriod: 44, retrograde: true) { spin in
            spin.addChildNode(planetNode(radius: 0.95, image: TextureCache.venus, normal: nil, fallback: .systemYellow, roughness: 0.65, limbTint: (1.0, 0.85, 0.45)))
        }
        let vHalo = sprite(TextureCache.haloWarm, 2.5, 2.5)
        vHalo.opacity = 0.45
        venus.holder.addChildNode(vHalo)

        let earth = addOrbitBody(distance: 25.0, orbitPeriod: 60, startAngleDeg: 166, inclinationDeg: 0, axialTiltDeg: 23.4, spinPeriod: 22) { spin in
            spin.addChildNode(planetNode(radius: 1.85, image: TextureCache.earth, normal: nil, fallback: .systemBlue, roughness: 0.52, limbTint: (0.35, 0.65, 1.0)))
            if let clouds = TextureCache.earthClouds {
                let cs = SCNSphere(radius: 1.88)
                cs.segmentCount = 48
                let cm = SCNMaterial()
                cm.lightingModel = .lambert
                cm.diffuse.contents = clouds
                cm.writesToDepthBuffer = false
                cs.materials = [cm]
                let cn = SCNNode(geometry: cs)
                cn.castsShadow = false
                markSolarBody(cn)
                cn.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0.3, z: 0, duration: 18)))
                spin.addChildNode(cn)
            }
        }
        let eHalo = sprite(TextureCache.halo, 5.1, 5.1)
        eHalo.opacity = 0.85
        earth.holder.addChildNode(eHalo)
        let atmoSphere = SCNSphere(radius: 1.98)
        atmoSphere.segmentCount = 40
        let atmoMat = SCNMaterial()
        atmoMat.lightingModel = .constant
        atmoMat.diffuse.contents = UIColor.black
        atmoMat.blendMode = .add
        atmoMat.writesToDepthBuffer = false
        atmoMat.shaderModifiers = [
            SCNShaderModifierEntryPoint.fragment:
                "#pragma body\nfloat3 n = normalize(_surface.normal);\nfloat3 v = normalize(_surface.view);\nfloat f = pow(1.0 - saturate(abs(dot(n, v))), 2.6);\n_output.color.rgb = float3(0.35, 0.62, 1.0) * f * 1.5;\n"
        ]
        atmoSphere.materials = [atmoMat]
        let atmoNode = SCNNode(geometry: atmoSphere)
        atmoNode.castsShadow = false
        earth.holder.addChildNode(atmoNode)
        addMoon(to: earth.holder, radius: 0.48, distance: 3.8, orbitPeriod: 11, startAngleDeg: 40, inclinationDeg: 5.1, image: TextureCache.moon, normal: TextureCache.moonNormal, fallback: .lightGray)

        let mars = addOrbitBody(distance: 34.0, orbitPeriod: 84, startAngleDeg: 204, inclinationDeg: 1.85, axialTiltDeg: 25.2, spinPeriod: 23) { spin in
            spin.addChildNode(planetNode(radius: 1.15, image: TextureCache.mars, normal: TextureCache.marsNormal, fallback: .systemRed, roughness: 0.88, limbTint: (1.0, 0.52, 0.28)))
        }
        let mHalo = sprite(TextureCache.haloWarm, 3.1, 3.1)
        mHalo.opacity = 0.55
        mars.holder.addChildNode(mHalo)
        addMoon(to: mars.axial, radius: 0.14, distance: 2.0, orbitPeriod: 4.2, startAngleDeg: 15, image: TextureCache.asteroid, normal: TextureCache.asteroidNormal, fallback: .brown)
        addMoon(to: mars.axial, radius: 0.10, distance: 2.8, orbitPeriod: 8.4, startAngleDeg: 185, image: TextureCache.asteroid, normal: TextureCache.asteroidNormal, fallback: .gray)

        let jupiter = addOrbitBody(distance: 82.0, orbitPeriod: 140, startAngleDeg: 167, inclinationDeg: 1.3, axialTiltDeg: 3.1, spinPeriod: 10) { spin in
            spin.addChildNode(planetNode(radius: 4.5, image: TextureCache.jupiter, normal: nil, fallback: UIColor(red: 0.85, green: 0.68, blue: 0.48, alpha: 1), roughness: 0.65, limbTint: (1.0, 0.78, 0.55), animatedFlow: true))
        }
        let jRing = SCNTorus(ringRadius: 6.2, pipeRadius: 0.08)
        jRing.ringSegmentCount = 64
        let jrm = SCNMaterial()
        jrm.lightingModel = .constant
        jrm.diffuse.contents = UIColor(red: 0.82, green: 0.72, blue: 0.58, alpha: 0.16)
        jrm.writesToDepthBuffer = false
        jRing.materials = [jrm]
        let jRingNode = SCNNode(geometry: jRing)
        jRingNode.scale = SCNVector3(1.0, 0.06, 1.0)
        jRingNode.castsShadow = false
        jupiter.axial.addChildNode(jRingNode)
        addMoon(to: jupiter.axial, radius: 0.36, distance: 6.8, orbitPeriod: 6.0, startAngleDeg: 20, image: nil, normal: TextureCache.moonNormal, fallback: UIColor(red: 0.95, green: 0.80, blue: 0.28, alpha: 1))
        addMoon(to: jupiter.axial, radius: 0.31, distance: 8.4, orbitPeriod: 9.5, startAngleDeg: 140, image: nil, normal: TextureCache.moonNormal, fallback: UIColor(red: 0.88, green: 0.86, blue: 0.78, alpha: 1))
        addMoon(to: jupiter.axial, radius: 0.48, distance: 10.4, orbitPeriod: 14.0, startAngleDeg: 250, image: TextureCache.moon, normal: TextureCache.moonNormal, fallback: UIColor(red: 0.64, green: 0.58, blue: 0.52, alpha: 1))
        addMoon(to: jupiter.axial, radius: 0.43, distance: 12.6, orbitPeriod: 20.0, startAngleDeg: 310, image: TextureCache.asteroid, normal: TextureCache.asteroidNormal, fallback: UIColor(red: 0.44, green: 0.40, blue: 0.38, alpha: 1))

        let saturn = addOrbitBody(distance: 106.0, orbitPeriod: 190, startAngleDeg: 194, inclinationDeg: 2.5, axialTiltDeg: 26.7, spinPeriod: 11) { spin in
            spin.addChildNode(planetNode(radius: 3.8, image: TextureCache.saturn, normal: nil, fallback: UIColor(red: 0.82, green: 0.68, blue: 0.5, alpha: 1), roughness: 0.72, limbTint: (1.0, 0.85, 0.60), animatedFlow: true))
        }
        let sRing = SCNPlane(width: 17.0, height: 17.0)
        let srm = SCNMaterial()
        srm.lightingModel = .constant
        srm.diffuse.contents = TextureCache.saturnRing ?? UIColor(red: 0.88, green: 0.78, blue: 0.60, alpha: 0.6)
        srm.isDoubleSided = true
        sRing.materials = [srm]
        let sRingNode = SCNNode(geometry: sRing)
        sRingNode.eulerAngles.x = -Float.pi / 2
        sRingNode.castsShadow = false
        sRingNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0, z: CGFloat(2 * Float.pi), duration: 48)))
        saturn.axial.addChildNode(sRingNode)
        addMoon(to: saturn.axial, radius: 0.16, distance: 9.2, orbitPeriod: 6.5, startAngleDeg: 45, image: TextureCache.moon, normal: TextureCache.moonNormal, fallback: .lightGray)
        addMoon(to: saturn.axial, radius: 0.20, distance: 10.6, orbitPeriod: 9.0, startAngleDeg: 175, image: nil, normal: TextureCache.moonNormal, fallback: UIColor(red: 0.92, green: 0.96, blue: 1.0, alpha: 1))
        addMoon(to: saturn.axial, radius: 0.50, distance: 13.0, orbitPeriod: 15.0, startAngleDeg: 290, image: nil, normal: nil, fallback: UIColor(red: 0.90, green: 0.68, blue: 0.34, alpha: 1))

        let uranus = addOrbitBody(distance: 130.0, orbitPeriod: 240, startAngleDeg: 172, inclinationDeg: 0.8, axialTiltDeg: 97.8, spinPeriod: 15, retrograde: true) { spin in
            spin.addChildNode(planetNode(radius: 2.5, image: TextureCache.uranus, normal: nil, fallback: .cyan, roughness: 0.68, limbTint: (0.55, 0.95, 1.0)))
        }
        let uRing = SCNPlane(width: 10.5, height: 10.5)
        let urm = SCNMaterial()
        urm.lightingModel = .constant
        urm.diffuse.contents = TextureCache.uranusRing ?? UIColor(red: 0.65, green: 0.88, blue: 0.95, alpha: 0.4)
        urm.isDoubleSided = true
        uRing.materials = [urm]
        let uRingNode = SCNNode(geometry: uRing)
        uRingNode.eulerAngles.x = -Float.pi / 2
        uRingNode.castsShadow = false
        uranus.axial.addChildNode(uRingNode)
        addMoon(to: uranus.axial, radius: 0.24, distance: 6.2, orbitPeriod: 8.0, startAngleDeg: 60, image: TextureCache.moon, normal: TextureCache.moonNormal, fallback: .lightGray)
        addMoon(to: uranus.axial, radius: 0.22, distance: 7.6, orbitPeriod: 11.5, startAngleDeg: 210, image: TextureCache.moon, normal: TextureCache.moonNormal, fallback: .gray)

        let neptune = addOrbitBody(distance: 152.0, orbitPeriod: 300, startAngleDeg: 188, inclinationDeg: 1.8, axialTiltDeg: 28.3, spinPeriod: 14) { spin in
            spin.addChildNode(planetNode(radius: 2.4, image: TextureCache.neptune, normal: nil, fallback: .systemBlue, roughness: 0.65, limbTint: (0.35, 0.65, 1.0)))
        }
        let nHalo = sprite(TextureCache.halo, 6.2, 6.2)
        nHalo.opacity = 0.55
        neptune.holder.addChildNode(nHalo)
        addMoon(to: neptune.axial, radius: 0.34, distance: 5.4, orbitPeriod: 9.0, startAngleDeg: 120, inclinationDeg: 23.0, retrograde: true, image: TextureCache.moon, normal: TextureCache.moonNormal, fallback: UIColor(red: 0.85, green: 0.80, blue: 0.82, alpha: 1))

        let pluto = addOrbitBody(distance: 168.0, orbitPeriod: 360, startAngleDeg: 177, inclinationDeg: 9.0, axialTiltDeg: 122.5, spinPeriod: 28, retrograde: true) { spin in
            spin.addChildNode(planetNode(radius: 0.82, image: TextureCache.pluto, normal: nil, fallback: UIColor(red: 0.78, green: 0.65, blue: 0.55, alpha: 1), roughness: 0.90))
        }
        addMoon(to: pluto.holder, radius: 0.42, distance: 2.2, orbitPeriod: 8.0, startAngleDeg: 40, image: TextureCache.moon, normal: TextureCache.moonNormal, fallback: .gray)
    }

    private func asteroidGeometry(seed: Int, icy: Bool = false) -> SCNGeometry {
        let stacks = 7
        let slices = 10
        var verts: [SCNVector3] = []
        var norms: [SCNVector3] = []
        var uvs: [CGPoint] = []
        let f = Float(seed)
        for i in 0...stacks {
            let v = Float(i) / Float(stacks)
            let phi = (1.0 - v) * Float.pi
            for j in 0...slices {
                let u = Float(j) / Float(slices)
                let theta = u * 2.0 * Float.pi
                let nx = sin(phi) * cos(theta)
                let ny = cos(phi)
                let nz = sin(phi) * sin(theta)
                let disp = 1.0
                    + 0.24 * sin(nx * 3.1 + f * 1.7) * cos(nz * 2.7 + f)
                    + 0.14 * cos(ny * 4.3 + nx * 2.1 + f * 2.3)
                let r = max(0.55, disp)
                verts.append(SCNVector3(nx * r, ny * r * 0.82, nz * r))
                norms.append(SCNVector3(nx, ny, nz))
                uvs.append(CGPoint(x: CGFloat(u), y: CGFloat(v)))
            }
        }
        var idx: [Int32] = []
        let cols = slices + 1
        for i in 0..<stacks {
            for j in 0..<slices {
                let a = Int32(i * cols + j)
                let b = Int32((i + 1) * cols + j)
                let c = Int32(i * cols + j + 1)
                let d = Int32((i + 1) * cols + j + 1)
                idx.append(contentsOf: [a, b, c, c, b, d])
            }
        }
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = TextureCache.asteroid ?? UIColor(white: 0.48, alpha: 1)
        if icy { m.multiply.contents = UIColor(red: 0.72, green: 0.86, blue: 1.0, alpha: 1) }
        if let nm = TextureCache.asteroidNormal { m.normal.contents = nm; m.normal.intensity = 1.2 }
        m.roughness.contents = icy ? 0.68 : 0.92
        m.metalness.contents = icy ? 0.05 : 0.12
        let geo = SCNGeometry(
            sources: [SCNGeometrySource(vertices: verts), SCNGeometrySource(normals: norms), SCNGeometrySource(textureCoordinates: uvs)],
            elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)]
        )
        geo.materials = [m]
        return geo
    }

    private func buildBeltRing(geos: [SCNGeometry], count: Int, heroCount: Int, rMin: Float, rMax: Float, ySpread: Float, sMin: Float, sMax: Float, orbitPeriod: TimeInterval) {
        let piv = SCNNode()
        piv.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat(2 * Float.pi), z: 0, duration: orbitPeriod)))
        beltsNode.addChildNode(piv)

        let staticGroup = SCNNode()
        for i in 0..<count {
            let angle = Float.random(in: 0...(2 * Float.pi))
            let dist = Float.random(in: rMin...rMax)
            let y = Float.random(in: -ySpread...ySpread)
            let n = SCNNode(geometry: geos[i % geos.count])
            n.position = SCNVector3(dist * sin(angle), y, dist * cos(angle))
            n.eulerAngles = SCNVector3(Float.random(in: 0...6), Float.random(in: 0...6), Float.random(in: 0...6))
            let sx = Float.random(in: sMin...sMax)
            let sy = sx * Float.random(in: 0.72...1.25)
            let sz = sx * Float.random(in: 0.72...1.25)
            n.scale = SCNVector3(sx, sy, sz)
            n.castsShadow = false
            if i < heroCount {
                markSolarBody(n)
                let rx = CGFloat(Float.random(in: -3...3))
                let ry = CGFloat(Float.random(in: -3...3))
                let rz = CGFloat(Float.random(in: -3...3))
                n.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: rx, y: ry, z: rz, duration: Double.random(in: 6...14))))
                piv.addChildNode(n)
            } else {
                staticGroup.addChildNode(n)
            }
        }
        let batch = staticGroup.flattenedClone()
        batch.castsShadow = false
        markSolarBody(batch)
        piv.addChildNode(batch)
    }

    private func buildAsteroidBelt() {
        solarSystem.addChildNode(beltsNode)
        let geos = (0..<5).map { asteroidGeometry(seed: $0 + 1) }
        buildBeltRing(geos: geos, count: 80, heroCount: 16, rMin: 54, rMax: 58, ySpread: 2.2, sMin: 0.16, sMax: 0.45, orbitPeriod: 112)
        buildBeltRing(geos: geos, count: 85, heroCount: 16, rMin: 58, rMax: 63, ySpread: 2.8, sMin: 0.18, sMax: 0.56, orbitPeriod: 126)
        buildBeltRing(geos: geos, count: 70, heroCount: 13, rMin: 63, rMax: 68, ySpread: 3.2, sMin: 0.16, sMax: 0.48, orbitPeriod: 142)

        addOrbitBody(distance: 60.5, orbitPeriod: 118, startAngleDeg: 183, inclinationDeg: 6.5, axialTiltDeg: 4.0, spinPeriod: 16) { spin in
            spin.addChildNode(planetNode(radius: 0.54, image: TextureCache.moon, normal: TextureCache.moonNormal, fallback: .gray, roughness: 0.92))
        }
    }

    private func buildKuiperBelt() {
        let icyGeos = (0..<4).map { asteroidGeometry(seed: $0 + 21, icy: true) }
        buildBeltRing(geos: icyGeos, count: 85, heroCount: 14, rMin: 166, rMax: 176, ySpread: 5.0, sMin: 0.25, sMax: 0.72, orbitPeriod: 340)
        buildBeltRing(geos: icyGeos, count: 75, heroCount: 12, rMin: 176, rMax: 188, ySpread: 6.0, sMin: 0.28, sMax: 0.78, orbitPeriod: 390)
    }

    private func buildComet() {
        let plane = SCNNode()
        plane.eulerAngles = SCNVector3(0.18, 0, -0.22)
        solarSystem.addChildNode(plane)

        let piv = SCNNode()
        piv.eulerAngles.y = 198 * Float.pi / 180.0
        piv.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat(2 * Float.pi), z: 0, duration: 52)))
        plane.addChildNode(piv)

        let comet = SCNNode()
        comet.position = SCNVector3(48.0, 0, 0)
        piv.addChildNode(comet)

        let core = planetNode(radius: 0.34, image: TextureCache.moon, normal: TextureCache.moonNormal, fallback: .cyan, roughness: 0.6)
        core.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0.5, y: 1.2, z: 0.3, duration: 4)))
        comet.addChildNode(core)

        let coma = sprite(TextureCache.glow, 3.6, 3.6)
        coma.opacity = 0.85
        comet.addChildNode(coma)

        if let tailImg = TextureCache.cometTail {
            let tm = SCNMaterial()
            tm.lightingModel = .constant
            tm.diffuse.contents = tailImg
            tm.blendMode = .add
            tm.writesToDepthBuffer = false
            tm.isDoubleSided = true
            let tp = SCNPlane(width: 12.0, height: 2.8)
            tp.materials = [tm]
            for k in 0..<2 {
                let tn = SCNNode(geometry: tp)
                tn.position = SCNVector3(5.4, 0, 0)
                tn.eulerAngles.x = Float(k) * Float.pi / 2
                tn.castsShadow = false
                comet.addChildNode(tn)
            }
        }
    }

    private func buildBoardRig() {
        boardOrbitPivot.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat(2 * Float.pi), z: 0, duration: 180)), forKey: "boardOrbit")
        solarSystem.addChildNode(boardOrbitPivot)
        boardAnchor.position = SCNVector3(0, 8.4, 44.0)
        boardOrbitPivot.addChildNode(boardAnchor)
        boardAnchor.addChildNode(boardMount)
    }

    private func buildBeams(from sun: SCNVector3) {
        boardAnchor.addChildNode(beamsNode)
        guard let tex = TextureCache.beam else { return }
        let warmMat = SCNMaterial()
        warmMat.lightingModel = .constant
        warmMat.diffuse.contents = tex
        warmMat.blendMode = .add
        warmMat.writesToDepthBuffer = false
        warmMat.isDoubleSided = true

        let coolMat = SCNMaterial()
        coolMat.lightingModel = .constant
        coolMat.diffuse.contents = tex
        coolMat.multiply.contents = UIColor(red: 0.55, green: 0.80, blue: 1.0, alpha: 1)
        coolMat.blendMode = .add
        coolMat.writesToDepthBuffer = false
        coolMat.isDoubleSided = true

        for i in 0..<20 {
            let target = SCNVector3(Float.random(in: -7.5...7.5), Float.random(in: -0.5...4.5), Float.random(in: -5...4))
            let dx = target.x - sun.x
            let dy = target.y - sun.y
            let dz = target.z - sun.z
            let length = (dx * dx + dy * dy + dz * dz).squareRoot()
            let holder = SCNNode()
            holder.position = SCNVector3((sun.x + target.x) / 2, (sun.y + target.y) / 2, (sun.z + target.z) / 2)
            beamsNode.addChildNode(holder)
            holder.look(at: target)
            let width = CGFloat(Float.random(in: 1.2...3.8))
            let beamMat = (i < 14) ? warmMat : coolMat
            for k in 0..<2 {
                let spin = SCNNode()
                spin.eulerAngles.z = Float(k) * Float.pi / 2 + Float.random(in: 0...0.5)
                let plane = SCNPlane(width: width, height: CGFloat(length * 1.05))
                plane.materials = [beamMat]
                let pn = SCNNode(geometry: plane)
                pn.eulerAngles.x = Float.pi / 2
                pn.castsShadow = false
                spin.addChildNode(pn)
                holder.addChildNode(spin)
            }
            let base = CGFloat(Float.random(in: 0.08...0.22))
            holder.opacity = base
            let up = SCNAction.fadeOpacity(to: base * 1.5, duration: Double.random(in: 2.5...5.0))
            let down = SCNAction.fadeOpacity(to: base * 0.55, duration: Double.random(in: 2.5...5.0))
            up.timingMode = .easeInEaseOut
            down.timingMode = .easeInEaseOut
            holder.runAction(SCNAction.repeatForever(SCNAction.sequence([up, down])))
        }
    }

    private func buildDust() {
        let ps = SCNParticleSystem()
        ps.loops = true
        ps.birthRate = 18
        ps.warmupDuration = 10
        ps.particleLifeSpan = 14
        ps.particleLifeSpanVariation = 4
        ps.emitterShape = SCNBox(width: 15, height: 5, length: 15, chamferRadius: 0)
        ps.birthLocation = .volume
        ps.birthDirection = .random
        ps.particleVelocity = 0.12
        ps.particleVelocityVariation = 0.1
        ps.acceleration = SCNVector3(0.01, 0.015, 0)
        ps.particleSize = 0.07
        ps.particleSizeVariation = 0.05
        ps.particleColor = UIColor(red: 1.0, green: 0.9, blue: 0.75, alpha: 0.6)
        ps.blendMode = .additive
        ps.isLightingEnabled = false
        if let img = TextureCache.dust { ps.particleImage = img }
        dustNode.position = SCNVector3(0, 2.6, 0)
        dustNode.addParticleSystem(ps)
        boardAnchor.addChildNode(dustNode)
    }

    private func startBoardFloat() {
        boardMount.removeAction(forKey: "float")
        let period: TimeInterval = 120.0
        let w0 = Float(2.0 * Double.pi / period)
        let drift = SCNAction.customAction(duration: period) { node, elapsed in
            let t = Float(elapsed)
            let y = 0.16 * sin(14 * w0 * t) + 0.04 * sin(27 * w0 * t + 0.8)
            let x = 0.09 * sin(7 * w0 * t + 0.4)
            let z = 0.08 * cos(9 * w0 * t + 1.1)
            let rx = 0.018 * sin(11 * w0 * t + 0.3)
            let rz = 0.020 * cos(8 * w0 * t + 1.4)
            let ry = 0.014 * sin(5 * w0 * t + 0.7)
            node.position = SCNVector3(x, y, z)
            node.eulerAngles = SCNVector3(rx, ry, rz)
        }
        boardMount.runAction(SCNAction.repeatForever(drift), forKey: "float")
    }

    private func buildCameraAndLights() {
        let cam = SCNCamera()
        cam.zNear = 0.1
        cam.zFar = 600
        cam.fieldOfView = 64
        camNode.camera = cam
        camNode.position = baseCam
        camNode.look(at: SCNVector3(0, 1.35, -1.5))
        gyroNode.addChildNode(camNode)
        pitch.addChildNode(gyroNode)
        orbit.addChildNode(pitch)
        boardAnchor.addChildNode(orbit)

        let back = SCNLight()
        back.type = .directional
        back.intensity = 1220
        back.color = UIColor(red: 1.0, green: 0.85, blue: 0.66, alpha: 1)
        back.castsShadow = true
        back.shadowMode = .deferred
        back.shadowRadius = 2.8
        back.shadowBias = 0.90
        back.shadowColor = UIColor(white: 0, alpha: 0.56)
        back.automaticallyAdjustsShadowProjection = false
        back.orthographicScale = 9.5
        back.categoryBitMask = 1
        let bn = SCNNode()
        bn.light = back
        bn.position = SCNVector3(-4, 11, -18)
        boardAnchor.addChildNode(bn)
        bn.look(at: SCNVector3Zero)
        backLight = back

        let key = SCNLight()
        key.type = .spot
        key.intensity = 760
        key.color = UIColor(red: 1.0, green: 0.95, blue: 0.89, alpha: 1)
        key.spotInnerAngle = 26
        key.spotOuterAngle = 82
        key.castsShadow = true
        key.shadowMode = .deferred
        key.shadowRadius = 4.2
        key.shadowMapSize = CGSize(width: 2048, height: 2048)
        key.shadowSampleCount = 8
        key.shadowColor = UIColor(white: 0, alpha: 0.24)
        key.zNear = 2.0
        key.zFar = 38.0
        key.categoryBitMask = 1
        let kn = SCNNode()
        kn.light = key
        kn.position = SCNVector3(7, 13, 11)
        boardAnchor.addChildNode(kn)
        kn.look(at: SCNVector3Zero)
        keyLight = key

        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = 280
        fill.color = UIColor(red: 0.55, green: 0.70, blue: 1.0, alpha: 1)
        fill.categoryBitMask = 1
        let fn = SCNNode()
        fn.light = fill
        fn.position = SCNVector3(-8, 4, 8)
        boardAnchor.addChildNode(fn)
        fn.look(at: SCNVector3Zero)
        fillLight = fill

        let under = SCNLight()
        under.type = .directional
        under.intensity = 230
        under.color = UIColor(red: 0.42, green: 0.60, blue: 0.98, alpha: 1)
        under.categoryBitMask = 1
        let un = SCNNode()
        un.light = under
        un.position = SCNVector3(2, -10, 4)
        boardAnchor.addChildNode(un)
        un.look(at: SCNVector3Zero)
        underLight = under

        let amb = SCNLight()
        amb.type = .ambient
        amb.intensity = 105
        amb.color = UIColor(red: 0.72, green: 0.78, blue: 1.0, alpha: 1)
        let an = SCNNode()
        an.light = amb
        scene.rootNode.addChildNode(an)
        ambientLight = amb
    }

    func applyQuality(_ q: GraphicsQuality) {
        currentQuality = q
        guard let cam = camNode.camera else { return }
        switch q {
        case .standard:
            cam.wantsHDR = false
            cam.wantsExposureAdaptation = false
            cam.bloomIntensity = 0
            cam.saturation = 1.0
            cam.contrast = 0.0
            cam.screenSpaceAmbientOcclusionIntensity = 0
            cam.wantsDepthOfField = false
            cam.motionBlurIntensity = 0
            cam.vignettingIntensity = 0
            cam.grainIntensity = 0
            cam.colorFringeStrength = 0
            backLight?.shadowMapSize = CGSize(width: 1024, height: 1024)
            backLight?.shadowSampleCount = 4
            keyLight?.castsShadow = false
            beamsNode.isHidden = true
            dustNode.isHidden = true
        case .high:
            configureFilmLook(cam)
            cam.screenSpaceAmbientOcclusionIntensity = 0.35
            cam.screenSpaceAmbientOcclusionRadius = 0.45
            cam.wantsDepthOfField = false
            cam.motionBlurIntensity = 0
            cam.grainIntensity = 0
            cam.colorFringeStrength = 0
            backLight?.shadowMapSize = CGSize(width: 2048, height: 2048)
            backLight?.shadowSampleCount = 8
            keyLight?.castsShadow = false
            beamsNode.isHidden = false
            dustNode.isHidden = false
        case .ultra:
            configureFilmLook(cam)
            cam.screenSpaceAmbientOcclusionIntensity = 0.95
            cam.screenSpaceAmbientOcclusionRadius = 0.55
            cam.screenSpaceAmbientOcclusionBias = 0.025
            cam.screenSpaceAmbientOcclusionDepthThreshold = 0.18
            cam.screenSpaceAmbientOcclusionNormalThreshold = 0.25
            cam.wantsDepthOfField = true
            cam.focusDistance = 13.8 * CGFloat(zoom)
            cam.fStop = 7.6
            cam.apertureBladeCount = 7
            cam.motionBlurIntensity = 0.18
            cam.grainIntensity = 0.07
            cam.grainScale = 1.4
            cam.colorFringeStrength = 0.75
            backLight?.shadowMapSize = CGSize(width: 4096, height: 4096)
            backLight?.shadowSampleCount = 16
            keyLight?.castsShadow = true
            beamsNode.isHidden = false
            dustNode.isHidden = false
        }
    }

    private func configureFilmLook(_ cam: SCNCamera) {
        cam.wantsHDR = true
        cam.wantsExposureAdaptation = true
        cam.exposureOffset = -0.22
        cam.minimumExposure = -1.2
        cam.maximumExposure = 1.4
        cam.bloomIntensity = 0.72
        cam.bloomThreshold = 1.35
        cam.bloomBlurRadius = 11
        cam.bloomIterationCount = 2
        cam.vignettingIntensity = 0.48
        cam.vignettingPower = 1.25
        cam.saturation = 1.08
        cam.contrast = 0.10
    }

    func startMenuOrbit() {
        orbit.removeAction(forKey: "focus")
        pitch.eulerAngles.x = 0
        orbit.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0.25, z: 0, duration: 20)), forKey: "menuOrbit")
    }

    func focus(flipped: Bool) {
        orbit.removeAction(forKey: "menuOrbit")
        pitch.eulerAngles.x = 0
        zoom = 1.0
        camNode.position = baseCam
        camNode.camera?.focusDistance = 13.8
        let target: CGFloat = flipped ? CGFloat.pi : 0
        orbit.runAction(SCNAction.rotateTo(x: 0, y: target, z: 0, duration: 0.9, usesShortestUnitArc: true), forKey: "focus")
    }

    func pan(dx: CGFloat, dy: CGFloat) {
        orbit.removeAction(forKey: "focus")
        orbit.eulerAngles.y -= Float(dx) * 0.006
        let nx = pitch.eulerAngles.x - Float(dy) * 0.004
        pitch.eulerAngles.x = max(-0.8, min(0.3, nx))
    }

    func pinch(scale: CGFloat) {
        if scale <= 0 { return }
        zoom = min(1.5, max(0.55, zoom / Float(scale)))
        camNode.position = SCNVector3(baseCam.x * zoom, baseCam.y * zoom, baseCam.z * zoom)
        camNode.camera?.focusDistance = 13.8 * CGFloat(zoom)
    }
}

struct Chess3DContainer: UIViewRepresentable {
    @ObservedObject var gm: GameManager

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = gm.space.scene
        view.pointOfView = gm.space.cameraNode
        view.antialiasingMode = .multisampling4X
        view.isTemporalAntialiasingEnabled = true
        view.rendersContinuously = true
        view.backgroundColor = UIColor.black
        view.delegate = context.coordinator
        gm.space.scene.physicsWorld.contactDelegate = context.coordinator
        gm.attachBoardToSpace()

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        let dblTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        dblTap.numberOfTapsRequired = 2
        tap.require(toFail: dblTap)
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(dblTap)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(gm: gm) }

    final class Coordinator: NSObject, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {
        let gm: GameManager
        private var isDraggingPiece = false
        private var lastDragLocal: SCNVector3? = nil
        private var lastDragTime: TimeInterval = 0
        private var dragVelocityLocal = SCNVector3Zero
        private var lastClackTime: TimeInterval = 0

        init(gm: GameManager) { self.gm = gm }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            gm.space.updateFrame(atTime: time)
            if gm.controlMode == .drag {
                gm.boardCtl.updateDraggedPiecePhysics()
            }
        }

        func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
            guard contact.collisionImpulse > 0.7 else { return }
            let now = Date().timeIntervalSinceReferenceDate
            if now - lastClackTime < 0.08 { return }
            lastClackTime = now
            SoundEngine.shared.play("click", enabled: gm.sfxEnabled)
        }

        private func rayBoardPoint(_ view: SCNView, screenPoint: CGPoint, yPlane: Float) -> SCNVector3? {
            let p0 = view.unprojectPoint(SCNVector3(Float(screenPoint.x), Float(screenPoint.y), 0))
            let p1 = view.unprojectPoint(SCNVector3(Float(screenPoint.x), Float(screenPoint.y), 1))
            let o = gm.boardCtl.root.convertPosition(p0, from: nil)
            let f = gm.boardCtl.root.convertPosition(p1, from: nil)
            let dy = f.y - o.y
            guard abs(dy) > 0.001 else { return nil }
            let t = (yPlane - o.y) / dy
            guard t > 0 else { return nil }
            let lx = min(7.0, max(-7.0, o.x + (f.x - o.x) * t))
            let lz = min(7.0, max(-7.0, o.z + (f.z - o.z) * t))
            return SCNVector3(lx, yPlane, lz)
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let view = g.view as? SCNView else { return }
            let p = g.location(in: view)
            let hits = view.hitTest(p, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            for h in hits {
                if let s = BoardController.squareIndex(from: h.node) {
                    gm.tapSquare(s)
                    return
                }
            }
        }

        @objc func handleDoubleTap(_ g: UITapGestureRecognizer) {
            guard gm.controlMode == .drag, let view = g.view as? SCNView else { return }
            let p = g.location(in: view)
            let hits = view.hitTest(p, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            for h in hits {
                if let s = BoardController.squareIndex(from: h.node) {
                    let camW = gm.space.cameraNode.presentation.worldPosition
                    let hitW = h.worldCoordinates
                    let dirLocal = gm.boardCtl.root.convertVector(SCNVector3(hitW.x - camW.x, 0, hitW.z - camW.z), from: nil)
                    gm.knockOverPiece(at: s, viewDir: dirLocal)
                    return
                }
            }
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let view = g.view as? SCNView else { return }
            let p = g.location(in: view)
            switch g.state {
            case .began:
                isDraggingPiece = false
                lastDragLocal = nil
                dragVelocityLocal = SCNVector3Zero
                if gm.controlMode == .drag {
                    let hits = view.hitTest(p, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
                    for h in hits {
                        if let s = BoardController.squareIndex(from: h.node),
                           let pt = rayBoardPoint(view, screenPoint: p, yPlane: 0.58) {
                            if gm.beginPieceDrag(square: s, atLocal: pt) {
                                isDraggingPiece = true
                                lastDragLocal = pt
                                lastDragTime = Date().timeIntervalSinceReferenceDate
                                return
                            }
                        }
                    }
                }
                let t = g.translation(in: view)
                gm.space.pan(dx: t.x, dy: t.y)
                g.setTranslation(.zero, in: view)

            case .changed:
                if isDraggingPiece {
                    if let pt = rayBoardPoint(view, screenPoint: p, yPlane: 0.58) {
                        let now = Date().timeIntervalSinceReferenceDate
                        let dt = Float(max(0.008, now - lastDragTime))
                        if let prev = lastDragLocal {
                            dragVelocityLocal = SCNVector3((pt.x - prev.x) / dt, 0, (pt.z - prev.z) / dt)
                        }
                        lastDragLocal = pt
                        lastDragTime = now
                        gm.updatePieceDrag(toLocal: pt)
                    }
                } else {
                    let t = g.translation(in: view)
                    gm.space.pan(dx: t.x, dy: t.y)
                    g.setTranslation(.zero, in: view)
                }

            case .ended, .cancelled:
                if isDraggingPiece {
                    isDraggingPiece = false
                    let pt = rayBoardPoint(view, screenPoint: p, yPlane: 0.58) ?? lastDragLocal
                    let worldVel = gm.boardCtl.root.convertVector(dragVelocityLocal, to: nil)
                    gm.endPieceDrag(atLocal: pt, releaseVelocity: worldVel)
                }
            default:
                break
            }
        }

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            gm.space.pinch(scale: g.scale)
            g.scale = 1.0
        }
    }
}

struct ARChessContainer: UIViewRepresentable {
    @ObservedObject var gm: GameManager

    func makeUIView(context: Context) -> ARSCNView {
        let v = ARSCNView()
        v.autoenablesDefaultLighting = true
        v.automaticallyUpdatesLighting = true
        gm.arSceneView = v
        gm.arBoardAnchorNode = nil
        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = [.horizontal]
        v.session.run(cfg)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        v.addGestureRecognizer(tap)
        return v
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    func makeCoordinator() -> Coordinator { Coordinator(gm: gm) }

    final class Coordinator: NSObject {
        let gm: GameManager
        init(gm: GameManager) { self.gm = gm }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let view = g.view as? ARSCNView else { return }
            let p = g.location(in: view)
            if gm.arBoardAnchorNode == nil {
                guard let query = view.raycastQuery(from: p, allowing: .estimatedPlane, alignment: .horizontal),
                      let hit = view.session.raycast(query).first else {
                    gm.statusText = "Плоскость не найдена — поводи камерой по столу"
                    return
                }
                let anchor = SCNNode()
                anchor.simdTransform = hit.worldTransform
                anchor.scale = SCNVector3(0.04, 0.04, 0.04)
                view.scene.rootNode.addChildNode(anchor)
                gm.attachBoard(to: anchor)
                gm.arBoardAnchorNode = anchor
                gm.statusText = "Доска на столе!"
                return
            }
            let hits = view.hitTest(p, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            for h in hits {
                if let s = BoardController.squareIndex(from: h.node) {
                    gm.tapSquare(s)
                    return
                }
            }
        }
    }
}

@main
struct VibeChessApp: App {
    var body: some Scene {
        WindowGroup {
            MainGameView()
        }
    }
}

struct GlassStyle: ViewModifier {
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(Color.black.opacity(0.58))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }
}

extension View {
    func glass(_ radius: CGFloat = 12) -> some View {
        modifier(GlassStyle(radius: radius))
    }
}

private func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
    return Font.system(size: size, weight: weight, design: .monospaced)
}

struct MainGameView: View {
    @StateObject private var gm = GameManager()
    @State private var showSaves = false
    @State private var showSettings = false
    @State private var showAIChat = false
    @State private var showCommanderSelect = false
    @State private var showRoulette = false
    @State private var showArmy = false
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            sceneLayer
            uiLayer
        }
        .onReceive(timer) { _ in gm.onClockTick() }
        .sheet(isPresented: $showSaves) { SavesModalView(gm: gm) }
        .sheet(isPresented: $showAIChat) { AIChatModalView(gm: gm) }
        .sheet(isPresented: $showSettings) { SettingsModalView(gm: gm) }
        .sheet(isPresented: $showCommanderSelect) { CommanderSelectModalView(gm: gm) }
        .sheet(isPresented: $showRoulette) { RouletteModalView(gm: gm) }
        .sheet(isPresented: $showArmy) { ArmyModalView(gm: gm) }
    }

    @ViewBuilder private var sceneLayer: some View {
        if gm.isARMode {
            ARChessContainer(gm: gm).ignoresSafeArea()
        } else {
            Chess3DContainer(gm: gm).ignoresSafeArea()
        }
    }

    @ViewBuilder private var uiLayer: some View {
        if gm.inMenu {
            MainMenuOverlay(
                gm: gm,
                showSaves: $showSaves,
                showSettings: $showSettings,
                showAIChat: $showAIChat,
                showCommanderSelect: $showCommanderSelect
            )
        } else if gm.isRoguelikeActive, let run = gm.roguelikeRun {
            roguelikeLayer(run: run)
        } else {
            classicLayer
        }
    }

    @ViewBuilder private func roguelikeLayer(run: RoguelikeRun) -> some View {
        ZStack {
            switch run.phase {
            case .map:
                CosmicMapOverlay(
                    gm: gm,
                    run: run,
                    showRoulette: $showRoulette,
                    showArmy: $showArmy,
                    showSettings: $showSettings
                )
            case .inBattle:
                GameHUDOverlay(gm: gm, showAIChat: $showAIChat, showArmy: $showArmy)
                if gm.pendingRoguelikePromotion != nil {
                    RoguelikePromotionOverlay(gm: gm)
                }
                if gm.isPaused {
                    PauseMenuOverlay(gm: gm, showSaves: $showSaves, showSettings: $showSettings)
                }
            case .reward:
                RewardOverlay(gm: gm)
            case .shop:
                ShopOverlay(gm: gm, run: run, showRoulette: $showRoulette)
            case .event:
                EventOverlay(gm: gm)
            case .victory, .gameOver:
                RunEndOverlay(gm: gm, run: run, showCommanderSelect: $showCommanderSelect)
            }
        }
    }

    private var classicLayer: some View {
        ZStack {
            GameHUDOverlay(gm: gm, showAIChat: $showAIChat, showArmy: $showArmy)
            if gm.pendingPromotion != nil {
                PromotionOverlay(gm: gm)
            }
            if gm.gameResult != nil {
                GameOverOverlay(gm: gm)
            }
            if gm.isPaused {
                PauseMenuOverlay(gm: gm, showSaves: $showSaves, showSettings: $showSettings)
            }
        }
    }
}

struct MainMenuOverlay: View {
    @ObservedObject var gm: GameManager
    @Binding var showSaves: Bool
    @Binding var showSettings: Bool
    @Binding var showAIChat: Bool
    @Binding var showCommanderSelect: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("VIBE CHESS 3D")
                    .font(mono(30, .black))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan, radius: 10)
                Text("шахматы и рогалик среди планет")
                    .font(mono(11, .medium))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.top, 52)
            Spacer()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    roguelikeCard
                    optionsCard
                    startButtons
                    footerRow
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .frame(maxHeight: 590)
        }
    }

    private var roguelikeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🚀 ХОД ЗА ХОДОМ • РОГАЛИК")
                        .font(mono(14, .black))
                        .foregroundColor(.orange)
                    Text("Бета 1.0 • Маршрут по Солнечной системе")
                        .font(mono(10))
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                Text("✨ \(gm.roguelikeMeta.starShards)")
                    .font(mono(12, .black))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.18))
                    .cornerRadius(8)
            }

            Text("Маленькая армия, дефицит пешек, Космическая Рулетка за кредиты и пассивки для Короля.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 8) {
                if gm.hasActiveRoguelikeRun, let r = gm.roguelikeRun {
                    Button(action: { gm.continueRoguelikeRun() }) {
                        Text("ПРОДОЛЖИТЬ (Сектор \(r.currentLayer + 1))")
                            .font(mono(12, .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    Button(action: { showCommanderSelect = true }) {
                        Text("НОВЫЙ")
                            .font(mono(12, .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(Color.orange.opacity(0.18))
                            .cornerRadius(12)
                    }
                } else {
                    Button(action: { showCommanderSelect = true }) {
                        Text("НАЧАТЬ КОСМИЧЕСКИЙ ЗАБЕГ")
                            .font(mono(13, .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.08))
        .glass(18)
    }

    private func caption(_ t: String) -> some View {
        Text(t).font(mono(10)).foregroundColor(.white.opacity(0.6))
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("♟️ КЛАССИЧЕСКИЕ ШАХМАТЫ")
                .font(mono(12, .black))
                .foregroundColor(.cyan)

            caption("РЕЖИМ:")
            Picker("", selection: $gm.mode) {
                ForEach(GameMode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)

            if gm.mode == .vsBot {
                caption("СЛОЖНОСТЬ БОТА:")
                Picker("", selection: $gm.difficulty) {
                    ForEach(BotDifficulty.allCases) { d in Text(d.rawValue).tag(d) }
                }
                .pickerStyle(.segmented)

                caption("ТВОЯ СТОРОНА:")
                Picker("", selection: $gm.playerSide) {
                    Text("Белые").tag(Side.white)
                    Text("Чёрные").tag(Side.black)
                }
                .pickerStyle(.segmented)
            }

            caption("УПРАВЛЕНИЕ ФИГУРАМИ:")
            Picker("", selection: $gm.controlMode) {
                ForEach(ControlMode.allCases) { c in Text(c.rawValue).tag(c) }
            }
            .pickerStyle(.segmented)

            HStack {
                caption("КОНТРОЛЬ ВРЕМЕНИ:")
                Spacer()
                Picker("", selection: $gm.timeControl) {
                    ForEach(TimeControl.allCases) { t in Text(t.rawValue).tag(t) }
                }
                .pickerStyle(.menu)
                .tint(.cyan)
            }

            Toggle(isOn: $gm.isARMode) {
                Label("AR-режим (на столе)", systemImage: "camera.viewfinder")
                    .font(mono(12))
                    .foregroundColor(.cyan)
            }
        }
        .padding(16)
        .glass(18)
    }

    private var startButtons: some View {
        VStack(spacing: 10) {
            Button(action: { gm.startNewGame() }) {
                Text("КЛАССИЧЕСКАЯ ПАРТИЯ")
                    .font(mono(14))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.cyan)
                    .cornerRadius(14)
            }
            if gm.hasAutoSave {
                Button(action: { gm.continueGame() }) {
                    Text("ПРОДОЛЖИТЬ КЛАССИКУ")
                        .font(mono(12))
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .glass(14)
                }
            }
        }
    }

    private var footerRow: some View {
        HStack {
            Button(action: { showSaves = true }) {
                Label("СЕЙВЫ", systemImage: "folder.fill").font(mono(11)).foregroundColor(.yellow)
            }
            Spacer()
            Button(action: { showSettings = true }) {
                Label("НАСТРОЙКИ", systemImage: "gearshape.fill").font(mono(11)).foregroundColor(.white)
            }
            Spacer()
            Button(action: { showAIChat = true }) {
                Label("ИИ ЧАТ", systemImage: "brain.head.profile").font(mono(11)).foregroundColor(.cyan)
            }
        }
        .padding(.horizontal, 6)
    }
}

struct GameHUDOverlay: View {
    @ObservedObject var gm: GameManager
    @Binding var showAIChat: Bool
    @Binding var showArmy: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                Button(action: { gm.pauseGame() }) {
                    Image(systemName: "pause.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .glass(20)
                }
                Spacer()
                VStack(spacing: 6) {
                    if gm.isRoguelikeActive { roguelikeBar }
                    else if gm.isClockActive { clockView }
                    statusPill
                }
                Spacer()
                VStack(spacing: 6) {
                    Button(action: { showAIChat = true }) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.cyan)
                            .padding(10)
                            .glass(20)
                    }
                    if gm.isRoguelikeActive {
                        Button(action: { showArmy = true }) {
                            Image(systemName: "shield.checkerboard")
                                .foregroundColor(.orange)
                                .padding(10)
                                .glass(20)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 50)

            if gm.isCheckNow && gm.gameResult == nil {
                Text("ШАХ!")
                    .font(mono(18, .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(10)
            }

            if let banner = gm.battleBannerText {
                Text(banner)
                    .font(mono(12, .black))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .glass(12)
            }

            Spacer()

            if let tip = gm.selectedUnitTooltip {
                Text(tip)
                    .font(mono(11))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glass(12)
                    .padding(.horizontal, 14)
            }

            HStack(spacing: 8) {
                Button(action: { gm.performUndo() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Откат (\(gm.undoCount))")
                    }
                    .font(mono(11))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .glass(10)
                    .opacity(gm.undoCount > 0 ? 1.0 : 0.4)
                }

                if !gm.isARMode {
                    Button(action: { gm.toggleControlMode() }) {
                        HStack(spacing: 4) {
                            Image(systemName: gm.controlMode == .drag ? "hand.raised.fill" : "hand.tap.fill")
                            Text(gm.controlMode == .drag ? "Физика" : "Тап")
                        }
                        .font(mono(11))
                        .foregroundColor(gm.controlMode == .drag ? .orange : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .glass(10)
                    }
                    if gm.controlMode == .drag {
                        Button(action: { gm.realignPhysicsPieces() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(mono(12))
                                .foregroundColor(.green)
                                .padding(8)
                                .glass(10)
                        }
                    }
                }

                Spacer()
                Text(gm.lastMoveNotation)
                    .font(mono(11))
                    .foregroundColor(.cyan)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .glass(10)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 28)
        }
    }

    private var roguelikeBar: some View {
        let credits = (gm.roguelikeRun?.credits ?? 0) + (gm.battleState?.battleCredits ?? 0)
        let aegis = gm.battleState?.aegisLeft ?? 0
        let pawnsLeft = gm.battleState?.units.values.filter {
            $0.pieceType == 1 && !(gm.battleState?.destroyedIds.contains($0.id) ?? false)
        }.count ?? gm.alivePawnCount
        return HStack(spacing: 8) {
            Text("🪙 \(credits)").foregroundColor(.yellow)
            Text("♟️ \(pawnsLeft)").foregroundColor(pawnsLeft <= 1 ? .red : .white)
            if aegis > 0 {
                Text("🛡️ \(aegis)").foregroundColor(.green)
            }
        }
        .font(mono(12, .black))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glass(10)
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            if gm.isThinking || gm.isAdviceThinking {
                ProgressView().tint(.cyan)
            }
            Text(gm.statusText)
                .font(mono(11))
                .foregroundColor(.cyan)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glass(10)
    }

    private var clockView: some View {
        let wTurn = gm.turnIsWhite
        let wBg = wTurn ? Color.white.opacity(0.22) : Color.black.opacity(0.5)
        let bBg = wTurn ? Color.black.opacity(0.5) : Color.white.opacity(0.22)
        let wFg = wTurn ? Color.green : Color.white.opacity(0.6)
        let bFg = wTurn ? Color.white.opacity(0.6) : Color.green
        return HStack(spacing: 8) {
            Text("⚪️ \(formatSec(gm.whiteSeconds))")
                .font(mono(13)).foregroundColor(wFg)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(wBg).cornerRadius(8)
            Text("⚫️ \(formatSec(gm.blackSeconds))")
                .font(mono(13)).foregroundColor(bFg)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(bBg).cornerRadius(8)
        }
    }

    private func formatSec(_ s: Int) -> String {
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

fileprivate struct NodeBoundsKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

struct CosmicMapOverlay: View {
    @ObservedObject var gm: GameManager
    var run: RoguelikeRun
    @Binding var showRoulette: Bool
    @Binding var showArmy: Bool
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 10) {
            topHeader
            routeScrollView
            bottomActionBar
        }
        .padding(.top, 46)
        .padding(.bottom, 22)
    }

    private var topHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { gm.exitToMenu() }) {
                    Image(systemName: "house.fill")
                        .foregroundColor(.white)
                        .padding(9)
                        .glass(16)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(run.endlessLoop > 0 ? "БЕСКОНЕЧНЫЙ ЦИКЛ #\(run.endlessLoop + 1)" : "КОСМИЧЕСКИЙ МАРШРУТ")
                        .font(mono(13, .black))
                        .foregroundColor(.cyan)
                    Text("\(run.commander.rawValue) • Пройдено систем: \(run.completedNodeIds.count)/8")
                        .font(mono(10))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.white)
                        .padding(9)
                        .glass(16)
                }
            }

            HStack(spacing: 12) {
                statChip("🪙 \(run.credits)", color: .yellow)
                statChip("♟️ Пешки: \(gm.alivePawnCount)", color: gm.alivePawnCount <= 1 ? .red : .cyan)
                statChip("🛡️ \(run.aegisCharges)", color: .green)
                statChip("↩️ +\(run.bonusUndos)", color: .orange)
            }
        }
        .padding(.horizontal, 14)
    }

    private func statChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(mono(11, .bold))
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .glass(10)
    }

    private var routeScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    ForEach(Array(run.mapLayers.enumerated()), id: \.offset) { layerIdx, nodes in
                        VStack(spacing: 8) {
                            if let first = nodes.first {
                                Text("СЕКТОР \(layerIdx + 1) • \(first.planet.rawValue.uppercased())")
                                    .font(mono(10, .bold))
                                    .foregroundColor(first.planet.badgeColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.55))
                                    .cornerRadius(8)
                            }
                            HStack(spacing: 12) {
                                ForEach(nodes) { node in
                                    nodeCard(node)
                                }
                            }
                        }
                        .id(layerIdx)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
                .backgroundPreferenceValue(NodeBoundsKey.self) { anchors in
                    GeometryReader { geo in
                        Canvas { ctx, _ in
                            for layerNodes in run.mapLayers {
                                for node in layerNodes {
                                    guard let a1 = anchors[node.id] else { continue }
                                    let r1 = geo[a1]
                                    let p1 = CGPoint(x: r1.midX, y: r1.midY)
                                    for nextId in node.nextNodeIds {
                                        guard let a2 = anchors[nextId] else { continue }
                                        let r2 = geo[a2]
                                        let p2 = CGPoint(x: r2.midX, y: r2.midY)
                                        var path = Path()
                                        path.move(to: p1)
                                        path.addLine(to: p2)
                                        let isTraversed = run.completedNodeIds.contains(node.id)
                                        let isNextFromCur = (run.currentNodeId == node.id)
                                        let col = isNextFromCur ? Color.cyan : (isTraversed ? Color.green.opacity(0.6) : Color.white.opacity(0.22))
                                        ctx.stroke(path, with: .color(col), lineWidth: isNextFromCur ? 3.5 : 1.8)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                let target = min(run.mapLayers.count - 1, run.currentNodeId == nil ? 0 : run.currentLayer + 1)
                withAnimation { proxy.scrollTo(target, anchor: .center) }
            }
        }
    }

    private func nodeCard(_ node: MapNode) -> some View {
        let available = gm.isNodeAvailable(node)
        let completed = run.completedNodeIds.contains(node.id)
        let borderColor: Color = available ? .cyan : (completed ? .green : Color.white.opacity(0.15))

        return Button(action: {
            if available { gm.selectMapNode(node) }
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(node.type.icon).font(.system(size: 18))
                    if completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                Text(node.type.rawValue.uppercased())
                    .font(mono(10, .black))
                    .foregroundColor(node.type.color)
                Text(node.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 118, minHeight: 74)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(available ? Color.cyan.opacity(0.18) : (completed ? Color.green.opacity(0.10) : Color.black.opacity(0.65)))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: available ? 2.2 : 1)
            )
            .shadow(color: available ? .cyan.opacity(0.6) : .clear, radius: 8)
            .opacity((available || completed) ? 1.0 : 0.58)
        }
        .disabled(!available)
        .anchorPreference(key: NodeBoundsKey.self, value: .bounds) { [node.id: $0] }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button(action: { showRoulette = true }) {
                HStack(spacing: 6) {
                    Text("🎰")
                    Text("РУЛЕТКА (\(gm.rouletteCost) 🪙)")
                }
                .font(mono(12, .black))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(14)
            }

            Button(action: { showArmy = true }) {
                HStack(spacing: 6) {
                    Text("⚔️")
                    Text("АРМИЯ (\(run.roster.count))")
                }
                .font(mono(12, .bold))
                .foregroundColor(.cyan)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glass(14)
            }
        }
        .padding(.horizontal, 14)
    }
}

struct CommanderSelectModalView: View {
    @ObservedObject var gm: GameManager
    @Environment(\.dismiss) var dismiss
    @State private var selected: CommanderClass = .vanguard

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("ВЫБЕРИ КОМАНДИРА")
                            .font(mono(13, .black))
                            .foregroundColor(.cyan)
                        Spacer()
                        Text("✨ Осколки: \(gm.roguelikeMeta.starShards)")
                            .font(mono(12, .black))
                            .foregroundColor(.yellow)
                    }

                    ForEach(CommanderClass.allCases) { cmd in
                        commanderCard(cmd)
                    }

                    Button(action: {
                        gm.startNewRoguelike(commander: selected)
                        dismiss()
                    }) {
                        Text("🚀 ЗАПУСТИТЬ ЗАБЕГ: \(selected.rawValue.uppercased())")
                            .font(mono(14, .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(14)
                    }
                    .padding(.top, 4)

                    Divider().padding(.vertical, 4)

                    Text("✨ ЗВЁЗДНАЯ КУЗНИЦА (МЕТА-БОНУСЫ)")
                        .font(mono(12, .black))
                        .foregroundColor(.yellow)

                    ForEach(MetaPerk.allCases) { perk in
                        metaPerkRow(perk)
                    }
                }
                .padding()
            }
            .navigationTitle("Новый Космический Забег")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private func commanderCard(_ cmd: CommanderClass) -> some View {
        let isSel = selected == cmd
        return Button(action: { selected = cmd }) {
            HStack(spacing: 12) {
                Image(systemName: cmd.icon)
                    .font(.title2)
                    .foregroundColor(isSel ? .orange : .cyan)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(cmd.rawValue).font(mono(14, .black)).foregroundColor(.primary)
                        Text("• \(cmd.subtitle)").font(.caption).foregroundColor(.secondary)
                    }
                    Text(cmd.details).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.leading)
                }
                Spacer()
                if isSel {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.orange)
                }
            }
            .padding(12)
            .background(isSel ? Color.orange.opacity(0.15) : Color.gray.opacity(0.12))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSel ? Color.orange : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func metaPerkRow(_ perk: MetaPerk) -> some View {
        let unlocked = gm.roguelikeMeta.unlockedPerks.contains(perk)
        let canBuy = !unlocked && gm.roguelikeMeta.starShards >= perk.cost
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(perk.rawValue).font(mono(12, .bold))
                Text(perk.description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if unlocked {
                Text("ОТКРЫТО").font(mono(10, .black)).foregroundColor(.green)
            } else {
                Button("✨ \(perk.cost)") { gm.buyMetaPerk(perk) }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .foregroundColor(.black)
                    .disabled(!canBuy)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct RoguelikePromotionOverlay: View {
    @ObservedObject var gm: GameManager
    @State private var chosenPiece: Int = 5
    @State private var chosenBuff: AscensionBuff? = nil

    var body: some View {
        if let req = gm.pendingRoguelikePromotion {
            ZStack {
                Color.black.opacity(0.68).ignoresSafeArea()
                VStack(spacing: 14) {
                    Text("🌟 ВОЗВЫШЕНИЕ ПЕШКИ [\(req.pawnClass.title.uppercased())]")
                        .font(mono(14, .black))
                        .foregroundColor(.yellow)
                        .multilineTextAlignment(.center)

                    Text("Бонус класса: \(req.pawnClass.description)")
                        .font(.caption)
                        .foregroundColor(.cyan)
                        .multilineTextAlignment(.center)

                    Text("1. Выбери новую форму (остаётся в армии навсегда):")
                        .font(mono(11))
                        .foregroundColor(.white.opacity(0.85))

                    HStack(spacing: 8) {
                        pieceBtn("♕", "Ферзь", 5)
                        pieceBtn("♖", "Ладья", 4)
                        pieceBtn("♗", "Слон", 3)
                        pieceBtn("♘", "Конь", 2)
                    }

                    Text("2. Выбери постоянный Баф:")
                        .font(mono(11))
                        .foregroundColor(.white.opacity(0.85))

                    VStack(spacing: 8) {
                        ForEach(req.buffChoices) { buff in
                            let active = (chosenBuff ?? req.buffChoices.first) == buff
                            Button(action: { chosenBuff = buff }) {
                                HStack {
                                    Text(buff.icon).font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(buff.rawValue).font(mono(12, .black)).foregroundColor(.white)
                                        Text(buff.description).font(.caption2).foregroundColor(.white.opacity(0.75))
                                    }
                                    Spacer()
                                    if active { Image(systemName: "checkmark.circle.fill").foregroundColor(.orange) }
                                }
                                .padding(9)
                                .background(active ? Color.orange.opacity(0.28) : Color.white.opacity(0.08))
                                .cornerRadius(10)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Отмена") { gm.cancelRoguelikePromotion() }
                            .font(mono(12))
                            .foregroundColor(.white.opacity(0.7))

                        Button(action: {
                            let finalBuff = chosenBuff ?? req.buffChoices.first ?? .credits80
                            gm.confirmRoguelikePromotion(pieceType: chosenPiece, buff: finalBuff)
                        }) {
                            Text("ВОЗВЫСИТЬ!")
                                .font(mono(13, .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.yellow)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
                .glass(22)
                .padding(.horizontal, 16)
            }
        }
    }

    private func pieceBtn(_ glyph: String, _ name: String, _ type: Int) -> some View {
        let sel = chosenPiece == type
        return Button(action: { chosenPiece = type }) {
            VStack(spacing: 3) {
                Text(glyph).font(.system(size: 32))
                Text(name).font(mono(10))
            }
            .foregroundColor(.white)
            .frame(width: 66, height: 68)
            .background(sel ? Color.cyan.opacity(0.45) : Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(sel ? Color.cyan : Color.clear, lineWidth: 2))
        }
    }
}

struct RewardOverlay: View {
    @ObservedObject var gm: GameManager

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("🏆 СЕКТОР ЗАЧИЩЕН!")
                    .font(mono(20, .black))
                    .foregroundColor(.yellow)

                Text(gm.lastBattleSummary)
                    .font(mono(11))
                    .foregroundColor(.cyan)
                    .multilineTextAlignment(.center)

                Text("ВЫБЕРИ УЛУЧШЕНИЕ:")
                    .font(mono(12, .bold))
                    .foregroundColor(.white.opacity(0.8))

                ForEach(gm.rewardOptions) { opt in
                    Button(action: { gm.chooseReward(opt) }) {
                        HStack(spacing: 12) {
                            Text(opt.icon).font(.system(size: 30))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(opt.title)
                                    .font(mono(13, .black))
                                    .foregroundColor(opt.accent)
                                Text(opt.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.5))
                        }
                        .padding(14)
                        .background(opt.accent.opacity(0.14))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(opt.accent.opacity(0.5), lineWidth: 1))
                    }
                }

                Button("Пропустить награду (+30 🪙)") {
                    gm.skipRewardForGold()
                }
                .font(mono(12))
                .foregroundColor(.yellow)
                .padding(.top, 4)
            }
            .padding(22)
            .glass(22)
            .padding(.horizontal, 18)
        }
    }
}

struct ShopOverlay: View {
    @ObservedObject var gm: GameManager
    var run: RoguelikeRun
    @Binding var showRoulette: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    Text("🛒 КОСМИЧЕСКИЙ БАЗАР")
                        .font(mono(16, .black))
                        .foregroundColor(.yellow)
                    Spacer()
                    Text("🪙 \(run.credits)")
                        .font(mono(14, .black))
                        .foregroundColor(.yellow)
                }

                Button(action: { showRoulette = true }) {
                    HStack {
                        Text("🎰")
                        VStack(alignment: .leading) {
                            Text("РУЛЕТКА ПЕШЕК И КЛАССОВ")
                                .font(mono(12, .black))
                            Text("В запасе пешек: \(gm.alivePawnCount) • Крутить за \(gm.rouletteCost) 🪙")
                                .font(.caption2)
                        }
                        Spacer()
                        Text("КРУТИТЬ").font(mono(11, .black))
                    }
                    .foregroundColor(.black)
                    .padding(12)
                    .background(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(14)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 9) {
                        let damaged = run.roster.filter { $0.isDamaged }
                        if !damaged.isEmpty {
                            Text("🔧 РЕМОНТ ПОДБИТЫХ ФИГУР (40 🪙)")
                                .font(mono(10, .bold))
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(damaged) { u in
                                HStack {
                                    Text("\(pieceGlyph(u.pieceType)) \(pieceTitle(u.pieceType)) [\(u.unitClass.title)]")
                                        .font(mono(12))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button("Починить 40 🪙") { gm.repairDamagedUnit(u.id) }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.orange)
                                        .disabled(run.credits < 40)
                                }
                                .padding(10)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(10)
                            }
                        }

                        ForEach(gm.shopItems) { item in
                            HStack(spacing: 10) {
                                Text(item.icon).font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(mono(12, .bold)).foregroundColor(.white)
                                    Text(item.subtitle).font(.caption2).foregroundColor(.white.opacity(0.75))
                                }
                                Spacer()
                                if item.sold {
                                    Text("КУПЛЕНО").font(mono(10, .black)).foregroundColor(.green)
                                } else {
                                    Button("🪙 \(item.price)") { gm.buyShopItem(item) }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.cyan)
                                        .foregroundColor(.black)
                                        .disabled(run.credits < item.price)
                                }
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                        }
                    }
                }
                .frame(maxHeight: 340)

                Button(action: { gm.leaveShop() }) {
                    Text("ПРОДОЛЖИТЬ МАРШРУТ")
                        .font(mono(13, .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cyan)
                        .cornerRadius(12)
                }
            }
            .padding(18)
            .glass(22)
            .padding(.horizontal, 16)
        }
    }
}

struct EventOverlay: View {
    @ObservedObject var gm: GameManager

    var body: some View {
        ZStack {
            Color.black.opacity(0.68).ignoresSafeArea()
            if let ev = gm.activeEvent {
                VStack(spacing: 14) {
                    Text("✨ \(ev.title.uppercased())")
                        .font(mono(17, .black))
                        .foregroundColor(.purple)

                    Text(ev.story)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)

                    if let outcome = gm.eventOutcomeText {
                        Text(outcome)
                            .font(mono(12, .bold))
                            .foregroundColor(.cyan)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.cyan.opacity(0.15))
                            .cornerRadius(12)

                        Button(action: { gm.leaveCosmicEvent() }) {
                            Text("ДАЛЬШЕ")
                                .font(mono(13, .black))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.cyan)
                                .cornerRadius(12)
                        }
                    } else {
                        ForEach(ev.choices) { c in
                            Button(action: { gm.resolveCosmicEvent(c) }) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(c.label).font(mono(12, .black)).foregroundColor(.white)
                                    Text(c.effectNote).font(.caption2).foregroundColor(.cyan)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.purple.opacity(0.22))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.6), lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(22)
                .glass(22)
                .padding(.horizontal, 18)
            }
        }
    }
}

struct RouletteModalView: View {
    @ObservedObject var gm: GameManager
    @Environment(\.dismiss) var dismiss
    @State private var strip: [RoulettePrize] = []
    @State private var scrollIndex: CGFloat = 2
    @State private var isSpinning = false
    @State private var wonPrize: RoulettePrize? = nil

    private let itemW: CGFloat = 96
    private let spacing: CGFloat = 10

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Text("🪙 Баланс: \(gm.roguelikeRun?.credits ?? 0)")
                        .font(mono(14, .black))
                        .foregroundColor(.yellow)
                    Spacer()
                    Text("♟️ Пешек: \(gm.alivePawnCount)")
                        .font(mono(13, .bold))
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal)

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.4))
                        .frame(height: 132)

                    GeometryReader { geo in
                        let step = itemW + spacing
                        let centerOffset = geo.size.width / 2 - itemW / 2
                        HStack(spacing: spacing) {
                            ForEach(strip) { item in
                                VStack(spacing: 4) {
                                    Text(item.icon).font(.system(size: 32))
                                    Text(item.title)
                                        .font(mono(9, .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(width: itemW, height: 108)
                                .background(item.color.opacity(0.24))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(item.color, lineWidth: 1.5))
                            }
                        }
                        .frame(width: geo.size.width, alignment: .leading)
                        .offset(x: centerOffset - scrollIndex * step, y: 12)
                    }
                    .frame(height: 132)
                    .clipped()

                    VStack {
                        Text("▼").foregroundColor(.yellow).font(.headline)
                        Spacer()
                        Text("▲").foregroundColor(.yellow).font(.headline)
                    }
                    .frame(height: 144)
                }

                if let prize = wonPrize {
                    VStack(spacing: 4) {
                        Text("ВЫПАЛО: \(prize.icon) \(prize.title)")
                            .font(mono(14, .black))
                            .foregroundColor(prize.color)
                        Text(prize.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(10)
                    .background(prize.color.opacity(0.14))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Button(action: startSpin) {
                    Text(isSpinning ? "КРУТИМ БАРАБАН..." : "🎰 КРУТИТЬ ЗА \(gm.rouletteCost) 🪙")
                        .font(mono(14, .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background((gm.roguelikeRun?.credits ?? 0) >= gm.rouletteCost && !isSpinning ? Color.orange : Color.gray)
                        .cornerRadius(14)
                }
                .disabled(isSpinning || (gm.roguelikeRun?.credits ?? 0) < gm.rouletteCost)
                .padding(.horizontal)

                List {
                    Section("Классы пешек из капсулы") {
                        ForEach(UnitClass.allCases.filter { $0 != .standard }) { uc in
                            HStack {
                                Circle().fill(uc.swiftUIColor).frame(width: 10, height: 10)
                                VStack(alignment: .leading) {
                                    Text(uc.title).font(mono(12, .bold))
                                    Text(uc.description).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 12)
            .navigationTitle("Космическая Рулетка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }.disabled(isSpinning)
                }
            }
            .onAppear { buildInitialStrip() }
        }
    }

    private func buildInitialStrip() {
        if strip.isEmpty {
            strip = (0..<24).map { _ in gm.generateRandomRoulettePrize() }
            scrollIndex = 2
        }
    }

    private func startSpin() {
        guard !isSpinning, let win = gm.spinRoulette() else { return }
        isSpinning = true
        wonPrize = nil
        var arr = (0..<24).map { _ in gm.generateRandomRoulettePrize() }
        arr[20] = win
        strip = arr
        scrollIndex = 1

        SoundEngine.shared.play("select", enabled: gm.sfxEnabled)
        for k in 1...10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 0.16) {
                SoundEngine.shared.play("click", enabled: gm.sfxEnabled)
            }
        }

        withAnimation(.timingCurve(0.10, 0.90, 0.18, 1.0, duration: 2.1)) {
            scrollIndex = 20
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.15) {
            isSpinning = false
            wonPrize = win
            SoundEngine.shared.play("win", enabled: gm.sfxEnabled)
        }
    }
}

struct ArmyModalView: View {
    @ObservedObject var gm: GameManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let run = gm.roguelikeRun {
                    Section("Армия (\(run.roster.filter { $0.isDeployed && !$0.isDamaged }.count) в строю • до 8 пешек и 8 фигур)") {
                        ForEach(run.roster) { u in
                            HStack {
                                Text(pieceGlyph(u.pieceType)).font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(pieceTitle(u.pieceType)).font(mono(13, .bold))
                                        if u.unitClass != .standard {
                                            Text(u.unitClass.title)
                                                .font(mono(9, .black))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(u.unitClass.swiftUIColor)
                                                .cornerRadius(5)
                                        }
                                        if u.isDamaged {
                                            Text("ПОДБИТА").font(mono(9, .black)).foregroundColor(.red)
                                        }
                                    }
                                    if u.unitClass != .standard {
                                        Text(u.unitClass.description).font(.caption2).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if u.pieceType != 6 && !u.isDamaged && run.phase == .map {
                                    Button(u.isDeployed ? "В строю" : "Резерв") {
                                        gm.toggleUnitDeployment(u.id)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(u.isDeployed ? .green : .gray)
                                }
                            }
                        }
                    }

                    Section("Пассивки Короля и Реликвии (\(run.relics.count))") {
                        if run.relics.isEmpty {
                            Text("Пока нет реликвий").foregroundColor(.secondary)
                        } else {
                            ForEach(run.relics) { r in
                                HStack(alignment: .top) {
                                    Text(r.icon).font(.title3)
                                    VStack(alignment: .leading) {
                                        Text(r.rawValue).font(mono(12, .bold))
                                        Text(r.description).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Отряд и Реликвии")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

struct RunEndOverlay: View {
    @ObservedObject var gm: GameManager
    var run: RoguelikeRun
    @Binding var showCommanderSelect: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(run.phase == .victory ? "👑 ТРИУМФ!" : "💀 СМЕРТЬ — КОНЕЦ ЗАБЕГА")
                    .font(mono(14, .black))
                    .foregroundColor(run.phase == .victory ? .yellow : .red)

                Text(gm.runEndTitle)
                    .font(mono(20, .black))
                    .foregroundColor(.cyan)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 6) {
                    statRow("Пройдено боёв:", "\(run.battlesWon)")
                    statRow("Побеждено элит:", "\(run.elitesDefeated)")
                    statRow("Возвышено пешек:", "\(run.pawnsPromoted)")
                    statRow("Срублено врагов:", "\(run.enemiesCaptured)")
                    statRow("Потеряно пешек:", "\(run.pawnsLost)")
                    Divider()
                    statRow("Получено Осколков:", "+\(gm.runEndShardsEarned) ✨")
                }
                .font(mono(12))
                .foregroundColor(.white)
                .padding(14)
                .background(Color.white.opacity(0.08))
                .cornerRadius(14)

                if run.phase == .victory {
                    Button(action: { gm.continueIntoEndlessLoop() }) {
                        Text("🔥 В БЕСКОНЕЧНЫЙ РЕЖИМ (ЦИКЛ #\(run.endlessLoop + 2))")
                            .font(mono(12, .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                }

                Button(action: {
                    gm.abandonRoguelikeRun()
                    showCommanderSelect = true
                }) {
                    Text("🚀 НОВЫЙ ЗАБЕГ")
                        .font(mono(14, .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cyan)
                        .cornerRadius(12)
                }

                Button("В главное меню") { gm.abandonRoguelikeRun() }
                    .font(mono(12))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(24)
            .glass(22)
            .padding(.horizontal, 22)
        }
    }

    private func statRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(v).foregroundColor(.yellow)
        }
    }
}

struct PromotionOverlay: View {
    @ObservedObject var gm: GameManager

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("ПРЕВРАЩЕНИЕ ПЕШКИ")
                    .font(mono(14))
                    .foregroundColor(.white)
                HStack(spacing: 10) {
                    promoButton("♕", "Ферзь", 5)
                    promoButton("♖", "Ладья", 4)
                    promoButton("♗", "Слон", 3)
                    promoButton("♘", "Конь", 2)
                }
                Button("Отмена") { gm.cancelPromotion() }
                    .font(mono(12))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(22)
            .glass(22)
        }
    }

    private func promoButton(_ glyph: String, _ name: String, _ type: Int) -> some View {
        Button(action: { gm.choosePromotion(type) }) {
            VStack(spacing: 4) {
                Text(glyph).font(.system(size: 38))
                Text(name).font(mono(10))
            }
            .foregroundColor(.white)
            .frame(width: 66, height: 78)
            .background(Color.cyan.opacity(0.25))
            .cornerRadius(12)
        }
    }
}

struct GameOverOverlay: View {
    @ObservedObject var gm: GameManager
    @State private var hidden = false

    var body: some View {
        Group {
            if !hidden {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    VStack(spacing: 14) {
                        Text("ПАРТИЯ ОКОНЧЕНА")
                            .font(mono(13))
                            .foregroundColor(.white.opacity(0.7))
                        Text(gm.gameResult?.title ?? "")
                            .font(mono(20, .black))
                            .foregroundColor(.cyan)
                            .multilineTextAlignment(.center)
                        Button(action: { gm.restartGame() }) {
                            Text("РЕВАНШ")
                                .font(mono(14))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.cyan)
                                .cornerRadius(12)
                        }
                        Button(action: { hidden = true }) {
                            Text("Осмотреть доску").font(mono(12)).foregroundColor(.white)
                        }
                        Button(action: { gm.exitToMenu() }) {
                            Text("В главное меню").font(mono(12)).foregroundColor(.red)
                        }
                    }
                    .padding(24)
                    .glass(22)
                    .padding(.horizontal, 30)
                }
            }
        }
    }
}

struct PauseMenuOverlay: View {
    @ObservedObject var gm: GameManager
    @Binding var showSaves: Bool
    @Binding var showSettings: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("ПАУЗА").font(mono(26, .black)).foregroundColor(.white)
                Button("Продолжить") { gm.resumeGame() }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                Button("Настройки") { showSettings = true }
                    .buttonStyle(.bordered)
                if !gm.isRoguelikeActive {
                    Button("Сохранить партию") { showSaves = true }
                        .buttonStyle(.bordered)
                    Button("Новая партия") {
                        gm.isPaused = false
                        gm.restartGame()
                    }
                    .buttonStyle(.bordered)
                }
                Button(gm.isRoguelikeActive ? "Вернуться на карту / в меню" : "Выход в главное меню") {
                    gm.exitToMenu()
                }
                .foregroundColor(.cyan)
                if gm.isRoguelikeActive {
                    Button("Сдаться (Завершить забег)") {
                        gm.isPaused = false
                        gm.abandonRoguelikeRun()
                    }
                    .foregroundColor(.red)
                }
            }
            .padding(26)
            .glass(20)
        }
    }
}

struct AIChatModalView: View {
    @ObservedObject var gm: GameManager
    @Environment(\.dismiss) var dismiss
    @State private var input = ""

    var body: some View {
        NavigationStack {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(gm.chat) { msg in
                                bubble(msg).id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: gm.chat.count) { _ in
                        if let last = gm.chat.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("🧠 Лучший ход?") { gm.sendUserMessage("Какой ход лучший?") }
                            .buttonStyle(.bordered)
                            .tint(.cyan)
                        Button("⚖️ Оцени позицию") { gm.sendUserMessage("Оцени шансы") }
                            .buttonStyle(.bordered)
                            .tint(.cyan)
                    }
                    .padding(.horizontal)
                }
                HStack {
                    TextField("Сообщение ИИ...", text: $input)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { send() }
                    Button(action: { send() }) {
                        Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundColor(.cyan)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .padding(.top, 4)
            }
            .navigationTitle("AI Каспаров-9000")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private func send() {
        gm.sendUserMessage(input)
        input = ""
    }

    @ViewBuilder private func bubble(_ msg: ChatMessage) -> some View {
        if msg.sender == "Ты" {
            HStack {
                Spacer()
                VStack(alignment: .trailing) {
                    Text(msg.sender).font(.caption2).foregroundColor(.gray)
                    Text(msg.text).padding(10).background(Color.cyan.opacity(0.3)).cornerRadius(12)
                }
            }
        } else {
            HStack {
                VStack(alignment: .leading) {
                    Text(msg.sender).font(.caption2).foregroundColor(.gray)
                    Text(msg.text).padding(10).background(Color.gray.opacity(0.2)).cornerRadius(12)
                }
                Spacer()
            }
        }
    }
}

struct SettingsModalView: View {
    @ObservedObject var gm: GameManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Звук и музыка")) {
                    Toggle("Звуковые эффекты", isOn: $gm.sfxEnabled)
                    Toggle("Фоновая музыка космоса", isOn: $gm.musicEnabled)
                    Toggle("Голос комментатора", isOn: $gm.voiceEnabled)
                }
                Section(header: Text("Управление и гироскоп")) {
                    Picker("Режим фигур", selection: $gm.controlMode) {
                        ForEach(ControlMode.allCases) { c in Text(c.rawValue).tag(c) }
                    }
                    .pickerStyle(.segmented)
                    Text("В режиме «Руками (Физика)» фигуры можно брать и переносить пальцем, сталкивать друг с другом и опрокидывать двойным нажатием.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Toggle("Камера по гироскопу", isOn: $gm.gyroEnabled)
                    if gm.gyroEnabled {
                        Button("Калибровать гироскоп") {
                            gm.space.recalibrateGyro()
                        }
                    }
                }
                Section(header: Text("Графика RTX 4K")) {
                    Picker("Качество", selection: $gm.graphicsQuality) {
                        ForEach(GraphicsQuality.allCases) { q in Text(q.rawValue).tag(q) }
                    }
                    .pickerStyle(.segmented)
                    Text("Ультра: 4K текстуры, Metal-шейдеры, лакировка ClearCoat, двойные тени, DoF боке, TAA, лучи света и взрывы метеоритов.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section(header: Text("Игра")) {
                    Toggle("Подсвечивать доступные ходы", isOn: $gm.showHints)
                    Picker("Сложность бота (Классика)", selection: $gm.difficulty) {
                        ForEach(BotDifficulty.allCases) { d in Text(d.rawValue).tag(d) }
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

struct SavesModalView: View {
    @ObservedObject var gm: GameManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !gm.inMenu && !gm.isRoguelikeActive {
                    Section("Сохранить партию") {
                        ForEach(1...3, id: \.self) { num in
                            Button("Сохранить в слот #\(num)") {
                                gm.saveToSlot(slotId: "slot_\(num)", title: "Слот #\(num)")
                                dismiss()
                            }
                        }
                    }
                }
                Section("Загрузить партию") {
                    if gm.saveSlots.isEmpty {
                        Text("Нет сохранений").foregroundColor(.secondary)
                    } else {
                        ForEach(gm.saveSlots) { slot in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(slot.title).font(.headline)
                                    Text("\(slot.dateString) • Ход \(slot.board.fullmove)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Загрузить") {
                                    gm.loadFromSlot(slot)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    gm.deleteSlot(slot.id)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Слоты сохранений")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

