// Fonction à appeler après exécution d’un trade pour confirmer au backend
void ConfirmerExecutionTrade(string backendUrl, string client_login, string trade_id, string client_ticket_id)
{
   string json = "{";
   json += "\"client_login\":\"" + client_login + "\",";
   json += "\"trade_id\":\"" + trade_id + "\",";
   json += "\"client_ticket_id\":\"" + client_ticket_id + "\"";
   json += "}";
   char data[], result[];
   string headers = "Content-Type: application/json\r\n";
   if(StringLen(InpApiKey) > 0)
      headers += "x-api-key: " + InpApiKey + "\r\n";
   int jsonLen = StringLen(json);
   ArrayResize(data, jsonLen);
   StringToCharArray(json, data, 0, jsonLen, CP_UTF8);
   string response_headers = "";
   int res = WebRequest("POST", backendUrl + "/client/trade_executed", headers, 1000, data, result, response_headers);
   string response_body = CharArrayToString(result, 0, -1, CP_UTF8);
   if(res == 200 && StringFind(response_body, "error") < 0)
      Print("[FLOW] POST /client/trade_executed status=200 trade_id=", trade_id, " ticket=", client_ticket_id, " body=", response_body);
   else
      Print("[FLOW] POST /client/trade_executed échec status=", res, " trade_id=", trade_id, " ticket=", client_ticket_id, " last_error=", GetLastError(), " body=", response_body);
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
input bool     InpRunIdentitySelfTest = true;                  // Active le self-test tag/magic/comment au démarrage

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
   long sequence_id;
   string action; // OPEN/CLOSE
   string status; // PENDING/EXECUTED/FAILED
   datetime timestamp;
};

struct IdentityTestVector {
   string input_trade_id;
   string expected_normalized_trade_id;
   string expected_trade_tag;
   int expected_magic_number;
   string expected_broker_comment;
};

TradeJournalEntry G_TradeJournal[1000]; // Simple buffer, à remplacer par fichier ou DB locale en prod
int G_TradeJournalSize = 0;

string CollapseSpaces(string value)
{
   while(StringFind(value, "  ") >= 0)
      StringReplace(value, "  ", " ");
   return value;
}

int CountOccurrences(string haystack, string needle)
{
   int count = 0;
   int start = 0;

   while(true)
   {
      int found = StringFind(haystack, needle, start);
      if(found < 0)
         break;
      count++;
      start = found + StringLen(needle);
   }

   return count;
}

string NormalizeTradeId(string rawTradeId)
{
   string normalized = rawTradeId;
   StringTrimLeft(normalized);
   StringTrimRight(normalized);
   StringToLower(normalized);
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

bool RunIdentitySelfTest()
{
   IdentityTestVector cases[4];

   cases[0].input_trade_id = "abc-123";
   cases[0].expected_normalized_trade_id = "abc-123";
   cases[0].expected_trade_tag = "1qd63puhj4j52";
   cases[0].expected_magic_number = 417833958;
   cases[0].expected_broker_comment = "FRP|v1|t=1qd63puhj4j52";

   cases[1].input_trade_id = "  ABC-123  ";
   cases[1].expected_normalized_trade_id = "abc-123";
   cases[1].expected_trade_tag = "1qd63puhj4j52";
   cases[1].expected_magic_number = 417833958;
   cases[1].expected_broker_comment = "FRP|v1|t=1qd63puhj4j52";

   cases[2].input_trade_id = "trade-001";
   cases[2].expected_normalized_trade_id = "trade-001";
   cases[2].expected_trade_tag = "2muxtqum3mr1z";
   cases[2].expected_magic_number = 411121111;
   cases[2].expected_broker_comment = "FRP|v1|t=2muxtqum3mr1z";

   cases[3].input_trade_id = "trade  with   spaces";
   cases[3].expected_normalized_trade_id = "trade with spaces";
   cases[3].expected_trade_tag = "23mkknalyzn9q";
   cases[3].expected_magic_number = 413631278;
   cases[3].expected_broker_comment = "FRP|v1|t=23mkknalyzn9q";

   bool allMatch = true;
   Print("[IDENTITY_SELF_TEST] START");

   for(int i = 0; i < ArraySize(cases); i++)
   {
      string actualNormalized = NormalizeTradeId(cases[i].input_trade_id);
      string actualTradeTag = MakeTradeTag(cases[i].input_trade_id);
      int actualMagicNumber = MakeMagicNumber(cases[i].input_trade_id);
      string actualBrokerComment = MakeBrokerComment(cases[i].input_trade_id);

      bool normalizedMatch = (actualNormalized == cases[i].expected_normalized_trade_id);
      bool tradeTagMatch = (actualTradeTag == cases[i].expected_trade_tag);
      bool magicMatch = (actualMagicNumber == cases[i].expected_magic_number);
      bool commentMatch = (actualBrokerComment == cases[i].expected_broker_comment);
      bool caseMatch = normalizedMatch && tradeTagMatch && magicMatch && commentMatch;

      Print("[IDENTITY_SELF_TEST] INPUT=", cases[i].input_trade_id);
      Print(
         "[IDENTITY_SELF_TEST] OUTPUT EA normalized=", actualNormalized,
         " tag=", actualTradeTag,
         " magic=", IntegerToString(actualMagicNumber),
         " comment=", actualBrokerComment
      );
      Print(
         "[IDENTITY_SELF_TEST] OUTPUT BACKEND normalized=", cases[i].expected_normalized_trade_id,
         " tag=", cases[i].expected_trade_tag,
         " magic=", IntegerToString(cases[i].expected_magic_number),
         " comment=", cases[i].expected_broker_comment
      );
      Print("[IDENTITY_SELF_TEST] RESULT=", (caseMatch ? "MATCH" : "MISMATCH"));

      if(!caseMatch)
         allMatch = false;
   }

   Print("[IDENTITY_SELF_TEST] FINAL_RESULT=", (allMatch ? "MATCH" : "MISMATCH"));
   return allMatch;
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
   Print("[IDENTITY_SELF_TEST] ENABLED=", (InpRunIdentitySelfTest ? "true" : "false"));

   if(InpRunIdentitySelfTest && !RunIdentitySelfTest())
   {
      Print("[IDENTITY_SELF_TEST] Echec du self-test. Initialisation interrompue.");
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
   string url = InpBackendUrl + "/client/pending_trades/" + G_ClientId;

   string headers = "";
   if(StringLen(InpApiKey) > 0)
      headers = "x-api-key: " + InpApiKey + "\r\n";

   int res = WebRequest("GET", url, headers, 1000, data, result, result_headers);

   if(res == 200)
   {
      string jsonResponse;
      jsonResponse = CharArrayToString(result, 0, -1, CP_UTF8);
      Print("[FLOW] GET /client/pending_trades status=200 bytes=", ArraySize(result), " json_length=", StringLen(jsonResponse));
      Print("[FLOW] JSON START=", StringSubstr(jsonResponse, 0, MathMin(200, StringLen(jsonResponse))));

      bool hasItemsEnvelope = (StringFind(jsonResponse, "\"items\"") >= 0);
      bool hasPendingEnvelope = (StringFind(jsonResponse, "\"pending_trades\"") >= 0);
      string responseVersion = "unknown";
      int versionStart = StringFind(jsonResponse, "\"version\":\"");
      if(versionStart >= 0)
      {
         versionStart += StringLen("\"version\":\"");
         int versionEnd = StringFind(jsonResponse, "\"", versionStart);
         if(versionEnd > versionStart)
            responseVersion = StringSubstr(jsonResponse, versionStart, versionEnd - versionStart);
      }
      Print("[FLOW] ENVELOPE version=", responseVersion, " legacy_pending_trades=", (hasPendingEnvelope ? "true" : "false"));

      if(!hasItemsEnvelope && !hasPendingEnvelope)
      {
         Print("[FLOW] ERREUR: format JSON invalide (clé items/pending_trades absente).");
         return;
      }

      if(hasPendingEnvelope && !hasItemsEnvelope)
         Print("[FLOW] WARNING: legacy format pending_trades détecté.");

      int approxItemsCount = CountOccurrences(jsonResponse, "\"id\":\"");
      Print("[FLOW] version=", responseVersion, " items_count=", approxItemsCount);

      if(StringFind(jsonResponse, "\"items\":[]") >= 0 || StringFind(jsonResponse, "\"items\": []") >= 0 || StringFind(jsonResponse, "\"pending_trades\":[]") >= 0 || StringFind(jsonResponse, "\"pending_trades\": []") >= 0)
      {
         Print("[FLOW] Aucun trade réel (items vide). version=", responseVersion);
         return;
      }

      Print("[FLOW] Trades en attente détectés, passage au parsing.");
      ParseAndProcess(jsonResponse);
   }
   else
   {
      Print("[FLOW] GET /client/pending_trades échec code=", res, " last_error=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Simple JSON Parsing & Execution Logic                            |
//+------------------------------------------------------------------+
void ParseAndProcess(string json)
{
   Print("[FLOW] Parsing JSON brut.");
   bool hasItemsEnvelope = (StringFind(json, "\"items\"") >= 0);
   bool hasPendingEnvelope = (StringFind(json, "\"pending_trades\"") >= 0);
   if(!hasItemsEnvelope && !hasPendingEnvelope)
   {
      Print("[FLOW] Parse abort: clé items/pending_trades introuvable.");
      return;
   }

   int itemsStart = StringFind(json, "[");
   int itemsEnd = StringFind(json, "]", itemsStart);
   if(itemsStart < 0 || itemsEnd < 0 || itemsEnd <= itemsStart)
   {
      Print("[FLOW] Parse abort: impossible d'extraire le tableau items.");
      return;
   }

   string itemsJson = StringSubstr(json, itemsStart + 1, itemsEnd - itemsStart - 1);
   Print("[FLOW] ITEMS JSON START=", StringSubstr(itemsJson, 0, MathMin(200, StringLen(itemsJson))));
   if(StringLen(itemsJson) == 0)
   {
      Print("[FLOW] Aucun item à parser après extraction du tableau.");
      return;
   }

   string trades[];
   ushort sep = StringGetCharacter("}", 0);
   StringSplit(itemsJson, sep, trades);
   Print("[FLOW] Fragments JSON détectés=", ArraySize(trades));

   for(int i=0; i<ArraySize(trades); i++)
   {
      string item = trades[i];
      if(StringLen(item) < 10)
      {
         Print("[FLOW] Fragment ignoré index=", i, " reason=trop_court");
         continue;
      }

      if(StringFind(item, "\"id\"") < 0)
      {
         Print("[FLOW] Fragment ignoré index=", i, " reason=id_absent raw=", item);
         continue;
      }

      // 1. Extraire les données clés
      string copiedTradeId = ExtractValue(item, "\"id\":\"");
      string status        = ExtractValue(item, "\"status\":\"");
      string symbol        = ExtractValue(item, "\"symbol\":\"");
      string type          = ExtractValue(item, "\"trade_type\":\"");
      double volume        = StringToDouble(ExtractValue(item, "\"volume\":"));
      double openPrice     = StringToDouble(ExtractValue(item, "\"open_price\":"));
      double sl            = StringToDouble(ExtractValue(item, "\"sl\":"));
      double tp            = StringToDouble(ExtractValue(item, "\"tp\":"));
      string ticketId      = ExtractValue(item, "\"ticket_id\":\"");
      string clientTicket  = ExtractValue(item, "\"client_ticket_id\":\"");
      long sequence_id      = StringToInteger(ExtractValue(item, "\"sequence_id\":"));
      string action        = ExtractValue(item, "\"action\":\""); // "OPEN" ou "CLOSE"

      if(StringLen(copiedTradeId) == 0)
      {
         Print("[FLOW] Fragment ignoré index=", i, " reason=trade_id_vide raw=", item);
         continue;
      }

      Print("[FLOW] Item brut index=", i, " trade_id=", copiedTradeId, " status=", status, " action=", action, " symbol=", symbol, " type=", type, " volume=", DoubleToString(volume, 2), " open_price=", DoubleToString(openPrice, 5), " sl=", DoubleToString(sl, 5), " tp=", DoubleToString(tp, 5), " ticket_id=", ticketId, " client_ticket_id=", clientTicket, " seq=", sequence_id);
      Print("[FLOW] PARSED trade_id=", copiedTradeId, " volume=", DoubleToString(volume, 2), " symbol=", symbol, " type=", type, " action=", action);

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
         if(volume <= 0)
         {
            Print("[FLOW] EXECUTION ABORTED trade_id=", copiedTradeId, " reason=volume_invalid parsed_volume=", DoubleToString(volume, 2));
            continue;
         }
         if(symbol == "" || (type != "BUY" && type != "SELL"))
         {
            Print("[FLOW] INVALID DATA trade_id=", copiedTradeId, " symbol=", symbol, " type=", type, " volume=", DoubleToString(volume, 2));
            continue;
         }
         Print("[FLOW] Préparation ordre magic=", magicNumber, " comment=", brokerComment);
         G_Trade.SetExpertMagicNumber((ulong)magicNumber);
         if(type == "BUY")
            success = G_Trade.Buy(volume, symbol, 0, sl, tp, brokerComment);
         else if(type == "SELL")
            success = G_Trade.Sell(volume, symbol, 0, sl, tp, brokerComment);
         else
            Print("[FLOW] Type non supporté pour trade_id=", copiedTradeId, " type=", type);

         // Journalisation locale
         G_TradeJournal[G_TradeJournalSize].trade_id = copiedTradeId;
         G_TradeJournal[G_TradeJournalSize].sequence_id = sequence_id;
         G_TradeJournal[G_TradeJournalSize].action = "OPEN";
         G_TradeJournal[G_TradeJournalSize].timestamp = TimeCurrent();
         if(success)
         {
            G_TradeJournal[G_TradeJournalSize].status = "EXECUTED";
            ulong ticket = G_Trade.ResultDeal();
            Print("[FLOW] EXECUTION SUCCESS trade_id=", copiedTradeId, " deal=", ticket, " retcode=", G_Trade.ResultRetcode(), " desc=", G_Trade.ResultRetcodeDescription());
            ConfirmerExecutionTrade(InpBackendUrl, G_ClientId, copiedTradeId, IntegerToString(ticket));
         }
         else
         {
            G_TradeJournal[G_TradeJournalSize].status = "FAILED";
            Print("[FLOW] EXECUTION FAILED trade_id=", copiedTradeId, " retcode=", G_Trade.ResultRetcode(), " desc=", G_Trade.ResultRetcodeDescription());
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
               Print("[FLOW] CLOSE exécuté trade_id=", copiedTradeId, " ticket=", ticketToClose, " profit=", DoubleToString(profit, 2));
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
               Print("[FLOW] CLOSE échec trade_id=", copiedTradeId, " ticket=", ticketToClose, " desc=", G_Trade.ResultRetcodeDescription());
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
            Print("[FLOW] CLOSE impossible trade_id=", copiedTradeId, " ticket=", ticketToClose, " reason=position_not_found");
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
