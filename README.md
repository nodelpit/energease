# EnergEase

EnergeASE est une application Rails permettant le suivi et l'analyse de votre consommation d'énergie en intégrant les données d'Enedis (gestionnaire du réseau de distribution d'électricité en France).

## Fonctionnalités

- Connexion via l'API Enedis (DataConnect)
- Visualisation de la consommation d'énergie (quotidienne et mensuelle)
- Analyses et graphiques de consommation
- Suivi des tendances d'utilisation

## Mode de démonstration

⚠️ **Important** : Cette application est actuellement en mode démonstration uniquement.

Le processus d'authentification OAuth2 d'Enedis nécessite une validation en production pour récupérer de véritables données de consommation des utilisateurs. Dans cette version de démonstration :

- L'authentification réelle avec Enedis n'est pas disponible
- Les données de consommation affichées sont générées automatiquement
- Le service `MockApiService` simule les réponses de l'API Enedis avec des données fictives
- L'interface utilisateur fonctionne comme si elle était connectée à de vraies données

Cette approche permet de tester et d'explorer toutes les fonctionnalités de l'application sans avoir besoin d'une autorisation complète d'Enedis pour l'accès aux données réelles des utilisateurs.
