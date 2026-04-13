# Pack de distribution - Test réel 10 utilisateurs

Backend: `https://frappedollars-backend-1.onrender.com`

EA client à installer: [mt5/FrappedDollarsClient.mq5](mt5/FrappedDollarsClient.mq5)

## Règles de test

- Utiliser le compte MT5 Deriv Demo indiqué ci-dessous.
- Ne pas changer le broker, le serveur ou le type de compte.
- Ne pas modifier le code de l'EA.
- Renseigner uniquement la clé API fournie.
- Vérifier que le trading automatique est activé dans MT5.

## Installation simple

1. Ouvrir MT5.
2. Ouvrir le compte Deriv Demo correspondant.
3. Copier l'EA client [mt5/FrappedDollarsClient.mq5](mt5/FrappedDollarsClient.mq5) dans le dossier Experts et le compiler si nécessaire.
4. Glisser l'EA sur un graphique.
5. Coller la clé API du client dans `InpApiKey`.
6. Laisser `InpBroker = Deriv`, `InpServer = Demo`, `InpAccountType = DEMO`.
7. Vérifier que le trading automatique est activé.
8. Attendre le polling du backend et la réception d'un trade.

## Clés API par utilisateur

| # | MT5 login | Client login complet | Clé API |
|---|---|---|---|
| 1 | `201305586` | `201305586_Deriv_Demo_DEMO` | `afQZ6-Vkp8je5SentGRX0JhI5NY10DCvC1mmDGVTuvY` |
| 2 | `32171079` | `32171079_Deriv_Demo_DEMO` | `UcfiToVoEm1BTPtvbwTc4xEecHDxhU27ebvSkV1RoLw` |
| 3 | `201305300` | `201305300_Deriv_Demo_DEMO` | `cIeHlh0trnAFkI0RhXnynCyQT3qu5TaLcMhxsufhWIY` |
| 4 | `29672579` | `29672579_Deriv_Demo_DEMO` | `3MVTKNBsF9jJCEzo5Pjb2eRUHeOsKeMIm0-Jk4f8iX4` |
| 5 | `40894054` | `40894054_Deriv_Demo_DEMO` | `4JjZmkHSdhgXLmSH67v7Z33wA9vM7J61x8gegkXcIa0` |
| 6 | `31730081` | `31730081_Deriv_Demo_DEMO` | `PY7kjAfDqjOmz5-tHrRkouAVZ_ZQqMlM2Hyn10exiYI` |
| 7 | `29498909` | `29498909_Deriv_Demo_DEMO` | `4JUmEvYLc-aR4INyBJvMHfGEBdgwo2e-ML_SBMIbhlY` |
| 8 | `29316654` | `29316654_Deriv_Demo_DEMO` | `zVvIlxSzh0gp6lTYerfblqxPjM6tTvce3E7fHta0VX8` |
| 9 | `32033400` | `32033400_Deriv_Demo_DEMO` | `4QzALB2twWvce-acJYtcqu0lKNJK8yczciiV46HUEwo` |
| 10 | `201265520` | `201265520_Deriv_Demo_DEMO` | `5FBJgblu2xKnnxcCyv9LLkV38R5fT_86mJhGmnJYJ1o` |

## Ce que chaque utilisateur doit voir

- Le EA démarre sans erreur.
- Le backend répond `200` au polling.
- Un trade envoyé par le master apparaît dans la file.
- Le trade passe de `PENDING` à `DISPATCHED`.
- Après exécution MT5, le backend reçoit l'ACK `EXECUTED`.

## Contrôles pendant le test

- Pas d'erreur d'auth `401`.
- Pas de désynchronisation entre master et client.
- Pas d'échec de sélection de symbole.
- Pas de double exécution du même trade.

## Références utiles

- Rapport de provisioning: [preprod-report-10.json](preprod-report-10.json)
- Script de préprod: [scripts/preprod_10_clients.py](scripts/preprod_10_clients.py)
- Notes de test: [PREPROD_TESTING.md](PREPROD_TESTING.md)
