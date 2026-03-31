// Fonction à appeler après exécution d’un trade pour confirmer au backend
void ConfirmerExecutionTrade(string backendUrl, string client_login, string trade_id)
{
   string json = "{";
   json += "\"client_login\":\"" + client_login + "\",";
   json += "\"trade_id\":\"" + trade_id + "\"";
   json += "}";
   char data[], result[];
   string headers = "Content-Type: application/json\r\n";
   if(StringLen(InpApiKey) > 0)
      headers += "x-api-key: " + InpApiKey + "\r\n";
   int jsonLen = StringLen(json);
   ArrayResize(data, jsonLen);
   StringToCharArray(json, data, 0, jsonLen, CP_UTF8);
   int res = WebRequest("POST", backendUrl + "/client/trade_executed", headers, 1000, data, result, headers);
   if(res==200) Print("Confirmation d’exécution envoyée pour le trade ", trade_id);
   else Print("Erreur lors de la confirmation d’exécution : ", GetLastError());
}
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
input string   InpBroker       = "ICMarketsSC";               // Nom du broker (à renseigner)
input string   InpServer       = "Demo";                      // Nom du serveur (à renseigner)
input string   InpAccountType  = "LIVE";                      // Type de compte (LIVE/DEMO)
input int      InpTimerSeconds = 2;                            // Vérification toutes les 2 sec
input string   InpApiKey       = "";                           // Clé API à renseigner (copier/coller depuis le backend)

//--- Globals
//--- Globals
CTrade         G_Trade;
string         G_ClientId;

#define TAG_LENGTH 13
#define SYSTEM_PREFIX 410000000
#define MAGIC_RANGE 10000000
#define MAX_SIGNED_INT 2147483647

//--- Journalisation locale (simple, à améliorer pour la prod)
struct TradeJournalEntry {
   string trade_id;
   int sequence_id;
   string action; // OPEN/CLOSE
   string status; // PENDING/EXECUTED/FAILED
   datetime timestamp;
};
TradeJournalEntry G_TradeJournal[1000]; // Simple buffer, à remplacer par fichier ou DB locale en prod
int G_TradeJournalSize = 0;

string CollapseSpaces(string value)
{
   while(StringFind(value, "  ") >= 0)
      StringReplace(value, "  ", " ");
   return value;
}

string NormalizeTradeId(string rawTradeId)
{
   string normalized = rawTradeId;
   normalized = StringTrimLeft(normalized);
   normalized = StringTrimRight(normalized);
   normalized = StringToLower(normalized);
   normalized = CollapseSpaces(normalized);
   return normalized;
}

ulong Fnv1a64Utf8(string normalizedTradeId)
{
   uchar bytes[];
   int count = StringToCharArray(normalizedTradeId, bytes, 0, WHOLE_ARRAY, CP_UTF8);
   ulong hash = 0xCBF29CE484222325;

   for(int i = 0; i < count; i++)
   {
      if(bytes[i] == 0)
         break;
      hash ^= (ulong)bytes[i];
      hash *= 0x100000001B3;
   }
   return hash;
}

uint Fnv1a32Utf8(string normalizedTradeId)
{
   uchar bytes[];
   int count = StringToCharArray(normalizedTradeId, bytes, 0, WHOLE_ARRAY, CP_UTF8);
   uint hash = 0x811C9DC5;

   for(int i = 0; i < count; i++)
   {
      if(bytes[i] == 0)
         break;
      hash ^= (uint)bytes[i];
      hash *= 0x01000193;
   }
   return hash;
}

string Base36LowerUnsigned(ulong value)
{
   string alphabet = "0123456789abcdefghijklmnopqrstuvwxyz";
   if(value == 0)
      return "0";

   string output = "";
   while(value > 0)
   {
      int digit = (int)(value % 36);
      output = StringSubstr(alphabet, digit, 1) + output;
      value = value / 36;
   }
   return output;
}

string MakeTradeTag(string rawTradeId)
{
   string normalized = NormalizeTradeId(rawTradeId);
   ulong hash64 = Fnv1a64Utf8(normalized);
   string fullBase36 = Base36LowerUnsigned(hash64);

   while(StringLen(fullBase36) < TAG_LENGTH)
      fullBase36 = "0" + fullBase36;

   return StringSubstr(fullBase36, StringLen(fullBase36) - TAG_LENGTH, TAG_LENGTH);
}

int MakeMagicNumber(string rawTradeId)
{
   string normalized = NormalizeTradeId(rawTradeId);
   uint hash32 = Fnv1a32Utf8(normalized);
   uint suffix = hash32 % MAGIC_RANGE;
   long magic = (long)SYSTEM_PREFIX + (long)suffix;

   if(magic < 0 || magic > MAX_SIGNED_INT)
      return -1;

   return (int)magic;
}

string MakeBrokerComment(string rawTradeId)
{
   return "FRP|v1|t=" + MakeTradeTag(rawTradeId);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{

   // Génération dynamique du client_id
   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   string login_str = IntegerToString(login);
   G_ClientId = login_str + "_" + InpBroker + "_" + InpServer + "_" + InpAccountType;
   Print("FrappedDollars Client EA v1.22 démarré pour le client_id: ", G_ClientId);

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
   string url = InpBackendUrl + "/client/pending_trades/" + G_ClientId;

   string headers = "";
   if(StringLen(InpApiKey) > 0)
      headers = "x-api-key: " + InpApiKey + "\r\n";

   int res = WebRequest("GET", url, headers, 1000, data, result, result_headers);

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
      int sequence_id      = StringToInteger(ExtractValue(item, "\"sequence_id\":"));
      string action        = ExtractValue(item, "\"action\":\""); // "OPEN" ou "CLOSE"

      // Vérification de l'ordre d'exécution (state machine simplifiée)
      if(action == "OPEN")
      {
         // Vérifier si ce trade_id a déjà été exécuté (idempotence locale)
         bool alreadyExecuted = false;
         for(int j=0; j<G_TradeJournalSize; j++)
            if(G_TradeJournal[j].trade_id == copiedTradeId && G_TradeJournal[j].action == "OPEN" && G_TradeJournal[j].status == "EXECUTED")
               alreadyExecuted = true;
         if(alreadyExecuted) continue;

         // Exécution de l'OPEN
         Print("[STATE] Tentative d'OPEN : ", symbol, " ", type, " Vol:", volume, " seq:", sequence_id);
         bool success = false;
         int magicNumber = MakeMagicNumber(copiedTradeId);
         string brokerComment = MakeBrokerComment(copiedTradeId);
         if(magicNumber < 0)
         {
            Print("Magic number invalide pour trade_id=", copiedTradeId);
            continue;
         }
         G_Trade.SetExpertMagicNumber((ulong)magicNumber);
         if(type == "BUY")
            success = G_Trade.Buy(volume, symbol, 0, sl, tp, brokerComment);
         else if(type == "SELL")
            success = G_Trade.Sell(volume, symbol, 0, sl, tp, brokerComment);

         // Journalisation locale
         G_TradeJournal[G_TradeJournalSize].trade_id = copiedTradeId;
         G_TradeJournal[G_TradeJournalSize].sequence_id = sequence_id;
         G_TradeJournal[G_TradeJournalSize].action = "OPEN";
         G_TradeJournal[G_TradeJournalSize].timestamp = TimeCurrent();
         if(success)
         {
            G_TradeJournal[G_TradeJournalSize].status = "EXECUTED";
            ulong ticket = G_Trade.ResultDeal();
            UpdateBackend(copiedTradeId, ticket, "SUCCESS", 0);
         }
         else
         {
            G_TradeJournal[G_TradeJournalSize].status = "FAILED";
            Print("Échec de l'ouverture : ", G_Trade.ResultRetcodeDescription());
            UpdateBackend(copiedTradeId, 0, "FAILED", 0);
         }
         G_TradeJournalSize++;
      }
      else if(action == "CLOSE")
      {
         // Vérifier que l'OPEN correspondant a été exécuté
         bool openExecuted = false;
         for(int j=0; j<G_TradeJournalSize; j++)
            if(G_TradeJournal[j].trade_id == copiedTradeId && G_TradeJournal[j].action == "OPEN" && G_TradeJournal[j].status == "EXECUTED")
               openExecuted = true;
         if(!openExecuted)
         {
            Print("[STATE] CLOSE ignoré car OPEN non exécuté pour trade_id=", copiedTradeId);
            continue;
         }

         // Vérifier si ce CLOSE a déjà été exécuté
         bool closeAlreadyExecuted = false;
         for(int j=0; j<G_TradeJournalSize; j++)
            if(G_TradeJournal[j].trade_id == copiedTradeId && G_TradeJournal[j].action == "CLOSE" && G_TradeJournal[j].status == "EXECUTED")
               closeAlreadyExecuted = true;
         if(closeAlreadyExecuted) continue;

         Print("[STATE] Tentative de CLOSE pour trade_id=", copiedTradeId, " ticket=", clientTicket);
         long tmpTicket = (long)StringToInteger(clientTicket);
         ulong ticketToClose = (ulong)tmpTicket;
         if(PositionSelectByTicket(ticketToClose))
         {
            string sym = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(G_Trade.PositionClose(sym))
            {
               Print("Position fermée avec succès : ", sym, " ticket=", ticketToClose);
               // Journalisation
               G_TradeJournal[G_TradeJournalSize].trade_id = copiedTradeId;
               G_TradeJournal[G_TradeJournalSize].sequence_id = sequence_id;
               G_TradeJournal[G_TradeJournalSize].action = "CLOSE";
               G_TradeJournal[G_TradeJournalSize].timestamp = TimeCurrent();
               G_TradeJournal[G_TradeJournalSize].status = "EXECUTED";
               G_TradeJournalSize++;
               UpdateBackend(copiedTradeId, ticketToClose, "CLOSED", profit);
            }
            else
            {
               Print("Échec de la fermeture : ", G_Trade.ResultRetcodeDescription());
               G_TradeJournal[G_TradeJournalSize].trade_id = copiedTradeId;
               G_TradeJournal[G_TradeJournalSize].sequence_id = sequence_id;
               G_TradeJournal[G_TradeJournalSize].action = "CLOSE";
               G_TradeJournal[G_TradeJournalSize].timestamp = TimeCurrent();
               G_TradeJournal[G_TradeJournalSize].status = "FAILED";
               G_TradeJournalSize++;
               UpdateBackend(copiedTradeId, ticketToClose, "FAILED_CLOSE", 0);
            }
         }
         else
         {
            Print("Impossible de sélectionner la position avec ticket : ", ticketToClose);
            G_TradeJournal[G_TradeJournalSize].trade_id = copiedTradeId;
            G_TradeJournal[G_TradeJournalSize].sequence_id = sequence_id;
            G_TradeJournal[G_TradeJournalSize].action = "CLOSE";
            G_TradeJournal[G_TradeJournalSize].timestamp = TimeCurrent();
            G_TradeJournal[G_TradeJournalSize].status = "FAILED_SELECT";
            G_TradeJournalSize++;
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
   if(StringLen(InpApiKey) > 0)
      headers += "x-api-key: " + InpApiKey + "\r\n";
   StringToCharArray(json, data);
   string result_headers = "";
   WebRequest("POST", url, headers, 1000, data, result, result_headers);
}
