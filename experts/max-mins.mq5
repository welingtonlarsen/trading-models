//+------------------------------------------------------------------+
//|                                                    123-setup.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade\PositionInfo.mqh>
CTrade trade;
CPositionInfo  positionInfo;

input int startHour = 13;
input int startMinute = 1;
input int closeHour = 17;
input int closeMinute = 0;

input int lote = 1;
input int stopLossPoints = 0;

input double dailyMaxFinantialLoss = -500.00;
input double dailyMaxFinantialGain = 1000.00;

int keltnerHandle = INVALID_HANDLE;
double keltnerValues[];
MqlRates candles[];


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
   ArraySetAsSeries(keltnerValues, true);
   ArraySetAsSeries(candles, true);

   keltnerHandle = iCustom(_Symbol, _Period, "keltner_channel.ex5");

   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
   closePositionsAndOrdersBeforeMarketClose();

   //Print("Resultado metodo = ", Controle());


   if(isPurchased() && Controle() <= dailyMaxFinantialLoss) {
      trade.PositionClose(_Symbol);
   }

   if(OrdersTotal() > 0 && Controle() <= dailyMaxFinantialLoss) {
      ulong ticket = OrderGetTicket(0);
      bool deleted = trade.OrderDelete(ticket);
   }


   if(isNewBar() && isOperationTime()) {
      updateIndicators();

      double max = getMax();
      double min = getMin();


      if(!isPurchased() && Controle() < dailyMaxFinantialGain) {
         if(OrdersTotal() > 0) {
            ulong ticket = OrderGetTicket(0);
            bool deleted = trade.OrderDelete(ticket);
         }

         if(candles[1].close > keltnerValues[1]) {
            double sl = stopLossPoints > 0 ? min - stopLossPoints : 0;

            trade.BuyLimit(lote, min, _Symbol, sl, max, 0, 0, "Compra buy limit");
         }

         if(candles[1].close < keltnerValues[1]) {
            double sl = stopLossPoints > 0 ? max + stopLossPoints : 0;

            trade.SellLimit(lote, max, _Symbol, sl, min, 0, 0, "Venda sell limit");
         }
      } else if(isPurchased()) {
         if(EnumToString(positionInfo.PositionType()) == "POSITION_TYPE_BUY") {
            double SL = trade.RequestSL();
            bool modified = trade.PositionModify(_Symbol, SL, max);
         }
         if(EnumToString(positionInfo.PositionType()) == "POSITION_TYPE_SELL") {
            double SL = trade.RequestSL();
            bool modified = trade.PositionModify(_Symbol,SL, min);
         }

      }

   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool areLastBarsValid() {
   int copied1 = CopyBuffer(keltnerHandle, 0, 0, 4, keltnerValues);
   int copied2 = CopyRates(_Symbol, _Period, 0, 6, candles);

   if(copied1 != 4 && copied2 != 6) {
      Alert("Erro ao copiar buffers para medias e velas: ",GetLastError(),"!");
   }


   double candle1Size = candles[1].high - candles[1].low;
   double candle2Size = candles[2].high - candles[2].low;
   double candle3Size = candles[3].high - candles[3].low;
   double candle4Size = candles[4].high - candles[4].low;

   return candle1Size > 0 && candle2Size > 0 && candle3Size > 0 && candle4Size > 0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closePositionsAndOrdersBeforeMarketClose() {
   datetime now = TimeCurrent();
   MqlDateTime nowSrt;
   TimeToStruct(now,nowSrt);


   if(nowSrt.hour >= closeHour && nowSrt.min >= closeMinute && OrdersTotal() > 0) {
      ulong ticket = OrderGetTicket(0);
      bool deleted = trade.OrderDelete(ticket);
   }

   if(nowSrt.hour >= closeHour && nowSrt.min >= closeMinute && isPurchased()) {
      trade.PositionClose(_Symbol);
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isOperationTime() {
   datetime now = TimeCurrent();
   MqlDateTime nowSrt;
   TimeToStruct(now,nowSrt);

   //return nowSrt.hour <= 17 && nowSrt.min < 40;

   if(nowSrt.hour == startHour) {
      return nowSrt.min >= startMinute;
   }

   if(nowSrt.hour == closeHour) {
      return nowSrt.min <= closeMinute;
   }

   if(nowSrt.hour > startHour && nowSrt.hour < closeHour) {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isNewBar() {
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_time=0;
//--- current time
   datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);

//--- if it is the first call of the function
   if(last_time==0) {
      //--- set the time and exit
      last_time=lastbar_time;
      return(false);
   }

//--- if the time differs
   if(last_time!=lastbar_time) {
      //--- memorize the time and return true
      last_time=lastbar_time;
      return(true);
   }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isPurchased() {
   bool purchased = false;
   if(PositionSelect(_Symbol)) {
      purchased = true;
   }

   return purchased;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void updateIndicators() {
   int copied1 = CopyBuffer(keltnerHandle, 0, 0, 4, keltnerValues);
   int copied2 = CopyRates(_Symbol, _Period, 0, 6, candles);

   if(copied1 != 4 && copied2 != 6) {
      Alert("Erro ao copiar buffers para medias e velas: ",GetLastError(),"!");
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getMax() {
   if(candles[1].high > candles[2].high) {
      return candles[1].high;
   } else {
      return candles[2].high;
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getMin() {
   if(candles[1].low < candles[2].low) {
      return candles[1].low;
   } else {
      return candles[2].low;
   }
}
//+------------------------------------------------------------------+
// https://www.mql5.com/pt/forum/344492
double Controle () {


   double resultado =0;
   double soma = 0;
   double profit = 0;

   //Lógica para o resultado do dia
   string CurrDate = TimeToString(TimeCurrent(), TIME_DATE);

   if (HistorySelect(StringToTime(CurrDate), TimeCurrent()))
      for (int i = HistoryDealsTotal(); i >= 0; i--) {
         const ulong Ticket = HistoryDealGetTicket(i);
         if((HistoryDealGetString(Ticket, DEAL_SYMBOL) == _Symbol))
            profit += HistoryDealGetDouble(Ticket, DEAL_PROFIT);
      }


   // Lógica para o resultado do trade em aberto

   for(int i=PositionsTotal()-1; i>=0; i--) { // Vare o histórico
      string simbolo = PositionGetSymbol(i); // Verifica a posição no Simbolo
      ulong magic = PositionGetInteger(POSITION_MAGIC);  // cria a variável para o numero magico e define ele
      if(simbolo==_Symbol)  // Verifica o número magico se ele é igual ao do robô que enviou a ordem
         resultado += PositionGetDouble(POSITION_PROFIT); // Soma todas as posições
   }

   //somatório do resultado do dia + trade em aberto

   soma = resultado + profit;


   return(soma);

}
//+------------------------------------------------------------------+
