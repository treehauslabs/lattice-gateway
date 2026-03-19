import Foundation
import Lattice
import AcornMemoryWorker
import Acorn
import Hummingbird
import UInt256
#if canImport(Glibc)
import Glibc
#endif

let httpPort = 8545
let p2pPort: UInt16 = 4001
let storagePath = "/tmp/lattice-gateway"

print("""

  \u{001B}[36m\u{001B}[1mLattice Gateway\u{001B}[0m
  JSON-RPC server for the Lattice blockchain

""")

let fm = FileManager.default
if !fm.fileExists(atPath: storagePath) {
    try fm.createDirectory(atPath: storagePath, withIntermediateDirectories: true)
}

let keyPair = CryptoUtils.generateKeyPair()
let address = CryptoUtils.createAddress(from: keyPair.publicKey)

let spec = ChainSpec(
    directory: "Nexus",
    maxNumberOfTransactionsPerBlock: 100,
    maxStateGrowth: 100_000,
    premine: 0,
    targetBlockTime: 1_000,
    initialRewardExponent: 10
)

let genesisConfig = GenesisConfig.standard(spec: spec)
let nodeConfig = LatticeNodeConfig(
    publicKey: keyPair.publicKey,
    privateKey: keyPair.privateKey,
    listenPort: p2pPort,
    storagePath: URL(filePath: storagePath),
    enableLocalDiscovery: true
)

print("  Initializing node...")

let node = try await LatticeNode(config: nodeConfig, genesisConfig: genesisConfig)
let genesisHash = await node.genesisResult.blockHash

print("  \u{001B}[2mAddress:\u{001B}[0m     \(address)")
print("  \u{001B}[2mGenesis:\u{001B}[0m     \(String(genesisHash.prefix(32)))...")
print("  \u{001B}[2mP2P Port:\u{001B}[0m    \(p2pPort)")
print("  \u{001B}[2mHTTP Port:\u{001B}[0m   \(httpPort)")
print("  \u{001B}[2mStorage:\u{001B}[0m     \(storagePath)")
print("")

try await node.start()
print("  \u{001B}[32m✓\u{001B}[0m Node started")

let context = NodeContext(
    node: node,
    genesisConfig: genesisConfig,
    publicKey: keyPair.publicKey,
    listenPort: p2pPort
)

let rpcRouter = RPCRouter(context: context)

let router = Router()
router.post("/") { request, _ -> Response in
    let body = try await request.body.collect(upTo: 1_048_576)
    let rpcRequest = try JSONDecoder().decode(RPCRequest.self, from: body)
    return try await rpcRouter.handle(rpcRequest)
}

router.on("/", method: .options) { _, _ -> Response in
    Response(
        status: .ok,
        headers: [
            .accessControlAllowOrigin: "*",
            .accessControlAllowMethods: "POST, OPTIONS",
            .accessControlAllowHeaders: "Content-Type",
        ]
    )
}

print("  \u{001B}[32m✓\u{001B}[0m HTTP server listening on http://127.0.0.1:\(httpPort)")
print("")
print("  \u{001B}[1mAvailable methods:\u{001B}[0m")
print("    lattice_chainHeight      lattice_chainTip")
print("    lattice_chainSpec         lattice_nodeInfo")
print("    lattice_peerCount         lattice_getMempoolInfo")
print("    lattice_getBlock          lattice_getLatestBlock")
print("    lattice_generateKeyPair")
print("")
print("  \u{001B}[2mExample:\u{001B}[0m")
print("    curl -X POST http://127.0.0.1:\(httpPort) \\")
print("      -H 'Content-Type: application/json' \\")
print("      -d '{\"jsonrpc\":\"2.0\",\"method\":\"lattice_nodeInfo\",\"params\":[],\"id\":1}'")
print("")

let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: httpPort))
)

try await app.runService()

await node.stop()
print("  \u{001B}[32m✓\u{001B}[0m Gateway stopped")
