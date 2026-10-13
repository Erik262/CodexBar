import Testing
@testable import CodexBar

struct SparkleUpdatePolicyTests {
    private static let feed = "https://example.invalid/appcast.xml"

    @Test
    func `developer ID builds update from their feed`() {
        #expect(SparkleUpdatePolicy.isEnabled(developerIDSigned: true, allowsAdHocUpdates: false, feedURL: Self.feed))
    }

    @Test
    func `ad-hoc builds stay disabled unless packaging opted in`() {
        #expect(!SparkleUpdatePolicy.isEnabled(developerIDSigned: false, allowsAdHocUpdates: false, feedURL: Self.feed))
        #expect(SparkleUpdatePolicy.isEnabled(developerIDSigned: false, allowsAdHocUpdates: true, feedURL: Self.feed))
    }

    @Test
    func `a build without a feed never enables updates`() {
        for feed in [nil, "", "  "] {
            #expect(!SparkleUpdatePolicy.isEnabled(developerIDSigned: true, allowsAdHocUpdates: true, feedURL: feed))
        }
    }
}
