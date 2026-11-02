# TP3 REST : Microservices « Calculatrice » avec Spring Boot

Matière : Architecture MicroServices | Filière : MPSRCC1 | Faculté des Sciences de Sfax

## 1. Contenu du dépôt

| Dossier | Rôle | Port |
|---|---|---|
| `calcul-service/` | Effectue les 4 calculs (ressource `/calcul`) | 8081 |
| `historique-service/` | Enregistre les opérations (ressource `/operations`), appelle `calcul-service` par HTTP | 8082 |
| `preuves/` | Sorties de `curl -i` de tous les tests | |
| `captures/` | Capture des deux consoles (Tomcat started on port 8081 et 8082) | |

## 2. Lancer le projet (WSL, sans IntelliJ)

Prérequis : JDK 17+, curl.

```bash
# Terminal 1
cd calcul-service
./mvnw clean package
java -jar target/calcul-service-0.0.1-SNAPSHOT.jar

# Terminal 2
cd historique-service
./mvnw clean package
java -jar target/historique-service-0.0.1-SNAPSHOT.jar
```

Test rapide :

```bash
curl -i "http://localhost:8081/calcul/somme?a=2&b=3"
curl -i -X POST -H "Content-Type: application/json" -d '{"operateur":"somme","a":8,"b":2}' http://localhost:8082/operations
```

---

## 3. Partie A : questions de conception

**1. Avantage et inconvénient de l'appel HTTP (au lieu d'un appel de méthode)**
Avantage : `calcul-service` est indépendant, on peut le modifier, le redéployer ou le multiplier sans toucher à `historique-service`. Inconvénient : l'appel passe par le réseau, donc il est plus lent qu'un appel de méthode et peut échouer (service arrêté, réseau coupé).

**2. Si `calcul-service` est arrêté**
Continuent de fonctionner : `GET /operations`, `GET /operations/{id}` et `DELETE /operations/{id}` (ils n'ont pas besoin de calcul). Échouent : les 4 requêtes `GET :8081/calcul/...` (service injoignable), et `POST /operations` et `PUT /operations/{id}` (le calcul est demandé à `calcul-service`, réponse 503).

**3. Pourquoi pas le même port ?**
Un port ne peut être occupé que par un seul processus à la fois : le second démarrage échoue avec « Port already in use ».

**4. Code de statut quand `calcul-service` est injoignable**
503 Service Unavailable : le serveur est correct, mais un service dont il dépend est indisponible.

## 4. Partie C : premier microservice

**Tableau de correspondance (C.2)**

| Spring (TP3) | JAX-RS (TP2) | Rôle dans cet exemple |
|---|---|---|
| `@RestController` | (pas d'équivalent direct) | Déclare une classe contrôleur REST dont les valeurs retournées forment le corps de la réponse |
| `@RequestMapping("/calcul")` | `@Path("/calcul")` sur la classe | Chemin de base de toutes les méthodes du contrôleur |
| `@GetMapping("/somme")` | `@GET` + `@Path("/somme")` | La méthode répond à `GET /calcul/somme` |
| `produces = MediaType.TEXT_PLAIN_VALUE` | `@Produces(MediaType.TEXT_PLAIN)` | La réponse est en texte brut |
| `@RequestParam("a") int a` | `@QueryParam("a") int a` | Lit le paramètre `a` de l'URL (`?a=2`) |
| `ResponseEntity.ok(...)` | `Response.ok(...).build()` | Construit une réponse de statut 200 |

**Tableau C.6 (origine des parties de l'URL)**

| Partie de l'URL | Origine |
|---|---|
| `localhost:8081` | Machine locale et port fixé par `server.port` dans `application.properties` |
| `/calcul` | `@RequestMapping("/calcul")` de la classe |
| `/somme` | `@GetMapping("/somme")` de la méthode |
| `?a=2&b=3` | Paramètres de requête lus par `@RequestParam("a")` et `@RequestParam("b")` |

**Question C.1.** Ont disparu `RestWebApp` et `/api`, et le port passe de 8080 à 8081. `RestWebApp` était le nom du `.war` déployé dans Tomcat (le contexte de l'application) : le microservice démarre seul avec le contexte `/`, il n'y a plus de déploiement. `/api` venait de `@ApplicationPath("/api")` dans la classe `RestApplication` : cette classe n'existe plus, `@SpringBootApplication` la remplace.

**Question C.2.** Un POST sur `/calcul/somme` renvoie **405 Method Not Allowed** : l'URI existe mais seul GET est géré. C'est le même statut qu'au TP2.

## 5. Partie D : compléter la calculatrice

Tests (voir `preuves/calcul-service.txt`) :

| Requête | Résultat |
|---|---|
| `GET /calcul/soustraction?a=10&b=4` | 6 |
| `GET /calcul/produit?a=6&b=7` | 42 |
| `GET /calcul/division?a=7&b=2` | 200, `3.5` |
| `GET /calcul/division?a=7&b=0` | 400, `Erreur : division par 0 impossible` |
| `GET /calcul/produit/6/7` | 42 |

**D.3 Observations.** `GET /calcul/somme?a=2` (b absent) et `GET /calcul/somme?a=abc&b=3` (a non entier) renvoient tous deux le statut **400 Bad Request**.

**Question D.1.** Spring ne donne pas de valeur par défaut à un paramètre absent : il répond 400 sans exécuter la méthode. L'attitude de Spring est plus conforme à REST : la requête du client est incorrecte, il faut le lui dire par un statut 4xx plutôt que renvoyer un résultat faux (somme avec b=0) qui masque l'erreur.

**Question D.2.** L'objet JSON d'erreur contient les champs `timestamp`, `status`, `error` et `path`.

**Question D.3.**

| Spring | JAX-RS |
|---|---|
| `@RequestParam` | `@QueryParam` |
| `@PathVariable` | `@PathParam` |

Pour lire l'identifiant dans `/operations/{id}`, on utilise `@PathVariable("id")`.

## 6. Partie E : JSON

**Question E.1.** Oui, les deux JSON sont équivalents : un objet JSON est un ensemble de champs nommés, dont l'ordre n'a pas d'importance, le client lit chaque valeur par son nom. Cette fois, la conversion a été faite par **Jackson** (inclus dans `spring-boot-starter-webmvc`), au lieu de JSON-B au TP2.

**Question E.2.** Pour renvoyer un objet, Spring utilise des convertisseurs de messages ; seul celui de Jackson pour JSON est disponible (aucune bibliothèque XML n'est dans le projet). Avec `Accept: application/xml`, Spring ne peut produire aucun format acceptable pour le client : il répond 406 Not Acceptable. Il n'est donc pas nécessaire que la méthode mentionne un format.

**E.4 (divisionDetail).** `GET /calcul/division/detail?a=..&b=..` renvoie un `Resultat` en JSON (200), ou 400 si `b` vaut 0.

## 7. Partie F : historique-service

### F.6 Création et lecture (voir `preuves/F6.txt`)

| N° | Requête | Corps envoyé | Statut | Réponse |
|---|---|---|---|---|
| 1 | POST /operations | `{"operateur":"somme","a":8,"b":2}` | 201 (+ en-tête `Location`) | `{"a":8,"b":2,"id":1,"operateur":"somme","resultat":10.0}` |
| 2 | POST /operations | `{"operateur":"division","a":7,"b":2}` | 201 | `{"a":7,"b":2,"id":2,"operateur":"division","resultat":3.5}` |
| 3 | GET /operations | aucun | 200 | liste des deux opérations |
| 4 | GET /operations/2 | aucun | 200 | l'opération 2 (division) |
| 5 | GET /operations/99 | aucun | 404 | corps vide |
| 6 | POST /operations | `{"operateur":"division","a":7,"b":0}` | 400 | `{"erreur":"Calcul impossible (division par 0 ?)"}` |
| 7 | POST /operations | `{"operateur":"racine","a":9,"b":0}` | 400 | `{"erreur":"Opérateur inconnu : racine"}` |

### F.7 Expérience : `calcul-service` arrêté (voir `preuves/F7.txt`)

| N° | Requête | Corps envoyé | Statut | Réponse |
|---|---|---|---|---|
| 8 | GET /operations | aucun | 200 | liste des opérations |
| 9 | GET /operations/1 | aucun | 200 | l'opération 1 |
| 10 | POST /operations | `{"operateur":"produit","a":3,"b":4}` | 503 | `{"erreur":"calcul-service est indisponible"}` |

Après redémarrage de `calcul-service`, la requête 10 répond 201 avec l'identifiant 3.

**Question F.1.** Les lectures (GET) ne font que lire la liste en mémoire d'`historique-service` : elles n'ont pas besoin de `calcul-service`. Ce n'était pas possible au TP2 : calcul et historique étaient dans le même `.war`, donc arrêter l'application arrêtait tout.

**Question F.2.** Sans le bloc `catch (ResourceAccessException e)`, l'exception remonte jusqu'à Spring, qui répond **500 Internal Server Error** avec une trace dans la console. Le client croirait à un bug du serveur, alors que la vraie cause est l'indisponibilité d'un service dont on dépend (503). La réponse est rapide car le refus de connexion est immédiat.

### F.8 PUT /operations/{id} (voir `preuves/F8.txt`)

| Situation | Statut | Corps |
|---|---|---|
| Aucune opération ne porte cet identifiant | 404 | `{"erreur":"Opération introuvable : <id>"}` |
| Calcul impossible (opérateur inconnu, division par 0) | 400 | `{"erreur":"..."}` |
| `calcul-service` injoignable | 503 | `{"erreur":"calcul-service est indisponible"}` |
| Modification réussie | 200 | l'opération modifiée en JSON (ex. résultat 16.0) |

### F.9 DELETE /operations/{id} (voir `preuves/F9.txt`)

| Situation | Statut | Corps |
|---|---|---|
| Aucune opération ne porte cet identifiant | 404 | vide |
| Suppression réussie | 204 | vide |

Tests : DELETE → 204, puis GET → 404, puis DELETE → 404.

---

## 8. Questions de synthèse

**1. Tableau A.3 : étape où la différence est observée**

| Aspect | Étape |
|---|---|
| Technologie | B.3, C.2 |
| Découpage | A.2, parties B et F (deux projets) |
| Résultat de la construction | B.3, C.5 (`.jar`) |
| Serveur | C.5 (ligne « Tomcat started on port ») |
| Port | C.4 |
| Adresse | C.6 |
| Activation | B.4 |
| Ressource REST | C.2 |
| Verbes HTTP | F.5, F.8, F.9 |
| Paramètres | C.2, D.4, F.5 (`@RequestBody`) |
| Réponse HTTP | C.2, D.2 |
| Conversion JSON | E.2 |
| Création des objets | C.1, C.2, F.4 |
| Communication | F.3 |

**2. Correspondance complète JAX-RS / Spring**

| JAX-RS (TP2) | Spring (TP3) |
|---|---|
| `@ApplicationPath` + classe `Application` | `@SpringBootApplication` + `main` |
| `@Path` (classe) | `@RestController` + `@RequestMapping` |
| `@Path` (méthode) | chemin dans `@GetMapping("...")` etc. |
| `@GET`, `@POST`, `@PUT`, `@DELETE` | `@GetMapping`, `@PostMapping`, `@PutMapping`, `@DeleteMapping` |
| `@QueryParam` | `@RequestParam` |
| `@PathParam` | `@PathVariable` |
| `@Consumes` + paramètre corps | `@RequestBody` |
| `@Produces` | `produces = ...` |
| `Response` | `ResponseEntity` |
| `uriInfo.getAbsolutePathBuilder()` | `ServletUriComponentsBuilder.fromCurrentRequest()` |
| JSON-B | Jackson |

**3. Construire et lancer sans IntelliJ**

```bash
cd calcul-service && ./mvnw clean package && java -jar target/calcul-service-0.0.1-SNAPSHOT.jar
# dans un second terminal
cd historique-service && ./mvnw clean package && java -jar target/historique-service-0.0.1-SNAPSHOT.jar
```

**4. Microservice et service web.** Un microservice est un service web : il expose ses fonctions par HTTP (URI, verbes, JSON). Mais un service web n'est pas toujours un microservice : `RestWebApp.war` du TP2 était un service web, mais pas un microservice, car il réunissait calcul et historique dans une seule application, qui dépendait d'un Tomcat installé à part. Un microservice est autonome, responsable d'une seule fonctionnalité, et déployable indépendamment.

**5. Trois exemplaires de `calcul-service`.** L'adresse `http://localhost:8081` est écrite en dur : `historique-service` ne connaît qu'un seul exemplaire et enverrait toutes ses requêtes à celui-là, sans répartition de charge ; les deux autres exemplaires (sur d'autres ports) resteraient ignorés. Il faut un mécanisme de découverte des instances et de répartition (traité au TP4).

**6. Stateless et liste des opérations.** Le principe stateless interdit de mémoriser l'état de la conversation avec un client (qui il est, ce qu'il a demandé avant) : chaque requête contient tout ce qu'il faut pour être traitée. La liste d'opérations n'est pas un état de client, mais l'état de la ressource `/operations`, commun à tous les clients, comme le contenu d'une base de données. Les requêtes restent indépendantes les unes des autres.

**7. Répétition de POST et PUT.** Deux fois le même POST crée deux opérations différentes (deux identifiants) : POST n'est pas idempotent. Deux fois le même PUT /operations/1 laisse la ressource dans le même état que la première fois : PUT est idempotent. La réponse est la même qu'au TP2, car cette différence vient de la définition des verbes HTTP, pas de la technologie utilisée.
