//+------------------------------------------------------------------+
//|                                         FrappedDollarsMaster.mq5 |
//|                                  Copyright 2024, FrappedDollars  |
//|                                       https://frappeddollars.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, FrappedDollars"
#property link      "https://frappeddollars.com"
#property version   "1.12"
#property strict

//--- Input parameters
input string   InpBackendUrl   = "https://frappedollars-backend-1.onrender.com";
input string   InpLogin        = ""; // Laisser vide pour auto, ou mettre le login voulu
input string   InpAccountType  = "MASTER"; // MASTER ou CLIENT
input string   InpApiKey       = ""; // Clé API master fournie par le backend

//--- Globals
struct TrackedTrade
{
   ulong ticket;
   string symbol;
   string trade_type;
   double volume;
   double open_price;
   double sl;
   double tp;
};

TrackedTrade G_ActiveTrades[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   string login = InpLogin;
   if(login=="") login = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   Print("FrappedDollars EA v1.12 démarré pour le compte: ", login, " (type: ", InpAccountType, ")");

   if(StringLen(InpApiKey) == 0) {
      Alert("ERREUR: InpApiKey est vide. Renseigne la clé API master fournie par le backend.");
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
            TrackedTrade trade;
            trade.ticket = ticket;
            trade.symbol = PositionGetString(POSITION_SYMBOL);
            trade.trade_type = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?"BUY":"SELL";
            trade.volume = PositionGetDouble(POSITION_VOLUME);
            trade.open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            trade.tp = PositionGetDouble(POSITION_TP);
            trade.sl = PositionGetDouble(POSITION_SL);
            AddTradeToList(trade);
            SendToAPI(trade.ticket, "OPEN", trade.symbol, trade.trade_type, trade.volume, trade.open_price, trade.sl, trade.tp);
         }
      }
   }

   // 2. Détecter les trades FERMÉS
   for(int i=ArraySize(G_ActiveTrades)-1; i>=0; i--)
   {
      ulong ticket = G_ActiveTrades[i].ticket;
      if(!PositionSelectByTicket(ticket))
      {
         // On envoie le CLOSE avec les dernières infos connues
         SendToAPI(
ticket,
            "CLOSE"            ,
            G_ActiveTrades[i].symbol,
            G_ActiveTrades[i].trade_type,
            G_ActiveTrades[i].volume,
            G_ActiveTrades[i].open_price,
            G_ActiveTrades[i].sl,
            G_ActiveTrades[i].tp
         );
         RemoveTradeFromList(i);
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
   if(StringLen(InpApiKey) > 0)
      headers += "x-api-key: " + InpApiKey + "\r\n";
   int jsonLen = StringLen(json);
   ArrayResize(data, jsonLen);
   StringToCharArray(json, data, 0, jsonLen, CP_UTF8);
   string response_headers = "";
   int res = WebRequest("POST", InpBackendUrl + "/master/trade", headers, 5000, data, result, response_headers);
   string response_body = CharArrayToString(result, 0, -1, CP_UTF8);
   if(res==200)
      Print("Trade envoyé: ", json, " body=", response_body);
   else
      Print("Erreur envoi trade: ", GetLastError(), " http=", res, " body=", response_body);
}


//--- Helpers pour la gestion de la liste locale
bool IsTicketInList(ulong ticket) {
   for(int i=0; i<ArraySize(G_ActiveTrades); i++) if(G_ActiveTrades[i].ticket == ticket) return true;
   return false;
}
void AddTradeToList(const TrackedTrade &trade) {
   int size = ArraySize(G_ActiveTrades);
   ArrayResize(G_ActiveTrades, size+1);
   G_ActiveTrades[size] = trade;
}
void RemoveTradeFromList(int index) {
   int size = ArraySize(G_ActiveTrades);
   for(int i=index; i<size-1; i++) G_ActiveTrades[i] = G_ActiveTrades[i+1];
   ArrayResize(G_ActiveTrades, size-1);
}
