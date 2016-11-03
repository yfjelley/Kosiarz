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

                while (!OrderClose(OrderTicket(),IN_Lots,price,IN_SlipPosition, Red))
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
    return (frameMin - 1) * Point;
}

double getSellStop()
{
    return (frameMax + 1) * Point;
}

void newSell()
{
    sellIf = 0;

   info("Sprzedajemy Lots:" + DoubleToString(IN_Lots) + " " +
                     "Bid:" + DoubleToString(Bid) + " " +
                     "SL: " + DoubleToStr(getSellStop()));

    int ticket=OrderSend(Symbol(), OP_SELL, IN_Lots, Bid, IN_SlipPosition, getSellStop(), 0,
                     "Kasiarz", IN_Uid,0,Red);

    if ( ticket<0 )
    {
        Wait();
    }

    if (ticket > 0)
    {
        setState(ST_OrderOpened);
    }
}

void newBuy()
{
    buyIf = 0;

   info("Kupujemy Lots:" + DoubleToString(IN_Lots) + " " +
                     "Ask:" + DoubleToString(Ask) + " " +
                     "SL: " + DoubleToStr(getBuyStop()));

    int ticket=OrderSend(Symbol(), OP_BUY, IN_Lots, Ask, IN_SlipPosition, getBuyStop(), 0,
                     "Kasiarz", IN_Uid, 0, Blue);

    if ( ticket<0 )
    {
        Wait();
    }

    if (ticket > 0)
    {
        setState(ST_OrderOpened);
    }
}

void commonCheck()
{
    if (dayCandle <= IN_FrameCandle )
    {
        if (frameMin == 0 || frameMin > Low[0])
        {
            info("Nowe frame Min " + DoubleToString(Low[0]));
            frameMin = Low[0];
        }

        if (frameMax == 0 || frameMax < High[0])
        {
            info("Nowe frame Max " + DoubleToString(High[0]));
            frameMax = High[0];
        }
    }
}

void checkFW20()
{
    if ( dayCandle < IN_FrameCandle )
    {
        if (dayCandle == 3 && isNewBar)
        {
            if (Close[2] > Open[2]  && Close[1] < todayOpen)
            {
                info("Sprzedajemy Candle " + IntegerToString(dayCandle));
                newSell();
            }

            if (Close[2] < Open[2]  && Close[1] > todayOpen)
            {
                info("Kupujemy Candle " + IntegerToString(dayCandle));
                newSell();
            }
        }
    }

    if ( dayCandle > IN_FrameCandle )
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

    if (todayMin == 0 || todayMin > Bid)
    {
        //info("Nowe Min " + DoubleToString(Bid));
        todayMin = Bid;
    }

    if (todayMax == 0 || todayMax < Ask)
    {
        //info("Nowe Max " + DoubleToString(Ask));
        todayMax = Ask;
    }

    // Numer swieczki
    if (Time[0] != prevTime)
    {
        prevTime = Time[0];
        dayCandle++;
        isNewBar = true;
//        info("Candle no " +  IntegerToString(dayCandle) + " - " + TimeToString(lastSession, TIME_DATE));
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
