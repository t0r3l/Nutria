curl -X POST http://34.245.111.159:8080/optimize \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "target_array": [2000, 75, 50, 250]
    },
    "meal_fraction": 0.3,
    "solveur": "hybride",
    "sample_size": 500,
    "target_legumes": 100,
    "regime": "Vegan"
  }'ùm 