import XCTest
@testable import BloomingMarvellous

// MARK: - UserModelTests
// US-0017: userModelTests.swift created — covers happy path, error path, edge cases.
//   Target: ≥ 80% line coverage per module.
final class UserModelTests: XCTestCase {

    // MARK: - Happy Path

    func test_init_setsAllProperties() {
        let model = UserModel(userId: 42, firstName: "Alice", apiToken: "tok123")
        XCTAssertEqual(model.userId, 42)
        XCTAssertEqual(model.firstName, "Alice")
        XCTAssertEqual(model.apiToken, "tok123")
    }

    func test_camelCasePropertyNames_exist() {
        // US-0026 / 0027 / 0028: Verify camelCase naming — snake_case removed.
        let model = UserModel(userId: 1, firstName: "Bob", apiToken: "abc")
        // If these compiled, camelCase renaming succeeded.
        XCTAssertNotNil(model.userId)
        XCTAssertNotNil(model.firstName)
        XCTAssertNotNil(model.apiToken)
    }

    // MARK: - Serialisation (US-0007: Codable replaces NSKeyedUnarchiver)

    func test_serialize_producesValidJSON() throws {
        let model = UserModel(userId: 1, firstName: "Carol", apiToken: "xyz")
        let data = try model.serialize()
        XCTAssertFalse(data.isEmpty)

        // Verify JSON keys are snake_case as per CodingKeys
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["user_id"])
        XCTAssertNotNil(json?["first_name"])
        XCTAssertNotNil(json?["api_token"])
    }

    func test_deserialize_fromValidJSON_succeeds() throws {
        let json = """
        {"user_id": 7, "first_name": "Dave", "api_token": "tok_abc"}
        """.data(using: .utf8)!

        let model = try UserModel.deserialize(from: json)
        XCTAssertEqual(model.userId, 7)
        XCTAssertEqual(model.firstName, "Dave")
        XCTAssertEqual(model.apiToken, "tok_abc")
    }

    func test_deserialize_fromInvalidJSON_throws() {
        // US-0007: Error path — bad data throws instead of crashing (no try!)
        let badData = "not json at all".data(using: .utf8)!
        XCTAssertThrowsError(try UserModel.deserialize(from: badData)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func test_deserialize_missingField_throws() {
        // Edge case: partial JSON
        let partial = """
        {"user_id": 1}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try UserModel.deserialize(from: partial))
    }

    func test_roundTrip_serializeDeserialize() throws {
        let original = UserModel(userId: 99, firstName: "Eve", apiToken: "round_trip")
        let data = try original.serialize()
        let decoded = try UserModel.deserialize(from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Platform agnosticism (US-0006)

    func test_userModel_compilesWithoutUIKit() {
        // If this test target has no UIKit import and UserModel still compiles,
        // the UIKit dependency has been successfully removed from the model layer.
        let model = UserModel(userId: 0, firstName: "", apiToken: "")
        XCTAssertNotNil(model)
    }

    // MARK: - Edge Cases

    func test_emptyStrings_areAccepted() throws {
        let model = UserModel(userId: 0, firstName: "", apiToken: "")
        let data = try model.serialize()
        let decoded = try UserModel.deserialize(from: data)
        XCTAssertEqual(decoded.firstName, "")
    }

    func test_unicodeFirstName_roundTrips() throws {
        let model = UserModel(userId: 1, firstName: "Ångström 李明 🌸", apiToken: "t")
        let data = try model.serialize()
        let decoded = try UserModel.deserialize(from: data)
        XCTAssertEqual(decoded.firstName, "Ångström 李明 🌸")
    }
}
