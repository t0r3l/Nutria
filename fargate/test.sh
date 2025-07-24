curl -s -X POST http://34.240.177.150:8080/optimize \
    -H "Content-Type: application/json" \
    -d '{
      "user": {"target_array": [2000, 150, 67, 250]},
      "meal_fraction": 0.3,
      "solveur": "hybride",
      "portion_legumes": 100
    }'