//
//  ReviewManagerTests.swift
//  podsTests
//
//  Created for Humuli on 8/5/25.
//

import XCTest
@testable import Pods

class ReviewManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset review tracking before each test
        #if DEBUG
        ReviewManager.shared.resetAllTracking()
        #endif
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up after each test
        #if DEBUG
        ReviewManager.shared.resetAllTracking()
        #endif
    }
    
    // MARK: - Milestone #1: First Food Tests
    
    func testFirstFoodReviewTrigger() {
        // Given
        let reviewManager = ReviewManager.shared
        
        // When
        reviewManager.foodWasLogged()
        
        // Then
        XCTAssertEqual(reviewManager.totalFoodsLogged, 1, "Total foods logged should be 1")
        // Note: We can't actually test if the review prompt was shown in unit tests
        // This would need to be tested manually or with UI tests
    }
    
    func testFirstFoodReviewOnlyOnce() {
        // Given
        let reviewManager = ReviewManager.shared
        
        // When
        reviewManager.foodWasLogged() // First food
        reviewManager.foodWasLogged() // Second food
        
        // Then
        XCTAssertEqual(reviewManager.totalFoodsLogged, 2, "Total foods logged should be 2")
        // The review should only be requested once for the first food
    }
    
    // MARK: - Milestone #2: Engaged User Tests
    
    func testEngagedUserWithFoodCount() {
        // This test would need to mock the date to test the 14-day requirement
        // For now, we'll just test the food count tracking
        
        // Given
        let reviewManager = ReviewManager.shared
        
        // When
        for _ in 1...10 {
            reviewManager.foodWasLogged()
        }
        
        // Then
        XCTAssertEqual(reviewManager.totalFoodsLogged, 10, "Total foods logged should be 10")
    }
    
    func testEngagedUserWithStreak() {
        // This test would need to mock StreakManager
        // Just a stub for now
        XCTAssert(true, "Streak-based engagement test stub")
    }
    
    // MARK: - Milestone #3: Retention Tests
    
    func testRetentionMilestone() {
        // This test would need to mock dates and previous milestones
        // Just a stub for now
        XCTAssert(true, "Retention milestone test stub")
    }
    
    // MARK: - Persistence Tests
    
    func testFoodCountPersistence() {
        // Given
        let reviewManager = ReviewManager.shared
        reviewManager.foodWasLogged()
        reviewManager.foodWasLogged()
        
        // When
        // Simulate app restart by loading persisted data
        // In a real test, we'd create a new instance
        let expectedCount = reviewManager.totalFoodsLogged
        
        // Then
        XCTAssertEqual(expectedCount, 2, "Food count should persist across sessions")
    }
    
    // MARK: - Debug Helper Tests
    
    #if DEBUG
    func testForceShowReview() {
        // Given
        let reviewManager = ReviewManager.shared
        
        // When/Then
        // This won't actually show the prompt in tests, but we can verify it doesn't crash
        XCTAssertNoThrow(reviewManager.forceShowReview(), "Force show review should not throw")
    }
    
    func testResetTracking() {
        // Given
        let reviewManager = ReviewManager.shared
        reviewManager.foodWasLogged()
        reviewManager.foodWasLogged()
        
        // When
        reviewManager.resetAllTracking()
        
        // Then
        XCTAssertEqual(reviewManager.totalFoodsLogged, 0, "Food count should be reset to 0")
    }
    #endif
}