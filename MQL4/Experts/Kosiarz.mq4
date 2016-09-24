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
    bool ok = false;

    if (Time[0] == prevTime)
    {
        ok = false;
    }

    if (ok)
    {
        prevTime = Time[0];

        if (State != ST_OrderOpened)
        {
            int hour    =   TimeHour(    Time[0]);
            int min     =   TimeMinute(  Time[0]);

            if (State == ST_OutOfHours && isTradingTime())
            {
                State = ST_TradableHours;
                TradingDay++;
                lastSession = Time[0];
                info("Nowy dzien " + TimeToString(lastSession, TIME_DATE));
            }

            if (isNoTradableTime())
            {
                State = ST_NoTradableHours;
                info("Nie gramy juz " + TimeToString(lastSession, TIME_DATE));
            }

            if (hour > IN_CloseHour || ( hour == IN_CloseHour && min > IN_CloseMinutes))
            {
                State = ST_OutOfHours;
                dayTick = 0;
                ok = false;
                info("Koniec dnia " + TimeToString(lastSession, TIME_DATE));
            }
        }
    }

    return (ok);
}

void openFW20()
{

}


void closeAllOrders()
{

}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if (!isTradingAllowed())
    {
        return;
    }
    dayTick++;
    info("Tik no " +  IntegerToString(dayTick) + " - " + TimeToString(lastSession, TIME_DATE));

    if (State == ST_TradableHours)
    {
        switch (IN_Market)
        {
            case     MARKET_FW20:
                openFW20();
                break;
            case     MARKET_DAX:
                break;
        }
    }

    int hour    =   TimeHour(    Time[0]);
    int min     =   TimeMinute(  Time[0]);
    if ((State != ST_OrderOpened) &&
        (hour > IN_CloseHour || ( hour == IN_CloseHour && min >= IN_CloseMinutes)))
    {
        closeAllOrders();
    }
}
