import Foundation
import Lattice
import Hummingbird

struct RPCRouter: Sendable {
    let context: NodeContext

    func handle(_ request: RPCRequest) async throws -> Response {
        switch request.method {
        case "lattice_chainHeight":
            let height = await context.chainHeight()
            return jsonResponse(result: height, id: request.id)

        case "lattice_chainTip":
            let tip = await context.chainTip()
            return jsonResponse(result: tip, id: request.id)

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
            return jsonResponse(result: info, id: request.id)

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
            return jsonResponse(result: info, id: request.id)

        case "lattice_peerCount":
            let count = await context.peerCount(directory: "Nexus") ?? 0
            return jsonResponse(result: count, id: request.id)

        case "lattice_getMempoolInfo":
            if let info = await context.mempoolInfo(directory: "Nexus") {
                let result = MempoolInfo(count: info.count, totalFees: info.fees)
                return jsonResponse(result: result, id: request.id)
            }
            return errorResponse(code: -32000, message: "Chain network not available", id: request.id)

        case "lattice_getBlock":
            guard let hash = request.params?.first?.stringValue else {
                return errorResponse(code: -32602, message: "Missing block hash parameter", id: request.id)
            }
            if let block = await context.getBlock(hash: hash) {
                let onMainChain = await context.isOnMainChain(hash: hash)
                let info = BlockInfo(
                    hash: block.blockHash,
                    index: block.blockIndex,
                    previousBlockHash: block.previousBlockHash,
                    childBlockHashes: block.childBlockHashes,
                    onMainChain: onMainChain
                )
                return jsonResponse(result: info, id: request.id)
            }
            return errorResponse(code: -32000, message: "Block not found", id: request.id)

        case "lattice_getLatestBlock":
            let block = await context.getLatestBlock()
            let info = BlockInfo(
                hash: block.blockHash,
                index: block.blockIndex,
                previousBlockHash: block.previousBlockHash,
                childBlockHashes: block.childBlockHashes,
                onMainChain: true
            )
            return jsonResponse(result: info, id: request.id)

        case "lattice_generateKeyPair":
            let keyPair = CryptoUtils.generateKeyPair()
            let address = CryptoUtils.createAddress(from: keyPair.publicKey)
            let result = KeyPairInfo(
                publicKey: keyPair.publicKey,
                privateKey: keyPair.privateKey,
                address: address
            )
            return jsonResponse(result: result, id: request.id)

        default:
            return errorResponse(code: -32601, message: "Method not found: \(request.method)", id: request.id)
        }
    }

    private func jsonResponse<T: Codable & Sendable>(result: T, id: Int) -> Response {
        let rpc = RPCResponse(jsonrpc: "2.0", result: result, error: nil as RPCError?, id: id)
        let data = try! JSONEncoder().encode(rpc)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json", .accessControlAllowOrigin: "*"],
            body: .init(byteBuffer: .init(data: data))
        )
    }

    private func errorResponse(code: Int, message: String, id: Int) -> Response {
        let rpc = RPCResponse<EmptyResult>(jsonrpc: "2.0", result: nil, error: RPCError(code: code, message: message), id: id)
        let data = try! JSONEncoder().encode(rpc)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json", .accessControlAllowOrigin: "*"],
            body: .init(byteBuffer: .init(data: data))
        )
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

struct BlockInfo: Codable, Sendable {
    let hash: String
    let index: UInt64
    let previousBlockHash: String?
    let childBlockHashes: [String]
    let onMainChain: Bool
}

struct KeyPairInfo: Codable, Sendable {
    let publicKey: String
    let privateKey: String
    let address: String
}
