//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

/**
 Web service proxy class.
 */
public class WebServiceProxy {
    /**
     Encoding options for POST requests.
     */
    public enum Encoding: Int {
        case applicationXWWWFormURLEncoded
        case multipartFormData
    }

    /**
     Service method options.
     */
    public enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    /**
     Response handler type alias.
     */
    public typealias ResponseHandler<T> = (_ content: Data, _ contentType: String?, _ headers: [String: String]) throws -> T

    /**
     Result handler type alias.
     */
    public typealias ResultHandler<T> = (_ result: Result<T, Error>) -> Void

    /**
     Creates a new web service proxy.

     - parameter session: The URL session the service proxy will use to issue HTTP requests.
     - parameter serverURL: The server URL.
     */
    public init(session: URLSession, serverURL: URL) {
        self.session = session
        self.serverURL = serverURL

        encoding = .applicationXWWWFormURLEncoded
    }

    /**
     The URL session the service proxy will use to issue HTTP requests.
     */
    public private(set) var session: URLSession

    /**
     The server URL.
     */
    public private(set) var serverURL: URL

    /**
     The encoding used to submit POST requests.
     */
    public var encoding: Encoding

    /**
     * The header dictionary.
     */
    public var headers: [String: String] = [:]

    /**
     * Constant representing an unspecified value.
     */
    public static let undefined = NSNull()

    /**
     Invokes a web service method.

     - parameter method: The HTTP verb associated with the request.
     - parameter path: The path associated with the request.
     - parameter arguments: The request arguments.
     - parameter content: The request content, or `nil` for the default content.
     - parameter contentType: The request content type, or `nil` for the default content type.
     - parameter resultHandler: A callback that will be invoked to handle the result.

     - returns: A URL session data task representing the invocation request, or `nil` if the task could not be created.
     */
    @discardableResult
    public func invoke(_ method: Method, path: String,
        arguments: [String: Any] = [:],
        content: Data? = nil, contentType: String? = nil,
        resultHandler: @escaping ResultHandler<Void>) -> URLSessionDataTask? {
        return invoke(method, path: path, arguments: arguments, content: content, responseHandler: { _, _, _ in }, resultHandler: resultHandler)
    }

    /**
     Invokes a web service method.

     - parameter method: The HTTP verb associated with the request.
     - parameter path: The path associated with the request.
     - parameter arguments: The request arguments.
     - parameter content: The request content, or `nil` for the default content.
     - parameter contentType: The request content type, or `nil` for the default content type.
     - parameter resultHandler: A callback that will be invoked to handle the result.

     - returns: A URL session data task representing the invocation request, or `nil` if the task could not be created.
     */
    @discardableResult
    public func invoke<T: Decodable>(_ method: Method, path: String,
        arguments: [String: Any] = [:],
        content: Data? = nil, contentType: String? = nil,
        resultHandler: @escaping ResultHandler<T>) -> URLSessionDataTask? {
        return invoke(method, path: path, arguments: arguments, content: content, responseHandler: { content, _, _ in
            let jsonDecoder = JSONDecoder()
            
            jsonDecoder.dateDecodingStrategy = .millisecondsSince1970

            return try jsonDecoder.decode(T.self, from: content)
        }, resultHandler: resultHandler)
    }

    /**
     Invokes a web service method.

     - parameter method: The HTTP verb associated with the request.
     - parameter path: The path associated with the request.
     - parameter arguments: The request arguments.
     - parameter content: The request content, or `nil` for the default content.
     - parameter contentType: The request content type, or `nil` for the default content type.
     - parameter responseHandler: A callback that will be invoked to handle the response.
     - parameter resultHandler: A callback that will be invoked to handle the result.

     - returns: A URL session data task representing the invocation request, or `nil` if the task could not be created.
     */
    @discardableResult
    public func invoke<T>(_ method: Method, path: String,
        arguments: [String: Any] = [:],
        content: Data? = nil, contentType: String? = nil,
        responseHandler: @escaping ResponseHandler<T>,
        resultHandler: @escaping ResultHandler<T>) -> URLSessionDataTask? {
        let query = (method != .post || content != nil) ? encodeQuery(for: arguments) : ""

        guard let url = URL(string: path + (query.isEmpty ? "" : "?" + query), relativeTo: serverURL) else {
            return nil
        }

        var urlRequest = URLRequest(url: url)

        urlRequest.httpMethod = method.rawValue

        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        switch method {
        case .post where content == nil:
            switch encoding {
            case .applicationXWWWFormURLEncoded:
                urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = encodeApplicationXWWWFormURLEncodedData(for: arguments)

            case .multipartFormData:
                let multipartBoundary = UUID().uuidString

                urlRequest.setValue("multipart/form-data; boundary=\(multipartBoundary)", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = encodeMultipartFormData(for: arguments, multipartBoundary: multipartBoundary)
            }

        default:
            if (content != nil) {
                urlRequest.setValue(contentType ?? "application/octet-stream", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = content
            }
        }

        let task = session.dataTask(with: urlRequest) { data, urlResponse, error in
            let result: Result<T, Error>
            if let content = data, let httpURLResponse = urlResponse as? HTTPURLResponse {
                do {
                    let statusCode = httpURLResponse.statusCode
                    let contentType = httpURLResponse.mimeType

                    if (statusCode / 100 == 2) {
                        var headers: [String: String] = [:]

                        for (key, value) in httpURLResponse.allHeaderFields {
                            headers[String(describing: key)] = String(describing: value)
                        }

                        result = .success(try responseHandler(content, contentType, headers))
                    } else {
                        let errorDescription: String?
                        if contentType?.hasPrefix("text/") ?? false {
                            errorDescription = String(data: content, encoding: .utf8)
                        } else {
                            errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                        }

                        result = .failure(WebServiceError(errorDescription: errorDescription, statusCode: statusCode))
                    }
                } catch {
                    result = .failure(error)
                }
            } else {
                result = .failure(error!)
            }

            OperationQueue.main.addOperation {
                resultHandler(result)
            }
        }

        task.resume()

        return task
    }

    func encodeQuery(for arguments: [String: Any]) -> String {
        var urlQueryItems: [URLQueryItem] = []

        for argument in arguments {
            if (argument.key.isEmpty) {
                continue
            }

            for element in argument.value as? [Any] ?? [argument.value] {
                guard let value = value(for: element) else {
                    continue
                }

                urlQueryItems.append(URLQueryItem(name: argument.key, value: value))
            }
        }

        var urlComponents = URLComponents()

        urlComponents.queryItems = urlQueryItems

        return urlComponents.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B") ?? ""
    }

    func encodeApplicationXWWWFormURLEncodedData(for arguments: [String: Any]) -> Data {
        var body = Data()

        body.append(utf8DataFor: encodeQuery(for: arguments))

        return body
    }

    func encodeMultipartFormData(for arguments: [String: Any], multipartBoundary: String) -> Data {
        var body = Data()

        for argument in arguments {
            for element in argument.value as? [Any] ?? [argument.value] {
                body.append(utf8DataFor: "--\(multipartBoundary)\r\n")
                body.append(utf8DataFor: "Content-Disposition: form-data; name=\"\(argument.key)\"")

                if let url = element as? URL {
                    body.append(utf8DataFor: "; filename=\"\(url.lastPathComponent)\"\r\n")
                    body.append(utf8DataFor: "Content-Type: application/octet-stream\r\n\r\n")

                    if let data = try? Data(contentsOf: url) {
                        body.append(data)
                    }
                } else {
                    body.append(utf8DataFor: "\r\n\r\n")

                    if let value = value(for: element) {
                        body.append(utf8DataFor: value)
                    }
                }

                body.append(utf8DataFor: "\r\n")
            }
        }

        body.append(utf8DataFor: "--\(multipartBoundary)--\r\n")

        return body
    }

    func value(for element: Any) -> String? {
        if (element is NSNull) {
            return nil
        } else if let date = element as? Date {
            return String(describing: Int64(date.timeIntervalSince1970 * 1000))
        } else {
            return String(describing: element)
        }
    }
}

extension Data {
    mutating func append(utf8DataFor string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
