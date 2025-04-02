# Socket module

Functions to test things in a local host.

# Functions

## socket.host(connection, content_type, response_code, content, port)

Opens a web socket and displays static HTML or JSOn into it.

## socket.host_with_response(connection, content_type, response_code, response_fn, port)

The same as socket.host but allows to threat incoming requests with a custom function.

## socket.http_header(connection, content_type, response_code)

Returns the most basic http header.