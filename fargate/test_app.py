from flask import Flask
import sys
import logging

# Force logging to stdout
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    stream=sys.stdout,
    force=True
)

app = Flask(__name__)

@app.route('/health')
def health():
    print("Health check called!", flush=True)
    logging.info("Health check endpoint called")
    return {'status': 'ok', 'message': 'Simple test app working'}, 200

@app.route('/')
def root():
    print("Root endpoint called!", flush=True)
    logging.info("Root endpoint called")
    return {'message': 'Test app is running'}, 200

if __name__ == '__main__':
    print("Starting test Flask app...", flush=True)
    logging.info("Starting test Flask app on port 8080")
    
    try:
        app.run(host='0.0.0.0', port=8080, debug=True)
    except Exception as e:
        print(f"Failed to start app: {e}", flush=True)
        logging.error(f"Failed to start app: {e}")
