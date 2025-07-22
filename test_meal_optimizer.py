#!/usr/bin/env python3
"""
Test script for the Fargate meal optimizer endpoint
"""

import requests
import json
import sys

# Configuration
FARGATE_URL = "http://localhost:8080"  # Update with your Fargate ALB URL
# FARGATE_URL = "http://your-alb-url.region.elb.amazonaws.com"

def test_health_check():
    """Test the health check endpoint"""
    print("Testing health check...")
    try:
        response = requests.get(f"{FARGATE_URL}/health")
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"Health check failed: {e}")
        return False

def test_meal_optimizer():
    """Test the meal optimizer endpoint"""
    print("\nTesting meal optimizer...")
    
    # Test payload
    payload = {
        "user": {
            "target_array": [2000, 600, 80, 200]  # [calories, carbs, fat, proteins]
        },
        "meal_fraction": 0.3,  # 30% of daily targets for this meal
        "solveur": "hybride",  # Options: "hybride", "nnls", "lsq"
        "sample_size": 1000
    }
    
    print(f"Request payload: {json.dumps(payload, indent=2)}")
    
    try:
        response = requests.post(
            f"{FARGATE_URL}/optimize",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        
        print(f"\nStatus Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("\nOptimization successful!")
            print(f"Solver used: {result.get('solver')}")
            print(f"Products in meal plan: {result.get('products_used')}")
            
            # Display meal plan
            print("\nMeal Plan:")
            for i, product in enumerate(result.get('meal_plan', [])[:10]):  # Show first 10
                print(f"  {i+1}. {product['product_name']}: {product['quantité_g']:.1f}g")
            
            if len(result.get('meal_plan', [])) > 10:
                print(f"  ... and {len(result['meal_plan']) - 10} more products")
            
            # Display verification
            verification = result.get('verification', {})
            print("\nNutrition verification:")
            print(f"  Targets: {verification.get('targets')}")
            print(f"  Obtained: {[f'{x:.1f}' for x in verification.get('obtained', [])]}")
            
        else:
            print(f"Error response: {response.text}")
            
        return response.status_code == 200
        
    except Exception as e:
        print(f"Optimizer test failed: {e}")
        return False

def test_with_different_solvers():
    """Test with different solver options"""
    print("\n\nTesting different solvers...")
    
    solvers = ["hybride", "nnls", "lsq_linear"]
    base_payload = {
        "user": {
            "target_array": [2000, 600, 80, 200]
        },
        "meal_fraction": 0.3,
        "sample_size": 500
    }
    
    for solver in solvers:
        print(f"\n--- Testing with solver: {solver} ---")
        payload = base_payload.copy()
        payload["solveur"] = solver
        
        try:
            response = requests.post(
                f"{FARGATE_URL}/optimize",
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"✓ Success: {result.get('products_used')} products in plan")
            else:
                print(f"✗ Failed: {response.status_code}")
                
        except Exception as e:
            print(f"✗ Error: {e}")

def test_edge_cases():
    """Test edge cases and error handling"""
    print("\n\nTesting edge cases...")
    
    # Test 1: Missing user data
    print("\n1. Testing missing user data...")
    response = requests.post(f"{FARGATE_URL}/optimize", json={})
    print(f"   Expected 400, got: {response.status_code}")
    
    # Test 2: Invalid target array
    print("\n2. Testing invalid target array...")
    response = requests.post(f"{FARGATE_URL}/optimize", json={
        "user": {"target_array": [2000]}  # Too few values
    })
    print(f"   Response: {response.status_code}")
    
    # Test 3: Very small meal fraction
    print("\n3. Testing very small meal fraction...")
    response = requests.post(f"{FARGATE_URL}/optimize", json={
        "user": {"target_array": [2000, 600, 80, 200]},
        "meal_fraction": 0.01
    })
    print(f"   Response: {response.status_code}")

if __name__ == "__main__":
    print("=== Fargate Meal Optimizer Test Suite ===\n")
    
    # Check if custom URL provided
    if len(sys.argv) > 1:
        FARGATE_URL = sys.argv[1].rstrip('/')
        print(f"Using URL: {FARGATE_URL}\n")
    
    # Run tests
    health_ok = test_health_check()
    if not health_ok:
        print("\nHealth check failed! Is the service running?")
        sys.exit(1)
    
    optimizer_ok = test_meal_optimizer()
    
    # Optional: run additional tests
    if optimizer_ok:
        test_with_different_solvers()
        test_edge_cases()
    
    print("\n=== Test suite completed ===")