//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  BeginRefundRequestHelper.swift
//
//  Created by Madeline Beyl on 10/13/21.

import Foundation

/**
 * Helper class responsible for handling any non-store-specific code involved in beginning a refund request.
 * Delegates store-specific operations to `SK2BeginRefundRequestHelper`.
 */
class BeginRefundRequestHelper {

    private let systemInfo: SystemInfo
    private let customerInfoManager: CustomerInfoManager
    private let identityManager: IdentityManager

#if os(iOS)
    @available(iOS 15.0, *)
    @available(macOS, unavailable)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    lazy var sk2Helper = SK2BeginRefundRequestHelper()
#endif

    init(systemInfo: SystemInfo, customerInfoManager: CustomerInfoManager, identityManager: IdentityManager) {
        self.systemInfo = systemInfo
        self.customerInfoManager = customerInfoManager
        self.identityManager = identityManager
    }

#if os(iOS)
    /*
     * Entry point for beginning the refund request. Handles getting the current windowScene and verifying the
     * transaction before calling into `SK2BeginRefundRequestHelper`'s `initiateRefundRequest`.
     */
    @available(iOS 15.0, *)
    @available(macOS, unavailable)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    @MainActor
    func beginRefundRequest(forProduct productID: String) async throws -> RefundRequestStatus {
        guard let windowScene = systemInfo.sharedUIApplication?.currentWindowScene else {
            throw ErrorUtils.storeProblemError(withMessage: "Failed to get UIWindowScene")
        }

        let transactionID = try await sk2Helper.verifyTransaction(productID: productID)
        return try await sk2Helper.initiateRefundRequest(transactionID: transactionID,
                                                         windowScene: windowScene)
    }

    @available(iOS 15.0, *)
    @available(macOS, unavailable)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    func beginRefundRequest(forEntitlement entitlementID: String) async throws -> RefundRequestStatus {
        let entitlement = try await getEntitlement(entitlementID: entitlementID)
        return try await self.beginRefundRequest(forProduct: entitlement.productIdentifier)
    }

    @available(iOS 15.0, *)
    @available(macOS, unavailable)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    func beginRefundRequestForActiveEntitlement() async throws -> RefundRequestStatus {
        let activeEntitlement = try await getEntitlement(entitlementID: nil)
        return try await self.beginRefundRequest(forProduct: activeEntitlement.productIdentifier)
    }
#endif
}

#if os(iOS)
@available(iOS 15.0, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
private extension BeginRefundRequestHelper {

    /*
     * Gets entitlement with the given `entitlementID` from customerInfo, or the active entitlement
     * if no ID passed in.
     */
    func getEntitlement(entitlementID: String?) async throws -> EntitlementInfo {
        let currentAppUserID = identityManager.currentAppUserID
        return try await withCheckedThrowingContinuation { continuation in
            customerInfoManager.customerInfo(appUserID: currentAppUserID) { customerInfo, error in
                if let error = error {
                    let message = Strings.purchase.begin_refund_customer_info_error(
                        entitlementID: entitlementID).description
                    continuation.resume(
                        throwing: ErrorUtils.beginRefundRequestError(withMessage: message, error: error))
                    Logger.error(message)
                    return
                }

                guard let customerInfo = customerInfo else {
                    let message = Strings.purchase.begin_refund_for_entitlement_nil_customer_info(
                        entitlementID: entitlementID).description
                    continuation.resume(throwing: ErrorUtils.beginRefundRequestError(withMessage: message))
                    Logger.error(message)
                    return
                }

                if let entitlementID = entitlementID {
                    guard let entitlement = customerInfo.entitlements[entitlementID] else {
                        let message = Strings.purchase.begin_refund_no_entitlement_found(
                            entitlementID: entitlementID).description
                        continuation.resume(throwing: ErrorUtils.beginRefundRequestError(withMessage: message))
                        Logger.error(message)
                        return
                    }
                    continuation.resume(returning: entitlement)
                    return
                }

                guard customerInfo.entitlements.active.count < 2 else {
                    let message = Strings.purchase.begin_refund_multiple_active_entitlements.description
                    continuation.resume(throwing: ErrorUtils.beginRefundRequestError(withMessage: message))
                    return
                }

                guard let activeEntitlement = customerInfo.entitlements.active.first?.value else {
                    let message = Strings.purchase.begin_refund_no_active_entitlement.description
                    continuation.resume(throwing: ErrorUtils.beginRefundRequestError(withMessage: message))
                    Logger.error(message)
                    return
                }

                continuation.resume(returning: activeEntitlement)
            }
        }
    }

}
#endif

/// Status codes for refund requests.
@objc(RCRefundRequestStatus) public enum RefundRequestStatus: Int {

    /// User canceled submission of the refund request.
    @objc(RCRefundRequestUserCancelled) case userCancelled = 0
    /// Apple has received the refund request.
    @objc(RCRefundRequestSuccess) case success
    /// There was an error with the request. See message for more details.
    @objc(RCRefundRequestError) case error

}
