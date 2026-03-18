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
input string   InpMasterLogin  = "12345678";

//--- Globals
// On utilise un tableau pour suivre les tickets ouverts
ulong    G_ActiveTickets[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("FrappedDollars Master EA v1.11 démarré");

   // Vérification WebRequest activé (74 = TERMI­NAL_WEBREQUEST)
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
         SendToAPI(ticket, "OPEN");
         AddTicketToList(ticket);
      }
   }

   // 2. Détecter les trades FERMÉS
   for(int i=ArraySize(G_ActiveTickets)-1; i>=0; i--)
   {
      ulong ticket = G_ActiveTickets[i];
      if(!PositionSelectByTicket(ticket))
      {
         SendToAPI(ticket, "CLOSE");
         RemoveTicketFromList(i);
      }
   }
}

void SendToAPI(ulong ticket, string action)
{

   string symbol = "";
   string trade_type = "";
   double volume = 0;
   double open_price = 0;
   double tp = 0;
   double sl = 0;

   if(PositionSelectByTicket(ticket)) {
      symbol = PositionGetString(POSITION_SYMBOL);
      trade_type = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?"BUY":"SELL";
      volume = PositionGetDouble(POSITION_VOLUME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      tp = PositionGetDouble(POSITION_TP);
      sl = PositionGetDouble(POSITION_SL);
   }

   string json = "{";
   json += "\"master_login\":\"" + InpMasterLogin + "\",";
   json += "\"ticket_id\":\"" + IntegerToString(ticket) + "\",";
   json += "\"action\":\"" + action + "\",";
   json += "\"symbol\":\"" + symbol + "\",";
   json += "\"trade_type\":\"" + trade_type + "\",";
   json += "\"volume\":" + DoubleToString(volume, 2) + ",";
   json += "\"open_price\":" + DoubleToString(open_price, 5) + ",";
   json += "\"tp\":" + DoubleToString(tp, 5) + ",";
   json += "\"sl\":" + DoubleToString(sl, 5);
   json += "}";

   char data[], result[];
   string headers;
   StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);
   int res = WebRequest("POST", InpBackendUrl + "/master/trade", "Content-Type: application/json\r\n", 1000, data, result, headers);

   if(res != 200)
      Print("Erreur API Master: code=", res, " / ", GetLastError());
   else
      Print("Signal ", action, " envoyé pour le ticket: ", ticket);
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
