using UnityEngine;

namespace Phelki
{
    /// <summary>Фразы деда-пасечника. Все придуманы для игры.</summary>
    public static class Lines
    {
        public static readonly string[] Silence = { "Ну? Я жду.", "Пчёлы тоже ждут.", "Хм..." };

        public static readonly string[] AnsweredBee =
            { "Вот это по-нашему. Пчёлок надо уважать!", "Наш человек! Держи улей." };

        public static readonly string[] AnsweredHuman =
            { "Ах вот ты как...", "Пчёлы это запомнят.", "Ну всё. Беги." };

        public static readonly string[] HubBee =
        {
            "Лети, родимая, цветы сами себя не опылят.", "Мёду бы побольше, зима на носу.",
            "Осы опять у мусорки трутся, осторожней там.", "Бабкины клумбы сегодня цветут — слетай."
        };

        public static readonly string[] HubHuman =
            { "А, это ты. Неуважающий.", "Пчёлы на тебя смотрят. Я бы не стоял тут." };

        public static readonly string[] Deposit = { "Мёд пошёл!", "Уважаю.", "Вот это работа!", "Неси ещё." };

        public static readonly string[] BigDeposit =
            { "Сколько принесла-то! Медаль тебе.", "Вот это улов! Зимой не пропадём." };

        public static readonly string[] Crash =
        {
            "Куда ж ты в стекло-то!", "Бум. Живая?", "Ну кто так летает...", "Аккуратней, пыльцу растеряла!"
        };

        public static readonly string[] Jam = { "Опять в варенье залезла!", "Сладко, да не туда." };
        public static readonly string[] WaspSteal = { "Осы пыльцу отжали!", "Эти в кепках опять за своё." };
        public static readonly string[] WaspStun = { "Так их, рывком!", "Вот это таран!" };
        public static readonly string[] Rare = { "Ого, бабкин цветок! Редкая пыльца." };
        public static readonly string[] Wind = { "Ветер поднялся, держись!", "Сдувает! Крепче держись." };
        public static readonly string[] Full = { "Полная, тяжёлая — неси в улей!" };
        public static readonly string[] TimeLow = { "Солнце садится, тащи всё в улей!" };
        public static readonly string[] Fan = { "Сосед вентилятор включил, вот же..." };

        public static readonly string[] ResultGood =
            { "Хороший вылет. Пчёлок ты уважаешь, видно сразу.", "Вот это я понимаю — пасечник!" };

        public static readonly string[] ResultBad =
            { "Маловато. Но пчёлы не сдаются.", "Ничего, завтра цветы снова зацветут." };

        // ── Побег (за людей) ──
        public static readonly string[] EscapeStart =
            { "Ну что, неуважающий, беги!", "Пчёлы тебя уже заметили." };

        public static readonly string[] Stung = { "Ага, попался!", "Это тебе за неуважение.", "Ещё разок!" };
        public static readonly string[] Swat = { "Ты что, по пчёлке мухобойкой?!", "Ох и получишь ты..." };
        public static readonly string[] SmokeUsed = { "Дымом, значит... хитрый.", "Дымарь мой стащил!" };
        public static readonly string[] JarTaken = { "Мёд таскаешь? Ну-ну.", "Положи банку, где взял!" };
        public static readonly string[] AllJars = { "Все банки собрал... К машине бежит!" };
        public static readonly string[] CarStarting = { "Заводит! Держи его!", "Не дайте ему уехать!" };
        public static readonly string[] Escaped = { "Ушёл... Пчёлы этого не забудут.", "Уехал. Ну ничего, вернётся." };

        public static readonly string[] Ambulance =
            { "Скорая уже едет. Пчёлок надо уважать.", "Вот к чему неуважение приводит." };

        public static readonly string[] EscapeTimeout = { "Темнеет. Пчёлы тебя тут и оставят." };

        public static string Pick(string[] lines) => lines[Random.Range(0, lines.Length)];
    }
}
