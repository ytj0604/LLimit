import Foundation
import XCTest
@testable import LLimit

final class AnthropicUsageAPITests: XCTestCase {
    func testMapsFableWeeklyScopedLimit() throws {
        let json = """
        {
          "five_hour": {
            "utilization": 15.0,
            "resets_at": "2026-07-31T12:00:00+00:00"
          },
          "seven_day": {
            "utilization": 40.0,
            "resets_at": "2026-08-06T12:00:00+00:00"
          },
          "seven_day_opus": null,
          "seven_day_sonnet": null,
          "limits": [
            {
              "kind": "session",
              "percent": 15,
              "is_active": false
            },
            {
              "kind": "weekly_all",
              "percent": 40,
              "is_active": false
            },
            {
              "kind": "weekly_scoped",
              "percent": 68,
              "resets_at": "2026-08-06T12:00:00+00:00",
              "scope": {
                "model": {
                  "id": null,
                  "display_name": "Fable"
                }
              },
              "is_active": true
            }
          ]
        }
        """

        let limits = try JSONDecoder().decode(
            AnthropicUsageAPI.RateLimits.self,
            from: Data(json.utf8)
        )
        let windows = AnthropicUsageAPI.usageWindows(from: limits)

        XCTAssertEqual(windows.map(\.label), ["5h", "7d", "7d Fable"])
        XCTAssertEqual(try XCTUnwrap(windows[0].usedPercent), 0.15, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(windows[1].usedPercent), 0.40, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(windows[2].usedPercent), 0.68, accuracy: 0.0001)
        XCTAssertNotNil(windows[2].resetsAt)
    }

    func testSupportsFutureScopedModelsWithoutHardcoding() throws {
        let json = """
        {
          "limits": [
            {
              "kind": "weekly_scoped",
              "utilization": 27,
              "scope": {
                "model": {
                  "display_name": "Future Model"
                }
              }
            }
          ]
        }
        """

        let limits = try JSONDecoder().decode(
            AnthropicUsageAPI.RateLimits.self,
            from: Data(json.utf8)
        )
        let windows = AnthropicUsageAPI.usageWindows(from: limits)

        XCTAssertEqual(windows.map(\.label), ["7d Future Model"])
        XCTAssertEqual(try XCTUnwrap(windows[0].usedPercent), 0.27, accuracy: 0.0001)
    }

    func testPrefersActiveScopedEntryAndAvoidsLegacyDuplicate() throws {
        let json = """
        {
          "seven_day_opus": {
            "utilization": 50
          },
          "limits": [
            {
              "kind": "weekly_scoped",
              "percent": 80,
              "scope": {
                "model": {
                  "display_name": "Opus"
                }
              },
              "is_active": false
            },
            {
              "kind": "weekly_scoped",
              "percent": 30,
              "scope": {
                "model": {
                  "display_name": "Claude Opus 5"
                }
              },
              "is_active": true
            }
          ]
        }
        """

        let limits = try JSONDecoder().decode(
            AnthropicUsageAPI.RateLimits.self,
            from: Data(json.utf8)
        )
        let windows = AnthropicUsageAPI.usageWindows(from: limits)

        XCTAssertEqual(windows.map(\.label), ["7d Claude Opus 5"])
        XCTAssertEqual(try XCTUnwrap(windows[0].usedPercent), 0.30, accuracy: 0.0001)
    }
}
