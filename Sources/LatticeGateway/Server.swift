import Foundation
import NIO
import NIOHTTP1

struct GatewayServer: Sendable {
    let host: String
    let port: Int
    let router: RPCRouter
    let group: EventLoopGroup

    init(host: String = "127.0.0.1", port: Int = 8545, router: RPCRouter, group: EventLoopGroup) {
        self.host = host
        self.port = port
        self.router = router
        self.group = group
    }

    func start() async throws -> Channel {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(.backlog, value: 256)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(router: self.router))
                }
            }
            .childChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.maxMessagesPerRead, value: 16)

        let channel = try await bootstrap.bind(host: host, port: port).get()
        return channel
    }
}
