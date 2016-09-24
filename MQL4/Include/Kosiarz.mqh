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


//+------------------------------------------------------------------+
//| Input parameters
//+------------------------------------------------------------------+
input int         IN_Uid            = 1975;         // UID
input ENUM_Market IN_Market         = MARKET_FW20;  // Rynek
input double      IN_Lots           = 0.01;         // Lot pozycji
input int         IN_OpenHour       = 9;            // Godz. startu strategii
input int         IN_OpenMinutes    = 0;            // Min. startu strategii
input int         IN_CloseHour      = 18;           // Godz. zamkniecia pozycji
input int         IN_CloseMinutes   = 0;            // Min. amkniecia pozycji
input int         IN_NoTrnHour      = 13;           // Max godz. otwarcia pozycji
input int         IN_NoTrnMinutes   = 30;           // Max min. otwarcia pozycji
input double      IN_TakeProfit     = 1.5;          // Profit to S/L
input int         IN_ShiftCandle    = 1;            // Ignorowane slopki
input bool        IN_Debug          = false;        // Dodatkow informacje

//+------------------------------------------------------------------+
//| ZMienne globalne
//+------------------------------------------------------------------+

static long     TradingDay      = 0;
static long     State           = ST_OutOfHours;
static datetime prevTime        = 0;
static datetime lastSession     = 0;
static int      dayTick         = 0;
