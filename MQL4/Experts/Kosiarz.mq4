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
    int hour    =   TimeHour(    Time[0]);
    int min     =   TimeMinute(  Time[0]);
    bool ok     =   false;

    if ((hour > IN_OpenHour || ( hour == IN_OpenHour && min >= IN_OpenMinutes)) &&
       (hour < IN_NoTrnHour || ( hour == IN_NoTrnHour && min < IN_NoTrnMinutes)))
    {
        ok = true;
    }
    return(ok);
}

bool isNoTradableTime()
{
    int hour    =   TimeHour(    Time[0]);
    int min     =   TimeMinute(  Time[0]);
    bool ok     =   false;

    if ((hour > IN_NoTrnHour || ( hour == IN_NoTrnHour && min >= IN_NoTrnMinutes))  &&
       (hour < IN_CloseHour || ( hour == IN_CloseHour && min < IN_CloseMinutes)))
    {
        ok = true;
    }

    return(ok);
}


bool isTradingAllowed()
{
    bool ok = true;

    if (Time[0] == prevTime)
    {
        ok = false;
    }

    if (ok)
    {
        prevTime = Time[0];

        if (systemState != ST_OrderOpened)
        {
            int hour    =   TimeHour(    Time[0]);
            int min     =   TimeMinute(  Time[0]);
            if (systemState == ST_OutOfHours && isTradingTime())
            {
                info("Nowy dzien " + TimeToString(lastSession, TIME_DATE));
                yesterdayClose = iClose(Symbol(), PERIOD_D1, 1);
                todayOpen   = Open[0];
                todayMin    = 0;
                todayMax    = 0;
                frameMin    = 0;
                frameMax    = 0;
                sellIf      = 0;
                buyIf       = 0;
                systemState = ST_TradableHours;
                TradingDay++;
                lastSession = Time[0];
            }
            else if (isNoTradableTime())
            {
                info("Nie gramy juz " + TimeToString(lastSession, TIME_DATE));
                systemState = ST_NoTradableHours;
                sellIf      = 0;
                buyIf       = 0;
            }
            else if (hour > IN_CloseHour || ( hour == IN_CloseHour && min > IN_CloseMinutes))
            {
                info("Koniec dnia " + TimeToString(lastSession, TIME_DATE));
                systemState = ST_OutOfHours;
                dayCandle = 0;
                ok = false;
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
    return Bid-10*Point;
}

double getSellStop()
{
    return Ask+10*Point;
}

void newSell()
{
    sellIf = 0;
    int ticket=OrderSend(Symbol(), OP_SELL, IN_Lots, Bid, IN_SlipPosition, getSellStop(), 0,
                     "Kasiarz", IN_Uid,0,Red);

    if ( ticket<0 )
    {
        Wait();
        prevTime=Time[1];
    }
}

void newBuy()
{
    buyIf = 0;
    int ticket=OrderSend(Symbol(), OP_BUY, IN_Lots, Ask, IN_SlipPosition, getBuyStop, 0,
                     "Kasiarz", IN_Uid, 0, Blue);

    if ( ticket<0 )
    {
        Wait();
        prevTime=Time[1];
    }
}

void commonCheck()
{
    if (dayCandle>1 &&  dayCandle <= IN_FrameCandle )
    {
        if (frameMin == 0 || frameMin > Low[1])
        {
            info("Nowe frame Min " + DoubleToString(Low[1]));
            frameMin = Low[1];
        }

        if (frameMax == 0 || frameMax < High[1])
        {
            info("Nowe frame Max " + DoubleToString(High[1]));
            frameMin = High[1];
        }
    }
}

void checkFW20()
{
    if ( dayCandle == IN_FrameCandle )
    {

    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime t = TimeCurrent();
    int hour    =   TimeHour(    t);
    int min     =   TimeMinute(  t);

    RefreshRates();
    if ((systemState == ST_OrderOpened) &&
        (hour > IN_CloseHour || ( hour == IN_CloseHour && min >= IN_CloseMinutes)))
    {
        closeAllOrders();
    }

    if (todayMin == 0 || todayMin > Bid)
    {
        info("Nowe Min " + DoubleToString(Bid));
        todayMin = Bid;
    }

    if (todayMax == 0 || todayMax < Ask)
    {
        info("Nowe Max " + DoubleToString(Ask));
        todayMin = Ask;
    }

    if (!isTradingAllowed())
    {
        return;
    }

    dayCandle++;
    info("Candle no " +  IntegerToString(dayCandle) + " - " + TimeToString(lastSession, TIME_DATE));

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
