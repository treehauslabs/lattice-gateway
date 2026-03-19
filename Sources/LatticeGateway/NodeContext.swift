import Foundation
import Lattice

final class NodeContext: @unchecked Sendable {
    let node: LatticeNode
    let genesisConfig: GenesisConfig
    let publicKey: String
    let address: String
    let listenPort: UInt16

    init(node: LatticeNode, genesisConfig: GenesisConfig, publicKey: String, listenPort: UInt16) {
        self.node = node
        self.genesisConfig = genesisConfig
        self.publicKey = publicKey
        self.address = CryptoUtils.createAddress(from: publicKey)
        self.listenPort = listenPort
    }

    func chainHeight() async -> UInt64 {
        let chainState = await node.genesisResult.chainState
        return await chainState.getHighestBlockIndex()
    }

    func chainTip() async -> String {
        let chainState = await node.genesisResult.chainState
        return await chainState.getMainChainTip()
    }

    func genesisHash() async -> String {
        await node.genesisResult.blockHash
    }

    func mempoolInfo(directory: String) async -> (count: Int, fees: UInt64)? {
        guard let network = await node.network(for: directory) else { return nil }
        let count = await network.mempool.count
        let fees = await network.mempool.totalFees()
        return (count, fees)
    }

    func peerCount(directory: String) async -> Int? {
        guard let network = await node.network(for: directory) else { return nil }
        return await network.ivy.connectedPeers.count
    }

    func getBlock(hash: String) async -> BlockMeta? {
        let chainState = await node.genesisResult.chainState
        return await chainState.getConsensusBlock(hash: hash)
    }

    func getLatestBlock() async -> BlockMeta {
        let chainState = await node.genesisResult.chainState
        return await chainState.getHighestBlock()
    }

    func isOnMainChain(hash: String) async -> Bool {
        let chainState = await node.genesisResult.chainState
        return await chainState.isOnMainChain(hash: hash)
    }
}
