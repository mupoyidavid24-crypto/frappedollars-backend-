//+------------------------------------------------------------------+
//|                                         FrappedDollarsClient.mq5 |
//|                                  Copyright 2024, FrappedDollars  |
//|                                       https://frappeddollars.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, FrappedDollars"
#property link      "https://frappeddollars.com"
#property version   "1.22"
#property strict

#include <Trade\Trade.mqh>

//--- Input parameters
input string   InpBackendUrl   = "https://frappedollars-backend-1.onrender.com"; // URL du Backend (prod Render)
input string   InpClientLogin  = "87654321";                 // Votre Login MT5
input string   InpAllowedLogin = "32048608";                 // Login MT5 autorisé
input int      InpTimerSeconds = 2;                          // Vérification toutes les 2 sec

//--- Globals
CTrade         G_Trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("FrappedDollars Client EA v1.22 démarré pour le compte: ", InpClientLogin);

   // Sécurisation : l'EA ne fonctionne que sur le compte autorisé
   long allowedLogin = (long)StringToInteger(InpAllowedLogin); // conversion explicite
   if (AccountInfoInteger(ACCOUNT_LOGIN) != allowedLogin) {
      Alert("EA non autorisé pour ce compte.");
      ExpertRemove();
      return(INIT_FAILED);
   }

   if(!TerminalInfoInteger(74))
   {
      Print("ERREUR: WebRequest n'est pas activé. Ajoutez l'URL du backend dans les Options.");
      return(INIT_FAILED);
   }

   EventSetTimer(InpTimerSeconds);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { EventKillTimer(); }

void OnTimer() { FetchAndExecute(); }

//+------------------------------------------------------------------+
//| Fetch trades from Backend and Execute them                       |
//+------------------------------------------------------------------+
void FetchAndExecute()
{
   uchar data[];
   uchar result[];
   string result_headers = "";
   string url = InpBackendUrl + "/client/pending_trades/" + InpClientLogin;

   int res = WebRequest("GET", url, "", 1000, data, result, result_headers);

   if(res == 200)
   {
      string jsonResponse;
      CharArrayToString(result, jsonResponse);
      if(jsonResponse != "[]")
      {
         Print("Trades en attente détectés...");
         ParseAndProcess(jsonResponse);
      }
   }
   else
   {
      Print("Erreur WebRequest code: ", res, " / ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Simple JSON Parsing & Execution Logic                            |
//+------------------------------------------------------------------+
void ParseAndProcess(string json)
{
   string trades[];
   ushort sep = StringGetCharacter("}", 0);
   StringSplit(json, sep, trades);

   for(int i=0; i<ArraySize(trades); i++)
   {
      string item = trades[i];
      if(StringLen(item) < 10) continue;

      // 1. Extraire les données clés
      string copiedTradeId = ExtractValue(item, "\"id\":\"");
      string status        = ExtractValue(item, "\"execution_status\":\"");
      string symbol        = ExtractValue(item, "\"symbol\":\"");
      string type          = ExtractValue(item, "\"trade_type\":\"");
      double volume        = StringToDouble(ExtractValue(item, "\"volume_executed\":"));
      double sl            = StringToDouble(ExtractValue(item, "\"sl\":"));
      double tp            = StringToDouble(ExtractValue(item, "\"tp\":"));
      string clientTicket  = ExtractValue(item, "\"client_ticket_id\":\"");

      // --- ACTION : OUVERTURE ---
      if(status == "PENDING")
      {
         Print("Exécution d'une OUVERTURE : ", symbol, " ", type, " Vol:", volume);

         bool success = false;
         if(type == "BUY")
            success = G_Trade.Buy(volume, symbol, 0, sl, tp, "FrappedDollars Copy");
         else if(type == "SELL")
            success = G_Trade.Sell(volume, symbol, 0, sl, tp, "FrappedDollars Copy");

         if(success)
         {
            ulong ticket = G_Trade.ResultDeal();
            UpdateBackend(copiedTradeId, ticket, "SUCCESS", 0);
         }
         else
         {
            Print("Échec de l'ouverture : ", G_Trade.ResultRetcodeDescription());
            UpdateBackend(copiedTradeId, 0, "FAILED", 0);
         }
      }

      // --- ACTION : FERMETURE ---
      else if(status == "PENDING_CLOSE")
      {
         Print("Exécution d'une FERMETURE pour le ticket client : ", clientTicket);

         long tmpTicket = (long)StringToInteger(clientTicket); // conversion explicite string → long
         ulong ticketToClose = (ulong)tmpTicket;               // conversion explicite long → ulong

         if(PositionSelectByTicket(ticketToClose))
         {
            string sym = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);

            if(G_Trade.PositionClose(sym))
            {
               Print("Position fermée avec succès : ", sym, " ticket=", ticketToClose);
               UpdateBackend(copiedTradeId, ticketToClose, "CLOSED", profit);
            }
            else
            {
               Print("Échec de la fermeture : ", G_Trade.ResultRetcodeDescription());
               UpdateBackend(copiedTradeId, ticketToClose, "FAILED_CLOSE", 0);
            }
         }
         else
         {
            Print("Impossible de sélectionner la position avec ticket : ", ticketToClose);
            UpdateBackend(copiedTradeId, ticketToClose, "FAILED_SELECT", 0);
         }
      }
   }
}

//--- Helper pour extraire une valeur simple du JSON
string ExtractValue(string json, string key)
{
   int start = StringFind(json, key);
   if(start < 0) return "";
   start += StringLen(key);
   int end = StringFind(json, "\"", start);
   if(end < 0) end = StringFind(json, ",", start);
   if(end < 0) end = StringFind(json, "}", start);
   return StringSubstr(json, start, end - start);
}

void UpdateBackend(string copiedTradeId, ulong ticket, string status, double profit)
{
   string url = InpBackendUrl + "/client/update_trade";
   string json = "{\"copied_trade_id\":\"" + copiedTradeId + "\", \"ticket\":\"" + IntegerToString(ticket) + "\", \"status\":\"" + status + "\", \"profit\":" + DoubleToString(profit, 2) + "}";

   uchar data[];
   uchar result[];
   string headers = "Content-Type: application/json\r\n";
   StringToCharArray(json, data);
   string result_headers = "";
   WebRequest("POST", url, headers, 1000, data, result, result_headers);
}
