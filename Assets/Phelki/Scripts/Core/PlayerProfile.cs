using System;
using UnityEngine;

namespace Phelki
{
    public enum Side
    {
        None = 0,
        Bee = 1,
        Human = 2
    }

    /// <summary>
    /// Профиль игрока. Пока хранится на телефоне; когда появится сервер,
    /// ответ на вопрос и мёд будут храниться там и переживут переустановку.
    /// </summary>
    [Serializable]
    public class PlayerProfile
    {
        const string Key = "phelki.profile.v1";
        public const int ChangeWindowSeconds = 600;

        public int side;
        public long answeredAt;
        public bool changedOnce;
        public int honey;
        public int bestSortieHoney;
        public int sorties;

        // Сторона людей
        public int escapeAttempts;
        public int escapeWins;
        public float bestEscapeTime; // 0 — ещё не сбегал

        static PlayerProfile _current;

        public static PlayerProfile Current
        {
            get
            {
                if (_current == null) Load();
                return _current;
            }
        }

        public Side Side => (Side)side;

        public static long Now => DateTimeOffset.UtcNow.ToUnixTimeSeconds();

        /// <summary>Можно один раз передумать в первые 10 минут после ответа.</summary>
        public bool CanChangeAnswer => answeredAt > 0 && !changedOnce && SecondsToChange > 0;

        public int SecondsToChange =>
            (int)Math.Max(0, ChangeWindowSeconds - (Now - answeredAt));

        public static void Load()
        {
            var json = PlayerPrefs.GetString(Key, "");
            _current = string.IsNullOrEmpty(json) ? null : JsonUtility.FromJson<PlayerProfile>(json);
            if (_current == null) _current = new PlayerProfile();
        }

        public void Answer(Side chosen)
        {
            if (Side == Side.None)
            {
                side = (int)chosen;
                answeredAt = Now;
            }
            else if (CanChangeAnswer && chosen != Side)
            {
                side = (int)chosen;
                changedOnce = true;
            }
            Save();
        }

        public void Save()
        {
            PlayerPrefs.SetString(Key, JsonUtility.ToJson(this));
            PlayerPrefs.Save();
        }

#if UNITY_EDITOR
        /// <summary>Для тестов в редакторе: снова показать вопрос.</summary>
        [UnityEditor.MenuItem("Phelki/Сбросить профиль (снова задать вопрос)")]
        static void ResetProfile()
        {
            PlayerPrefs.DeleteKey(Key);
            _current = null;
            Debug.Log("Профиль сброшен — при следующем запуске дед снова спросит.");
        }
#endif
    }
}
