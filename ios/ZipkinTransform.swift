/*
Copyright 2022 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import Foundation
import DeviceKit

// Zipkin conversion code modified from https://github.com/open-telemetry/opentelemetry-swift/blob/main/Sources/Exporters/Zipkin/Implementation/ZipkinConversionExtension.swift

class ZipkinEndpoint: Encodable {
    var serviceName: String
    var ipv4: String?
    var ipv6: String?
    var port: Int?

    public init(serviceName: String, ipv4: String? = nil, ipv6: String? = nil, port: Int? = nil) {
        self.serviceName = serviceName
        self.ipv4 = ipv4
        self.ipv6 = ipv6
        self.port = port
    }

    public func clone(serviceName: String) -> ZipkinEndpoint {
        return ZipkinEndpoint(serviceName: serviceName, ipv4: ipv4, ipv6: ipv6, port: port)
    }

    public func write() -> [String: Any] {
        var output = [String: Any]()

        output["serviceName"] = serviceName
        output["ipv4"] = ipv4
        output["ipv6"] = ipv6
        output["port"] = port

        return output
    }
}

struct ZipkinSpan: Encodable {
    var traceId: String
    var parentId: String?
    var id: String
    var kind: String?
    var name: String
    var timestamp: UInt64
    var duration: UInt64?
    var remoteEndpoint: ZipkinEndpoint?
    var annotations: [ZipkinAnnotation]
    var tags: [String: String]

    init(traceId: String, parentId: String?, id: String, kind: String?, name: String, timestamp: UInt64, duration: UInt64?, remoteEndpoint: ZipkinEndpoint?, annotations: [ZipkinAnnotation], tags: [String: String]) {

        self.traceId = traceId
        self.parentId = parentId
        self.id = id
        self.kind = kind
        self.name = name
        self.timestamp = timestamp
        self.duration = duration
        self.remoteEndpoint = remoteEndpoint
        self.annotations = annotations
        self.tags = tags
    }

    public func write() -> [String: Any] {
        var output = [String: Any]()

        output["traceId"] = traceId
        output["name"] = name
        output["parentId"] = parentId
        output["id"] = id
        output["kind"] = kind
        output["timestamp"] = timestamp
        output["duration"] = duration
        output["localEndpoint"] = ["serviceName": "myservice"]

        if remoteEndpoint != nil {
            output["remoteEndpoint"] = remoteEndpoint!.write()
        }

        if annotations.count > 0 {
            let annotationsArray: [Any] = annotations.map {
                var object = [String: Any]()
                object["timestamp"] = $0.timestamp
                object["value"] = $0.value
                return object
            }

            output["annotations"] = annotationsArray
        }

        if tags.count > 0 {
            output["tags"] = tags
        }

        return output
    }
}

struct ZipkinAnnotation: Encodable {
    var timestamp: UInt64
    var value: String
}

struct ZipkinTransform {
    static let statusCode = "otel.status_code"
    static let statusErrorDescription = "error"

    static let remoteEndpointServiceNameKeyResolution = ["peer.service": 0,
                                                         "net.peer.name": 1,
                                                         "peer.hostname": 2,
                                                         "peer.address": 2,
                                                         "http.host": 3,
                                                         "db.instance": 4]

    static var remoteEndpointCache = [String: ZipkinEndpoint]()

    static let defaultServiceName = "unknown_service:" + ProcessInfo.processInfo.processName

    struct AttributeEnumerationState {
        var tags = [String: String]()
        var RemoteEndpointServiceName: String?
        var remoteEndpointServiceNamePriority: Int?
        var serviceName: String?
        var serviceNamespace: String?
    }

    static func toZipkinSpans(spans: [Dictionary<String, Any>]) -> [ZipkinSpan] {
        return spans.map { ZipkinTransform.toZipkinSpan(otelSpan: $0) }
    }

    static func toZipkinSpan(otelSpan: Dictionary<String, Any>) -> ZipkinSpan {
        let parentId = otelSpan["parentId"] as? String
        let traceId = otelSpan["traceId"] as? String ?? "00000000000000000000000000000000"
        let spanId = otelSpan["id"] as? String ?? "0000000000000000"
        let name = otelSpan["name"] as? String ?? "unknown"
        var tags = otelSpan["tags"] as? Dictionary<String, String> ?? [:]
        tags["device.model.name"] = Device.current.description

        return ZipkinSpan(traceId: traceId,
                          parentId: parentId,
                          id: spanId,
                          kind: otelSpan["kind"] as? String,
                          name: name,
                          timestamp: otelSpan["timestamp"] as? UInt64 ?? 0,
                          duration: otelSpan["duration"] as? UInt64 ?? 0,
                          remoteEndpoint: nil,
                          annotations: [],
                          tags: tags)
    }
}
