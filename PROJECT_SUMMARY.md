# 🚀 FrappedDollars - Résumé du Projet

Ce document sert de sauvegarde technique pour la V1.1 de l'application de Copy Trading.

## 🏗 Architecture
- **Front web / mobile :** Flutter
- **Hosting front :** Firebase Hosting uniquement
- **Authentification :** Supabase Auth comme source de vérité
- **Base de données :** Supabase PostgreSQL + Realtime comme source de vérité
- **Backend :** FastAPI (Python)
- **Source de vérité business :** backend FastAPI via `/business/rules` et inclusion dans `/dashboard/state`.
- **Trading :** Expert Advisors MQL5 (Master & Client)
- **Paiements :** Flutterwave (Intégré)
- **Non utilisé :** Firestore pour les données métier

## 💰 Logique Business (Verrouillée)
- **Abonnement Trading :** 50$ / semaine.
- **Hébergement VPS :** 30$ / mois (pour les utilisateurs sur téléphone).
- **Limite de Profit :** limite technique de protection: la copie s'arrête automatiquement lorsque le profit hebdomadaire atteint 120 USD.
- **Capital Minimum :** 30$ requis sur le compte MT5 client pour copier un trade.
- **Calcul du Lot :** `Lot_client = Lot_master * (Capital_client / Capital_master)`.
- **Fidélité :** Synchronisation temps réel de l'ouverture ET de la fermeture des positions.

## 💎 Liste VIP (Accès Gratuit Illimité)
Les emails suivants sont exemptés de paiement via un trigger SQL :
- mupoyidavid24@gmail.com
- emmanuelwondo07@gmail.com
- chanelmimpiya1@gmail.com
- claudemenji3@gmail.com
- junioryamba86@gmail.com
- kwetemuanaezechiasmuzechsong93@gmail.com

## 📱 Fonctionnalités de l'App
- **Dashboard :** Solde, Équité, Graphique de performance (LineChart).
- **Leaderboard :** Top 10 des meilleurs traders (Anonymisé).
- **Support :** Système de tickets en temps réel.
- **Apprentissage :** Centre de tutoriels vidéo/articles.
- **Parrainage :** Système de partage de code (Gain 5%).
- **Sécurité :** Déverrouillage par Biométrie (Empreinte/FaceID).

## 🧪 Protocole de Test Final
1. Lancer le backend : `uvicorn main:app --reload`.
2. Lancer l'app : `flutter run`.
3. Attacher `FrappedDollarsMaster.mq5` sur le compte Maître MT5.
4. Attacher `FrappedDollarsClient.mq5` sur le compte Client MT5.
5. Ouvrir un trade sur le Maître et observer la copie instantanée.

---
*Dernière mise à jour : Discussion sauvegardée le 2024-05-25*
