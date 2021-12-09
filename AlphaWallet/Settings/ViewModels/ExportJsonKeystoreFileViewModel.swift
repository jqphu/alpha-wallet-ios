//
//  ExportJsonKeystoreFileViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 10/12/21.
//

import Foundation
import PromiseKit

class ExportJsonKeystoreFileViewModel {
    private let keystore: Keystore

    init(keystore: Keystore) {
        self.keystore = keystore
    }

    func computeJsonKeystore(password: String) -> Promise<String> {
        return Promise {seal in
            if keystore.isHdWallet(wallet: keystore.currentWallet) {
                // TODO: Convert from HDWallet into Non-HDWallet then export
                seal.reject(KeystoreError.userCancelled)
            } else {
                keystore.exportRawPrivateKeyForNonHdWalletForBackup(forAccount: self.keystore.currentWallet.address, newPassword: password) { result in
                    switch result {
                    case .success(let jsonString):
                        seal.fulfill(jsonString)
                    case .failure(let error):
                        seal.reject(error)
                    }
                }
            }
        }
    }
}
