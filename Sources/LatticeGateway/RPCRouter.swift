import Foundation
import Lattice

struct RPCRouter: Sendable {
    let context: NodeContext

    func handle(_ request: RPCRequest) async -> RPCResponse {
        switch request.method {
        case "lattice_chainHeight":
            let height = await context.chainHeight()
            return .success(height, id: request.id)

        case "lattice_chainTip":
            let tip = await context.chainTip()
            return .success(tip, id: request.id)

        case "lattice_chainSpec":
            let spec = context.genesisConfig.spec
            let info = ChainSpecInfo(
                directory: spec.directory,
                targetBlockTime: spec.targetBlockTime,
                maxTransactionsPerBlock: spec.maxNumberOfTransactionsPerBlock,
                maxStateGrowth: spec.maxStateGrowth,
                initialRewardExponent: spec.initialRewardExponent,
                halvingInterval: spec.halvingInterval,
                initialReward: spec.initialReward
            )
            return .success(info, id: request.id)

        case "lattice_nodeInfo":
            let height = await context.chainHeight()
            let tip = await context.chainTip()
            let genesis = await context.genesisHash()
            let peers = await context.peerCount(directory: "Nexus") ?? 0
            let info = NodeInfo(
                publicKey: context.publicKey,
                address: context.address,
                listenPort: context.listenPort,
                chainHeight: height,
                chainTip: tip,
                genesisHash: genesis,
                peerCount: peers
            )
            return .success(info, id: request.id)

        case "lattice_peerCount":
            let count = await context.peerCount(directory: "Nexus") ?? 0
            return .success(count, id: request.id)

        case "lattice_getMempoolInfo":
            if let info = await context.mempoolInfo(directory: "Nexus") {
                let result = MempoolInfo(count: info.count, totalFees: info.fees)
                return .success(result, id: request.id)
            }
            return .error(code: -32000, message: "Chain network not available", id: request.id)

        case "lattice_generateKeyPair":
            let keyPair = CryptoUtils.generateKeyPair()
            let address = CryptoUtils.createAddress(from: keyPair.publicKey)
            let result = KeyPairInfo(
                publicKey: keyPair.publicKey,
                privateKey: keyPair.privateKey,
                address: address
            )
            return .success(result, id: request.id)

        case "lattice_getBalance":
            guard let address = request.params?.first?.stringValue else {
                return .error(code: -32602, message: "Missing address parameter", id: request.id)
            }
            _ = address
            return .error(code: -32601, message: "Balance queries require state resolution (coming soon)", id: request.id)

        default:
            return .error(code: -32601, message: "Method not found: \(request.method)", id: request.id)
        }
    }
}

struct ChainSpecInfo: Codable, Sendable {
    let directory: String
    let targetBlockTime: UInt64
    let maxTransactionsPerBlock: UInt64
    let maxStateGrowth: Int
    let initialRewardExponent: UInt8
    let halvingInterval: UInt64
    let initialReward: UInt64
}

struct NodeInfo: Codable, Sendable {
    let publicKey: String
    let address: String
    let listenPort: UInt16
    let chainHeight: UInt64
    let chainTip: String
    let genesisHash: String
    let peerCount: Int
}

struct MempoolInfo: Codable, Sendable {
    let count: Int
    let totalFees: UInt64
}

struct KeyPairInfo: Codable, Sendable {
    let publicKey: String
    let privateKey: String
    let address: String
}
