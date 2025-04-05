import XCTest
@testable import Scanner

class ViewControllerLoadPerformanceTests: XCTestCase {

    func testMainViewControllerLoadPerformance() {
        self.measure {
            // Replace "Main" with your storyboard name and "MainViewControllerID" with the view controller’s identifier.
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let viewController = storyboard.instantiateViewController(withIdentifier: "HomeScreenView") as? HomeScreenView else {
                XCTFail("Could not instantiate MainViewController")
                return
            }
            // Load the view hierarchy
//            viewController.start
        }
    }
    
    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

}

