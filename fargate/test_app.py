from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/', methods=['POST'])
def handle_message():
    data = request.get_json()
    
    if not data or 'message' not in data:
        return jsonify({'error': 'No message provided'}), 400
    
    message = data['message'].lower()
    
    if message == 'hello':
        return jsonify({'response': 'hi'}), 200
    elif message == 'goodbye':
        return jsonify({'response': 'bye'}), 200
    else:
        return jsonify({'response': 'unknown message'}), 200

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)