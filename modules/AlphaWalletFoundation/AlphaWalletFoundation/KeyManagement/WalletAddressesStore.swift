//
//  WalletStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.01.2022.
//

import Foundation
import Combine

public protocol WalletAddressesStoreMigration {
    func migrate(to store: WalletAddressesStore) -> WalletAddressesStore
}

public protocol WalletAddressesStore: WalletAddressesStoreMigration {
    var watchAddresses: [String] { get set }
    var ethereumAddressesWithPrivateKeys: [String] { get set }
    var ethereumAddressesWithSeed: [String] { get set }
    var ethereumAddressesProtectedByUserPresence: [String] { get set }
    var hasWallets: Bool { get }
    var wallets: [Wallet] { get }
    var hasMigratedFromKeystoreFiles: Bool { get }
    var recentlyUsedWallet: Wallet? { get set }
    var walletsPublisher: AnyPublisher<Set<Wallet>, Never> { get }
    var didAddWalletPublisher: AnyPublisher<Wallet, Never> { get }
    var didRemoveWalletPublisher: AnyPublisher<Wallet, Never> { get }

    mutating func removeAddress(_ account: Wallet)
    mutating func add(wallet: Wallet)
    mutating func addToListOfEthereumAddressesProtectedByUserPresence(_ address: AlphaWallet.Address)
}

extension WalletAddressesStore {

    public func migrate(to store: WalletAddressesStore) -> WalletAddressesStore {
        var store = store
        store.watchAddresses = watchAddresses
        store.ethereumAddressesWithPrivateKeys = ethereumAddressesWithPrivateKeys
        store.ethereumAddressesWithSeed = ethereumAddressesWithSeed
        store.ethereumAddressesProtectedByUserPresence = ethereumAddressesProtectedByUserPresence

        return store
    }
}
