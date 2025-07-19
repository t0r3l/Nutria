#!/usr/bin/env python3
"""
Local test script for the Fargate application
"""
import requests
import json

def test_health():
    """Test health endpoint"""
    try:
        response = requests.get("http://localhost:8080/health")
        print(f"Health check: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Health check failed: {e}")
        return False

def test_optimization():
    """Test optimization endpoint"""
    try:
        payload = {
            "user": {
                "target_array": [2000, 600, 80, 200]
            },
            "meal_fraction": 0.3,
            "solveur": "hybride",
            "sample_size": 1000
        }
        
        response = requests.post(
            "http://localhost:8080/optimize",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        
        print(f"Optimization test: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"Products used: {data.get('products_used', 'N/A')}")
            print(f"Solver: {data.get('solver', 'N/A')}")
            print(f"Residual: {data.get('residual', 'N/A')}")
        else:
            print(f"Error: {response.text}")
        
        return response.status_code == 200
    except Exception as e:
        print(f"Optimization test failed: {e}")
        return False

if __name__ == "__main__":
    print("🧪 Testing Fargate application locally...")
    print("Make sure the app is running: python app.py")
    print()
    
    if test_health():
        print("✅ Health check passed")
    else:
        print("❌ Health check failed")
    
    print()
    
    if test_optimization():
        print("✅ Optimization test passed")
    else:
        print("❌ Optimization test failed")
