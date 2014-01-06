import time
import BaseHTTPServer
import urlparse
import urllib

HOST_NAME = 'YOURHOSTNAME.COM'
PORT_NUMBER = 8000

request_times = {}
messages = []

class MyHandler(BaseHTTPServer.BaseHTTPRequestHandler):
    def do_HEAD(s):
        s.send_response(200)
        s.send_header("Content-type", "text/html; charset=utf-8")
        s.end_headers()
    def do_GET(s):
        s.send_response(200)
        s.send_header("Content-type", "text/html; charset=utf-8")
        s.end_headers()

        if s.path == "/favicon.ico":
            return

        parsed_path = urlparse.urlparse(s.path)
        try:
            params = dict([p.split('=') for p in parsed_path[4].split('&')])
        except:
            params = {}

        current_time = time.time()
        hostname = urllib.unquote_plus(params['hostname']).decode('utf-8')
        received_messages = urllib.unquote_plus(params['messages']).decode('utf-8')

        if not request_times.has_key(hostname):
            request_times[hostname] = current_time

        if received_messages:
            received_messages_list = received_messages.split('\n')
            for message in received_messages_list:
                store_message = {
                    'message': message,
                    'timestamp': current_time,
                    'hostname': hostname
               }
                messages.append(store_message)

        first = True
        for message in messages:
            if message['timestamp'] > request_times[hostname] and message['hostname'] != hostname:
                send_message = message['message']
                if not first:
                    s.wfile.write("\n")
                s.wfile.write(send_message.encode('utf-8'))
                first = False
            elif current_time - message['timestamp'] > 10.0:
                messages.remove(message)

        request_times[hostname] = time.time()


if __name__ == '__main__':
    server_class = BaseHTTPServer.HTTPServer
    httpd = server_class((HOST_NAME, PORT_NUMBER), MyHandler)
    print time.asctime(), "Server Starts - %s:%s" % (HOST_NAME, PORT_NUMBER)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
    print time.asctime(), "Server Stops - %s:%s" % (HOST_NAME, PORT_NUMBER)
