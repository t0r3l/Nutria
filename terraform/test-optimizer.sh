#\!/bin/bash
curl -X POST "https://tztmsbrq2k.execute-api.eu-west-1.amazonaws.com/dev/optimize" -H "Content-Type: application/json" -d '{"user":{"target_array":[2000,600,80,200]},"meal_fraction":0.3,"solveur":"hybride","sample_size":500}'
