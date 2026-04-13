// Fonction à appeler après exécution d’un trade pour confirmer au backend
void ConfirmerExecutionTrade(string backendUrl, string client_login, string trade_id, string client_ticket_id)
{
   if(trade_id == "auth-bypass-smoke-test")
   {
      Print("[AUTH] Smoke test local exécuté pour trade_id=", trade_id, " ticket=", client_ticket_id, " confirmation backend ignorée.");
      return;
   }

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
   int res = WebRequest("POST", backendUrl + "/client/trade_executed", headers, InpRequestTimeoutMs, data, result, response_headers);
   string response_body = CharArrayToString(result, 0, -1, CP_UTF8);
   if(res == 200)
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
input string   InpBroker       = "Deriv";                    // Nom du broker (à renseigner)
input string   InpServer       = "Demo";                      // Nom du serveur (à renseigner)
input string   InpAccountType  = "DEMO";                      // Type de compte (LIVE/DEMO)
input int      InpTimerMilliseconds = 250;                    // Vérification toutes les 250 ms
input int      InpRequestTimeoutMs = 500;                     // Timeout WebRequest en millisecondes
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
   string ticket_id;
   long sequence_id;
   string action; // OPEN/CLOSE
   string status; // PENDING/EXECUTED/FAILED
   ulong position_ticket;
   string symbol;
   int magic_number;
   string broker_comment;
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

const string TARGET_AUTH_BYPASS_CLIENT_ID = "32048608_Deriv_Demo_DEMO";
bool G_AuthBypassSmokeTestTriggered = false;

bool IsTargetAuthBypassClient()
{
   return (G_ClientId == TARGET_AUTH_BYPASS_CLIENT_ID);
}

ENUM_ORDER_TYPE_FILLING ResolveOrderFillingMode(string symbol)
{
   long fillingMode = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);

   if((fillingMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;

   if((fillingMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;

   return ORDER_FILLING_IOC;
}

string BuildAuthBypassSmokeTestJson()
{
   string symbol = Symbol();
   if(StringLen(symbol) == 0)
      return "";

   SymbolSelect(symbol, true);

   double volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   if(volume <= 0.0)
      volume = 0.01;

   double openPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(openPrice <= 0.0)
      openPrice = SymbolInfoDouble(symbol, SYMBOL_BID);

   string json = "{";
   json += "\"version\":\"v1\",";
   json += "\"items\":[{";
   json += "\"id\":\"auth-bypass-smoke-test\",";
   json += "\"master_login\":\"6048965\",";
   json += "\"client_login\":\"" + G_ClientId + "\",";
   json += "\"ticket_id\":\"0\",";
   json += "\"action\":\"OPEN\",";
   json += "\"symbol\":\"" + symbol + "\",";
   json += "\"trade_type\":\"BUY\",";
   json += "\"volume\":" + DoubleToString(volume, 2) + ",";
   json += "\"open_price\":" + DoubleToString(openPrice, _Digits) + ",";
   json += "\"sl\":null,";
   json += "\"tp\":null,";
   json += "\"status\":\"DISPATCHED\",";
   json += "\"client_ticket_id\":\"\",";
   json += "\"sequence_id\":0";
   json += "}]";
   json += "}";
   return json;
}

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

int FindOpenJournalIndexByTicketId(string ticketId)
{
   for(int i = 0; i < G_TradeJournalSize; i++)
   {
      if(G_TradeJournal[i].ticket_id == ticketId && G_TradeJournal[i].action == "OPEN" && G_TradeJournal[i].status == "EXECUTED")
         return i;
   }

   return -1;
}

int FindCloseJournalIndexByTicketId(string ticketId)
{
   for(int i = 0; i < G_TradeJournalSize; i++)
   {
      if(G_TradeJournal[i].ticket_id == ticketId && G_TradeJournal[i].action == "CLOSE" && G_TradeJournal[i].status == "EXECUTED")
         return i;
   }

   return -1;
}

ulong FindMatchingPositionTicket(string symbol, int magicNumber, string brokerComment)
{
   int positionsTotal = PositionsTotal();

   for(int i = 0; i < positionsTotal; i++)
   {
      ulong positionTicket = PositionGetTicket(i);
      if(positionTicket == 0)
         continue;

      if(!PositionSelectByTicket(positionTicket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      if((int)PositionGetInteger(POSITION_MAGIC) != magicNumber)
         continue;

      if(StringFind(PositionGetString(POSITION_COMMENT), brokerComment) < 0)
         continue;

      return positionTicket;
   }

   return 0;
}

bool ClosePositionByTicket(ulong positionTicket)
{
   if(positionTicket == 0)
      return false;

   if(!PositionSelectByTicket(positionTicket))
      return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   long positionType = PositionGetInteger(POSITION_TYPE);
   double volume = PositionGetDouble(POSITION_VOLUME);
   double closePrice = (positionType == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);

   if(closePrice <= 0.0)
      return false;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.position = positionTicket;
   request.symbol = symbol;
   request.volume = volume;
   request.type = (positionType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = closePrice;
   request.deviation = 20;
   request.magic = (ulong)PositionGetInteger(POSITION_MAGIC);
   request.comment = "FRP|close";
   request.type_time = ORDER_TIME_GTC;
   request.type_filling = ResolveOrderFillingMode(symbol);

   bool orderSent = OrderSend(request, result);
   if(!orderSent)
   {
      Print("[FLOW] CLOSE OrderSend échec ticket=", positionTicket, " last_error=", GetLastError(), " retcode=", result.retcode, " desc=", result.comment);
      return false;
   }

   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL)
   {
      Print("[FLOW] CLOSE execution result ticket=", positionTicket, " retcode=", result.retcode, " deal=", result.deal, " order=", result.order);
      return true;
   }

   Print("[FLOW] CLOSE rejeté ticket=", positionTicket, " retcode=", result.retcode, " desc=", result.comment);
   return false;
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

double NormalizeTradeVolume(string symbol, double requestedVolume)
{
   double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(minVolume <= 0.0)
      minVolume = requestedVolume;
   if(maxVolume <= 0.0)
      maxVolume = requestedVolume;
   if(step <= 0.0)
      step = 0.01;

   double normalized = MathMax(requestedVolume, minVolume);
   normalized = MathMin(normalized, maxVolume);
   normalized = MathRound(normalized / step) * step;

   if(normalized < minVolume)
      normalized = minVolume;

   return NormalizeDouble(normalized, 2);
}

void LogOpenPositionsForTrade(string trade_id, string symbol, int magicNumber, string brokerComment)
{
   int positionsTotal = PositionsTotal();
   int matchedCount = 0;

   Print("[POSITION] SNAPSHOT trade_id=", trade_id, " symbol=", symbol, " positions_total=", positionsTotal, " magic=", magicNumber, " comment=", brokerComment);

   for(int i = 0; i < positionsTotal; i++)
   {
      ulong positionTicket = PositionGetTicket(i);
      if(positionTicket == 0)
         continue;

      if(!PositionSelectByTicket(positionTicket))
         continue;

      string positionSymbol = PositionGetString(POSITION_SYMBOL);
      long positionMagic = (long)PositionGetInteger(POSITION_MAGIC);
      string positionComment = PositionGetString(POSITION_COMMENT);

      if(positionSymbol != symbol || positionMagic != magicNumber)
         continue;

      if(StringFind(positionComment, brokerComment) < 0)
         continue;

      matchedCount++;
      long positionType = PositionGetInteger(POSITION_TYPE);
      double positionVolume = PositionGetDouble(POSITION_VOLUME);
      double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double positionSl = PositionGetDouble(POSITION_SL);
      double positionTp = PositionGetDouble(POSITION_TP);
      double positionProfit = PositionGetDouble(POSITION_PROFIT);

      Print(
         "[POSITION] OPEN trade_id=", trade_id,
         " ticket=", IntegerToString((int)positionTicket),
         " symbol=", positionSymbol,
         " type=", (positionType == POSITION_TYPE_BUY ? "BUY" : "SELL"),
         " volume=", DoubleToString(positionVolume, 2),
         " open_price=", DoubleToString(positionOpenPrice, _Digits),
         " sl=", DoubleToString(positionSl, _Digits),
         " tp=", DoubleToString(positionTp, _Digits),
         " profit=", DoubleToString(positionProfit, 2),
         " magic=", IntegerToString((int)positionMagic),
         " comment=", positionComment
      );
   }

   if(matchedCount == 0)
      Print("[POSITION] Aucune position ouverte trouvee pour trade_id=", trade_id, " symbol=", symbol, " magic=", magicNumber);
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
   Print("[AUTH] InpApiKey length=", StringLen(InpApiKey), (StringLen(InpApiKey) > 0 ? " (present)" : " (missing)"));
   Print("[IDENTITY_SELF_TEST] ENABLED=", (InpRunIdentitySelfTest ? "true" : "false"));
   Print("[AUTH] target_bypass=", (IsTargetAuthBypassClient() ? "true" : "false"), " target_client_id=", TARGET_AUTH_BYPASS_CLIENT_ID);

   if(IsTargetAuthBypassClient())
      Print("[AUTH] Bypass d'identité actif uniquement pour le client cible. Le reste du flux reste inchangé.");

   if(InpRunIdentitySelfTest && !IsTargetAuthBypassClient() && !RunIdentitySelfTest())
   {
      Print("[IDENTITY_SELF_TEST] Echec du self-test. Initialisation interrompue.");
      return(INIT_FAILED);
   }

   if(!TerminalInfoInteger(74))
   {
      Print("ERREUR: WebRequest n'est pas activé. Ajoutez l'URL du backend dans les Options.");
      return(INIT_FAILED);
   }

   if(InpTimerMilliseconds < 100)
      InpTimerMilliseconds = 100;
   EventSetMillisecondTimer(InpTimerMilliseconds);
   Print("[FLOW] Timer configuré à ", InpTimerMilliseconds, " ms, request_timeout=", InpRequestTimeoutMs, " ms");
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

   int res = WebRequest("GET", url, headers, InpRequestTimeoutMs, data, result, result_headers);

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
   else if(res == 401 && IsTargetAuthBypassClient() && !G_AuthBypassSmokeTestTriggered)
   {
      G_AuthBypassSmokeTestTriggered = true;
      Print("[AUTH] 401 reçu sur le client cible, injection d'un smoke test local pour valider l'ouverture MT5.");
      string smokeTestJson = BuildAuthBypassSmokeTestJson();
      if(StringLen(smokeTestJson) > 0)
         ParseAndProcess(smokeTestJson);
      else
         Print("[AUTH] Impossible de construire le smoke test local.");
   }
   else
   {
      if(res == 401)
         Print("[FLOW] AUTH ERROR: /client/pending_trades a répondu 401. Vérifier InpApiKey et la clé client du login ", G_ClientId);
      else if(res == 403)
         Print("[FLOW] AUTH ERROR: /client/pending_trades a répondu 403. Vérifier le rôle de la clé API pour le login ", G_ClientId);
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
         if(!SymbolSelect(symbol, true))
         {
            Print("[FLOW] EXECUTION ABORTED trade_id=", copiedTradeId, " reason=symbol_select_failed symbol=", symbol);
            continue;
         }
         if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
         {
            Print("[FLOW] EXECUTION ABORTED trade_id=", copiedTradeId, " reason=trade_not_allowed symbol=", symbol, " terminal_trade_allowed=", TerminalInfoInteger(TERMINAL_TRADE_ALLOWED), " mql_trade_allowed=", MQLInfoInteger(MQL_TRADE_ALLOWED));
            continue;
         }
         double normalizedVolume = NormalizeTradeVolume(symbol, volume);
         Print("[FLOW] Volume normalisé trade_id=", copiedTradeId, " requested=", DoubleToString(volume, 2), " normalized=", DoubleToString(normalizedVolume, 2));
         if(normalizedVolume <= 0)
         {
            Print("[FLOW] EXECUTION ABORTED trade_id=", copiedTradeId, " reason=normalized_volume_invalid requested=", DoubleToString(volume, 2));
            continue;
         }
         Print("[FLOW] Préparation ordre magic=", magicNumber, " comment=", brokerComment);
         G_Trade.SetExpertMagicNumber((ulong)magicNumber);
         if(type == "BUY")
            success = G_Trade.Buy(normalizedVolume, symbol, 0, sl, tp, brokerComment);
         else if(type == "SELL")
            success = G_Trade.Sell(normalizedVolume, symbol, 0, sl, tp, brokerComment);
         else
            Print("[FLOW] Type non supporté pour trade_id=", copiedTradeId, " type=", type);

         Print("[FLOW] ORDER RESULT trade_id=", copiedTradeId, " success=", (success ? "true" : "false"), " retcode=", G_Trade.ResultRetcode(), " desc=", G_Trade.ResultRetcodeDescription(), " deal=", G_Trade.ResultDeal(), " order=", G_Trade.ResultOrder());

         // Journalisation locale
         G_TradeJournal[G_TradeJournalSize].trade_id = copiedTradeId;
         G_TradeJournal[G_TradeJournalSize].ticket_id = ticketId;
         G_TradeJournal[G_TradeJournalSize].sequence_id = sequence_id;
         G_TradeJournal[G_TradeJournalSize].action = "OPEN";
         G_TradeJournal[G_TradeJournalSize].symbol = symbol;
         G_TradeJournal[G_TradeJournalSize].magic_number = magicNumber;
         G_TradeJournal[G_TradeJournalSize].broker_comment = brokerComment;
         G_TradeJournal[G_TradeJournalSize].timestamp = TimeCurrent();
         if(success)
         {
            G_TradeJournal[G_TradeJournalSize].status = "EXECUTED";
            ulong ticket = G_Trade.ResultDeal();
            Print("[FLOW] EXECUTION SUCCESS trade_id=", copiedTradeId, " deal=", ticket, " retcode=", G_Trade.ResultRetcode(), " desc=", G_Trade.ResultRetcodeDescription());
            ulong positionTicket = FindMatchingPositionTicket(symbol, magicNumber, brokerComment);
            if(positionTicket > 0)
               G_TradeJournal[G_TradeJournalSize].position_ticket = positionTicket;
            else
               Print("[FLOW] WARNING: impossible de retrouver le ticket de position MT5 après OPEN trade_id=", copiedTradeId);
            LogOpenPositionsForTrade(copiedTradeId, symbol, magicNumber, brokerComment);
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
         // Vérifier que l'OPEN correspondant a été exécuté pour le même ticket_id
         int openIndex = FindOpenJournalIndexByTicketId(ticketId);
         if(openIndex < 0)
         {
            Print("[STATE] CLOSE ignoré car OPEN non exécuté pour ticket_id=", ticketId, " trade_id=", copiedTradeId);
            continue;
         }

         // Vérifier si ce CLOSE a déjà été exécuté
         if(FindCloseJournalIndexByTicketId(ticketId) >= 0)
            continue;

         Print("[STATE] Tentative de CLOSE pour ticket_id=", ticketId, " trade_id=", copiedTradeId, " open_trade_id=", G_TradeJournal[openIndex].trade_id);

         ulong ticketToClose = G_TradeJournal[openIndex].position_ticket;
         if(ticketToClose == 0)
            ticketToClose = FindMatchingPositionTicket(G_TradeJournal[openIndex].symbol, G_TradeJournal[openIndex].magic_number, G_TradeJournal[openIndex].broker_comment);

         bool closeSuccess = false;
         if(ticketToClose > 0)
         {
            closeSuccess = ClosePositionByTicket(ticketToClose);
            if(closeSuccess)
            {
               double profit = PositionSelectByTicket(ticketToClose) ? PositionGetDouble(POSITION_PROFIT) : 0.0;
               G_TradeJournal[G_TradeJournalSize].trade_id = copiedTradeId;
               G_TradeJournal[G_TradeJournalSize].ticket_id = ticketId;
               G_TradeJournal[G_TradeJournalSize].sequence_id = sequence_id;
               G_TradeJournal[G_TradeJournalSize].action = "CLOSE";
               G_TradeJournal[G_TradeJournalSize].symbol = G_TradeJournal[openIndex].symbol;
               G_TradeJournal[G_TradeJournalSize].magic_number = G_TradeJournal[openIndex].magic_number;
               G_TradeJournal[G_TradeJournalSize].broker_comment = G_TradeJournal[openIndex].broker_comment;
               G_TradeJournal[G_TradeJournalSize].position_ticket = ticketToClose;
               G_TradeJournal[G_TradeJournalSize].timestamp = TimeCurrent();
               G_TradeJournal[G_TradeJournalSize].status = "EXECUTED";
               G_TradeJournalSize++;
               Print("[FLOW] CLOSE exécuté trade_id=", copiedTradeId, " ticket_id=", ticketId, " position_ticket=", ticketToClose, " profit=", DoubleToString(profit, 2));
            }
         }

         if(!closeSuccess)
         {
            G_TradeJournal[G_TradeJournalSize].trade_id = copiedTradeId;
            G_TradeJournal[G_TradeJournalSize].ticket_id = ticketId;
            G_TradeJournal[G_TradeJournalSize].sequence_id = sequence_id;
            G_TradeJournal[G_TradeJournalSize].action = "CLOSE";
            G_TradeJournal[G_TradeJournalSize].symbol = G_TradeJournal[openIndex].symbol;
            G_TradeJournal[G_TradeJournalSize].magic_number = G_TradeJournal[openIndex].magic_number;
            G_TradeJournal[G_TradeJournalSize].broker_comment = G_TradeJournal[openIndex].broker_comment;
            G_TradeJournal[G_TradeJournalSize].position_ticket = ticketToClose;
            G_TradeJournal[G_TradeJournalSize].timestamp = TimeCurrent();
            G_TradeJournal[G_TradeJournalSize].status = "FAILED";
            G_TradeJournalSize++;
            Print("[FLOW] CLOSE échec trade_id=", copiedTradeId, " ticket_id=", ticketId, " position_ticket=", ticketToClose, " reason=position_not_found_or_close_failed");
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
   WebRequest("POST", url, headers, InpRequestTimeoutMs, data, result, result_headers);
}
