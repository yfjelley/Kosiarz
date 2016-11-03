//+------------------------------------------------------------------+
//| ENUM
//+------------------------------------------------------------------+
enum ENUM_Market
{
    MARKET_FW20, //WIG 20
    MARKET_DAX   //DAX
};

enum ENUM_State
{
    ST_OutOfHours,        // Po za godzinami
    ST_TradableHours,     // Mozna otworzyc pzycje
    ST_NoTradableHours,   // Juz nie gramy
    ST_OrderOpened        // Otwart pozycja
};

/*
    SGT_None        -  Brak sygnalu
    SGT_FalseGap    -  Luka na otwarciu nastepnie pierwsza(e) swiece zgodnie z
                       kierunkiem. Pozycja jest otwoerana i cena przebija min/max
                       z pierwszej swiecy.
*/
enum ENUM_SignalType
{
    SGT_None, // Brak sygnalu
    SGT_FalseGap
};


//+------------------------------------------------------------------+
//| Input parameters
//+------------------------------------------------------------------+
input int         IN_Uid            = 1975;         // UID
input ENUM_Market IN_Market         = MARKET_FW20;  // Rynek
input double      IN_Lots           = 0.1;         // Lot pozycji
input int         IN_OpenHour       = 8;            // Godz. startu strategii
input int         IN_OpenMinutes    = 45;            // Min. startu strategii
input int         IN_CloseHour      = 16;           // Godz. zamkniecia pozycji
input int         IN_CloseMinutes   = 44;            // Min. amkniecia pozycji
input int         IN_NoTrnHour      = 13;           // Max godz. otwarcia pozycji
input int         IN_NoTrnMinutes   = 30;           // Max min. otwarcia pozycji
input double      IN_TakeProfit     = 1.5;          // Profit to S/L
input int         IN_ShiftCandle    = 0;            // Ignorowane slopki
input int         IN_FrameCandle    = 4;            // Ramka danych +1
input int         IN_SlipPosition   = 3;            // Poslizg pozycji
input bool        IN_Debug          = false;        // Dodatkow informacje

//+------------------------------------------------------------------+
//| Zmienne globalne
//+------------------------------------------------------------------+

long            TradingDay      = 0;
ENUM_State      systemState     = ST_OutOfHours;
ENUM_SignalType sygnal          = SGT_None;
datetime        prevTime        = 0;
datetime        lastSession     = 0;
int             dayCandle       = 0;
int             checkedCandle   = 0;

double          yesterdayClose  = 0;
double          todayOpen  = 0;
double          todayMin   = 0;
double          frameMin   = 0;
double          todayMax   = 0;
double          frameMax   = 0;
double          buyIf      = 0;
double          sellIf     = 0;
bool            isNewBar   = false;
