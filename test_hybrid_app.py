#!/usr/bin/env python3
"""
Test script for app2_hybrid.py
Demonstrates local vs AWS environment detection and optimization with portion_legumes
"""

import requests
import json
import time
import subprocess
import os
import signal
from multiprocessing import Process

def start_hybrid_app(port=8082):
    """Start the hybrid app in the background"""
    env = os.environ.copy()
    env['PORT'] = str(port)
    env['ENVIRONMENT'] = 'local'  # Force local mode for testing
    
    cmd = ['python', '/home/torel/IdeaProjects/NutriaIngestionAndSolver/fargate/app2_hybrid.py']
    process = subprocess.Popen(cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    # Wait for app to start
    time.sleep(3)
    return process

def test_health_endpoint(port=8082):
    """Test the health endpoint"""
    print("🏥 Testing Health Endpoint:")
    print("=" * 50)
    
    try:
        response = requests.get(f"http://localhost:{port}/health", timeout=5)
        health_data = response.json()
        
        print(f"✅ Status: {health_data.get('status')}")
        print(f"🌍 Environment: {health_data.get('environment')}")
        print(f"📊 Data Source: {health_data.get('data_source')}")
        print(f"📁 Local File: {health_data.get('local_file', 'N/A')}")
        print(f"🔗 Data Connectivity: {health_data.get('data_connectivity')}")
        print(f"🚀 Deployment Type: {health_data.get('deployment')}")
        
        return True
    except Exception as e:
        print(f"❌ Health check failed: {e}")
        return False

def test_optimization_endpoint(port=8082):
    """Test the optimization endpoint with different parameters"""
    print("\n🍽️  Testing Optimization Endpoint:")
    print("=" * 50)
    
    # Test cases with different portion_legumes values
    test_cases = [
        {
            "name": "Basic optimization (portion_legumes=100)",
            "payload": {
                "user": {"target_array": [2000, 150, 67, 250]},
                "meal_fraction": 0.3,
                "solveur": "hybride",
                "portion_legumes": 100
            }
        },
        {
            "name": "Higher legumes target (portion_legumes=200)",
            "payload": {
                "user": {"target_array": [2000, 150, 67, 250]},
                "meal_fraction": 0.3,
                "solveur": "hybride", 
                "portion_legumes": 200
            }
        },
        {
            "name": "No legumes constraint (portion_legumes=0)",
            "payload": {
                "user": {"target_array": [2000, 150, 67, 250]},
                "meal_fraction": 0.3,
                "solveur": "hybride",
                "portion_legumes": 0
            }
        }
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n📝 Test Case {i}: {test_case['name']}")
        print("-" * 40)
        
        try:
            response = requests.post(
                f"http://localhost:{port}/optimize",
                json=test_case['payload'],
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                
                print(f"✅ Status: Success ({response.status_code})")
                print(f"🔧 Solver Used: {data.get('solver')}")
                print(f"📊 Products Used: {data.get('products_used')}")
                print(f"🥬 Portion Legumes: {test_case['payload']['portion_legumes']}g")
                print(f"🏗️  Deployment Info: {data.get('deployment_info', {}).get('type')}")
                print(f"📈 Data Source: {data.get('deployment_info', {}).get('data_source')}")
                
                # Show top 3 products
                meal_plan = data.get('meal_plan', [])
                print(f"\n🍽️  Top 3 Products:")
                for j, product in enumerate(meal_plan[:3], 1):
                    name = product.get('product_name', 'Unknown')[:40]
                    quantity = product.get('quantité_g', 0)
                    print(f"   {j}. {name:<40} {quantity:.1f}g")
                
                # Show verification if available
                verification = data.get('verification')
                if verification:
                    targets = verification.get('targets', [])
                    obtained = verification.get('obtained', [])
                    if targets and obtained and len(targets) >= 4:
                        print(f"\n📊 Target vs Obtained (first 4 nutrients):")
                        nutrients = ['Energy (kcal)', 'Proteins (g)', 'Fat (g)', 'Carbs (g)']
                        try:
                            for k, (target, got, nutrient) in enumerate(zip(targets[:4], obtained[:4], nutrients)):
                                print(f"   {nutrient:<15}: {float(target):.1f} → {float(got):.1f}")
                        except (ValueError, TypeError) as e:
                            print(f"   📊 Verification data available but format not parseable")
                
            else:
                print(f"❌ Error ({response.status_code}): {response.text}")
                
        except Exception as e:
            print(f"❌ Request failed: {e}")

def test_environment_detection():
    """Test environment detection logic"""
    print("\n🌍 Testing Environment Detection:")
    print("=" * 50)
    
    # Test different environment variables
    test_envs = [
        ('local', 'LOCAL'),
        ('dev', 'LOCAL'), 
        ('development', 'LOCAL'),
        ('production', 'AWS'),
        ('prod', 'AWS'),
        ('staging', 'AWS')
    ]
    
    for env_value, expected_mode in test_envs:
        # Simulate the detection logic from app2_hybrid.py
        is_local = env_value.lower() in ['local', 'dev', 'development']
        actual_mode = 'LOCAL' if is_local else 'AWS'
        status = "✅" if actual_mode == expected_mode else "❌"
        print(f"{status} ENVIRONMENT='{env_value}' → {actual_mode} mode")

def main():
    """Main test function"""
    print("🧪 Nutria Hybrid App Test Suite")
    print("=" * 60)
    print("Testing app2_hybrid.py functionality")
    print("Local CSV file detection and optimization with portion_legumes\n")
    
    # Test environment detection logic
    test_environment_detection()
    
    # Start the hybrid app
    print("\n🚀 Starting hybrid app on port 8082...")
    app_process = start_hybrid_app(8082)
    
    try:
        # Test health endpoint
        if test_health_endpoint(8082):
            # Test optimization endpoint
            test_optimization_endpoint(8082)
        else:
            print("❌ Skipping optimization tests due to health check failure")
            
    finally:
        # Clean up
        print("\n🧹 Cleaning up...")
        try:
            app_process.terminate()
            app_process.wait(timeout=5)
            print("✅ App process terminated successfully")
        except:
            app_process.kill()
            print("⚠️  App process killed forcefully")
    
    print("\n🎉 Test suite completed!")

if __name__ == "__main__":
    main()