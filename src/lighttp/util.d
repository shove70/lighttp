﻿module lighttp.util;

import std.array : Appender;
import std.conv : to, ConvException;
import std.json : JSONValue;
import std.regex : ctRegex;
import std.string : toUpper, toLower, split, join, strip, indexOf;
import std.traits : EnumMembers;
import std.uri : encode, decode;

/**
 * Indicates the status of an HTTP response.
 */
struct Status {
	
	/**
	 * HTTP response status code.
	 */
	uint code;
	
	/**
	 * Additional short description of the status code.
	 */
	string message;
	
	bool opEquals(uint code) {
		return this.code == code;
	}
	
	bool opEquals(Status status) {
		return this.opEquals(status.code);
	}
	
	/**
	 * Concatenates the status code and the message into
	 * a string.
	 * Example:
	 * ---
	 * assert(Status(200, "OK").toString() == "200 OK");
	 * ---
	 */
	string toString() {
		return this.code.to!string ~ " " ~ this.message;
	}
	
	/**
	 * Creates a status from a known list of codes/messages.
	 * Example:
	 * ---
	 * assert(Status.get(200).message == "OK");
	 * ---
	 */
	public static Status get(uint code) {
		foreach(statusCode ; [EnumMembers!StatusCodes]) {
			if(code == statusCode.code) return statusCode;
		}
		return Status(code, "Unknown Status Code");
	}
	
}

/**
 * HTTP status codes and their human-readable names.
 */
enum StatusCodes : Status {
	
	// informational
	continue_ = Status(100, "Continue"),
	switchingProtocols = Status(101, "Switching Protocols"),
	
	// success
	ok = Status(200, "OK"),
	created = Status(201, "Created"),
	accepted = Status(202, "Accepted"),
	nonAuthoritativeContent = Status(203, "Non-Authoritative Information"),
	noContent = Status(204, "No Content"),
	resetContent = Status(205, "Reset Content"),
	partialContent = Status(206, "Partial Content"),
	
	// redirection
	multipleChoices = Status(300, "Multiple Choices"),
	movedPermanently = Status(301, "Moved Permanently"),
	found = Status(302, "Found"),
	seeOther = Status(303, "See Other"),
	notModified = Status(304, "Not Modified"),
	useProxy = Status(305, "Use Proxy"),
	switchProxy = Status(306, "Switch Proxy"),
	temporaryRedirect = Status(307, "Temporary Redirect"),
	permanentRedirect = Status(308, "Permanent Redirect"),
	
	// client errors
	badRequest = Status(400, "Bad Request"),
	unauthorized = Status(401, "Unauthorized"),
	paymentRequired = Status(402, "Payment Required"),
	forbidden = Status(403, "Forbidden"),
	notFound = Status(404, "Not Found"),
	methodNotAllowed = Status(405, "Method Not Allowed"),
	notAcceptable = Status(406, "Not Acceptable"),
	proxyAuthenticationRequired = Status(407, "Proxy Authentication Required"),
	requestTimeout = Status(408, "Request Timeout"),
	conflict = Status(409, "Conflict"),
	gone = Status(410, "Gone"),
	lengthRequired = Status(411, "Length Required"),
	preconditionFailed = Status(412, "Precondition Failed"),
	payloadTooLarge = Status(413, "Payload Too Large"),
	uriTooLong = Status(414, "URI Too Long"),
	unsupportedMediaType = Status(415, "Unsupported Media Type"),
	rangeNotSatisfiable = Status(416, "Range Not Satisfiable"),
	expectationFailed = Status(417, "Expectation Failed"),
	
	// server errors
	internalServerError = Status(500, "Internal Server Error"),
	notImplemented = Status(501, "Not Implemented"),
	badGateway = Status(502, "Bad Gateway"),
	serviceUnavailable = Status(503, "Service Unavailable"),
	gatewayTimeout = Status(504, "Gateway Timeout"),
	httpVersionNotSupported = Status(505, "HTTP Version Not Supported"),
	
}

/**
 * Frequently used Mime types.
 */
enum MimeTypes : string {
	
	// text
	html = "text/html",
	script = "text/javascript",
	css = "text/css",
	text = "text/plain",
	
	// images
	png = "image/png",
	jpeg = "image/jpeg",
	gif = "image/gif",
	ico = "image/x-icon",
	svg = "image/svg+xml",
	
	// other
	json = "application/json",
	zip = "application/zip",
	bin = "application/octet-stream",
	
}

/**
 * Base class for request and response. Contains common properties.
 */
abstract class HTTP {

	enum VERSION = "HTTP/1.1";
	
	enum GET = "GET";
	enum POST = "POST";

	/**
	 * Method used.
	 */
	public string method;

	/**
	 * Headers of the request/response.
	 */
	public string[string] headers;
	
	protected string _body;

	public this() {}

	public this(string method, string[string] headers) {
		this.method = method;
		this.headers = headers;
	}

	/**
	 * Gets the body of the request/response.
	 */
	public @property string body_() pure nothrow @safe @nogc {
		return _body;
	}

	/// ditto
	static if(__VERSION__ >= 2078) alias body = body_;

	/**
	 * Sets the body of the request/response.
	 */
	public @property string body_(T)(T data) {
		static if(is(T : string)) {
			return _body = cast(string)data;
		} else static if(is(T == JSONValue)) {
			this.headers["Content-Type"] = "application/json; charset=utf-8";
			return _body = data.toString();
		} else static if(is(T == JSONValue[string]) || is(T == JSONValue[])) {
			return body_ = JSONValue(data);
		} else {
			return _body = data.to!string;
		}
	}

}

enum defaultHeaders = (string[string]).init;

/**
 * Container for a HTTP request.
 * Example:
 * ---
 * new Request("GET", "/");
 * new Request(Request.POST, "/subscribe.php");
 * ---
 */
class Request : HTTP {

	private string _path;

	/**
	 * Query of the request. The part or the path after the
	 * question mark.
	 */
	public string[string] query;

	public this() {
		super();
	}
	
	public this(string method, string path, string[string] headers=defaultHeaders) {
		super(method, headers);
		this.path = path;
	}

	/**
	 * Gets the path of the request.
	 */
	public @property string path() pure nothrow @safe @nogc {
		return _path;
	}

	private @property string path(string path) {
		immutable qm = path.indexOf("?");
		if(qm == -1) {
			_path = path;
		} else {
			_path = path[0..qm];
			foreach(query ; path[qm+1..$].split("&")) {
				immutable eq = query.indexOf("=");
				if(eq > 0) this.query[query[0..eq]] = query[eq+1..$];
			}
		}
		return _path;
	}
	
	/**
	 * Encodes the request into a string.
	 * The `Content-Length` header property is always added automatically.
	 * Example:
	 * ---
	 * auto request = new Request(Request.GET, "index.html");
	 * assert(request.toString() == "GET /index.html HTTP/1.1\r\nContent-Length: 0\r\n");
	 * ---
	 */
	public override string toString() {
		if(this.body_.length) this.headers["Content-Length"] = to!string(this.body_.length);
		return encodeHTTP(this.method.toUpper() ~ " " ~ encode(this.path) ~ " HTTP/1.1", this.headers, this.body_);
	}
	
	/**
	 * Parses a string and returns whether the request was valid.
	 * Please note that every key in the header is converted to lowercase for
	 * an easier search in the associative array.
	 * Example:
	 * ---
	 * Request request = new Request();
	 * assert(request.parse("GET /index.html HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: Keep-Alive\r\n"));
	 * assert(request.method == Request.GET);
	 * assert(request.headers["Host"] == "127.0.0.1");
	 * assert(request.headers["Connection"] == "Keep-Alive");
	 * ---
	 */
	public bool parse(string data) {
		string status;
		if(decodeHTTP(data, status, this.headers, this._body)) {
			string[] spl = status.split(" ");
			if(spl.length == 3) {
				this.method = spl[0];
				this.path = decode(spl[1]);
				return true;
			}
		}
		return false;
	}
	
}

/**
 * Container for an HTTP response.
 * Example:
 * ---
 * new Response(200, ["Connection": "Close"], "<b>Hi there</b>");
 * new Response(404, [], "Cannot find the specified path");
 * new Response(204);
 * ---
 */
class Response : HTTP {
	
	/**
	 * Status of the response.
	 */
	Status status;
	
	/**
	 * If the response was parsed, indicates whether it was in a
	 * valid HTTP format.
	 */
	bool valid;

	public this() {}
	
	public this(Status status, string[string] headers=defaultHeaders, string body_="") {
		this.status = status;
		this.headers = headers;
		this.body_ = body_;
	}
	
	public this(uint statusCode, string[string] headers=defaultHeaders, string body_="") {
		this(Status.get(statusCode), headers, body_);
	}
	
	public this(Status status, string body_) {
		this(status, defaultHeaders, body_);
	}
	
	public this(uint statusCode, string body_) {
		this(statusCode, defaultHeaders, body_);
	}

	/**
	 * Sets the response's content-type header.
	 * Example:
	 * ---
	 * response.contentType = MimeTypes.html;
	 * ---
	 */
	public @property string contentType(string contentType) pure nothrow @safe {
		return this.headers["Content-Type"] = contentType;
	}
	
	/**
	 * Creates a 3xx redirect response and adds the `Location` field to
	 * the header.
	 * If not specified status code `301 Moved Permanently` will be used.
	 * Example:
	 * ---
	 * response.redirect("/index.html");
	 * response.redirect(302, "/view.php");
	 * response.redirect(StatusCodes.seeOther, "/icon.png", ["Server": "sel-net"]);
	 * ---
	 */
	public void redirect(Status status, string location) {
		this.status = status;
		this.headers["Location"] = location;
	}
	
	/// ditto
	public void redirect(uint statusCode, string location) {
		this.redirect(Status.get(statusCode), location);
	}
	
	/// ditto
	public void redirect(string location) {
		this.redirect(StatusCodes.movedPermanently, location);
	}
	
	/**
	 * Encodes the response into a string.
	 * The `Content-Length` header field is created automatically
	 * based on the length of the content field.
	 * Example:
	 * ---
	 * auto response = new Response(200, [], "Hi");
	 * assert(response.toString() == "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nHi");
	 * ---
	 */
	public override string toString() {
		this.headers["Content-Length"] = to!string(this.body_.length);
		return encodeHTTP("HTTP/1.1 " ~ this.status.toString(), this.headers, this.body_);
	}
	
	/**
	 * Parses a string and returns a Response.
	 * If the response is successfully parsed Response.valid will be true.
	 * Please note that every key in the header is converted to lowercase for
	 * an easier search in the associative array.
	 * Example:
	 * ---
	 * auto response = new Response()
	 * assert(response.parse("HTTP/1.1 200 OK\r\nContent-Type: plain/text\r\nContent-Length: 4\r\n\r\ntest"));
	 * assert(response.status == 200);
	 * assert(response.headers["content-type"] == "text/plain");
	 * assert(response.headers["content-length"] == "4");
	 * assert(response.content == "test");
	 * ---
	 */
	public bool parse(string str) {
		string status;
		if(decodeHTTP(str, status, this.headers, this._body)) {
			string[] head = status.split(" ");
			if(head.length >= 3) {
				try {
					this.status = Status(to!uint(head[1]), join(head[2..$], " "));
					return true;
				} catch(ConvException) {}
			}
		}
		return false;
	}
	
}

private enum CR_LF = "\r\n";

private string encodeHTTP(string status, string[string] headers, string content) {
	Appender!string ret;
	ret.put(status);
	ret.put(CR_LF);
	foreach(key, value; headers) {
		ret.put(key);
		ret.put(": ");
		ret.put(value);
		ret.put(CR_LF);
	}
	ret.put(CR_LF); // empty line
	ret.put(content);
	return ret.data;
}

private bool decodeHTTP(string str, ref string status, ref string[string] headers, ref string content) {
	string[] spl = str.split(CR_LF);
	if(spl.length > 1) {
		status = spl[0];
		size_t index;
		while(++index < spl.length && spl[index].length) { // read until empty line
			auto s = spl[index].split(":");
			if(s.length >= 2) {
				headers[s[0].strip.toLower()] = s[1..$].join(":").strip;
			} else {
				return false; // invalid header
			}
		}
		content = join(spl[index+1..$], "\r\n");
		return true;
	} else {
		return false;
	}
}
