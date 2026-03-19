import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat

final class HTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let router: RPCRouter
    private var bodyBuffer: ByteBuffer?
    private var requestHead: HTTPRequestHead?

    init(router: RPCRouter) {
        self.router = router
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)

        switch part {
        case .head(let head):
            requestHead = head
            bodyBuffer = context.channel.allocator.buffer(capacity: 0)

        case .body(var body):
            bodyBuffer?.writeBuffer(&body)

        case .end:
            guard let head = requestHead else { return }
            handleRequest(context: context, head: head, body: bodyBuffer)
            requestHead = nil
            bodyBuffer = nil
        }
    }

    private func handleRequest(context: ChannelHandlerContext, head: HTTPRequestHead, body: ByteBuffer?) {
        if head.method == .OPTIONS {
            sendCORSPreflight(context: context)
            return
        }

        guard head.method == .POST else {
            sendError(context: context, status: .methodNotAllowed, message: "Only POST supported")
            return
        }

        guard let body = body, let data = body.getData(at: body.readerIndex, length: body.readableBytes) else {
            sendJSONRPCError(context: context, code: -32700, message: "Parse error", id: 0)
            return
        }

        let decoder = JSONDecoder()
        guard let rpcRequest = try? decoder.decode(RPCRequest.self, from: data) else {
            sendJSONRPCError(context: context, code: -32700, message: "Parse error: invalid JSON-RPC", id: 0)
            return
        }

        let router = self.router
        let eventLoop = context.eventLoop

        let promise = eventLoop.makePromise(of: RPCResponse.self)
        promise.completeWithTask {
            await router.handle(rpcRequest)
        }

        promise.futureResult.whenComplete { result in
            let response: RPCResponse
            switch result {
            case .success(let r):
                response = r
            case .failure(let error):
                response = .error(code: -32603, message: "Internal error: \(error)", id: rpcRequest.id)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let responseData = try? encoder.encode(response) else {
                self.sendError(context: context, status: .internalServerError, message: "Encoding error")
                return
            }

            var buffer = context.channel.allocator.buffer(capacity: responseData.count)
            buffer.writeBytes(responseData)

            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "application/json")
            headers.add(name: "Content-Length", value: "\(responseData.count)")
            headers.add(name: "Access-Control-Allow-Origin", value: "*")

            let responseHead = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
            context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        }
    }

    private func sendCORSPreflight(context: ChannelHandlerContext) {
        var headers = HTTPHeaders()
        headers.add(name: "Access-Control-Allow-Origin", value: "*")
        headers.add(name: "Access-Control-Allow-Methods", value: "POST, OPTIONS")
        headers.add(name: "Access-Control-Allow-Headers", value: "Content-Type")
        headers.add(name: "Content-Length", value: "0")

        let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func sendError(context: ChannelHandlerContext, status: HTTPResponseStatus, message: String) {
        let body = "{\"error\": \"\(message)\"}"
        var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
        buffer.writeString(body)

        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "application/json")
        headers.add(name: "Content-Length", value: "\(body.utf8.count)")

        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func sendJSONRPCError(context: ChannelHandlerContext, code: Int, message: String, id: Int) {
        let response = RPCResponse.error(code: code, message: message, id: id)
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(response) else { return }

        var buffer = context.channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)

        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "application/json")
        headers.add(name: "Content-Length", value: "\(data.count)")
        headers.add(name: "Access-Control-Allow-Origin", value: "*")

        let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
}
