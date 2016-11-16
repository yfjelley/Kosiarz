//+------------------------------------------------------------------+
//|                                                      kasiarz.mq4 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, Greemid."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Kosiarz.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    prevTime = Time[0];
    lastSession = Time[0];
    setState(ST_OutOfHours);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Wait                                                             |
//+------------------------------------------------------------------+
void Wait()
{
    Sleep(5000);
}

void info(string txt)
{
    if (IN_Debug)
    {
        Print(txt);
    }
}

bool isTradingTime()
{
    datetime t = TimeCurrent();
    int hour    =   TimeHour(    t);
    int min     =   TimeMinute(  t);
    bool ok     =   false;

    if ((hour > IN_OpenHour || ( hour == IN_OpenHour && min >= IN_OpenMinutes)) &&
       (hour < IN_NoTrnHour || ( hour == IN_NoTrnHour && min < IN_NoTrnMinutes)))
    {
        ok = true;
    }
    return(ok);
}

void setState(ENUM_State state)
{
    string  r = "";

    if (state != systemState)
    {
       switch (state)
       {
           case ST_OutOfHours:
               r = "Po za godzinami";
               break;
           case ST_TradableHours:
               r = "Mozna otworzyc pzycje";
               break;
           case ST_NoTradableHours:
               r = "Juz nie gramy";
               break;
           case ST_OrderOpened:
               r = "Otwarta pozycja";
               break;
       }
       info("Nowy status " + r + ". Candle no " +  IntegerToString(dayCandle));

       systemState = state;
   }
}

bool isNoTradableTime()
{
    datetime t = TimeCurrent();
    int hour    =   TimeHour(    t);
    int min     =   TimeMinute(  t);
    bool ok     =   false;

    if ((hour > IN_NoTrnHour || ( hour == IN_NoTrnHour && min >= IN_NoTrnMinutes))  &&
       (hour < IN_CloseHour || ( hour == IN_CloseHour && min < IN_CloseMinutes)))
    {
        ok = true;
    }

    return(ok);
}


void newDayReset()
{
    info("Reset danych " + DoubleToString(Bid));
    yesterdayClose = iClose(Symbol(), PERIOD_D1, 1);
    todayOpen   = Open[0];
    todayMin    = 0;
    todayMax    = 0;
    frameMin    = 0;
    frameMax    = 0;
    sellIf      = 0;
    buyIf       = 0;
    checkedCandle = 0;
    TradingDay++;
    lastSession = Time[0];
    dayCandle   = 0;
}

bool isTradingAllowed()
{
    bool ok = true;

/*  if (Time[0] == prevTime)
    {
        ok = false;
    }
    prevTime = Time[0];
}
*/
    if (ok)
    {

        if (systemState == ST_OrderOpened)
        {
            int    total    =   OrdersTotal();
            int    cnt      =   0;
            for (int i = 0; i < total; i++)
            {
                if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) &&
                    OrderSymbol()       == Symbol() &&
                    OrderMagicNumber()  == IN_Uid)
                {
                    cnt++;
                }
            }

            if (cnt == 0)
            setState(ST_OutOfHours);
        }

        if (systemState != ST_OrderOpened)
        {
            int hour    =   TimeHour(    Time[0]);
            int min     =   TimeMinute(  Time[0]);
            if (systemState == ST_OutOfHours && isTradingTime())
            {
                newDayReset();
                info("Nowy dzien " + TimeToString(lastSession, TIME_DATE));
                setState(ST_TradableHours);
            }
            else if (isNoTradableTime())
            {
                if (systemState != ST_NoTradableHours)
                {
                   info("Nie gramy juz " + TimeToString(lastSession, TIME_DATE));
                   setState(ST_NoTradableHours);
                   sellIf      = 0;
                   buyIf       = 0;
                }
            }
            else if (hour > IN_CloseHour || ( hour == IN_CloseHour && min > IN_CloseMinutes))
            {
                if (systemState != ST_OutOfHours)
                {
                   info("Koniec dnia " + TimeToString(lastSession, TIME_DATE));
                   setState(ST_OutOfHours);
                   dayCandle = 0;
                   ok = false;
               }
            }
        }
    }

    return (ok);
}

void closeAllOrders()
{
    int    ticket   =   -1;
    int    total    =   OrdersTotal();

    for (int i = 0; i < total; i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) &&
            OrderSymbol()       == Symbol() &&
            OrderMagicNumber()  == IN_Uid)
        {

            // Zamykamy otwarte zlecenia
            if (OrderType() == OP_BUY || OrderType() == OP_SELL)
            {
                double price = Ask;
                if (OrderType() == OP_BUY)
                {
                    price = Bid;
                }

                while (!OrderClose(OrderTicket(),OrderLots(),price,IN_SlipPosition, Red))
                {
                    Wait();
                    RefreshRates();
                }
            }
            else
            {
                // Zamykamy oczekujace
                while (!OrderDelete(OrderTicket()))
                {
                  Wait();
                }
            }
        }
    }
}

double getBuyStop()
{
    double sl = (frameMin - 1) * Point;
    if ( dayCandle >= IN_FrameCandle )
    {
        sl = Ask - (frameMax - frameMin)/2;
    }
    else
    {
        sl = (frameMin - 1) * Point;
    }

    if (Ask - sl < IN_MinSL* Point)
        sl = Ask - (IN_MinSL* Point);
    sl = NormalizeDouble(sl, Digits);

    return sl;
}

double getSellStop()
{
    double sl = 0;
    if ( dayCandle >= IN_FrameCandle )
    {
        sl = Bid + (frameMax - frameMin)/2;
    }
    else
    {
        sl = (frameMax + 1) * Point;
    }

    if ( sl - Bid  < IN_MinSL* Point)
        sl = Bid + (IN_MinSL* Point);
    sl = NormalizeDouble(sl, Digits);

    return sl;
}

double getLots(double sl)
{
    double lt = IN_Lots;
    double pointVal = MarketInfo(Symbol(),MODE_TICKVALUE) * IN_Lots;

    if (AccountBalance() > IN_InitDeposit)
    {
        double toPlay  = (AccountBalance() - IN_InitDeposit) * (IN_ValToRisk/100);
        double onPoint =  (toPlay / 3) * IN_Lots;

           int newLots = onPoint / (pointVal*sl);
        if ( newLots > 2 )
        {
            lt  = NormalizeDouble(newLots * IN_Lots,1);
        }
    }
    return (lt);
}


void newSell()
{
    sellIf = 0;

    double sl = getSellStop();
    double tp = Bid - ((sl-Bid) * IN_TakeProfit);
    tp = NormalizeDouble(tp, Digits);
    double lt = getLots(sl-Bid);

   info("Sprzedajemy Lots:" + DoubleToString(IN_Lots) + " " +
                     "Bid:" + DoubleToString(Bid) + " " +
                     "TP:" + DoubleToString(tp) + " " +
                     "SL: " + DoubleToStr(getSellStop()));

    int t1=OrderSend(Symbol(), OP_SELL, lt*2, Bid, IN_SlipPosition, sl, 0,
                     "Kasiarz", IN_Uid,0,Red);
    int t2=OrderSend(Symbol(), OP_SELL, lt, Bid, IN_SlipPosition, sl, tp,
                  "Kasiarz1", IN_Uid,0,Red);

    if ( t1<0 || t2<0)
    {
        Wait();
    }

    if (t1 > 0 || t2 > 0)
    {
        setState(ST_OrderOpened);
    }
}

void newBuy()
{
    buyIf = 0;

    double sl = getBuyStop();
    double tp = Ask + ((Ask - sl) * IN_TakeProfit);
    tp = NormalizeDouble(tp, Digits);
    double lt = getLots(Ask-sl);

    info("Kupujemy Lots:" + DoubleToString(IN_Lots) + " " +
                     "Ask:" + DoubleToString(Ask) + " " +
                     "SL: " + DoubleToStr(getBuyStop()));

    int t1=OrderSend(Symbol(), OP_BUY, lt*2, Ask, IN_SlipPosition, sl, 0,
                "Kasiarz", IN_Uid, 0, Blue);
    int t2=OrderSend(Symbol(), OP_BUY, lt, Ask, IN_SlipPosition, sl, tp,
                "Kasiarz1", IN_Uid, 0, Blue);

    if ( t1<0 || t2<0)
    {
        Wait();
    }

    if (t1 > 0 || t2 > 0)
    {
        setState(ST_OrderOpened);
    }
}

void checkSL()
{
    int    ticket   =   -1;
    int    total    =   OrdersTotal();

    for (int i = 0; i < total; i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) &&
            OrderSymbol()       == Symbol() &&
            OrderMagicNumber()  == IN_Uid)
        {

            double nsl = 0;

            if (OrderType() == OP_BUY)
            {
                double sl = OrderOpenPrice() - OrderStopLoss();
                double tp = OrderTakeProfit();
                if (sl > 0 )
                {
                    double d = (todayMax - OrderOpenPrice());
                    if ( d >= sl )
                    {
                        sl = OrderOpenPrice() + ((SymbolInfoInteger(Symbol(),SYMBOL_SPREAD) + 1 ) *Point );
                        bool res=OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,0,Blue);
                    }
                }
            }
            else if (OrderType() == OP_SELL)
            {
                double tp = OrderTakeProfit();
                double sl = OrderStopLoss() - OrderOpenPrice();
                info("Nowe Min " + DoubleToString(Low[0]));
                if (sl > 0 )
                {
                    double d = (OrderOpenPrice() - todayMin);
/*                    info("Nowe Min " + DoubleToString(todayMin) +
                         " d: "  + DoubleToString(d) +
                          " sl "+  DoubleToString(sl));*/
                    if ( d >= sl )
                    {
                        sl = OrderOpenPrice() - ((SymbolInfoInteger(Symbol(),SYMBOL_SPREAD) - 1 ) *Point );
                        bool res=OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,0,Blue);
                    }
                }
            }
        }
    }
}


void commonCheck()
{
    if (dayCandle <= IN_FrameCandle )
    {
        if (frameMin == 0 || frameMin > Low[0])
        {
            //info("Nowe frame Min " + DoubleToString(Low[0]));
            frameMin = Low[0];
        }

        if (frameMax == 0 || frameMax < High[0])
        {
            //info("Nowe frame Max " + DoubleToString(High[0]));
            frameMax = High[0];
        }
    }
}

void checkFW20()
{
    if ( dayCandle < IN_FrameCandle )
    {
        if (dayCandle == 3 && isNewBar &&
            (IN_Patern == PT_ALL || IN_Patern == PT_Szpulka))
        {
            info("Day Cnd "  + IntegerToString(dayCandle));
            if ((Close[2] == Open[2] && Close[1] < Low[2]))
            {
                //info("Sprzedajemy Candle " + IntegerToString(dayCandle));
                newSell();
            }
            else if  (Close[2] == Open[2] && Close[1] > High[2])
            {
                info("Kupujemy Candle " + IntegerToString(dayCandle));
                newBuy();
            }
        }

/*
        if (dayCandle == 3 && isNewBar)
        {
            if ((Close[2] > Open[2]  && Close[1] <  Low[2]) ||
                (Close[2] > Open[2]  && Close[1] < todayOpen && High[1] < High[2] && Low[0] < Low[1]) ||
                (Close[2] == Open[2] && Close[1] < Low[2]))
            {
                //info("Sprzedajemy Candle " + IntegerToString(dayCandle));
                newSell();
            }
            else if ((Close[2] < Open[2]  && Close[1] > todayOpen && Low[0] > Low[2] && High[0] > High[1]) ||
                (Close[2] == Open[2] && Close[1] > High[2]))
            {
                //info("Kupujemy Candle " + IntegerToString(dayCandle));
                newBuy();
            }
        }
*/
    }
/*
    if ( dayCandle >= IN_FrameCandle )
    {
        if (Bid >= frameMax + 1)
        {
            info("Kupujemy Ask" + DoubleToString(Ask) + " Bid" + DoubleToString(Bid));
            newBuy();
        }

        if (Ask <= frameMin - 1)
        {
            newSell();
        }
    }
*/
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime t = TimeCurrent();
    int hour    =   TimeHour(    t);
    int min     =   TimeMinute(  t);

    //if (systemState == ST_OrderOpened)
    //{
         //if ( hour == IN_CloseHour )
            //info("G: " + IntegerToString(hour) + " " + IntegerToString(min));
    //}

    RefreshRates();
    if ((systemState == ST_OrderOpened) &&
        (hour > IN_CloseHour || ( hour == IN_CloseHour && min >= IN_CloseMinutes)))
    {
        info("Zamknij wszystkie pozycje");
        closeAllOrders();
    }

    if (!isTradingAllowed())
    {
        return;
    }

    if (todayMin == 0 || todayMin > Low[0])
    {
        //info("Nowe Min " + DoubleToString(Bid));
        todayMin = Low[0];
        checkSL();
    }

    if (todayMax == 0 || todayMax < High[0])
    {
        //info("Nowe Max " + DoubleToString(Ask));
        todayMax = High[0];
        checkSL();
    }

    // Numer swieczki
    if (Time[0] != prevTime)
    {
        prevTime = Time[0];
        dayCandle++;
        isNewBar = true;

        //if (systemState == ST_OrderOpened)
        //{

        //}
//       info("Candle no " +  IntegerToString(dayCandle) + " - " + TimeToString(lastSession, TIME_DATE));
    }
    else
    {
        isNewBar = false;
    }

    if (systemState == ST_TradableHours)
    {
        commonCheck();
        switch (IN_Market)
        {
            case     MARKET_FW20:
                checkFW20();
                break;
            case     MARKET_DAX:
                break;
        }
    }
}
