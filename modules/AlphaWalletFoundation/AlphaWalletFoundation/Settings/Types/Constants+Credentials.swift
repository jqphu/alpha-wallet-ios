// Copyright © 2019 Stormbird PTE. LTD.
import Foundation

extension Constants {
    public enum Credentials {
        private static var cachedDevelopmentCredentials: [String: String]? = readDevelopmentCredentialsFile()

        private static func readDevelopmentCredentialsFile() -> [String: String]? {
            guard let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] else {
                debugLog("[Credentials] No .credentials file found for development because SOURCE_ROOT is not set")
                return nil
            }
            let fileName = "\(sourceRoot)/.credentials"
            guard let fileContents = try? String(contentsOfFile: fileName) else {
                debugLog("[Credentials] No .credentials file found for development at \(fileName)")
                return nil
            }
            let lines = fileContents.components(separatedBy: .newlines)
            let keyValues: [(String, String)] = lines.compactMap { line -> (String, String)? in
                Constants.Credentials.functional.extractKeyValueCredentials(line)
            }
            let dict = Dictionary(uniqueKeysWithValues: keyValues)
            debugLog("[Credentials] Loaded .credentials file found for development with key count: \(dict.count)")
            return dict
        }

        private static func env(_ name: String) -> String? {
            if Environment.isDebug, let cachedDevelopmentCredentials = cachedDevelopmentCredentials {
                return cachedDevelopmentCredentials[name]
            } else {
                return ProcessInfo.processInfo.environment[name]
            }
        }

        public static let analyticsKey = ""
        public static let mailChimpListSpecificKey = ""
        public static let walletConnectProjectId = env("WALLETCONNECTPROJECTID") ?? "8ba9ee138960775e5231b70cc5ef1c3a"
        static let infuraKey = env("INFURAKEY") ?? "ad6d834b7a1e4d03a7fde92020616149"
        static let etherscanKey = env("ETHERSCANKEY") ?? "1PX7RG8H4HTDY8X55YRMCAKPZK476M23ZR"
        static let binanceSmartChainExplorerApiKey: String? = env("BINANCESMARTCHAINEXPLORERAPIKEY")
        static let polygonScanExplorerApiKey: String? = env("POLYGONSCANEXPLORERAPIKEY")
        static let paperTrail = (host: env("PAPERTRAILHOST") ?? "", port: (env("PAPERTRAILPORT") ?? "").toInt() ?? 0)
        static let openseaKey = env("OPENSEAKEY") ?? nil
        static let rampApiKey = env("RAMPAPIKEY") ?? "j5wr7oqktym7z69yyf84bb8a6cqb7qfu5ynmeyvn"
        static let coinbaseAppId = env("COINBASEAPPID") ?? ""
        static let enjinUserName = env("ENJINUSERNAME") ?? "vlad_shepitko@outlook.com"
        static let enjinUserPassword = env("ENJINUSERPASSWORD") ?? "wf@qJPz75CL9Tw$"
        static let unstoppableDomainsV2ApiKey = env("UNSTOPPABLEDOMAINSV2KEY") ?? "Bearer rLuujk_dLBN-JDE6Xl8QSCg-FeIouRKM"
        static let blockscanChatProxyKey = env("BLOCKSCHATPROXYKEY") ?? ""
        static let covalentApiKey = env("COVALENTAPIKEY") ?? "ckey_7ee61be7f8364ba784f697510bd"
        //Without the "Basic " prefix
        static let klaytnRpcNodeKeyBasicAuth = env("KLAYTNRPCNODEKEYBASICAUTH") ?? ""
    }
}

extension Constants.Credentials {
    public enum functional {}
}

extension Constants.Credentials.functional {
    public static func extractKeyValueCredentials(_ line: String) -> (key: String, value: String)? {
        let keyValue = line.components(separatedBy: "=")
        if keyValue.count == 2 {
            return (keyValue[0], keyValue[1])
        } else if keyValue.count > 2 {
            //Needed to handle when = is in the API value, example Basic Auth
            return (keyValue[0], keyValue[1..<keyValue.count].joined(separator: "="))
        } else {
            return nil
        }
    }
}
