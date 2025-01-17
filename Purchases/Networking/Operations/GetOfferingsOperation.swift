//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  GetOfferingsOperation.swift
//
//  Created by Joshua Liebowitz on 11/19/21.

import Foundation

class GetOfferingsOperation: CacheableNetworkOperation {

    private let offeringsCallbackCache: CallbackCache<OfferingsCallback>
    private let configuration: AppUserConfiguration

    init(configuration: UserSpecificConfiguration,
         offeringsCallbackCache: CallbackCache<OfferingsCallback>) {
        self.configuration = configuration
        self.offeringsCallbackCache = offeringsCallbackCache

        super.init(configuration: configuration, individualizedCacheKeyPart: configuration.appUserID)
    }

    override func begin(completion: @escaping () -> Void) {
        self.getOfferings(completion: completion)
    }

}

private extension GetOfferingsOperation {

    func getOfferings(completion: @escaping () -> Void) {
        guard let appUserID = try? configuration.appUserID.escapedOrError() else {
            self.offeringsCallbackCache.performOnAllItemsAndRemoveFromCache(withCacheable: self) { callback in
                callback.completion(nil, ErrorUtils.missingAppUserIDError())
            }
            completion()

            return
        }

        let path = "/subscribers/\(appUserID)/offerings"
        httpClient.performGETRequest(path: path,
                                     headers: authHeaders) { statusCode, response, error in
            defer {
                completion()
            }

            if error == nil && statusCode < HTTPStatusCodes.redirect.rawValue {
                self.offeringsCallbackCache.performOnAllItemsAndRemoveFromCache(withCacheable: self) { callbackObject in
                    callbackObject.completion(response, nil)
                }
                return
            }

            let errorForCallbacks: Error
            if let error = error {
                errorForCallbacks = ErrorUtils.networkError(withUnderlyingError: error)
            } else if statusCode >= HTTPStatusCodes.redirect.rawValue {
                let backendCode = BackendErrorCode(code: response?["code"])
                let backendMessage = response?["message"] as? String
                errorForCallbacks = ErrorUtils.backendError(withBackendCode: backendCode,
                                                            backendMessage: backendMessage)
            } else {
                let subErrorCode = UnexpectedBackendResponseSubErrorCode.getOfferUnexpectedResponse
                errorForCallbacks = ErrorUtils.unexpectedBackendResponse(withSubError: subErrorCode)
            }

            let responseString = response?.debugDescription
            Logger.error(Strings.backendError.unknown_get_offerings_error(statusCode: statusCode,
                                                                          responseString: responseString))
            self.offeringsCallbackCache.performOnAllItemsAndRemoveFromCache(withCacheable: self) { callbackObject in
                callbackObject.completion(nil, errorForCallbacks)
            }
        }
    }

}
