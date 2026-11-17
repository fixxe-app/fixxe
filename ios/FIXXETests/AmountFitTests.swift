import XCTest
@testable import FIXXE

/// Длинная сумма в поле ввода уменьшается, а не обрезается — как на Android и в вебе.
final class AmountFitTests: XCTestCase {
    private let base: CGFloat = 20, field: CGFloat = 126

    func testRule() {
        XCTAssertEqual(AmountFit.size(base: 22, widthAtBase: 100, available: 130), 22)
        XCTAssertEqual(AmountFit.size(base: 22, widthAtBase: 130, available: 130), 22)
        XCTAssertEqual(AmountFit.size(base: 22, widthAtBase: 200, available: 130), 22 * 130 / 200, accuracy: 1e-9)
        XCTAssertEqual(AmountFit.size(base: 22, widthAtBase: 1000, available: 130), 11)
        XCTAssertEqual(AmountFit.size(base: 22, widthAtBase: 0, available: 130), 22)
    }

    func testShortAmountKeepsNormalSize() {
        XCTAssertEqual(AmountFit.fontSize(for: "150 000", base: base, width: field), base)
        XCTAssertEqual(AmountFit.fontSize(for: "", base: base, width: field), base)
    }

    func testLongAmountShrinksToFit() {
        for text in ["1 500 000 000", "150000000000000", "17 644 725 250,55"] {
            let size = AmountFit.fontSize(for: text, base: base, width: field)
            XCTAssertLessThan(size, base, "\(text) не уменьшилась")
            XCTAssertLessThanOrEqual(AmountFit.width(text, size: size), field, "\(text) не влезает при \(size)")
        }
    }

    func testNeverBelowHalf() {
        XCTAssertEqual(AmountFit.fontSize(for: "150 000 000 000 000 000 000 000", base: base, width: field), base / 2)
    }
}
