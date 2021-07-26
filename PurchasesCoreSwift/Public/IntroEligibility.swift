//
//  IntroEligibility.swift
//  PurchasesCoreSwift
//
//  Created by Joshua Liebowitz on 7/6/21.
//  Copyright © 2021 Purchases. All rights reserved.
//

import Foundation

/**
 @typedef RCIntroEligibilityStatus
 @brief Enum of different possible states for intro price eligibility status.
 @constant RCIntroEligibilityStatusUnknown RevenueCat doesn't have enough information to determine eligibility.
 @constant RCIntroEligibilityStatusIneligible The user is not eligible for a free trial or intro pricing for this product.
 @constant RCIntroEligibilityStatusEligible The user is eligible for a free trial or intro pricing for this product.
 */
@objc(RCIntroEligibilityStatus) public enum IntroEligibilityStatus: Int {
    /**
     RevenueCat doesn't have enough information to determine eligibility.
     */
    case unknown = 0
    /**
     The user is not eligible for a free trial or intro pricing for this product.
     */
    case ineligible
    /**
     The user is eligible for a free trial or intro pricing for this product.
     */
    case eligible
}

private extension IntroEligibilityStatus {

    enum IntroEligibilityStatusError: LocalizedError {
        case invalidStatusCode(Int)

        var errorDescription: String? {
            switch self {
            case .invalidStatusCode(let code):
                return "😿 Invalid status code: \(code)"
            }
        }
    }

    init(statusCode: Int) throws {
        switch statusCode {
        case 0:
            self = .unknown
        case 1:
            self = .ineligible
        case 2:
            self = .eligible
        default:
            throw IntroEligibilityStatusError.invalidStatusCode(statusCode)
        }
    }
}

/**
 Class that holds the introductory price status
 */
@objc(RCIntroEligibility) public class IntroEligibility: NSObject {

    /**
     The introductory price eligibility status
     */
    @objc public let status: IntroEligibilityStatus

    @objc required public init(eligibilityStatus status: IntroEligibilityStatus) {
        self.status = status
    }

    @objc public init(eligibilityStatusCode statusCode: NSNumber) throws {
        self.status = try IntroEligibilityStatus(statusCode: statusCode.intValue)
    }

    @objc public override init() {
        self.status = .unknown
    }

    public override var description: String {
        switch status {
        case .eligible:
            return "Eligible for trial or introductory price."
        case .ineligible:
            return "Not eligible for trial or introductory price."
        default:
            return "Status indeterminate."
        }
    }

}