[![Releases](https://img.shields.io/github/release/HTTP-RPC/Kilo.svg)](https://github.com/HTTP-RPC/Kilo/releases)

# Introduction
Kilo is a Swift package for consuming RESTful and REST-like web services. The project's name comes from the nautical _K_ or _Kilo_ flag, which means "I wish to communicate with you":

![](kilo.png)

For example, the following Swift code uses Kilo's `WebServiceProxy` class to access a simple web service that returns the first _n_ values in the Fibonacci sequence:

```swift
let webServiceProxy = WebServiceProxy(session: URLSession.shared, serviceURL: serviceURL)

// GET test/fibonacci?count=8
webServiceProxy.invoke(.get, path: "test/fibonacci", arguments: [
    "count": 8
]) { (result: Result<[Int], Error>) in
    switch (result) {
    case .success(let value):
        print(value) // [0, 1, 1, 2, 3, 5, 8, 13]

    case .failure(let error):
        print(error.localizedDescription)
    }
}
```

# WebServiceProxy
The `WebServiceProxy` class is used to issue API requests to the server. This class provides a single initializer that accepts the following arguments:

* `session` - a `URLSession` instance
* `serviceURL` - the base URL of the service

Service operations are initiated via one of the following methods:

```swift
public func invoke(_ method: Method, path: String,
    arguments: [String: Any] = [:], content: Data? = nil, contentType: String? = nil,
    resultHandler: @escaping ResultHandler<Void>) -> URLSessionDataTask? { ... }

public func invoke<B: Encodable>(_ method: Method, path: String,
    arguments: [String: Any] = [:], body: B,
    resultHandler: @escaping ResultHandler<Void>) throws -> URLSessionDataTask? { ... }

public func invoke<T: Decodable>(_ method: Method, path: String,
    arguments: [String: Any] = [:], content: Data? = nil, contentType: String? = nil,
    resultHandler: @escaping ResultHandler<T>) -> URLSessionDataTask? { ... }

public func invoke<B: Encodable, T: Decodable>(_ method: Method, path: String,
    arguments: [String: Any] = [:], body: B,
    resultHandler: @escaping ResultHandler<T>) throws -> URLSessionDataTask? { ... }

public func invoke<T>(_ method: Method, path: String,
    arguments: [String: Any] = [:], content: Data? = nil, contentType: String? = nil,
    responseHandler: @escaping ResponseHandler<T>,
    resultHandler: @escaping ResultHandler<T>) -> URLSessionDataTask? { ... }
```

All method variants accept the following arguments:

* `method` - the HTTP method to execute
* `path` - the path to the requested resource, relative to the service URL
* `arguments` - a dictionary containing the method arguments as key/value pairs
* `resultHandler` - a callback that will be invoked upon completion of the request

The first two versions execute a service method that does not return a value. The following two versions deserialize the response using `JSONDecoder`.

Three of the methods accept the following arguments for specifying custom request body content:

* `content` - an optional `Data` instance representing the body of the request
* `contentType` - an optional string value containing the MIME type of the content

The other two methods accept an encodable body value that is serialized using `JSONEncoder`.

The final version accepts an additional `responseHandler` argument to facilitate decoding of custom response content (for example, a `UIImage`).

JSON data is encoded and decoded using a date strategy of `millisecondsSince1970`.

Response and result handler callbacks are defined as follows:

```swift
public typealias ResponseHandler<T> = (_ content: Data, _ contentType: String?, _ headers: [String: String]) throws -> T

public typealias ResultHandler<T> = (_ result: Result<T, Error>) -> Void
```

All methods return an instance of `URLSessionDataTask` representing the invocation request. This allows an application to monitor the status of outstanding requests or cancel a request, if needed.

## Arguments
Like HTML forms, arguments are submitted either via the query string or in the request body. Arguments for `GET`, `PUT`, and `DELETE` requests are always sent in the query string. `POST` arguments are typically sent in the request body, and may be submitted as either "application/x-www-form-urlencoded" or "multipart/form-data" (determined via the service proxy's `encoding` property). However, if a custom body is specified via either the `content` or `body` parameter, `POST` arguments will be sent in the query string.

Any value may be used as an argument. However, `Date` instances are automatically converted to a 64-bit integer value representing epoch time (the number of milliseconds that have elapsed since midnight on January 1, 1970). Array instances represent multi-value parameters and behave similarly to `<select multiple>` tags in HTML. When using the multi-part encoding, instances of `URL` represent file uploads and behave similarly to `<input type="file">` tags in HTML forms.

The `undefined` property of the `WebServiceProxy` class can be used to represent unspecified or unknown values.

## Return Values
The result handler is called upon completion of the operation. If successful, the result will contain a deserialized representation of the content returned by the server. Otherwise, it will contain an error describing the problem that occurred. If the content type of the error response is "text/*", the deserialized response body will be provided in the error's localized description.

## Threading Considerations
While service requests are typically processed on a background thread, result handlers are always executed on the main thread. This allows the callback to update an application's user interface directly, rather than posting a separate update operation to the main queue. 

Response handlers are always executed in the background, before the result handler is invoked.

# Additional Information
For more information, see the [test cases](https://github.com/HTTP-RPC/Kilo/blob/master/Tests/KiloTests/KiloTests.swift).
