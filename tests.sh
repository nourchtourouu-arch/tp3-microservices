#!/bin/bash
H=http://localhost:8082
J='Content-Type: application/json'
t() { echo "\$ $*"; "$@"; echo; echo; }
mkdir -p preuves

{
  echo "=== F.6 ==="
  echo "# Test 1"; t curl -s -i -X POST -H "$J" -d '{"operateur":"somme","a":8,"b":2}' $H/operations
  echo "# Test 2"; t curl -s -i -X POST -H "$J" -d '{"operateur":"division","a":7,"b":2}' $H/operations
  echo "# Test 3"; t curl -s -i $H/operations
  echo "# Test 4"; t curl -s -i $H/operations/2
  echo "# Test 5"; t curl -s -i $H/operations/99
  echo "# Test 6"; t curl -s -i -X POST -H "$J" -d '{"operateur":"division","a":7,"b":0}' $H/operations
  echo "# Test 7"; t curl -s -i -X POST -H "$J" -d '{"operateur":"racine","a":9,"b":0}' $H/operations
} 2>&1 | tee preuves/F6.txt

{
  echo "=== F.8 PUT ==="
  echo "# PUT reussi (attendu 200, resultat 16.0)"; t curl -s -i -X PUT -H "$J" -d '{"operateur":"produit","a":8,"b":2}' $H/operations/1
  echo "# GET apres PUT"; t curl -s -i $H/operations/1
  echo "# PUT id inconnu (attendu 404)"; t curl -s -i -X PUT -H "$J" -d '{"operateur":"somme","a":1,"b":1}' $H/operations/99
  echo "# PUT division par 0 (attendu 400)"; t curl -s -i -X PUT -H "$J" -d '{"operateur":"division","a":7,"b":0}' $H/operations/1
  echo "# PUT operateur inconnu (attendu 400)"; t curl -s -i -X PUT -H "$J" -d '{"operateur":"racine","a":9,"b":0}' $H/operations/1
} 2>&1 | tee preuves/F8.txt

read -p ">>> Arrete calcul-service (Ctrl+C dans le terminal A), puis appuie sur Entree : "

{
  echo "=== F.7 (calcul-service arrete) ==="
  echo "# Test 8"; t curl -s -i $H/operations
  echo "# Test 9"; t curl -s -i $H/operations/1
  echo "# Test 10"; t curl -s -i -X POST -H "$J" -d '{"operateur":"produit","a":3,"b":4}' $H/operations
  echo "# PUT avec calcul-service injoignable (attendu 503)"; t curl -s -i -X PUT -H "$J" -d '{"operateur":"somme","a":1,"b":1}' $H/operations/1
} 2>&1 | tee preuves/F7.txt

read -p ">>> Relance calcul-service dans le terminal A (./mvnw spring-boot:run), attends 'Tomcat started', puis Entree : "

{
  echo "=== F.7 (calcul-service relance) ==="
  echo "# Test 10 renvoye (attendu 201, id 3)"; t curl -s -i -X POST -H "$J" -d '{"operateur":"produit","a":3,"b":4}' $H/operations
} 2>&1 | tee -a preuves/F7.txt

{
  echo "=== F.9 DELETE ==="
  echo "# DELETE 1 (attendu 204)"; t curl -s -i -X DELETE $H/operations/1
  echo "# GET 1 (attendu 404)"; t curl -s -i $H/operations/1
  echo "# DELETE 1 (attendu 404)"; t curl -s -i -X DELETE $H/operations/1
} 2>&1 | tee preuves/F9.txt
