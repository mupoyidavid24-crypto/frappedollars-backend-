//+------------------------------------------------------------------+
//|                                         FrappedDollarsMaster.mq5 |
//|                                  Copyright 2024, FrappedDollars  |
//|                                       https://frappeddollars.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, FrappedDollars"
#property link      "https://frappeddollars.com"
#property version   "1.11"
#property strict

//--- Input parameters
input string   InpBackendUrl   = "https://frappedollars-backend-1.onrender.com";
input string   InpLogin        = ""; // Laisser vide pour auto, ou mettre le login voulu
input string   InpAccountType  = "MASTER"; // MASTER ou CLIENT

//--- Globals
// On utilise un tableau pour suivre les tickets ouverts
ulong    G_ActiveTickets[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   string login = InpLogin;
   if(login=="") login = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   Print("FrappedDollars EA v1.11 démarré pour le compte: ", login, " (type: ", InpAccountType, ")");

   // Sécurité stricte : doit être lancé sur le compte maître 6048965
   if(login != "6048965") {
      Alert("ERREUR: Ce compte n'est pas autorisé à exécuter l'EA maître. Login attendu: 6048965, login courant: " + login);
      ExpertRemove();
      return(INIT_FAILED);
   }

   // Vérification WebRequest activé (74 = TERMINAL_WEBREQUEST)
   if(!TerminalInfoInteger(74))
   {
      Print("ERREUR: WebRequest non activé. Ajoutez l’URL du backend dans les Options.");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnTradeTransaction function (Plus précis que OnTick)             |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // Détecter les nouvelles positions ou les fermetures
   if(trans.type == TRADE_TRANSACTION_ORDER_DELETE || trans.type == TRADE_TRANSACTION_HISTORY_ADD)
   {
      // Un changement a eu lieu, on synchronise
      SyncTrades();
   }
}

void OnTick() { SyncTrades(); } // Sécurité supplémentaire

//+------------------------------------------------------------------+
//| Synchronize trades with Backend                                  |
//+------------------------------------------------------------------+
void SyncTrades()
{
   int currentTotal = PositionsTotal();

   // 1. Détecter les NOUVEAUX trades
   for(int i=0; i<currentTotal; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!IsTicketInList(ticket))
      {
         if(PositionSelectByTicket(ticket)) {
            string symbol = PositionGetString(POSITION_SYMBOL);
            string trade_type = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?"BUY":"SELL";
            double volume = PositionGetDouble(POSITION_VOLUME);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double tp = PositionGetDouble(POSITION_TP);
            double sl = PositionGetDouble(POSITION_SL);
            SendToAPI(ticket, "OPEN", symbol, trade_type, volume, open_price, sl, tp);
         }
         AddTicketToList(ticket);
      }
   }

   // 2. Détecter les trades FERMÉS
   for(int i=ArraySize(G_ActiveTickets)-1; i>=0; i--)
   {
      ulong ticket = G_ActiveTickets[i];
      // On capture les infos AVANT suppression (si possible)
      string symbol = "";
      string trade_type = "";
      double volume = 0;
      double open_price = 0;
      double tp = 0;
      double sl = 0;
      bool found = PositionSelectByTicket(ticket);
      if(found) {
         symbol = PositionGetString(POSITION_SYMBOL);
         trade_type = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?"BUY":"SELL";
         volume = PositionGetDouble(POSITION_VOLUME);
         open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         tp = PositionGetDouble(POSITION_TP);
         sl = PositionGetDouble(POSITION_SL);
      }
      if(!PositionSelectByTicket(ticket))
      {
         // On envoie le CLOSE avec les dernières infos connues
         SendToAPI(ticket, "CLOSE", symbol, trade_type, volume, open_price, sl, tp);
         RemoveTicketFromList(i);
      }
   }

}


// Fonction unique pour envoyer un trade (OPEN ou CLOSE) au backend
void SendToAPI(ulong ticket, string action, string symbol, string trade_type, double volume, double open_price, double sl, double tp)
{
   string login = InpLogin;
   if(login=="") login = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string json = "{";
   json += "\"master_login\":\"" + login + "\",";
   json += "\"ticket_id\":\"" + IntegerToString(ticket) + "\",";
   json += "\"action\":\"" + action + "\",";
   json += "\"symbol\":\"" + symbol + "\",";
   json += "\"trade_type\":\"" + trade_type + "\",";
   json += "\"volume\":" + DoubleToString(volume, 2) + ",";
   json += "\"open_price\":" + DoubleToString(open_price, 5) + ",";
   json += "\"sl\":" + ((sl==0)?"null":DoubleToString(sl,5)) + ",";
   json += "\"tp\":" + ((tp==0)?"null":DoubleToString(tp,5));
   json += "}";
   Print("JSON envoyé à l’API:", json);
   char data[], result[];
   string headers = "Content-Type: application/json\r\n";
   int jsonLen = StringLen(json);
   ArrayResize(data, jsonLen);
   StringToCharArray(json, data, 0, jsonLen, CP_UTF8);
   int res = WebRequest("POST", InpBackendUrl + "/master/trade", headers, 1000, data, result, headers);
   if(res==200) Print("Trade envoyé: ", json);
   else Print("Erreur envoi trade: ", GetLastError());
}


//--- Helpers pour la gestion de la liste locale
bool IsTicketInList(ulong ticket) {
   for(int i=0; i<ArraySize(G_ActiveTickets); i++) if(G_ActiveTickets[i] == ticket) return true;
   return false;
}
void AddTicketToList(ulong ticket) {
   int size = ArraySize(G_ActiveTickets);
   ArrayResize(G_ActiveTickets, size+1);
   G_ActiveTickets[size] = ticket;
}
void RemoveTicketFromList(int index) {
   int size = ArraySize(G_ActiveTickets);
   for(int i=index; i<size-1; i++) G_ActiveTickets[i] = G_ActiveTickets[i+1];
   ArrayResize(G_ActiveTickets, size-1);
}
