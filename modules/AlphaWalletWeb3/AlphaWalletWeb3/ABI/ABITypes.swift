//
//  ABITpees.swift
//  web3swift
//
//  Created by Alexander Vlasov on 06.12.2017.
//  Copyright © 2017 Bankex Foundation. All rights reserved.
//

import Foundation
import BigInt

// JSON Decoding
public struct ABIInput: Decodable {
    var name: String?
    var type: String
    var indexed: Bool?
}

public struct ABIOutput: Decodable {
    var name: String?
    var type: String
}

public struct ABIRecord: Decodable {
    var name: String?
    var type: String?
    var payable: Bool?
    var constant: Bool?
    var stateMutability: String?
    var inputs: [ABIInput]?
    var outputs: [ABIOutput]?
    var anonymous: Bool?
}

public struct EventLogJSON {

}

// Native parsing

protocol AbiValidating {
    var isValid: Bool { get }
}

protocol ABIElementPropertiesProtocol {
    var isArray: Bool { get }
    var arraySize: ABIElement.ArraySize { get }
    var subtype: ABIElement.ParameterType? { get }
    var memoryUsage: UInt64 { get }
    var emptyValue: Any { get }
}

public enum ABIElement {

    enum ArraySize { //bytes for convenience
        case staticSize(UInt64)
        case dynamicSize
        case notArray
    }

    case function(Function)
    case constructor(Constructor)
    case fallback(Fallback)
    case event(Event)

    public struct Function {
        let name: String?
        let inputs: [Input]
        let outputs: [Output]
        let constant: Bool
        let payable: Bool
        struct Output {
            let name: String
            let type: ParameterType
        }

        struct Input {
            let name: String
            let type: ParameterType
        }
    }

    public struct Constructor {
        let inputs: [Function.Input]
        let constant: Bool
        let payable: Bool
    }

    public struct Fallback {
        let constant: Bool
        let payable: Bool
    }

    public struct Event {
        let name: String
        let inputs: [Input]
        let anonymous: Bool

        struct Input {
            let name: String
            let type: ParameterType
            let indexed: Bool
        }
    }

    /// Specifies the type that parameters in a contract have.
    public enum ParameterType {
        case dynamicABIType(DynamicType)
        case staticABIType(StaticType)

        /// Denotes any type that has a fixed length.
        public enum StaticType: ABIElementPropertiesProtocol {
            var isArray: Bool {
                switch self {
                case .array:
                    return true
                default:
                    return false
                }
            }

            var arraySize: ABIElement.ArraySize {
                switch self {
                case .array(_, length: let length):
                    return ABIElement.ArraySize.staticSize(length)
                default:
                    return ABIElement.ArraySize.notArray
                }
            }

            var subtype: ABIElement.ParameterType? {
                switch self {
                case .array(let type, length: _):
                    return ParameterType.staticABIType(type)
                default:
                    return nil
                }
            }

            var memoryUsage: UInt64 {
                switch self {
                case .array(_, length: let length):
                    return 32*length
                default:
                    return 32
                }
            }

            var emptyValue: Any {
                switch self {
                case .uint:
                    return BigUInt(0)
                case .int:
                    return BigUInt(0)
                case .address:
                    return EthereumAddress("0x0000000000000000000000000000000000000000")!
                case .bool:
                    return false
                case .bytes:
                    return Data()
                case .array:
                    return [StaticType]()
                }
            }

            /// uint<M>: unsigned integer type of M bits, 0 < M <= 256, M % 8 == 0. e.g. uint32, uint8, uint256.
            case uint(bits: UInt64)
            /// int<M>: two's complement signed integer type of M bits, 0 < M <= 256, M % 8 == 0.
            case int(bits: UInt64)
            /// address: equivalent to uint160, except for the assumed interpretation and language typing.
            case address
            /// bool: equivalent to uint8 restricted to the values 0 and 1
            case bool
            /// bytes<M>: binary type of M bytes, 0 < M <= 32.
            case bytes(length: UInt64)
            /// function: equivalent to bytes24: an address, followed by a function selector
//            case function
            /// <type>[M]: a fixed-length array of the given fixed-length type.
            indirect case array(StaticType, length: UInt64)

            // The specification also defines the following types:
            // uint, int: synonyms for uint256, int256 respectively (not to be used for computing the function selector).
            // We do not include these in this enum, as we will just be mapping those
            // to .uint(bits: 256) and .int(bits: 256) directly.
        }

        /// Denotes any type that has a variable length.
        public enum DynamicType {
            var isArray: Bool {
                switch self {
                case .dynamicArray:
                    return true
                case .arrayOfDynamicTypes:
                    return true
                default:
                    return false
                }
            }

            var arraySize: ABIElement.ArraySize {
                switch self {
                case .dynamicArray:
                    return ABIElement.ArraySize.dynamicSize
                case .arrayOfDynamicTypes(_, length: let length):
                    return ABIElement.ArraySize.staticSize(length)
                default:
                    return ABIElement.ArraySize.notArray
                }
            }

            var subtype: ABIElement.ParameterType? {
                switch self {
                case .dynamicArray(let type):
                    return ParameterType.staticABIType(type)
                case .arrayOfDynamicTypes(let type, length: _):
                    return ParameterType.dynamicABIType(type)
                default:
                    return nil
                }
            }

            var memoryUsage: UInt64 {
                switch self {
//                case .dynamicArray(_):
//                    return 32
//                case .arrayOfDynamicTypes(_, length: _):
//                    return 32
                default:
                    return 32
                }
            }

            var emptyValue: Any {
                switch self {
                case .bytes:
                    return Data()
                case .string:
                    return ""
                case .arrayOfDynamicTypes:
                    return [DynamicType]()
                case .dynamicArray:
                    return [StaticType]()
                }
            }

            /// bytes: dynamic sized byte sequence.
            case bytes
            /// string: dynamic sized unicode string assumed to be UTF-8 encoded.
            case string
            /// <type>[]: a variable-length array of the given fixed-length type.
            case dynamicArray(StaticType)
            /// fixed length array of dynamic types is considered as dynamic type.
            indirect case arrayOfDynamicTypes(DynamicType, length: UInt64)
        }
    }
}

// MARK: - DynamicType Equatable
extension ABIElement.ParameterType.DynamicType: Equatable {
    public static func == (lhs: ABIElement.ParameterType.DynamicType, rhs: ABIElement.ParameterType.DynamicType) -> Bool {
        switch (lhs, rhs) {
        case (.bytes, .bytes):
            return true
        case (.string, .string):
            return true
        case (.dynamicArray(let value1), .dynamicArray(let value2)):
            return value1 == value2
        case (.arrayOfDynamicTypes(let type1, let len1), .arrayOfDynamicTypes(let type2, let len2)):
            return type1 == type2 && len1 == len2
        default:
            return false
        }
    }
}

// MARK: - ParameterType Equatable
extension ABIElement.ParameterType: Equatable {
    public static func == (lhs: ABIElement.ParameterType, rhs: ABIElement.ParameterType) -> Bool {
        switch (lhs, rhs) {
        case (.dynamicABIType(let value1), .dynamicABIType(let value2)):
            return value1 == value2
        case (.staticABIType(let value1), .staticABIType(let value2)):
            return value1 == value2
        default:
            return false
        }
    }
}

// MARK: - StaticType Equatable
extension ABIElement.ParameterType.StaticType: Equatable {
    public static func == (lhs: ABIElement.ParameterType.StaticType, rhs: ABIElement.ParameterType.StaticType) -> Bool {
        switch (lhs, rhs) {
        case let (.uint(length1), .uint(length2)):
            return length1 == length2
        case let (.int(length1), .int(length2)):
            return length1 == length2
        case (.address, .address):
            return true
        case (.bool, .bool):
            return true
        case let (.bytes(length1), .bytes(length2)):
            return length1 == length2
//        case (.function, .function):
//            return true
        case let (.array(type1, length1), .array(type2, length2)):
            return type1 == type2 && length1 == length2
        default:
            return false
        }
    }
}

// MARK: - ParameterType Validity
extension ABIElement.ParameterType: AbiValidating {
    public var isValid: Bool {
        switch self {
        case .staticABIType(let type):
            return type.isValid
        case .dynamicABIType(let type):
            return type.isValid
        }
    }
}

// MARK: - ParameterType.StaticType Validity
extension ABIElement.ParameterType.StaticType: AbiValidating {
    public var isValid: Bool {
        switch self {
        case .uint(let bits), .int(let bits):
            return bits > 0 && bits <= 256 && bits % 8 == 0
        case .bytes(let length):
            return length > 0 && length <= 32
        case let .array(type, _):
            return type.isValid
        default:
            return true
        }
    }
}

// MARK: - ParameterType.DynamicType Validity
extension ABIElement.ParameterType.DynamicType: AbiValidating {
    public var isValid: Bool {
        // Right now we cannot create invalid dynamic types.
        return true
    }
}

// MARK: - Method ID for ContractV1
extension ABIElement.Function {
    public var signature: String {
        return "\(name ?? "")(\(inputs.map { $0.type.abiRepresentation }.joined(separator: ",")))"
    }

    public var methodString: String {
        return String(signature.sha3(.keccak256).prefix(8))
    }

    public var methodEncoding: Data {
        return signature.data(using: .ascii)!.sha3(.keccak256)[0...3]
    }
}

// MARK: - Event topic
extension ABIElement.Event {
    public var signature: String {
        return "\(name)(\(inputs.map { $0.type.abiRepresentation }.joined(separator: ",")))"
    }

    public var topic: Data {
        return signature.data(using: .ascii)!.sha3(.keccak256)
    }
}

protocol AbiEncoding {
    var abiRepresentation: String { get }
}

extension ABIElement.ParameterType: AbiEncoding {
    public var abiRepresentation: String {
        switch self {
        case .staticABIType(let type):
            return type.abiRepresentation
        case .dynamicABIType(let type):
            return type.abiRepresentation
        }
    }
}

extension ABIElement.ParameterType.StaticType: AbiEncoding {
    public var abiRepresentation: String {
        switch self {
        case .uint(let bits):
            return "uint\(bits)"
        case .int(let bits):
            return "int\(bits)"
        case .address:
            return "address"
        case .bool:
            return "bool"
        case .bytes(let length):
            return "bytes\(length)"
//        case .function:
//            return "function"
        case let .array(type, length):
            return "\(type.abiRepresentation)[\(length)]"
        }
    }
}

extension ABIElement.ParameterType.DynamicType: AbiEncoding {
    public var abiRepresentation: String {
        switch self {
        case .bytes:
            return "bytes"
        case .string:
            return "string"
        case .dynamicArray(let type):
            return "\(type.abiRepresentation)[]"
        case .arrayOfDynamicTypes(let type, let length):
            return "\(type.abiRepresentation)[\(length)]"
        }
    }
}

