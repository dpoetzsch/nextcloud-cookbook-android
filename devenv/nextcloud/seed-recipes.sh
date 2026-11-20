#!/usr/bin/env bash
# Add sample recipes to the local Nextcloud via the Cookbook REST API.
set -euo pipefail
NC="${NC_URL:-http://localhost:8080}"
AUTH="${NC_AUTH:-admin:admin}"
API="$NC/index.php/apps/cookbook/api/v1"

post() {
  curl -fsS -u "$AUTH" -H 'Content-Type: application/json' -X POST "$API/recipes" -d "$1"
  echo
}

post '{
  "name": "Classic Pancakes",
  "description": "Fluffy breakfast pancakes.",
  "recipeCategory": "Breakfast",
  "keywords": "sweet,quick",
  "recipeYield": 4,
  "prepTime": "PT10M", "cookTime": "PT15M", "totalTime": "PT25M",
  "recipeIngredient": ["200 g flour", "2 eggs", "300 ml milk", "1 tbsp sugar", "1 tsp baking powder", "1 pinch salt"],
  "recipeInstructions": ["Whisk dry ingredients.", "Add eggs and milk, whisk until smooth.", "Fry ladlefuls in a hot buttered pan until golden on both sides."],
  "tool": ["Frying pan", "Whisk"]
}'

post '{
  "name": "Tomato Basil Pasta",
  "description": "A simple weeknight pasta.",
  "recipeCategory": "Main course",
  "keywords": "vegetarian,pasta",
  "recipeYield": 2,
  "prepTime": "PT5M", "cookTime": "PT20M", "totalTime": "PT25M",
  "recipeIngredient": ["250 g spaghetti", "400 g canned tomatoes", "2 cloves garlic", "1 handful basil", "2 tbsp olive oil", "Salt and pepper"],
  "recipeInstructions": ["Cook pasta in salted water.", "Fry garlic in olive oil, add tomatoes and simmer 15 minutes.", "Toss pasta with sauce and torn basil, season."],
  "tool": ["Pot", "Pan"]
}'

post '{
  "name": "Greek Salad",
  "description": "Fresh and crunchy.",
  "recipeCategory": "Salad",
  "keywords": "vegetarian,summer",
  "recipeYield": 2,
  "prepTime": "PT15M", "cookTime": "PT0M", "totalTime": "PT15M",
  "recipeIngredient": ["2 tomatoes", "1 cucumber", "1 red onion", "100 g feta", "1 handful olives", "3 tbsp olive oil", "1 tsp oregano"],
  "recipeInstructions": ["Chop vegetables.", "Combine with olives and feta.", "Dress with olive oil and oregano."],
  "tool": ["Knife", "Bowl"]
}'

echo "Recipes now on server:"
curl -fsS -u "$AUTH" "$API/recipes" | grep -o '"name":"[^"]*"'
