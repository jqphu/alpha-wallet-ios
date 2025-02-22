// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import AlphaWalletFoundation

protocol WalletCoordinatorDelegate: AnyObject {
    func didFinish(with account: Wallet, in coordinator: WalletCoordinator)
    func didCancel(in coordinator: WalletCoordinator)
}

class WalletCoordinator: Coordinator {
    private let config: Config
    private var keystore: Keystore
    private weak var importWalletViewController: ImportWalletViewController?
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType

    var navigationController: UINavigationController
    weak var delegate: WalletCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(
        config: Config,
        navigationController: UINavigationController = NavigationController(),
        keystore: Keystore,
        analytics: AnalyticsLogger,
        domainResolutionService: DomainResolutionServiceType
    ) {
        self.config = config
        self.navigationController = navigationController
        self.keystore = keystore
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        navigationController.navigationBar.isTranslucent = false
    }

    ///Return true if caller should proceed to show UI (`navigationController`)
    @discardableResult func start(_ entryPoint: WalletEntryPoint) -> Bool {
        switch entryPoint {
        case .importWallet(let params):
            let controller = ImportWalletViewController(keystore: keystore, analytics: analytics, domainResolutionService: domainResolutionService)
            controller.delegate = self
            switch params {
            case .json(let json):
                controller.set(tabSelection: .keystore)
                controller.setValueForCurrentField(string: json)
            case .seedPhase(let seedPhase):
                controller.set(tabSelection: .mnemonic)
                controller.setValueForCurrentField(string: seedPhase.joined(separator: " "))
            case .privateKey(let privateKey):
                controller.set(tabSelection: .privateKey)
                controller.setValueForCurrentField(string: privateKey)
            case .none:
                break
            }
            controller.navigationItem.rightBarButtonItem = UIBarButtonItem.cancelBarButton(self, selector: #selector(dismiss))
            navigationController.viewControllers = [controller]
            importWalletViewController = controller
        case .watchWallet(let address):
            let controller = ImportWalletViewController(keystore: keystore, analytics: analytics, domainResolutionService: domainResolutionService)
            controller.delegate = self
            controller.watchAddressTextField.value = address?.eip55String ?? ""
            controller.navigationItem.rightBarButtonItem = UIBarButtonItem.cancelBarButton(self, selector: #selector(dismiss))
            controller.showWatchTab()
            navigationController.viewControllers = [controller]
            importWalletViewController = controller
        case .createInstantWallet:
            createInstantWallet()
            return false
        case .addInitialWallet:
            let controller = CreateInitialWalletViewController(keystore: keystore)
            controller.delegate = self
            controller.configure()
            navigationController.viewControllers = [controller]
        }
        return true
    }

    func pushImportWallet() {
        let controller = ImportWalletViewController(keystore: keystore, analytics: analytics, domainResolutionService: domainResolutionService)
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(controller, animated: true)
    }

    func createInitialWalletIfMissing() {
        if !keystore.hasWallets {
            let result = keystore.createAccount()
            switch result {
            case .success(let account):
                keystore.recentlyUsedWallet = account
            case .failure:
                //TODO handle initial wallet creation error. App can't be used!
                break
            }
        }
    }

    //TODO Rename this is create in both settings and new install
    func createInstantWallet() {
        navigationController.displayLoading(text: R.string.localizable.walletCreateInProgress(), animated: false)
        keystore.createAccount { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let wallet):
                //Not the best implementation, since there's some coupling, but it's clean. We need this so we don't show the What's New UI right after a wallet is created and clash with the pop up prompting user to back up the new wallet, for new installs and creating new wallets for existing installs
                WhatsNewExperimentCoordinator.lastCreatedWalletTimestamp = Date()

                strongSelf.delegate?.didFinish(with: wallet, in: strongSelf)
            case .failure(let error):
                //TODO this wouldn't work since navigationController isn't shown anymore
                strongSelf.navigationController.displayError(error: error)
            }
            strongSelf.navigationController.hideLoading(animated: false)
        }
    }

    private func addWalletWith(entryPoint: WalletEntryPoint) {
        //Intentionally creating an instance of myself
        let coordinator = WalletCoordinator(config: config, keystore: keystore, analytics: analytics, domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(entryPoint)
        coordinator.navigationController.makePresentationFullScreenForiOS13Migration()
        navigationController.present(coordinator.navigationController, animated: true)
    }

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }

    //TODO Rename this is import in both settings and new install
    func didCreateAccount(account: Wallet) {
        delegate?.didFinish(with: account, in: self)
        //Bit of delay to wait for the UI animation to almost finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            SuccessOverlayView.show()
        }
    }
}

extension WalletCoordinator: ImportWalletViewControllerDelegate {

    func openQRCode(in controller: ImportWalletViewController) {
        guard let wallet = keystore.currentWallet, navigationController.ensureHasDeviceAuthorization() else { return }
        let scanQRCodeCoordinator = ScanQRCodeCoordinator(analytics: analytics, navigationController: navigationController, account: wallet, domainResolutionService: domainResolutionService)
        let coordinator = QRCodeResolutionCoordinator(config: config, coordinator: scanQRCodeCoordinator, usage: .importWalletOnly, account: wallet)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .importWalletScreen)
    }

    func didImportAccount(account: Wallet, in viewController: ImportWalletViewController) {
        config.addToWalletAddressesAlreadyPromptedForBackup(address: account.address)
        didCreateAccount(account: account)
    }
}

extension WalletCoordinator: QRCodeResolutionCoordinatorDelegate {

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolve qrCodeResolution: QrCodeResolution) {
        switch qrCodeResolution {
        case .walletConnectUrl, .transactionType, .url, .string:
            break
        case .address(let address, _):
            importWalletViewController?.set(tabSelection: .watch)
            importWalletViewController?.setValueForCurrentField(string: address.eip55String)
        case .json(let json):
            importWalletViewController?.set(tabSelection: .keystore)
            importWalletViewController?.setValueForCurrentField(string: json)
        case .seedPhase(let seedPhase):
            importWalletViewController?.set(tabSelection: .mnemonic)
            importWalletViewController?.setValueForCurrentField(string: seedPhase.joined(separator: " "))
        case .privateKey(let privateKey):
            importWalletViewController?.set(tabSelection: .privateKey)
            importWalletViewController?.setValueForCurrentField(string: privateKey)
        }

        removeCoordinator(coordinator)
    }

    func didCancel(in coordinator: QRCodeResolutionCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension WalletCoordinator: CreateInitialWalletViewControllerDelegate {

    func didTapCreateWallet(inViewController viewController: CreateInitialWalletViewController) {
        logInitialAction(.create)
        createInstantWallet()
    }

    func didTapWatchWallet(inViewController viewController: CreateInitialWalletViewController) {
        logInitialAction(.watch)
        addWalletWith(entryPoint: .watchWallet(address: nil))
    }

    func didTapImportWallet(inViewController viewController: CreateInitialWalletViewController) {
        logInitialAction(.import)
        addWalletWith(entryPoint: .importWallet(params: nil))
    }
}

extension WalletCoordinator: WalletCoordinatorDelegate {

    func didFinish(with account: Wallet, in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: false)
        removeCoordinator(coordinator)
        delegate?.didFinish(with: account, in: self)
    }

    func didCancel(in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }
}

// MARK: Analytics
extension WalletCoordinator {
    private func logInitialAction(_ action: Analytics.FirstWalletAction) {
        analytics.log(action: Analytics.Action.firstWalletAction, properties: [Analytics.Properties.type.rawValue: action.rawValue])
    }
}
